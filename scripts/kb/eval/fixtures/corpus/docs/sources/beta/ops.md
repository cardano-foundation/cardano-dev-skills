# Harbor operations

Operational guidance for running Harbor.

## Deployment

Deploy three nodes behind a load balancer for a minimal highly available cluster.

## Sizing

Plan one core and two gigabytes of memory per ten thousand messages per second.

## Configuration file

The server reads its settings from a YAML configuration file on startup.

## Ports

The server listens on one client port and one peer port.

## TLS

Enable TLS for client and peer traffic by pointing at a certificate and key.

## Certificate renewal

Reload certificates with a signal; no restart is needed.

## Key rotation

Rotate the signing key by adding the new key, waiting a full token lifetime, then removing the old key.

## Signing keys

Signing keys are stored in a file readable only by the service account.

## Access control

Roles grant send, receive or administer rights per queue prefix.

## Monitoring

Export metrics in the Prometheus format from the metrics port.

## Alerts

Alert on queue depth growth, dead letter arrivals and replica lag.

## Backups

Snapshot the data directory while the node is stopped or use the online snapshot call.

## Restoring backups

Restore a snapshot into an empty data directory and start the node.

## Rolling upgrade

Upgrade one node at a time and wait for replicas to catch up between nodes.

## Scaling out

Add nodes and rebalance partitions with the rebalance command.

## Scaling in

Drain a node before removing it so that its partitions move elsewhere.

## Disk full

When a disk fills the node rejects writes and keeps serving reads.

## Capacity planning

Track the growth of depth and retention to size disks ahead of time.

## Incident response

Collect logs and metrics, then open an incident record before restarting nodes.

## Runbook index

The runbooks cover leader loss, disk full and certificate expiry.

## Leader loss

Check the lease metric and wait out the lease before forcing an election.

## Log levels

Raise the log level at runtime with the admin endpoint.

## Support contacts

Reach the maintainers through the project tracker.
