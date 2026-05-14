use cardano/address.{Script}
use cardano/governance.{
  ConstitutionalCommitteeMember, DelegateRepresentative, StakePool,
}
use cardano/governance/voter.{compare}

// --------------------------------------------------------------------- compare

test compare_matrix() {
  let cc0 = ConstitutionalCommitteeMember(Script("0"))
  let cc1 = ConstitutionalCommitteeMember(Script("1"))

  let drep0 = DelegateRepresentative(Script("0"))
  let drep1 = DelegateRepresentative(Script("1"))

  let spo0 = StakePool("0")
  let spo1 = StakePool("1")

  and {
    (compare(cc0, cc0) == Equal)?,
    (compare(cc0, cc1) == Less)?,
    (compare(cc1, cc0) == Greater)?,
    (compare(drep0, drep0) == Equal)?,
    (compare(drep0, drep1) == Less)?,
    (compare(drep1, drep0) == Greater)?,
    (compare(spo0, spo0) == Equal)?,
    (compare(spo0, spo1) == Less)?,
    (compare(spo1, spo0) == Greater)?,
    (compare(cc0, drep0) == Less)?,
    (compare(cc0, drep1) == Less)?,
    (compare(cc0, spo0) == Less)?,
    (compare(cc0, spo1) == Less)?,
    (compare(drep0, cc0) == Greater)?,
    (compare(drep0, cc1) == Greater)?,
    (compare(drep0, spo0) == Less)?,
    (compare(drep0, spo1) == Less)?,
    (compare(spo0, cc0) == Greater)?,
    (compare(spo0, cc1) == Greater)?,
    (compare(spo0, drep0) == Greater)?,
    (compare(spo0, drep1) == Greater)?,
  }
}
