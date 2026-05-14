use cardano/transaction.{OutputReference}
use cardano/transaction/output_reference.{compare}

// --------------------------------------------------------------------- compare

test compare_matrix() {
  and {
    (compare(OutputReference("", 0), OutputReference("", 0)) == Equal)?,
    (compare(OutputReference("00", 42), OutputReference("00", 42)) == Equal)?,
    (compare(OutputReference("00", 0), OutputReference("01", 0)) == Less)?,
    (compare(OutputReference("01", 0), OutputReference("00", 0)) == Greater)?,
    (compare(OutputReference("00", 42), OutputReference("01", 14)) == Less)?,
    (compare(OutputReference("01", 14), OutputReference("00", 42)) == Greater)?,
    (compare(OutputReference("", 42), OutputReference("", 14)) == Greater)?,
    (compare(OutputReference("", 14), OutputReference("", 42)) == Less)?,
  }
}
