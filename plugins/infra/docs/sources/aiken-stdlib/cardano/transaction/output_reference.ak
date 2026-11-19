use aiken/primitive/bytearray
use aiken/primitive/int
use cardano/transaction.{OutputReference}

pub fn compare(left: OutputReference, right: OutputReference) -> Ordering {
  when bytearray.compare(left.transaction_id, right.transaction_id) is {
    Equal -> int.compare(left.output_index, right.output_index)
    ordering -> ordering
  }
}
