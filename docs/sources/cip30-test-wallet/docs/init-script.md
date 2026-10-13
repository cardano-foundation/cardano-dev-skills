# init-script

`init-script` writes the test wallet as one JavaScript file: the page bundle followed by the call that installs a configured wallet. It is meant for browser drivers that take an init script by path and run it before the page's own scripts, Playwright MCP's `--init-script` among them. Inside Playwright tests the fixture does the same job and is the better choice.

```bash
npx cip30-test-wallet init-script [--options <file.json>] [--network 0|1] [--name <name>] [--mnemonic-env <VAR>] [--out <file.js>]
```

| Flag | Meaning |
|---|---|
| `--options <file.json>` | Wallet options as JSON, the same shape as the fixture's `walletOptions`: `name`, `networkId`, `utxos`, `foreignUtxos`, `quirks`, `stakeRegistered` and the rest |
| `--network 0\|1` | Overrides `networkId`. 0 is testnet, 1 is mainnet |
| `--name <name>` | Overrides the key under `window.cardano`, `chw` by default |
| `--mnemonic-env <VAR>` | Reads the mnemonic from this environment variable, so it never appears on the command line or in shell history |
| `--out <file.js>` | Writes the script to this file. Without it the script goes to stdout |

Flags win over the options file. Without any flag the script installs the default wallet on testnet. Exit 0 on success, 2 when an argument or the options file is invalid.

```json
{ "networkId": 0, "utxos": [{ "lovelace": 50000000 }], "quirks": { "signHangs": true } }
```

## Playwright MCP

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest", "--isolated", "--init-script", "/absolute/path/to/wallet.js"]
    }
  }
}
```

Tested with `@playwright/mcp` 0.0.82 in Chrome against the demo dApp under its strict content security policy: detection, connect, `signTx` plus `submitTx`, `signData`, a `signHangs` quirk from the options file and its release through `window.__chw`. After changing options, regenerate the file and restart the MCP server.

## `window.__chw`

Without the fixture there is no `wallet` handle. The same controls are on `window.__chw`, reachable with any evaluate tool:

| Member | Meaning |
|---|---|
| `journal` | Array of `{ method, args, result?, error?, t }`, one entry per CIP-30 call, key material never included |
| `setQuirk(name, value)` | Flips a quirk at runtime. Throws for an unknown name and for the install-time quirks `lateInjection` and `answersEveryKey` |
| `release('signTx')`, `reject('signTx')` | Ends a hanging `signTx` and returns how many calls it settled |

Like the fixture's journal, this state lives in the page and resets on every navigation. Read the journal before the agent navigates away.

## Keys

The file holds the wallet's extended private keys in plain text. Use a test mnemonic only and keep the file out of version control.
