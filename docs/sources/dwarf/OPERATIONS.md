# Operations Guide

This guide covers normal operation after Dwarf Version 3 (V3) has been installed and the framework image has been built.

## Lifecycle Commands

Prepare package-local runtime directories:

```bash
delivery/scripts/install.sh
```

Build the Docker image:

```bash
delivery/scripts/build-image.sh
```

Deploy:

```bash
delivery/scripts/deploy.sh
```

Status:

```bash
delivery/scripts/status.sh
```

Undeploy while preserving runtime data:

```bash
delivery/scripts/undeploy.sh
```

Conservative uninstall:

```bash
delivery/scripts/uninstall.sh
```

## Dashboard Routes

After deployment, open:

```text
http://127.0.0.1:8787/operate
http://<host-local-area-network-ip>:8787/operate
```

Useful routes:

| Route | Purpose |
|---|---|
| `/operate` | Operational overview |
| `/operate/scenarios` | Scenario catalog |
| `/operate/targets` | Registered targets |
| `/operate/profiles` | Configured profiles |
| `/operate/status` | Deployment/status view |
| `/operate/bundles` | Evidence bundle browser |
| `/operate/coverage` | Coverage roll-up |
| `/operate/plugins` | Plugin and primitive registry |
| `/operate/config` | Read-only resolved config view |
| `/learn` | Documentation and onboarding pages |
| `/api/status` | JavaScript Object Notation (JSON) status payload |

The root path redirects to `/operate`.

## Graphical User Interface Handoff Documentation

The polished visual handoff page for recipients is:

```text
docs/index.html
```

It is a self-contained HyperText Markup Language (HTML) file covering the V3 delivery scope and the deployed dashboard. Use it when introducing the package to a new operator or when hosting the overview from GitHub Pages.

## Command-Line Interface Inside The Container

The framework lives at:

```text
/home/dwarf/dwarf-fw
```

The command-line interface (CLI) entrypoint is:

```text
python3 dwarf/cardano-profile
```

Examples:

```bash
docker exec dwarf-fw-june-m2 python3 dwarf/cardano-profile dashboard status
docker exec dwarf-fw-june-m2 python3 dwarf/cardano-profile test smoke list
docker exec dwarf-fw-june-m2 python3 dwarf/cardano-profile fuzz list
docker exec dwarf-fw-june-m2 python3 dwarf/cardano-profile scenario validate dwarf/scenarios/throughput-regression-floor-example-smoke.yaml
```

Open a shell:

```bash
docker exec -it dwarf-fw-june-m2 bash
```

## Running With A Non-Default Port

If another service already uses `8787`, deploy on another host port:

```bash
DWARF_DASHBOARD_PORT=8877 delivery/scripts/deploy.sh
DWARF_DASHBOARD_PORT=8877 delivery/scripts/status.sh
```

The container still listens internally on `8787`; only the host port changes.

## Moog Setup Form

Open `/operate/config` to enter Moog, GitHub, target repository, and Antithesis values from the dashboard. The form saves to the Dwarf `moog` config block and reads Docker environment variables as effective overrides. Values from `.env` are available when `delivery/scripts/deploy.sh` starts the container.

Client-prep mode allows saving GitHub PATs, Antithesis passwords/API keys, and agent email passwords in `var/state/config.yaml`. Secret inputs are masked after save, and a blank secret submission preserves the existing saved value.

## Optional Moog Bootstrap And Healthchecks

Dwarf does not set up Moog during normal install or deploy. To keep wallet/secrets/service changes explicit, the deploy script only runs Moog setup when requested:

```bash
DWARF_MOOG_BOOTSTRAP=plan delivery/scripts/deploy.sh
```

The plan mode prints the Moog bootstrap plan and changes no remote state. The approved mode requires a second confirmation variable:

```bash
DWARF_MOOG_BOOTSTRAP=approve \
DWARF_MOOG_BOOTSTRAP_APPROVE=1 \
delivery/scripts/deploy.sh
```

