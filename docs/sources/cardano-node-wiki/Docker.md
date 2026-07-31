Docker builds of [cardano-node](https://hub.docker.com/repository/docker/inputoutput/cardano-node) are available on Docker Hub.

Every release is tagged using semantic versioning and pushed to Docker Hub. For instance, images for release 1.10.0 can be pulled from Docker Hub via:

```
$ docker pull inputoutput/cardano-node:1.10.0
```


or the latest development version can be pulled using:

```
$ docker pull inputoutput/cardano-node:master
```

## How To Configure

Example configurations are available in the [cardano-node](https://github.com/intersectmbo/cardano-node/tree/master/configuration/defaults) repository:

```
configuration/
├── configuration.yaml
├── genesis.json
└── topology.json
```

You will need all the files in this directory.

## How To Run

Assuming you have created the configuration directory as a subdirectory, mount
the volume and run the node. For example,

```
docker run -v `pwd`/configuration/defaults/mainnet:/configuration inputoutput/cardano-node:1.10.1
docker run -v `pwd`/configuration/defaults/liveview:/configuration inputoutput/cardano-node:1.11.0
```

## How To Stop
```
CTRL+C
```

### Building the Docker image locally

Ensure that you have [Nix](https://nixos.org/) installed and the IOHK binary cache enabled
([instructions](https://github.com/input-output-hk/cardano-node-wiki/blob/main/docs/getting-started/building-the-node-using-nix.md)).

Then run this command from the `cardano-node` git repository:

```
docker load -i $(nix-build -A dockerImage --no-out-link)
```

If you have no local changes, the build should be downloaded from
the [IOHK binary cache](https://ci.iog.io/project/input-output-hk-cardano-node)
then loaded into the local Docker registry.
