# Compatible Wallets

:::warning
GovTool requires Cardano wallets to have upgraded to CIP-95 to be able to connect and share governance data, thus some existing Cardano wallets might not work.
:::

GovTool does not keep a fixed list of allowed wallets: any wallet that supports and enables [CIP-95](https://github.com/cardano-foundation/CIPs/tree/master/CIP-0095) can connect. If your wallet is not compatible, GovTool shows one of these errors when you try to connect:

* "Your wallet does not support the required CIP-30 extension, CIP-95."
* "Your wallet did not enable the needed CIP-95 functions during connection."

The status of individual wallets below is maintained manually and may change as wallets release updates.

### Mainnet Compatible Wallets (`gov.tools`)

Wallets which are working with GovTool on Mainnet.

<table><thead><tr><th>Wallet</th><th width="206">Download link</th><th>Status</th></tr></thead><tbody><tr><td><strong>Eternl</strong></td><td><a href="https://chromewebstore.google.com/detail/eternl/kmhcihpebfmpgmihbkipmjlmmioameka">visit site</a></td><td><mark style="color:green;background-color:green;">Online</mark></td></tr><tr><td><strong>Lace</strong></td><td><a href="https://chromewebstore.google.com/detail/lace/gafhhkghbfjjkeiendhlofajokpaflmk">visit site</a></td><td><mark style="color:green;background-color:green;">Online</mark></td></tr><tr><td><strong>NuFi</strong></td><td><a href="https://chromewebstore.google.com/detail/nufi/gpnihlnnodeiiaakbikldcihojploeca">visit site</a></td><td><mark style="color:green;background-color:green;">Online</mark></td></tr><tr><td><strong>Vespr</strong></td><td><a href="https://vespr.xyz/">visit site</a></td><td><mark style="color:green;background-color:green;">Online</mark> </td></tr><tr><td><strong>Typhon</strong></td><td><a href="https://chromewebstore.google.com/detail/typhon-wallet/kfdniefadaanbjodldohaedphafoffoh">visit site</a></td><td><mark style="color:green;background-color:green;">Online</mark></td></tr><tr><td><strong>Yoroi</strong></td><td><a href="https://chromewebstore.google.com/detail/yoroi/ffnbelfdoeiohenkjibnmadjiehjhajb">visit site</a></td><td><mark style="color:green;background-color:green;">Online</mark></td></tr><tr><td><strong>Ledger (hardware)</strong></td><td><a href="https://www.ledger.com/">visit site</a></td><td><mark style="color:green;background-color:green;">Compatible <strong>*(see note)</strong></mark></td></tr><tr><td><strong>Trezor (hardware)</strong></td><td><a href="https://trezor.io/">visit site</a></td><td><mark style="color:green;background-color:green;">Compatible <strong>**(see note)</strong></mark></td></tr><tr><td><strong>Keystone (hardware)</strong></td><td><a href="https://keyst.one/">visit site</a></td><td><mark style="color:green;background-color:green;">Compatible</mark></td></tr><tr><td><strong>Flint</strong></td><td>N/A</td><td><mark style="color:red;background-color:red;">Will not progress</mark> (see <a href="https://x.com/FlintWallet/status/1828184961960308832?t=0eIBBMnAY5feMTOlojFlSg&s=19">announcement</a>)</td></tr><tr><td><strong>Nami</strong></td><td>N/A</td><td><mark style="color:red;background-color:red;">Will not progress</mark> - Nami users are encouraged to upgrade to Lace for governance functionality - <a href="https://www.lace.io/blog/a-guide-to-laces-new-nami-mode">see blog</a>.</td></tr></tbody></table>

\*Ledger devices support all governance activities via GovTool, except submission of governance actions.

\*\*Trezor devices are limited with their governance functionality, only supporting DRep vote delegation via GovTool.

### Preview Network Compatible Wallets (`preview.gov.tools`)

Wallets which are working with GovTool on Preview testnet.

| Wallet     | Download link                                                                                  | Status                                                           |
| ---------- | ---------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| **Eternl** | [visit site](https://chromewebstore.google.com/detail/eternl/kmhcihpebfmpgmihbkipmjlmmioameka) | <mark style="color:green;background-color:green;">Online</mark>  |
| **Lace**   | [visit site](https://chromewebstore.google.com/detail/lace/gafhhkghbfjjkeiendhlofajokpaflmk)   | <mark style="color:green;background-color:green;">Online</mark>  |
| **Vespr**  | [visit site](https://vespr.xyz/)                                                               | <mark style="color:green;background-color:green;">Online</mark>  |

### SanchoNet Compatible Wallets (`sanchogov.tools`)

Wallets which are working with GovTool  on SanchoNet.

| Wallet                       | Download link                                                                                                  | Status                                                          |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| **Eternl**                   | [visit site](https://chromewebstore.google.com/detail/eternl/kmhcihpebfmpgmihbkipmjlmmioameka)                 | <mark style="color:green;background-color:green;">Online</mark> |
| **Nufi** _SanchoNet Version_ | [download here](https://assets.nu.fi/extension/sanchonet/nufi-cwe-sanchonet-latest.zip)                        | <mark style="color:green;background-color:green;">Online</mark> |
| **Yoroi (Nightly)**          | [visit site](https://chrome.google.com/webstore/detail/yoroi-nightly/poonlenmfdfbjfeeballhiibknlknepo/related) | <mark style="color:green;background-color:green;">Online</mark> |

### Wallets with in-wallet governance functionality

Some wallets have chosen to add the governance functionality in-wallet. This means that some governance flows are supported without leaving the connecting to GovTool or leaving the wallet.

| Wallet               | Download link                                                                                         | Description                                               |
| -------------------- | ----------------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| **Eternl**           | [visit site](https://chromewebstore.google.com/detail/eternl/kmhcihpebfmpgmihbkipmjlmmioameka)        | Supports DRep delegation in wallet.                       |
| **Typhon**           | [visit site](https://chromewebstore.google.com/detail/typhon-wallet/kfdniefadaanbjodldohaedphafoffoh) | Supports DRep delegation in wallet, with a DRep explorer. |
| **Yoroi**            | [visit site](https://chromewebstore.google.com/detail/yoroi/ffnbelfdoeiohenkjibnmadjiehjhajb)         | Supports DRep delegation in wallet.                       |
| Daedalus (full node) | [visit site](https://daedaluswallet.io/)                                                              | Supports DRep delegation in wallet.                       |
