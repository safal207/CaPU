# System Diagram: CaPU / vCML / LTP / T-Trace

This diagram illustrates the flow of data and the separation of concerns between the canonical components.

```
       +-----------------+
       | External System |
       +--------+--------+
                |
                v
       +-----------------+
       |       LTP       |  <-- Boundary Layer (Delivery + Replay/Oversight)
       | (Liminal Thread Protocol) |      (Optional, CaPU is transport-agnostic)
       +--------+--------+
                |
                |  (vCML Record)
                v
       +-------------------------------------------------------------+
       |                           CaPU                              |
       |                  (Causal Processing Unit)                   |
       |                                                             |
       |   +--------+      +-----------+      +--------+             |
       |   |  GATE  +----->| INCUBATE  +----->| COMMIT |             |
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
*   **LTP:** The pipe that brings data to the door.
*   **CaPU:** The execution runtime deciding whether actions may progress to side effects.
*   **T-Trace:** The camera recording what happened.
