//// Tx validity interval checks:
//// 1. tx validity interval should have an upper limit, after which tx could not be submitted, because we want signatures to be expirable.
//// 2. tx validity interval should have a lower limit, because we want to guarantee that the tx is produced after a certain moment in time.
//// 3. tx validity interval should have a fixed length, which is the time measurement absolute uncertainty.

use aiken/interval.{Interval, IntervalBound}
use cardano/transaction.{ValidityRange}
use ext/aiken/time.{PosixTime, PosixTimeDiff}

/// Get the middle of tx validity interval and check time accuracy
pub fn get_current_time(
  time_accuracy: PosixTimeDiff,
  tx_validity_range: ValidityRange,
) -> PosixTime {
  trace @"T4"

  let Interval { lower_bound, upper_bound } = tx_validity_range
  expect interval.Finite(start) = lower_bound.bound_type
  expect interval.Finite(end) = upper_bound.bound_type

  let validity_range_size: PosixTimeDiff = end - start
  expect validity_range_size <= time_accuracy

  ( end + start ) / 2
}
