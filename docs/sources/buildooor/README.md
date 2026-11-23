<p align="center">
    <p align="center">
        <img width="200px" src="./assets/buildooor.png" align="center"/>
        <h1 align="center">buildooor</h1>
    </p>
  <p align="center">Cardano transaction library in typescript</p>

  <p align="center">
    <a href="https://github.com/HarmonicLabs/buildooor/actions/workflows/ci.yml">
      <img src="https://img.shields.io/github/actions/workflow/status/HarmonicLabs/buildooor/ci.yml?branch=main&style=for-the-badge&label=CI" />
    </a>
    <img src="https://img.shields.io/github/commit-activity/m/HarmonicLabs/buildooor?style=for-the-badge" />
    <a href="https://twitter.com/hlabs_tech">
      <img src="https://img.shields.io/twitter/follow/hlabs_tech?style=for-the-badge&logo=twitter" />
    </a>
  </p>
</p>

# Buildooor

## Install

```bash
npm install @harmoniclabs/buildooor
```
## Source maps: where a script failed

Give the `TxBuilder` the source maps of your scripts (a Pebble project writes one next to the
script, `out/out.flat.map`), and a failing script says where it failed:

```ts
const txBuilder = new TxBuilder( protocolParameters, genesisInfos, {
    sourceMaps: [ readFileSync( "out/out.flat.map", "utf8" ) ]
});
```

```text
script '0d5b...' consumed with Spend redeemer and index '0'
failed at src/index.pebble:42:9
    at refund (src/index.pebble:42:9)
```

Add `saveFailedEvaluations: "./failed"` and each failing script is also saved, for
`pebble debug --eval <file>` to step through it with the variables' values.

See [docs/SOURCE_MAPS.md](./docs/SOURCE_MAPS.md).
