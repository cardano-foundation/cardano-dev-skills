use aiken/crypto.{VerificationKeyHash}
use core/datum.{AggregateMessage, FeedVkh, Nodes}

pub fn check_nodes_multisig(
  node_feeds: AggregateMessage,
  node_feeds_count: Int,
  tx_signatories: List<VerificationKeyHash>,
  allowed_nodes: Nodes,
  required_node_signatures_count: Int,
) -> Bool {
  trace @"T6"

  go_check_nodes_multisig(
    node_feeds,
    node_feeds_count,
    tx_signatories,
    allowed_nodes,
    required_node_signatures_count,
    0,
  )
}

fn go_check_nodes_multisig(
  node_feeds: AggregateMessage,
  expected_count: Int,
  signers: List<VerificationKeyHash>,
  allowed_nodes: Nodes,
  required_node_signatures_count: Int,
  processed: Int,
) -> Bool {
  when node_feeds is {
    [] ->
      processed == expected_count && processed >= required_node_signatures_count
    [Pair(feed_vkh, _), ..rest] ->
      when consume_allowed(allowed_nodes, feed_vkh) is {
        None -> False
        Some(updated_allowed) ->
          when remove_signer(signers, feed_vkh) is {
            None -> False
            Some(updated_signers) ->
              go_check_nodes_multisig(
                rest,
                expected_count,
                updated_signers,
                updated_allowed,
                required_node_signatures_count,
                processed + 1,
              )
          }
      }
  }
}

fn consume_allowed(allowed_nodes: Nodes, feed_vkh: FeedVkh) -> Option<Nodes> {
  when allowed_nodes is {
    [] -> None
    [allowed, ..rest] ->
      if allowed == feed_vkh {
        Some(rest)
      } else {
        when consume_allowed(rest, feed_vkh) is {
          None -> None
          Some(tail) -> Some([allowed, ..tail])
        }
      }
  }
}

fn remove_signer(
  signers: List<VerificationKeyHash>,
  feed_vkh: FeedVkh,
) -> Option<List<VerificationKeyHash>> {
  when signers is {
    [] -> None
    [signer, ..rest] ->
      if signer == feed_vkh {
        Some(rest)
      } else {
        when remove_signer(rest, feed_vkh) is {
          None -> None
          Some(tail) -> Some([signer, ..tail])
        }
      }
  }
}
