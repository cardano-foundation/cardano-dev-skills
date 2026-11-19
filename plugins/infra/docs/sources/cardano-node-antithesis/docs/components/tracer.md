# Tracer

The cardano-tracer daemon that collects structured logs from all Cardano nodes in the testnet.

## Role

All producers and relays connect to the tracer via a shared volume socket. The tracer writes structured JSON logs to `/opt/cardano-tracer/logs/<hostname>/node-<timestamp>.json`. These logs are then consumed by the tracer-sidecar for Antithesis assertion generation.

## Image

`ghcr.io/intersectmbo/cardano-tracer:<version>` (official IntersectMBO image)

## Configuration

- `tracer-config.yaml`: Configures log format (ForMachine), output directory, and Prometheus metrics
- Shared `tracer` volume: all nodes write trace data here, tracer-sidecar reads from it
