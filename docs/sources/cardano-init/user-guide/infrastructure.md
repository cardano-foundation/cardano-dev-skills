# Infrastructure providers

The **infrastructure** role uses [`cardano-up`](https://github.com/blinklabs-io/cardano-up), which needs Docker. It is the only role that accepts **several tools**: repeat the `--infra` flag to select more than one. All selected providers run together in one `cardano-up` context for the project, inside a single `infra/` component. Each provider writes its connection details to the project's `.env`, and the off-chain component reads them from there.

| Provider | Flag | Publishes to `.env` | Upstream |
|----------|------|---------------------|----------|
| Kupo | `--infra kupo` | `INDEXER_URL` | https://github.com/CardanoSolutions/kupo |
| Ogmios | `--infra ogmios` | `OGMIOS_URL` | https://ogmios.dev |
| Dolos | `--infra dolos` | `DOLOS_GRPC_URL`, `NODE_SOCKET_PATH` | https://github.com/txpipe/dolos |
| Tx Submit API | `--infra tx-submit-api` | `TX_SUBMIT_URL` | https://github.com/blinklabs-io/tx-submit-api |
| Cardano Node | `--infra cardano-node` | `NODE_SOCKET_PATH` | https://github.com/IntersectMBO/cardano-node |
| Cardano Node API | `--infra cardano-node-api` | `CARDANO_NODE_API_URL` | https://github.com/blinklabs-io/cardano-node-api |
| Dingo | `--infra dingo` | `INDEXER_URL`, `NODE_SOCKET_PATH` | https://github.com/blinklabs-io/dingo |

```bash
# An indexer (Kupo) and a query bridge (Ogmios) over one node (cardano-up adds cardano-node):
cardano-init --name my-protocol --off-chain meshjs --infra kupo --infra ogmios

# Start the services and write their connection details to .env (keeps running):
just -f infra/Justfile dev
```

- **Dolos and Dingo are nodes themselves.** They need no separate `cardano-node`, and each provides its own `NODE_SOCKET_PATH`. Dingo also serves a Blockfrost-compatible API as `INDEXER_URL`.
- **One chain index per project.** `.env` has one `INDEXER_URL`, so select either Kupo or Dingo.
