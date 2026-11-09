package ouroboros

import (
	"context"
	"errors"
	"fmt"
	"net"
	"time"

	gouroboros "github.com/blinklabs-io/gouroboros"
	"github.com/blinklabs-io/gouroboros/protocol"
	"github.com/blinklabs-io/gouroboros/protocol/localstatequery"
	"github.com/blinklabs-io/gouroboros/protocol/localtxsubmission"
)

// dialFunc opens the transport to the node. Tests replace it to talk to a
// scripted peer instead of a socket.
type dialFunc func(ctx context.Context) (net.Conn, error)

// session owns at most one node-to-client connection and runs one operation
// on it at a time. A connection is opened by the first operation that needs
// it and is discarded after any failure, so a node restart costs only the
// operations in flight at the time.
type session struct {
	dial             dialFunc
	networkMagic     uint32
	handshakeTimeout time.Duration
	queryTimeout     time.Duration
	submitTimeout    time.Duration

	// gate serializes operations: sending to it takes the turn, receiving
	// from it gives the turn back. Unlike a mutex, a caller waiting for its
	// turn can give up when its context ends. LocalStateQuery keeps the
	// acquired ledger state on the connection, so an acquire and the queries
	// that read it must not interleave with another operation's. Every field
	// below is read and written only by the goroutine holding the turn.
	gate   chan struct{}
	raw    net.Conn
	conn   *gouroboros.Connection
	health *connHealth
}

// connHealth reports when a connection has failed or shut down, and why.
type connHealth struct {
	done chan struct{} // closed once the connection fails or shuts down
	err  error         // the first error the connection reported; set before done closes
}

func newSession(dial dialFunc, networkMagic uint32, handshakeTimeout, queryTimeout, submitTimeout time.Duration) *session {
	return &session{
		dial:             dial,
		networkMagic:     networkMagic,
		handshakeTimeout: handshakeTimeout,
		queryTimeout:     queryTimeout,
		submitTimeout:    submitTimeout,
		gate:             make(chan struct{}, 1),
	}
}

// errNodeClosedConnection explains an operation that failed because the node
// closed the connection without the connection reporting an error.
var errNodeClosedConnection = errors.New("the node closed the connection")

// errTransactionRejected marks submission failures the node decided on, as
// opposed to transport failures. The connection stays usable after them.
var errTransactionRejected = errors.New("node rejected the transaction")

// run executes op on a live connection, dialing and handshaking first if
// needed. If ctx ends before op returns, the transport is closed to unblock
// op and ctx.Err is returned. Any failure other than a transaction rejection
// discards the connection, since the mini-protocol state it leaves behind is
// unknown; the next operation reconnects. An operation waiting for its turn
// returns ctx.Err as soon as ctx ends.
func (s *session) run(ctx context.Context, op func(*gouroboros.Connection) error) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	select {
	case s.gate <- struct{}{}:
	case <-ctx.Done():
		return ctx.Err()
	}
	defer func() { <-s.gate }()
	// ctx may have ended while this operation waited for its turn. Starting
	// now would close a healthy connection to abandon work nobody wants.
	if err := ctx.Err(); err != nil {
		return err
	}

	if s.health != nil {
		select {
		case <-s.health.done:
			_ = s.closeLocked()
		default:
		}
	}
	if s.raw == nil {
		raw, err := s.dial(ctx)
		if err != nil {
			return fmt.Errorf("connect to node: %w", err)
		}
		s.raw = raw
	}

	type outcome struct {
		conn   *gouroboros.Connection
		health *connHealth
		err    error
	}
	raw, conn := s.raw, s.conn
	done := make(chan outcome, 1)
	go func() {
		o := outcome{conn: conn}
		if o.conn == nil {
			o.conn, o.health, o.err = s.handshake(raw)
			if o.err != nil {
				done <- o
				return
			}
		}
		o.err = op(o.conn)
		done <- o
	}()

	var o outcome
	select {
	case o = <-done:
	case <-ctx.Done():
		// Closing the transport makes the node calls op is blocked in fail.
		_ = raw.Close()
		o = <-done
		o.err = ctx.Err()
	}
	if o.health != nil {
		s.conn, s.health = o.conn, o.health
	}
	if o.err != nil && (ctx.Err() != nil || !errors.Is(o.err, errTransactionRejected)) {
		// A mini-protocol reports only that it is shutting down when the
		// connection under it fails: a query timeout, an oversized reply or
		// the node closing the socket. The connection is then already
		// shutting itself down and reports why on the way. Closing it first
		// could discard that report, so wait for it, within a bound in case
		// it never comes.
		shutDown := ctx.Err() == nil && errors.Is(o.err, protocol.ErrProtocolShuttingDown)
		selfClosed := false
		if shutDown && s.health != nil {
			timer := time.NewTimer(shutdownReportWait)
			select {
			case <-s.health.done:
				selfClosed = true
			case <-ctx.Done():
			case <-timer.C:
			}
			timer.Stop()
		}
		cause := s.closeLocked()
		switch {
		case shutDown && cause != nil:
			o.err = fmt.Errorf("%w: connection failed: %w", o.err, cause)
		case selfClosed:
			// A connection that shuts itself down without an error was
			// closed by the node. gouroboros reports no error when every
			// protocol looks idle, which a protocol the closed socket has
			// already stopped does.
			o.err = fmt.Errorf("%w: %w", o.err, errNodeClosedConnection)
		}
	}
	return o.err
}

