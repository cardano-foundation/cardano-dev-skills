use cardano/address.{Credential}
use cardano/certificate.{Certificate, RegisterCredential}
use cardano/transaction.{Transaction}

validator issue {
  withdraw(redeemer: Int, _account: Credential, _self: Transaction) {
    trace @"withdraw"
    redeemer == 100
  }

  // Both validators here are withdraw-0. A withdraw-0 cannot appear in a
  // transaction until its stake credential is REGISTERED on chain, and a Conway
  // registration certificate executes the script under the PUBLISH purpose —
  // so without this handler the `else` branch below rejects the registration
  // and the substandard can never be used at all.
  //
  // Registration ONLY. Deregistration is deliberately refused: an unregistered
  // credential cannot be withdrawn against, so allowing anyone to deregister
  // would let a third party disable every token governed by this substandard.
  // Same shape as the core validators (upstream transfer/third_party/unfracking).
  publish(_r: Data, c: Certificate, _s: Transaction) {
    when c is {
      RegisterCredential { .. } -> True
      _ -> False
    }
  }

  else(_) {
    trace @"fallback"
    False
  }
}

validator transfer {
  withdraw(redeemer: Int, _account: Credential, _self: Transaction) {
    trace @"withdraw"
    redeemer == 200
  }

  // Both validators here are withdraw-0. A withdraw-0 cannot appear in a
  // transaction until its stake credential is REGISTERED on chain, and a Conway
  // registration certificate executes the script under the PUBLISH purpose —
  // so without this handler the `else` branch below rejects the registration
  // and the substandard can never be used at all.
  //
  // Registration ONLY. Deregistration is deliberately refused: an unregistered
  // credential cannot be withdrawn against, so allowing anyone to deregister
  // would let a third party disable every token governed by this substandard.
  // Same shape as the core validators (upstream transfer/third_party/unfracking).
  publish(_r: Data, c: Certificate, _s: Transaction) {
    when c is {
      RegisterCredential { .. } -> True
      _ -> False
    }
  }

  else(_) {
    trace @"fallback"
    False
  }
}
