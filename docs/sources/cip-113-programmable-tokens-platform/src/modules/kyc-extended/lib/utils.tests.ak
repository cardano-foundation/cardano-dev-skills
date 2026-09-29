use cardano/address.{Address, Inline, Pointer, Script, VerificationKey}
use cardano/assets
use cardano/transaction.{NoDatum, Output}
use utils.{extract_recipient_witnesses}

// ─── Test helpers ───────────────────────────────────────────────────────────

const prog_cred = VerificationKey(#"aabbccdd")

const pkh_alice = #"0102030405060708091011121314151617181920212223242526272829"

const pkh_bob = #"1112131415161718192021222324252627282930313233343536373839"

const script_hash = #"2122232425262728292031323334353637383940414243444546474849"

const other_cred = VerificationKey(#"99887766")

fn make_output(pay_cred, stake_cred) -> Output {
  Output {
    address: Address { payment_credential: pay_cred, stake_credential: stake_cred },
    value: assets.zero,
    datum: NoDatum,
    reference_script: None,
  }
}

// ─── extract_recipient_witnesses tests ──────────────────────────────────────

test extract_single_vkey_output() {
  let output =
    make_output(
      prog_cred,
      Some(Inline(VerificationKey(pkh_alice))),
    )
  extract_recipient_witnesses([output], prog_cred) == [pkh_alice]
}

test extract_multiple_outputs() {
  let out_alice =
    make_output(prog_cred, Some(Inline(VerificationKey(pkh_alice))))
  let out_bob =
    make_output(prog_cred, Some(Inline(VerificationKey(pkh_bob))))
  extract_recipient_witnesses([out_alice, out_bob], prog_cred) == [
    pkh_alice,
    pkh_bob,
  ]
}

test extract_mixed_prog_base_and_other() {
  let out_prog =
    make_output(prog_cred, Some(Inline(VerificationKey(pkh_alice))))
  let out_other =
    make_output(other_cred, Some(Inline(VerificationKey(pkh_bob))))
  // Only the prog_base output contributes a witness
  extract_recipient_witnesses([out_prog, out_other], prog_cred) == [pkh_alice]
}

test extract_script_stake_credential() {
  let out =
    make_output(prog_cred, Some(Inline(Script(script_hash))))
  extract_recipient_witnesses([out], prog_cred) == [script_hash]
}

test extract_no_matching_outputs() {
  let out = make_output(other_cred, Some(Inline(VerificationKey(pkh_alice))))
  extract_recipient_witnesses([out], prog_cred) == []
}

test extract_empty_outputs() {
  extract_recipient_witnesses([], prog_cred) == []
}

test extract_fails_on_missing_stake_credential() fail {
  let out = make_output(prog_cred, None)
  extract_recipient_witnesses([out], prog_cred) == []
}

test extract_fails_on_non_inline_stake_credential() fail {
  // Pointer stake credential — not Inline; should fail
  let out =
    make_output(
      prog_cred,
      Some(Pointer { slot_number: 1, transaction_index: 2, certificate_index: 3 }),
    )
  extract_recipient_witnesses([out], prog_cred) == []
}
