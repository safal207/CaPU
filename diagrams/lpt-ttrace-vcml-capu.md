# System Diagram: CaPU / vCML / LPT / T-Trace

This diagram illustrates the flow of data and the separation of concerns between the canonical components.

```
       +-----------------+
       | External System |
       +--------+--------+
                |
                v
       +-----------------+
       |       LPT       |  <-- Transport Layer (Secure Delivery)
       | (Liminal Proto) |      (Optional, CaPU is transport-agnostic)
       +--------+--------+
                |
                |  (vCML Record)
                v
       +-------------------------------------------------------------+
       |                           CaPU                              |
       |                  (Causal Processing Unit)                   |
       |                                                             |
       |   +--------+      +-----------+      +--------+             |
       |   |  GATE  +----->| INCUBATOR +----->| COMMIT |             |
       |   +---+----+      +-----------+      +----+---+             |
       |       |                                   |                 |
       |       | (Decision)                        v                 |
       |       v                              +----------+           |
       |  +----------+                        | EXECUTOR |           |
       |  | Decision |                        +----+-----+           |
       |  |  Logic   |                             |                 |
       |  +----------+                             | (Side Effects)  |
       |                                           v                 |
       +--------+----------------------------------+-----------------+
                |                                  |
                | (Events)                         |
                v                                  v
       +-----------------+                 +----------------+
       |     T-Trace     |                 | External State |
       |   (Trace Sink)  |                 | (DB, API, ...) |
       +-----------------+                 +----------------+
```

## Legend

*   **vCML:** The data format flowing through the arrows.
*   **LPT:** The pipe that brings data to the door.
*   **CaPU:** The engine deciding if/when to open the door and what to do.
*   **T-Trace:** The camera recording what happened.
