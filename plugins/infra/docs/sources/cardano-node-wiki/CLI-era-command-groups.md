`cardano-cli` is transitioning to a new command structure where instead of each
era-senstivie command getting an era flag (eg `--babbage-era`, `--conway-era`),
we will have the era as a top-level command.

For the moment, this will be:

* `byron`: already exists and will be unchanged
* `shelley`: re-purposed to mean `shelley-era` only rather than `shelley-based` era
* `allegra`: `allegra` era only
* `mary`: `mary` era only
* `alonzo`: `alonzo` era only
* `babbage`: `babbage` era only
* `conway`: `conway` era only

Then we will have the following:

* `latest`: the latest supported era.  The latest officially supported era in the CLI
* `experimental`: the era following the latest era that is not yet officially supported in the CLI
* `legacy`: the commands that existed before the restructuring.  Gradually these commands
  will be migrated to fit into the new command structure.

The `latest` command group is implied, so any sub-commands there-in will also be available
at the top-level for convenience.

The `legacy` command group is also implied, so any sub-commands there-in will be
available at the top-level for convenience provided that the `latest` version of that
command does not yet exist.
