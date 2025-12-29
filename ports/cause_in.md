# CauseIn Port

The **CauseIn** port accepts a vCML cause wrapped in the device envelope.
It defines how the device receives causes without prescribing transport.

See [DEPENDENCIES.md](../DEPENDENCIES.md) for canonical ownership of vCML/LPT.

## Input Contract

```
submit(envelope, vcml_record) -> ack
```

### Parameters

- `envelope`: Device envelope as defined in [envelope.md](envelope.md).
- `vcml_record`: Canonical vCML record (unmodified).

### Ack

A minimal acknowledgement that the device accepted the submission for validation.

```
ack:
  accepted_for_validation: boolean
  cause_id: string
  correlation_id: string
```

## Notes

- CaPU is transport-agnostic; LPT is only one possible source.
- No alternative cause format is introduced here.
- Decision and reason enumerations are defined in [DECISION_CODES.md](../DECISION_CODES.md).
