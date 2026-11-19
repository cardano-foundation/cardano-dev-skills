Hello all, this page will be used to keep a static status of the Byron Re-Write node front end integrations.

These are the:
* Cardano Wallet Front End 
* Wallet Back End 
* Block Explorer 


📅 _As of 12/07/2019_

***

****Cardano Wallet (Front End)**** 💰  Tasks - remaining development team effort
- Adding decoupled wallet backend binaries into the development environment and build cycle
- Integration of the decoupled wallet backend process management
- Integration of the V2 API (incl. separation of legacy wallet and new wallets handling)
- Daedalus test suite setup adjustments (related to the removal of state-reset API endpoint)
- Implementation of BIP-44 related UI changes
- Removal of unsupported features (Ada redemption) 

***

****Wallet Back End**** 🤝 Tasks - remaining development team effort
- Implement the networking layer to communicate with the Haskell nodes
- Implement the transaction layer to serialize and sign transactions for the Haskell nodes
- Enable support for random address derivation
- Run our integration & e2e test suite using the new Haskell nodes as a backend target
- Add a third executable target for our command-line, and have the ability to serve the wallet on top of a new Haskell node
- Finalize cross-compilation to windows
- Finalize missing / unimplemented endpoints of the API

***

****Block Explorer**** 🌍 Tasks - remaining development team effort
- Develop back end DB
- Front end GUI (scope as per previous Byron)
