# Data model of a Yaci Store analytics store

What the tables are, how they are partitioned, and where the grain surprises people. Column
lists below were read from `analytics-describe-table` on the hosted instance on 2026-09-07;
re-describe before relying on them, upstream adds columns between releases.

## What the store is

Yaci Store indexes the chain into PostgreSQL. The analytics store exports those tables to
Parquet files (or a DuckLake catalog) with Hive partitioning: daily tables live under
`<table>/date=YYYY-MM-DD/`, epoch tables under `<table>/epoch=N/`. A sandboxed DuckDB engine
reads the files and serves them under the table's plain name to the MCP tools and the REST
query API. Table names are the PostgreSQL names, singular: `block`, `transaction`,
`address_utxo`, `epoch_stake`, `reward`, `voting_procedure`.

## Freshness and scope

- A UTC day is exported once every row in it is older than the rollback window (about 12 h on
  mainnet) plus a margin, and the export runs one day behind that. In practice yesterday's data
  is present, today's is not. `analytics-list-tables` reports `dataAsOf` and the staleness in
  days; quote both in every answer.
- With live federation on (self-hosted, `yaci.store.analytics.query.live-data-enabled=true`) a
  table's `dataScope` is `historical+live` and its unified view reaches the chain tip; the
  current epoch's rows in epoch tables keep changing until the epoch closes. The hosted instance
  reports `historical` for every table.
- `analytics-address-balance` is the exception: it reads live PostgreSQL, so an address balance
  from it and a sum over yesterday's `address_utxo` legitimately differ.
- Mainnet only on the hosted instance. `cardano-network-info` returns the network, the protocol
  magic, slot length (1 s), epoch length (432,000 slots, 5 days), and the Byron genesis time.

## Partitions and pruning

Every daily table carries a `date` column, every epoch table an `epoch` column, and the engine
prunes files by that column. A `WHERE date >= ...` or `WHERE epoch BETWEEN ...` is the
difference between milliseconds and a scan of a table with a billion rows. Most daily tables
also carry `epoch`; filtering on it works through file statistics and is a few times slower
than `date`.

Trust the column list over the metadata. `describe-table` reports a `partitionColumn`; if that
column is not in `columns`, the metadata is stale for that table and a filter on it fails. Use
the `epoch` or `date` column that is present. Tables that report `NONE` or `UNKNOWN` are small;
filter on `epoch` anyway for the sake of the habit.

## Table families

Column names and types come from `analytics-describe-table` at query time; the full exporter
list is in `docs/sources/yaci-store/analytics/overview/page.mdx`. What follows is the grain of
each table and the columns whose meaning the describe output does not tell you.

Daily tables (partition `date`), largest first:

| Table | Grain | What to know |
|---|---|---|
| `address_utxo` | one row per asset per output (flattened) | `tx_hash` + `output_index` identify the output; `asset_unit` is `lovelace` or `policy_id || asset_name_hex`; `owner_addr` and `owner_stake_addr` both present on base addresses |
| `tx_input` | one row per spent output, partitioned by the day it was spent | `tx_hash` + `output_index` name the output consumed; `spent_tx_hash` and `spent_epoch` say when |
| `transaction_metadata` | one row per label per transaction | `body` is the metadata content, third-party text |
| `transaction` | one row per transaction | `fee` in lovelace; `invalid` marks phase-2 failures; `inputs`, `outputs`, `reference_inputs`, `collateral_inputs` are JSON strings, join the flattened tables instead; `treasury_donation` |
| `stake_address_balance` | one row per balance change, not a daily snapshot | |
| `assets` | mint and burn events | `quantity` positive for `mint_type = 'MINT'`, negative for `'BURN'`; `unit` is policy plus hex name |
| `block` | one row per block | `slot_leader` is the 56-hex pool id hash, the same value as `epoch_stake.pool_id`; `no_of_txs`, `total_fees` |
| `withdrawal` | reward withdrawals by stake address | `amount` in lovelace |
| `delegation`, `stake_registration`, `delegation_vote` | certificates | `address` is the stake address; `delegation_vote.drep_type` uses the `drep_dist` values |
| `pool`, `pool_registration`, `pool_retirement` | pool lifecycle | `pool.status`: `REGISTRATION`, `UPDATE`, `RETIRING` (certificate submitted, `retire_epoch` set), `RETIRED` (took effect) |
| `voting_procedure` | one row per vote cast; a voter can re-vote | `voter_type`: `DREP_KEY_HASH`, `DREP_SCRIPT_HASH`, `STAKING_POOL_KEY_HASH`, `CONSTITUTIONAL_COMMITTEE_HOT_KEY_HASH`, `CONSTITUTIONAL_COMMITTEE_HOT_SCRIPT_HASH`; `vote`: `YES`, `NO`, `ABSTAIN`; `idx` orders votes within a transaction |
| `gov_action_proposal` | one row per proposal | `tx_hash` + `idx` identify it; `details` is a JSON string; `anchor_url` is a third-party document |
| `datum`, `script`, `transaction_scripts`, `drep`, `drep_registration`, `committee_registration`, `committee_deregistration`, `protocol_params_proposal`, `invalid_transaction`, `rollback`, `cost_model` | small or self-explanatory | |

Epoch tables (partition `epoch`):

