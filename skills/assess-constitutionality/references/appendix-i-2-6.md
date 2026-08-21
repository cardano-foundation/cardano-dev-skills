### **2.6. Monitoring and Reversion of Parameter Changes**

All network parameter changes must be monitored carefully for no less
than 2 epochs (10 days)

-   Changes must be reverted as soon as possible if block propagation
    delays exceed 4.5s for more than 5% of blocks over any 6 hour
    rolling window

All other parameter changes should be monitored

-   The reversion plan should be implemented if the overall effect on
    performance, security, functionality, or long-term sustainability
    is unacceptable.

A specific reversion/recovery plan must be produced for each parameter
change. This plan must include:

-   Which parameters need to change and in which ways in order to return
    to the previous state (or a similar state)

-   How to recover the network in the event of disastrous failure

This plan should be followed if problems are observed following the
parameter change. Note that not all changes can be reverted. Additional
care must be taken when making changes to these parameters.
