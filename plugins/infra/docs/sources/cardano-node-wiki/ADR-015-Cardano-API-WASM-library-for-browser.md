# ADR-015: JavaScript API for Cardano via WASM-compiled cardano-api

# Status

✅ Adopted 2025-05-22

# Context

Decentralized Applications (DApps) mainly revolve around web browsers. The Cardano blockchain platform features `cardano-api`, a comprehensive Haskell library developed in conjunction with `cardano-node`, and offers extensive blockchain interaction capabilities implemented in a robust way thanks to strong typing, formal specifications, and extensive testing.

For developers building on Cardano, a range of JavaScript and TypeScript libraries are available. These include tools such as [Lucid Evolution](https://github.com/Anastasia-Labs/lucid-evolution), [Helios](https://helios-lang.io/), [MeshJS](https://meshjs.dev/), [cardano-serialization-lib](https://github.com/Emurgo/cardano-serialization-lib), [cardano-sdk-js](https://github.com/input-output-hk/cardano-js-sdk), [Ogmios](https://ogmios.dev/), and [TyphonJS](https://github.com/StricaHQ/typhonjs).

Concurrently, efforts that provide compilation from Haskell to WebAssembly (WASM) are reaching increasingly wider support for the functionalities provided by Haskell (recently expanding to include advanced features like Template Haskell). WebAssembly is a technology that can be run in the same environments that JavaScript and TypeScript can, and that it can be invoked from those languages. And, like those languages, WebAssembly can provide strong sandboxing and widespread portability, particularly in browsers.

This Architectural Decision Record (ADR), explores the creation of a new JavaScript and TypeScript API for Cardano. The primary method proposed is to compile the existing `cardano-api` (written in Haskell) to WebAssembly (WASM) and to write a thin wrapper around it.

## Rationale

As described in the previous section, there already exist several JavaScript/TypeScript libraries and APIs that support DApps. Nevertheless, the extensive and robust features provided by `cardano-api` would benefit DApps, so compiling it to WebAssembly and providing a JavaScript and TypeScript API would provide several advantages:
* **Comprehensiveness:** `cardano-api` is especially comprehensive in its functionalities, since it is developed in sync with `cardano-node`.
* **Robustness:** Because `cardano-api` is developed in Haskell, it relies heavily in type correctness, and because it is heavily tested, it is especially trustworthy. Because the JavaScript/TypeScript API would take advantage of the same code, the robustness would be inherited.
* **Pure browser support:** DApp libraries tend to be more focused on supporting execution in the backend (through [Node.js](https://nodejs.org/) and [Bun](https://bun.sh/)). There are good reasons for doing this, but explicitly supporting JavaScript in the browser has some advantages:
  * **Incentivize adoption:** By making the library easier to try out, we would be reducing the friction to adoption.
  * **Improved trust through decentralisation:** Since code would be running in the browser, and thus the user's computer, it may be easier for the user to trust it than it would for an opaque web service. Transaction signing necessarily happens on the client side anyway, because it needs to be done by the user's wallet, but it would be even more trustworthy and decentralised if the whole dApp logic code would also run in the user's computer and if it was inspectable (which is typically the case for unobfuscated JavaScript). It would also reduce the amount of information that needs to be shared with the server, increasing privacy for users.
  * **Easier deployment:** Static web apps are easier to deploy than dynamic ones, because only a web server is needed. They also require less processing on the web server, less memory usage per user (it can be done statelessly), they benefit much more from optimisations like caching, and their execution model is simpler (since they doesn't require complex synchronisation between frontend and backend). In fact, there are services like [`github.io`](https://pages.github.com/) that allow hosting static pages free of charge, and this is much harder to find for dynamic pages. For this reason, being able to make static dApps would lower the barrier for hosting them which would, in turn, potentially lead to increased adoption as well.

Other potential opportunities and considerations to keep in mind:
* **Aditional conectivity:** We can potentially provide ways to connect to a `cardano-node` directly. And we can consider offering a provider that is uses [CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS), which would allow dApps run purely in the browser (see [Appendix](#appendix-cors-and-sop-explained)).
* **Ease of Use & Documentation:** Most popular libraries provide introductory guides, that are comprehensive, simple, clear. Autocompletion in IDEs is crucial and often serves as de-facto documentation. In addition to all that, we should make comprehensive documentation for the whole API (reference) and make it easily accessible.
* **CIP-30 Integration:** Existing libraries seem to provide wallet support through [CIP-30](https://cips.cardano.org/cip/CIP-30). We may want to do that too, or at least make it easy for our API to interact with already existing libraries and APIs that already support CIP-30. The later may be hard because some of the most popular libraries integrate the wallets and transaction handling very closely and not necessarily in a functionaly pure way. It may also be used as a provider of information to some extent.
* **Browser Compatibility & Testing:** For the reasons we mentioned before, we should use the CI to test compatibility with all potential workflows, including vanilla JavaScript and [TypeScript](https://www.typescriptlang.org/) from the browser, as well as integration with `Node.js`. Testing pure browser workflows can be tricky because we may need to use UI testing libraries like [`Playwright`](https://playwright.dev/).
* **Standard publication:** It is pretty standard for `Node.js` libraries to be distributed through channels like [`npm`](https://www.npmjs.com/), so we should probably make sure to upload the library to those.

## Decision

We propose to create a new JavaScript and TypeScript library API for Cardano by compiling the `cardano-api` (Haskell) to WebAssembly (WASM) and adding a thin wrapper. This would allow developers to easy and cross-platform access to a subset of `cardano-api` functionalities from the browser and `Node.js` environments and similar.

**Key Features & Design Goals:**

1.  **WASM core:** Compile `cardano-api` to WASM to leverage its extensive features, and correctness.
2.  **JavaScript/TypeScript interface:**
    * Provide simple, user-friendly, and well documented JavaScript ES6 module and TypeScript bindings.
    * Offer strong typing with TypeScript for enhanced robustness (types) and developer experience (autocompletion).
    * Support vanilla JavaScript usage for easy testing and adoption.
3.  **API design:**
    * **Low-Level access:** Expose a subset of `cardano-api` with a thin wrapper.
    * **High-Level abstractions (potential):** Consider optional, higher-level APIs, probably as separate modules. Examples:
        * A "virtual wallet" abstraction that handles UTXO management and coin selection automatically.
        * Simplified (possibly monadic) transaction building.
    * **CIP-30 support:** Potentially support CIP-30 compatibility to interact with browser wallet extensions, either as a separate module or as part of the "virtual wallet" abstraction.
    * **Data providers:** Allow configuration of blockchain data providers (e.g., [BlockFrost](https://blockfrost.io/), [Koios](https://koios.rest/)). Consider offering a CORS-friendly proxy service (with robust caching to mitigate DDoS risk) to provide support for frontend-only DApp development.
4.  **Development Experience:**
    * **Minimal JS glue:** Maximize Haskell code and minimize the JavaScript FFI glue code and try to generate glue code automatically if possible. This allows leveraging Haskell for most of the development, improving our productivity and the type safety of our code.
    * **Haskell API mirroring:** Because WASM ghc compiler target doesn't seem to support `haskell-language-server`, we should keep a pure Haskell API that closely mirrors the desired JavaScript API structure to be able to work on it using the HLS as far as possible, and use FFI just for type conversion.
    * **Type conversion:** Implement `ToJSVal` / `FromJSVal` type-classes in Haskell, analogously to `ToJSON` / `FromJSON` in [Aeson](https://hackage.haskell.org/package/aeson), for conversions between Haskell and JS types. JSON string serialization can be used as an efficient intermediate representation. The mechanism can follow these steps:
       1. Check if the Haskell type has an `Aeson` instance, if it doesn't convert it into a `TextEnvelope`.
       2. Take the Haskell type with `Aeson` instance or its `TextEnvelope` (which has an `Aeson` instance), and use the instance to serialise it as a `String` containing its JSON representation.
       3. Convert the `String` to `JSString` (using the `toJSString` function from `GHC.Wasm.Prim` in the `ghc-experimental` package)
       4. Deserialise the JSON in the `JSString` using the `JSON.parse` JavaScript function. This can be from Haskell by using a `foreign import`, and that will give us a `JSVal`, which we can pass directly to JavaScript through the API.

         The same process can be followed in the reverse direction by using `JSON.stringify` function in JavaScript, and the `fromJSString` function from `GHC.Wasm.Prim`.
    * **Error handling:** Ensure clear, descriptive, and catchable errors.
    * **BigInt for large amounts:** Use JavaScript [`BigInt`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt	) for Ada/Lovelace amounts to prevent precision loss (also serialised/deserialised as/from strings).
5.  **Documentation & Examples:**
    * Comprehensive API documentation that is easy to navigate.
    * Step-by-step guides for getting started, including handling `async` calls.
    * Clear examples for main use cases.
    * Ensure good IDE autocompletion support (like in [Visual Studio Code](https://code.visualstudio.com/)).
6.  **Distribution:** Distribute the library via NPM and potentially in [`github.io`](https://pages.github.com/).
7.  **Testing:**
    * CI pipelines to consider for:
        * WASM compilation. (Build)
        * Generation and consistency of JS/TS bindings. (Like with golden tests)
        * Functionality across supported environments. (Browsers via tools like Playwright, and also Node.js)
        * Glue generation verification. (Like with golden tests)
8.  **Stability:** Aim to maintain a stable API to avoid user frustration.

**Haskell to JavaScript Bridging Example:**

We would make a Haskell wrapper that is really close to what we want at the JavaScript level but using Haskell terms:

```haskell
signTransactionImpl :: Api.TxBody Api.ConwayEra -> Api.SigningKey Api.PaymentKey -> IO (Api.Tx Api.ConwayEra)
signTransactionImpl unsignedTx signingKey = do
    let sbe :: Api.ShelleyBasedEra Api.ConwayEra = Api.shelleyBasedEra
    let witness = Api.WitnessPaymentKey signingKey
    let oldApiSignedTx :: Api.Tx Api.ConwayEra = Api.signShelleyTransaction sbe unsignedTx [witness]
    return oldApiSignedTx
```

Then we would write a conversion layer that is still in Haskell, but converts to and from JavaScript marshallable types and uses the pure Haskell function:

```haskell
foreign export javascript "signTransaction"
    signTransaction :: JSVal -> JSString -> IO JSVal
signTransaction txBody privKey = do
    -- Convert JS params to Haskell types
    unsignedTx <- jsValToType (Api.AsTxBody Api.AsConwayEra) txBody
    let (Right signingKey) = Api.deserialiseFromBech32 (Api.AsSigningKey Api.AsPaymentKey) (Text.pack (fromJSString privKey))
    -- Call the pure Haskell function
    oldApiSignedTx <- signTransactionImpl unsignedTx signingKey
    -- Convert Haskell type to JS
    let envelope = Api.serialiseToTextEnvelope (Just "Ledger Cddl Format") oldApiSignedTx
    jsonToJSVal envelope
```

This could be done more generically with a `FromJS` and `ToJS` class, as mentioned.

**JavaScript Initialization and Usage Example:**

The JavaScript glue can be very simple and basically packages the FFI Haskell functions:

```javascript
// cardano-api.js (or similar entry point for the library)

import { WASI } from "https://unpkg.com/@bjorn3/browser_wasi_shim@0.4.1/dist/index.js";
import ghc_wasm_jsffi from "./cardano-wasm.js"; // This is generated automatically from WASM
const __exports = {};
const wasi = new WASI([], [], []);

// Initialisation function returns a promise to an object with the API
async function initialize() {
  let {instance} = await WebAssembly.instantiateStreaming(fetch("./cardano-wasm.wasm"), {
    ghc_wasm_jsffi: ghc_wasm_jsffi(__exports),
    wasi_snapshot_preview1: wasi.wasiImport,
  })
  Object.assign(__exports, instance.exports);
  wasi.initialize(instance);

  // Re-export desired Haskell functions
  return { mkTransaction: instance.exports.mkTransaction
         , signTransaction: instance.exports.signTransaction
         , mkTxIn: instance.exports.mkTxIn
         };
}

// We only expose the initialization function
export default initialize;
```

Example usage of the JS API could be as simple as defining an `async` function and then calling `.then()` on it:

```html
<html>
<body>
<script type="module">
  import cardano_api from "./cardano-api.js";
  let promise = cardano_api();
  async function do_async_work() {
    let api = await promise;

    let txIn = await api.mkTxIn("be6efd42a3d7b9a00d09d77a5d41e55ceaf0bd093a8aa8a893ce70d9caafd978", 0);
    console.log("Tx input:");
    console.log(txIn);

    let destAddr = "addr_test1vzpfxhjyjdlgk5c0xt8xw26avqxs52rtf69993j4tajehpcue4v2v";
    let privKey = "addr_sk1648253w4tf6fv5fk28dc7crsjsaw7d9ymhztd4favg3cwkhz7x8sl5u3ms";
    let amountInLovelace = 10_000_000n; // We pass Lovelace amounts as BigInt
    let feesInLovelace = 2_000_000n;

    let unsignedTx = await api.mkTransaction(txIn, destAddr, amountInLovelace, feesInLovelace);
    console.log("Tx body:");
    console.log(unsignedTx);

    let signedTx = await api.signTransaction(unsignedTx, privKey);
    console.log("Signed tx:");
    console.log(signedTx);
  }
  do_async_work().then(() => {});
</script>
</body>
</html>
```

**Stateful API (Wallet-like features):**

If we do a stateful API (e.g., for a "virtual wallet"), the state can be managed in Haskell. Each function in the stateful API would take the state as its first parameter and return a tuple with the new state and the resulting state (this can be modeled as a [`State` monad](https://hackage.haskell.org/package/mtl/docs/Control-Monad-State-Class.html)). The JavaScript glue code would hold this state globally and pass it automatically for each function call, making it appear as an object-oriented API in JavaScript. This state could include loaded private keys (handled securely), UTXO sets, etc. This could be implemented as an abstraction layer that uses the core stateless functions under the hood.

For example, let's imagine we have a wallet with a derivation scheme, and we want a stateful function that takes an unsigned transaction and it derives a new key from the derivation scheme, records the number of derivated keys, it uses the newly derived key to sign the transaction and it returns it signed. In Haskell the function doing this we could have a signature like:

```haskell
signTx :: WalletState -> Api.TxBody Api.ConwayEra -> IO (WalletState, Api.Tx Api.ConwayEra)
```

Or the `State` monad equivalent. Then we would export it as JavaScript as an async function with two parameters (the wallet state, and the unsigned transaction), and it would return a list with two elements (the new wallet state, and the signed transaction), because JavaScript doesn't have tuples.

Then, as part of the JavaScript wrapper where we re-export the Haskell functions, we can instead export a wrapper function. Let's assume the Haskell function is exported with the name `haskellExportedSignTxFunction` (for illustrative purpouses). Then we can create a wrapper function in JavaScript as follows:

```javascript
async function signTx(unsignedTx) {
  var result = await haskellExportedSignTxFunction(state, unsignedTx);
  var [ newState, signedTx ] = result;
  state = newState;
  return signedTx;
}
```

Where `state` is a variable declared globally in JavaScript. This way, the user doesn't need to think about the `state` since it is passed automatically to the function `signTx` automatically.

## Consequences

### Positive:

* A powerful, secure, and comprehensive Cardano library for browser and Node.js environments.
* Enhanced DApp developer productivity and capability.
* Greater potential for decentralization and user transparency in DApps.
* Establishes a robust foundation for future tooling and higher-level libraries.
* Ability to work primarily in Haskell with HLS for the core logic.

### Negative/Challenges:

* Complexity of setting up and maintaining the Haskell-to-WASM compilation toolchain and FFI.
* Potential initial performance overhead or bundle size issues with WASM (mitigation through optimization).
* Potential difficulties when debugging across the Haskell-WASM-JS boundary.
* Effort required for manual creation and maintenance of TypeScript definitions if generation is not feasible or good enough.
* Effort required for developing comprehensive tests, especially browser-based integration tests (e.g., using Playwright).
* Effort required to design JS/TS API from a DApp user perspective.
* Effort required to maintain compatibility with WASM of all dependencies of `cardano-api` through changes and upgrades.

## Conclusion

Developing a JavaScript/TypeScript API for Cardano by compiling `cardano-api` to WASM is very feasible and we can make it easy and frictionless for the user. We must make sure to keep it simple, stable, and test all the user flows. We also should ensure we use pure Haskell as far as possible to take advantage of HLS as much as possible, and we can automate as much of the glue layer generation as possible in two ways:

* Generalising the boilerplate so that it is reusable and structured.
* Making the API inspectable by JavaScript and deriving part of it using JavaScript reflection capabilities.
* Using meta programming to generate boilerplate (Template Haskell).

We must also provide a TypeScript declaration file for the API to both make it easier (through auto-complete documentation) and safer (through types) for users to develop using the API. And we will aim to derive the type declaration file automatically from the Haskell code to ensure consistency. We should also ensure compatibility with the different workflows and consistency through the use of CI whenever possible.

## Appendix: **CORS and SOP explained**

SOP (or Same-Origin Policy) is a restriction that is enforced by browsers to protect both users and servers from potential attacks from malicious web applications to other web applications or APIs unless they opt out by using CORS (Cross-Origin Resource Sharing), which is a mechanism that lets servers allow web applications to circumvent the Same-Origin Policy restriction. In our particular case, a service that offers a public API would be protected by SOP because a random JS application wouldn't be able to access it directly from the user's browser (i.e: the user's computer). Instead, the app would be forced to access the API from the backend of the JS application, and that helps security because the source for the request is specifc to the app, since it is done from the app's backend server. And the requests from that server:
  - Can easily be blocked if the API is abused.
  - Cannot pass as the user (because the request won't include the user's cookies, for example).
Additionally, if SOP was not in place, a very popular but malicious website could easily include a JavaScript snippet that would cause every visitor of the malicious website to silently make potentially costly requests against a victim API, and that would potentially work out as DDOS (Distribute Denegation of Services) attack, by consuming lots of resources from the victim API.

Unfortunately, this means that JavaScript cannot access public API's unless those API's use CORS to lift SOP restrictions. This ADR suggests that there could potentially exist a service like [Koios](https://koios.rest/) that does this, as long as it can be guaranteed that the queries offered by the API are made in a way that is efficient enough, and user supplantation is made impossible or not applicable.

## Related ADRs

- [ADR-004](ADR-004-Support-only-for-mainnet-and-upcoming-eras) — defines the eras available to the WASM API.
- [ADR-014](ADR-014-Total-conversion-functions-conventions) — the `Inject`/`Convert` pattern is analogous to the `ToJSVal`/`FromJSVal` type classes proposed here.
- [ADR-018](ADR-018-cardano-rpc-grpc-server) — the gRPC server provides a complementary access method; its Envoy/gRPC-Web support enables browser clients.
