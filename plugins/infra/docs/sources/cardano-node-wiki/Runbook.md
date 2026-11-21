
# Get the address for a verification key

```
cardano-cli address build \
  --testnet-magic 42 \
  --payment-verification-key-file $VERIFICATION_KEY_FILE
```

# Get the UTxOs for an address

```
CARDANO_NODE_SOCKET_PATH=example/main.sock \
cardano-cli query utxo \
  --testnet-magic 42 \
  --address $ADDRESS
```
