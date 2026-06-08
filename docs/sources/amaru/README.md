<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://amaru.global/_astro/logo-dark.De0RyNtz.svg">
    <source media="(prefers-color-scheme: light)" srcset="https://amaru.global/_astro/logo-light.C5lipD4m.svg">
    <img alt="Amaru" src="https://amaru.global/_astro/logo-dark.De0RyNtz.svg" height="100">
  </picture>
  <hr />
    <h2 align="center" style="border-bottom: none">A Cardano node client written in Rust.</h2>

[![Licence](https://img.shields.io/github/license/pragma-org/amaru?style=for-the-badge)](https://github.com/pragma-org/amaru/blob/main/LICENSE)
[![Twitter/X](https://img.shields.io/badge/Follow-@amaru__cardano-blue?style=for-the-badge&logo=x)](https://x.com/amaru_cardano)
[![Discord](https://img.shields.io/badge/PRAGMA-%23amaru-5865f2?style=for-the-badge&logo=discord)](https://discord.gg/3nZYCHW9Ns)

  <hr/>
</div>


## Getting Started

> [!WARNING]
>
> Amaru is still in an exploratory phase. Our development strategy favors early
> integration of components, so that progress is instantly visible, even though
> features might be limited or incomplete.

### Installing

#### Pre-compiled executables

We regularly push pre-compiled (statically linked) executables to [Github
Pages](https://pragma-org.github.io/amaru/) for the following platforms:

| Platform | Arch      |
| ---      | ---       |
| Linux    | `x86_64`  |
| Linux    | `aarch64` |
| MacOS    | `aarch64` |

We also _in theory_ support Windows (64-bit) as well as WASM and RISC-V for
certain components (e.g. amaru-ledger, amaru-consensus, ...). The support there
is preliminary and mostly experimental.


#### Docker Images (arm64 / amd64)

```console
docker pull ghcr.io/pragma-org/amaru:latest
```

#### Building from sources

```console
make build
```

> [!TIP]
> **Prefer not to install Rust locally?** We provide a Docker-based build and run path.
> See [docker/README.md](./docker/README.md) for instructions on using Docker instead.

### Running

> [!IMPORTANT]
> These instructions assume one starts from scratch, and has access to a synced [cardano-node](https://github.com/IntersectMBO/cardano-node/)
on the selected network (e.g. [preprod](https://book.world.dev.cardano.org/env-preprod.html)).
>
> Although you may explicitly provide peers, Amaru will automatically infer some peers from the ledger state. To run a local peer, refer to [Cardano's developers portal](https://developers.cardano.org/docs/get-started/cardano-node/running-cardano).

1. Bootstrap the node:

```bash
make AMARU_NETWORK=preprod bootstrap
```

2. _(Optional)_ Setup observability backends:

```console
docker-compose -f monitoring/jaeger/docker-compose.yml up
```

3. Run Amaru:

```console
make AMARU_NETWORK=preprod start
```

> [!TIP]
> To ensure logs are forwarded to an OpenTelemetry backend, set `AMARU_WITH_OPEN_TELEMETRY=true`:
>
> ```console
> make AMARU_NETWORK=preprod AMARU_WITH_OPEN_TELEMETRY=true start
> ```

### Monitoring

See [monitoring/README.md](./monitoring/README.md).

<hr/>

<p align="center">
  :boat: <a href="https://github.com/orgs/pragma-org/projects/3">Roadmap</a>
  |
  :triangular_ruler: <a href="./CONTRIBUTING.md">Contributing</a>
  |
  📰 <a href="./CHANGELOG.md">ChangeLog</a>
</p>
