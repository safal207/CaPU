# CaPU v0.29 native Bitwuzla evaluation

Status: experimental evaluation, runnable manually and on pull requests that
change its workflow, adapter, or Bitwuzla configuration files. The existing Z3
workflow and its required checks remain unchanged. A local experiment or a
parsed workflow file is not evidence that the GitHub Actions workflow has run.
Manual dispatch is available only after this workflow exists on the default
branch. The pull-request trigger allows a hosted run to be checked beforehand.

The evaluation uses three separately named SymbiYosys configurations:

| Check | Mode and bound | Scope |
|---|---|---|
| v0.29 safety | BMC depth 22 | The existing reduced-width, four-beat recovery model |
| v0.29 cover | Cover depth 36 | Existing reachability properties and generated witnesses |
| v0.28 regression | BMC depth 18 | Existing durable-negative-completion safety model |

The evaluation workflow also runs the existing v0.29/v0.28 deterministic RTL
trajectories and checkpoint tests. A bounded PASS concerns the modeled states,
assumptions and bound; it is not an unbounded proof or production DMA claim.
A timeout is a failure to complete the evaluation, not a passing proof.

## Solver interface

The workflow builds Bitwuzla 0.9.1 from its pinned source commit and uses the
existing pinned SymbiYosys revision. Yosys 0.33 invokes Bitwuzla with `--smt2`,
whereas Bitwuzla 0.9.1 uses `--lang smt2`. The small
`tools/bitwuzla_cli_compat.sh` adapter translates that argument and `exec`s the
native binary. It does not parse, modify, or decide SMT formulas. Only the
non-incremental invocation used by these configurations is supported.

## Local evaluation

With compatible Yosys, SymbiYosys and native Bitwuzla 0.9.1 installed, make the
adapter available under the executable name `bitwuzla` and set the native path:

```bash
mkdir -p /tmp/capu-bitwuzla-bin
cp tools/bitwuzla_cli_compat.sh /tmp/capu-bitwuzla-bin/bitwuzla
chmod +x /tmp/capu-bitwuzla-bin/bitwuzla
export CAPU_BITWUZLA_BIN=/absolute/path/to/bitwuzla
export PATH="/tmp/capu-bitwuzla-bin:$PATH"
sby -f formal/capu_multibeat_dma_recovery_v29_bitwuzla.sby
sby -f formal/capu_multibeat_dma_recovery_v29_cover_bitwuzla.sby
sby -f formal/capu_durable_negative_completion_v28_bitwuzla.sby
```

The optional workflow retains logs, witness files, version information, source
revision and input digests as an artifact. A separate successful run of the
workflow on the exact reviewed revision is required before making CI or release
claims about it. Repeated measurements under comparable conditions are needed
before asserting a general performance advantage.