Approved bootstrap creates only the Moog directory skeleton and a remote operator plan file. It does not fetch binaries, create wallet files, read secrets, write PATs, write Antithesis credentials, enable systemd units, or start Moog services.

Use this healthcheck sequence after bootstrap or manual Moog changes:

```bash
docker exec dwarf-fw-june-m2 /home/dwarf/dwarf-fw/dwarf/cardano-profile moog bootstrap --json
docker exec dwarf-fw-june-m2 /home/dwarf/dwarf-fw/dwarf/cardano-profile moog healthcheck --json
docker exec dwarf-fw-june-m2 /home/dwarf/dwarf-fw/dwarf/cardano-profile wallet healthcheck moog-requester --json
docker exec dwarf-fw-june-m2 /home/dwarf/dwarf-fw/dwarf/cardano-profile moog readiness --repo <org/repo> --github-user <user> --json
docker exec dwarf-fw-june-m2 /home/dwarf/dwarf-fw/dwarf/cardano-profile moog preflight --asset-dir <dir> --repo <org/repo> --github-user <user> --directory <path> --commit <sha> --json
```

## Runtime Data Layout

Host paths:

```text
var/runs
var/state
var/bundles
```

Container paths:

```text
/var/dwarf/runs
/var/dwarf/state
/var/dwarf/bundles
```

Purpose:

| Path | Purpose |
|---|---|
| `var/runs` | Run directories and generated evidence |
| `var/state` | Config, chain head, runtime state |
| `var/bundles` | Exported or preserved bundle archives |

These directories are bind-mounted instead of Docker volumes so operators can inspect and back them up directly.

## Evidence Bundles

Dwarf’s evidence model is documented in:

```text
dwarf/docs/forensic-bundle-format.md
```

Every meaningful run is expected to produce a self-contained bundle with manifest, scenario copy, environment capture, logs, assertions, and provenance-chain metadata.

## Configuration

The default config path inside the container is:

```text
/var/dwarf/state/config.yaml
```

Mapped from:

```text
var/state/config.yaml
```

If no config exists, dashboard status still works but reports:

```text
Config missing. Run intake first.
```

That is acceptable for a clean delivery smoke test. Operators can later create config through the CLI or by writing the config file directly.

## Security Posture

The delivery stack is intentionally conservative:

- dashboard binds to `0.0.0.0` by default for loopback and local area network (LAN) access
- container filesystem is read-only
- Linux capabilities are dropped
- `no-new-privileges` is enabled
- runtime data is limited to explicit bind mounts
- SSH keys are not mounted by default
- Cardano substrate containers are not started by default

## Troubleshooting

### Docker daemon unreachable

Run:

```bash
docker version
```

If this fails, fix host Docker access before running Dwarf scripts.

### Port already in use

Check:

```bash
ss -ltnp | grep 8787
```

Use another port:

```bash
DWARF_DASHBOARD_PORT=8877 delivery/scripts/deploy.sh
```

### Container exits immediately

Run:

```bash
docker logs dwarf-fw-june-m2
delivery/scripts/status.sh
```

Common causes:

- image was not built
- runtime paths are not writable
- port mapping conflicts
- Docker daemon restarted while container was starting

### Build fails at apt snapshot update

The V3 Dockerfile should include:

```text
Acquire::Check-Valid-Until "false";
Acquire::Check-Date "false";
```

Run:

```bash
bash delivery/tests/test_delivery_contract.sh
```

If the contract test fails, do not ship the package.

### Browser shows a connection reset immediately after deploy

The dashboard process may still be starting. Wait a few seconds and retry:

```bash
curl -fsS http://127.0.0.1:8787/api/status
curl -fsS http://<host-lan-ip>:8787/api/status
```

### `/api/operate/runs` returns 404

This was observed during manual Playwright probing. It does not block the rendered Operate and Scenarios pages, but it should be tracked as an API coverage gap if that endpoint is expected by future UI code.
