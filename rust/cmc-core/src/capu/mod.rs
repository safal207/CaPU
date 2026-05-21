//! Software reference units for the CaPU legitimacy processor.
//!
//! These modules are intentionally small and additive. They begin the bridge
//! from the processor model / semantic ISA / microarchitecture documents into
//! executable Rust units without changing the existing CMC reviewer outputs.

pub mod boundary_router;
pub mod cause_unit;
pub mod commit_unit;
pub mod decision_unit;
pub mod decoder;
pub mod transition;
