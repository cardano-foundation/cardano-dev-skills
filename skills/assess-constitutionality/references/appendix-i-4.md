### **4. Guardrails and Guidelines on "Hard Fork Initiation" actions**

The "Hard Fork Initiation" action requires both a new major and a new
minor protocol version to be specified.

-   As positive integers

As the result of a hard fork, new updatable protocol parameters may be
introduced. Guardrails may be defined for these parameters, which will
take effect following the hard fork. Existing updatable protocol
parameters may also be deprecated by the hard fork, in which case the
guardrails become obsolete for all future changes.

##### **GUARDRAILS**

HARDFORK-01 (~ - no access to existing parameter values) The major
protocol version must be the same as or one greater than the major
version that will be enacted immediately prior to this change. If the
major protocol version is one greater, then the minor protocol version
must be zero

HARDFORK-02a (~ - no access to existing parameter values) Unless the
major protocol version is also changed, the minor protocol version must
be greater than the minor version that will be enacted immediately prior
to this change

HARDFORK-03 (~ - no access to existing parameter values) At least one
of the protocol versions (major or minor or both) must change

HARDFORK-04a (x) At least 85% of stake pools by active stake should have
upgraded to a Cardano Blockchain node version that is capable of
processing the rules associated with the new protocol version

HARDFORK-05 (x) Any new updatable protocol parameters that are
introduced with a hard fork must be included in this Appendix and
suitable guardrails defined for those parameters

HARDFORK-06 (x) Settings for any new protocol parameters that are
introduced with a hard fork must be included in the appropriate Genesis
file

HARDFORK-07 (x) Any deprecated protocol parameters must be indicated in
this Appendix

HARDFORK-08 (~ - no access to *Plutus cost model* parameters) New
Plutus versions must be supported by a version-specific *Plutus cost
model* that covers each primitive that is available in the new Plutus
version
