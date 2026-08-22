# cardano-api outer loop

This offline example pins the `cardano-api-10.19.1.0` release source and resolves
its Cardano package closure through a pinned CHaP index. It repeatedly
rebuilds a fresh `TxBodyContent` around `makeTransactionBodyAutoBalance`. The
recipient amount depends on the previous candidate fee; convergence requires
the newly observed fee to equal that guess. The fixture is synthetic, the loop
has an eight-pass bound, and every pass prints its fee and change observation.
