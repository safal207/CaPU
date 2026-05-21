//! Software reference units for the CaPU legitimacy processor.
//!
//! These modules are intentionally small and additive. They begin the bridge
//! from the processor model / semantic ISA / microarchitecture documents into
//! executable Rust units without changing the existing CMC reviewer outputs.

pub mod commit_unit;
pub mod transition;
