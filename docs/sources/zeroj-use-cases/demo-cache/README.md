# Demo Cache

This directory contains precomputed development-only Groth16 setup artifacts for
the Spring Boot demos. They are committed only to make presentation startup
fast when Docker images are built locally.

These files are not production trusted setup ceremony outputs. They are created
with ZeroJ's insecure single-party development setup and must never be reused
for production circuits.

`docker/run-spring-usecase.sh` copies the selected usecase cache into `/app/data`
when the app container starts and the runtime volume does not already contain
any `setup-*.bin` file. `./demo.sh <usecase> --clean-cache` removes the selected
demo volume and disables seeding for that run, forcing the setup to regenerate
from scratch.

The manifests are informational. The applications still validate setup shape at
load time and regenerate if a setup artifact does not match the current circuit.
