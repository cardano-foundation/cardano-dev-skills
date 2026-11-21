use aiken/primitive/bytearray
use cardano/address/credential
use cardano/governance.{
  ConstitutionalCommitteeMember, DelegateRepresentative, StakePool, Voter,
}

pub fn compare(left: Voter, right: Voter) -> Ordering {
  when left is {
    ConstitutionalCommitteeMember(left) ->
      when right is {
        ConstitutionalCommitteeMember(right) -> credential.compare(left, right)
        _ -> Less
      }
    DelegateRepresentative(left) ->
      when right is {
        DelegateRepresentative(right) -> credential.compare(left, right)
        ConstitutionalCommitteeMember(_) -> Greater
        _ -> Less
      }
    StakePool(left) ->
      when right is {
        StakePool(right) -> bytearray.compare(left, right)
        _ -> Greater
      }
  }
}
