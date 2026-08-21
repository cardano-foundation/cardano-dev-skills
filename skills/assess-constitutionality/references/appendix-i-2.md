### **2. Guardrails and Guidelines on "Parameter Update" actions**

Below are Guardrails and guidelines for changing updatable protocol
parameter settings via the "Parameter Update" action such that the
Cardano Blockchain is never in an unrecoverable state as a result of
such changes.

Note that, to avoid ambiguity, this Appendix uses the parameter name
that is used in "Parameter Update" actions rather than any other
convention.

##### **GUARDRAILS**

PARAM-01 (y) Any protocol parameter that is not explicitly named in this
document must not be changed by a "Parameter Update" action

PARAM-02a (y) Where a protocol parameter is explicitly listed in this
document but no checkable Guardrails are specified, the Guardrails
Script must not impose any constraints on changes to the parameter.
Checkable Guardrails are shown by a (y)