// shutdownReportWait bounds how long run waits for a failed connection to
// report why it failed.
const shutdownReportWait = time.Second

// handshake opens a node-to-client connection over raw. It touches no
// session state, so it can run while the caller waits on its context.
func (s *session) handshake(raw net.Conn) (*gouroboros.Connection, *connHealth, error) {
	// The node-to-client handshake has no timeout of its own and the muxer's
	// read timeout is off, so a peer that accepts the socket but never
	// answers would block an operation without a deadline forever. Closing
	// the transport makes the handshake fail.
	timer := time.AfterFunc(s.handshakeTimeout, func() { _ = raw.Close() })
	conn, err := gouroboros.NewConnection(
		gouroboros.WithConnection(raw),
		gouroboros.WithNetworkMagic(s.networkMagic),
		gouroboros.WithNodeToNode(false),
		// Local queries can legitimately take minutes (a UTxO-by-address
		// scan on mainnet), so the muxer must not time out between segments.
		// Callers bound operations with their context instead.
		gouroboros.WithMuxerSegmentReadTimeout(0),
		gouroboros.WithLocalStateQueryConfig(localstatequery.NewConfig(
			localstatequery.WithQueryTimeout(s.queryTimeout),
		)),
		gouroboros.WithLocalTxSubmissionConfig(localtxsubmission.NewConfig(
			localtxsubmission.WithTimeout(s.submitTimeout),
		)),
	)
	if !timer.Stop() {
		// The timer closed the transport, so even a handshake that finished
		// at the same moment left an unusable connection.
		if err == nil {
			_ = conn.Close()
		}
		return nil, nil, fmt.Errorf("node-to-client handshake: no answer within %v", s.handshakeTimeout)
	}
	if err != nil {
		return nil, nil, fmt.Errorf("node-to-client handshake: %w", err)
	}
	health := &connHealth{done: make(chan struct{})}
	go func() {
		// The connection owns its error channel and closes it on shutdown.
		// A node that closes the socket while every protocol is idle shuts
		// the connection down without reporting an error, so the close
		// marks the connection failed as well as the first error does.
		defer close(health.done)
		if err, ok := <-conn.ErrorChan(); ok {
			health.err = err
		}
	}()
	return conn, health, nil
}

// closeLocked tears down the current connection, if any, and returns the
// first error the connection reported, if it reported one.
func (s *session) closeLocked() error {
	if s.raw != nil {
		_ = s.raw.Close()
	}
	var cause error
	if s.conn != nil {
		// Close returns after the connection's error channel is closed, so
		// the health watcher has finished.
		_ = s.conn.Close()
		<-s.health.done
		cause = s.health.err
	}
	s.raw, s.conn, s.health = nil, nil, nil
	return cause
}

// close releases the connection. The session stays usable and reconnects on
// the next operation.
func (s *session) close() {
	s.gate <- struct{}{}
	defer func() { <-s.gate }()
	_ = s.closeLocked()
}

// query acquires the node's current ledger state, runs fn against it and
// releases it, so every operation reads the tip as of its own start rather
// than a snapshot left over from an earlier one.
func (s *session) query(ctx context.Context, fn func(*localstatequery.Client) error) error {
	return s.run(ctx, func(conn *gouroboros.Connection) error {
		client := conn.LocalStateQuery().Client
		if err := client.AcquireVolatileTip(); err != nil {
			return fmt.Errorf("acquire ledger state: %w", err)
		}
		err := fn(client)
		if releaseErr := client.Release(); err == nil && releaseErr != nil {
			err = fmt.Errorf("release ledger state: %w", releaseErr)
		}
		return err
	})
}
