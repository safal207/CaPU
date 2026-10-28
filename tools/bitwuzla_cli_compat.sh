#!/usr/bin/env bash
# Yosys 0.33 passes --smt2; Bitwuzla 0.9.1 spells that --lang smt2.
# Only the non-incremental invocation used by these experiments is supported.
set -euo pipefail
: "${CAPU_BITWUZLA_BIN:?Set CAPU_BITWUZLA_BIN to the native Bitwuzla executable}"
if [[ $# -eq 1 && "$1" == "--smt2" ]]; then
  exec "$CAPU_BITWUZLA_BIN" --lang smt2
fi
if [[ $# -eq 1 && "$1" == "--version" ]]; then
  exec "$CAPU_BITWUZLA_BIN" --version
fi
printf 'Unsupported Bitwuzla invocation\n' >&2
exit 2
