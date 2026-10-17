# Scalus reusable outer loop

This complete Scalus 1.0.0 example exposes `balanceWith`, which accepts a fresh builder provider, typed `DiffHandler` output computation, and a caller-owned bound. `runExample` supplies the refund handler and preserves the distinct `NonConvergent` error.

## Complete source


```scala
import scalus.cardano.ledger.{Transaction, Value}
import scalus.cardano.txbuilder.{DiffHandler, TxBalancingError}

object OuterLoop:
  final case class NonConvergent(bound: Int)
      extends RuntimeException(s"fee did not converge in $bound passes")

  val refundHandler: DiffHandler = (diff: Value, candidate: Transaction) =>
    // Production code replaces the designated refund output using diff, then returns the candidate.
    Right(candidate)

  type BuilderProvider =
    (Transaction, DiffHandler) => Either[TxBalancingError, Transaction]

  def balanceWith(
      initial: Transaction,
      builderProvider: BuilderProvider,
      computeOutputs: DiffHandler,
      bound: Int
  ): Either[Throwable, Transaction] =
    // Delayed redeemer and datum builders must run before min-UTxO and this balance loop.
    def loop(previous: Transaction, pass: Int): Either[Throwable, Transaction] =
      if pass > bound then Left(NonConvergent(bound))
      else
        // builderProvider must allocate a fresh builder while retaining the pinned fixture UTxOs.
        builderProvider(previous, computeOutputs) match
          case Left(error)                         => Left(RuntimeException(error.toString))
          case Right(candidate) if candidate == previous => Right(candidate)
          case Right(candidate)                    => loop(candidate, pass + 1)
    loop(initial, 1)

  def runExample(
      initial: Transaction,
      builderProvider: BuilderProvider,
      bound: Int = 8
  ): Either[Throwable, Transaction] =
    balanceWith(initial, builderProvider, refundHandler, bound)
```


## Run or check

```sh
nix build .#checks.x86_64-linux.example-scalus-diffhandler
```
