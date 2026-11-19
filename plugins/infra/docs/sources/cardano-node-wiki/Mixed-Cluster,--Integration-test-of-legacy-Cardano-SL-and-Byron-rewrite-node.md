`CI` shall be running for every commit a test on a mixed cluster of legacy Cardano SL nodes (https://github.com/input-output-hk/cardano-sl/) and new nodes from Byron-rewrite (this repo: https://github.com/intersectmbo/cardano-node/).
The two worlds are interconnected using the Byron proxy (https://github.com/input-output-hk/cardano-byron-proxy/).
Either side can initiate transactions and mint blocks.

## Topology

```
     +---------------+---------------+
     |               |               |
+----v----+     +----v----+     +----v----+
|         |     |         |     |         |
| legacy  |     | legacy  |     | legacy  |
| CSL     |     | CSL     |     | CSL     |
|         |     |         |     |         |
+---------+     +----+----+     +---------+
                     ^
                     |
                     v
                +----+----+
                |         |
                |  Byron  |
                |  proxy  |
                |         |
                +----+----+
                     ^
                     |
                     v
 +---------+    +----+----+    +---------+
 |         |    |         |    |         |
 |  new    |    |  new    |    |  new    |
 |  node   |    |  node   |    |  node   |
 |         |    |         |    |         |
 +----+----+    +----+----+    +----+----+
      ^              ^              ^
      |              |              |
      +--------------+---------------

```

## Running the test

<.. tbd ..>
