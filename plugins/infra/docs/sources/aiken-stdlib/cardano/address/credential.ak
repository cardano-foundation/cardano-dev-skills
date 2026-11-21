use aiken/primitive/bytearray
use cardano/address.{Credential, Script, VerificationKey}

pub fn compare(left: Credential, right: Credential) -> Ordering {
  when left is {
    Script(left) ->
      when right is {
        Script(right) -> bytearray.compare(left, right)
        _ -> Less
      }
    VerificationKey(left) ->
      when right is {
        Script(_) -> Greater
        VerificationKey(right) -> bytearray.compare(left, right)
      }
  }
}