| Table | Grain | What to know |
|---|---|---|
| `epoch_stake` | one row per delegating stake address per epoch | `amount` is the active stake; `pool_id` is the pool hash |
| `reward` | one row per reward per stake address per epoch earned | `epoch` is when it was earned, `spendable_epoch` when it can be withdrawn (member and leader: `epoch + 2`); `type`: `member`, `leader`, `treasury`, `reserves` |
| `adapot` | one row per epoch, the pots at the boundary | `treasury`, `reserves`, `fees`, `deposits_stake`, `distributed_rewards`, `circulation`, all lovelace |
| `drep_dist` | one row per DRep per epoch | `amount` is voting power; `drep_type`: `ADDR_KEYHASH`, `SCRIPTHASH`, and the predefined `ABSTAIN`, `NO_CONFIDENCE` with a null `drep_id` |
| `gov_action_proposal_status` | one row per proposal per epoch it was tracked | `status` seen: `ACTIVE`, `RATIFIED`, `EXPIRED`; `voting_stats` is a JSON string with the per-body tallies and approval ratios |
| `epoch_param` | one row per epoch | `params` is a JSON string with snake_case keys (`max_tx_size`, `gov_action_lifetime`, `protocol_major_ver`) |
| `epoch`, `instant_reward`, `mir`, `reward_rest`, `unclaimed_reward_rest`, `committee`, `committee_member`, `committee_state`, `constitution`, `gov_epoch_activity` | small | |

Enum values above are what a `GROUP BY` returned on the verification date. The `describe-table`
hints list some of them and miss others; when a filter on an enum returns nothing, group by the
column and look.

## Grain and semantics

- `address_utxo` is flattened: an output holding ada and two tokens is three rows sharing
  `tx_hash` and `output_index`. Count outputs with `COUNT(DISTINCT (tx_hash, output_index))`,
  never `COUNT(*)`. Every output has exactly one `asset_unit = 'lovelace'` row; tokens are
  `policy_id || asset_name_hex`.
- Unspent means "no matching row in `tx_input`". The anti-join is valid only within one
  `dataScope`, because an output created in Parquet can be spent in the live tail. On the hosted
  instance a full-history anti-join for a busy address exceeds the 30 s limit; window both
  sides by `date` (an output cannot be spent before it exists, so the same window on `tx_input`
  is exact), or use `analytics-address-balance` for the balance now.
- `transaction.inputs` and `outputs` are JSON strings. Join `address_utxo` and `tx_input`
  instead of parsing them.
- `reward.epoch` is the epoch the reward was earned. Member and leader rewards become spendable
  at `epoch + 2`, and `adapot.distributed_rewards` at `epoch + 2` equals the sum of member and
  leader rewards for `epoch` to the lovelace. Use that as a cross-check.
- `adapot` values are the pots at the epoch boundary. A treasury delta between two epochs is
  income minus withdrawals; `withdrawal` is reward withdrawals by stake addresses, a different
  thing.
- `gov_action_proposal_status` has one row per proposal per epoch. Filter to the latest epoch
  for "current" and to a specific epoch for "as of". `voting_stats` holds `cc_yes`,
  `cc_no`, `cc_abstain`, `cc_approval_ratio`, `drep_yes_vote_stake`, `drep_no_vote_stake`,
  `drep_approval_ratio`, `spo_*` equivalents, and the do-not-vote and auto-abstain stakes.
- A proposal expires after `proposed epoch + gov_action_lifetime` (6 on mainnet on the
  verification date; read it from `epoch_param.params`).
- `voting_procedure` records every vote; a voter can re-vote. "Current position" is the latest
  row per (`voter_type`, `voter_hash`) by `slot`, then `idx`.
- `drep_dist` includes the two predefined DReps (`ABSTAIN`, `NO_CONFIDENCE`) with a null
  `drep_id`. Exclude them when counting registered DReps; include them when summing the electorate.
- `stake_address_balance` is an event log of balance changes, not an end-of-day snapshot.
- `assets.quantity` is `BIGINT` and saturates at 2^63-1 for the largest mints.
- All ada amounts are lovelace integers. Sums over big tables need `DECIMAL(38,0)`; DuckDB
  widens automatically for `SUM`, but divide only at presentation.

## Types and rendering

- `DATE` comes back as a `[year, month, day]` array through the MCP tool. `CAST(date AS VARCHAR)`
  gives `2026-09-06`.
- `block_time` is `TIMESTAMP WITH TIME ZONE` and comes back as epoch seconds.
  `strftime(block_time, '%Y-%m-%d %H:%M:%SZ')` renders UTC.
- `CURRENT_DATE - INTERVAL 30 DAY` works and keeps a query valid over time.
- `json_extract_string(col, '$.key')`, `json_keys(col)`, and `UNNEST` work on the JSON string
  columns.

## Limits and the error checklist

The validator rejects before execution and says why: more than one statement (a trailing
semicolon counts), anything but `SELECT`/`WITH`, `SHOW`/`DESCRIBE`/`information_schema`, file or
URL literals, blocked functions. The engine fails after execution and says only "Query execution
failed. Check query syntax and filters." When you see that:

1. A column name is wrong. Re-run `analytics-describe-table` and compare, including the
   partition column (see above).
2. The query exceeded 30 s. Add or tighten the partition filter, drop the full-history
   anti-join, aggregate instead of listing.
3. A function is unavailable in the sandbox. Try the plain-SQL form.
4. An enum literal is wrong. Group by the column to see the real values.

The result carries `row_count`, `truncated`, `max_rows` (10,000), and `execution_time_ms`.
`truncated: true` means aggregate or narrow, not page: there is no offset the validator lets
through reliably.
