use cardano/address.{Script, VerificationKey}
use cardano/address/credential.{compare}

// --------------------------------------------------------------------- compare

test compare_matrix() {
  and {
    (compare(Script(""), Script("")) == Equal)?,
    (compare(VerificationKey(""), VerificationKey("")) == Equal)?,
    (compare(Script(""), VerificationKey("")) == Less)?,
    (compare(VerificationKey(""), Script("")) == Greater)?,
    (compare(Script("01"), Script("02")) == Less)?,
    (compare(Script("02"), Script("01")) == Greater)?,
    (compare(VerificationKey("01"), VerificationKey("02")) == Less)?,
    (compare(VerificationKey("02"), VerificationKey("01")) == Greater)?,
  }
}
