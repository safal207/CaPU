use crate::CauseId;

/// Cause validation result for CaPU reference units.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CauseCheck {
    Present(CauseId),
    Missing,
}

impl CauseCheck {
    pub fn cause_id(self) -> Option<CauseId> {
        match self {
            Self::Present(cause_id) => Some(cause_id),
            Self::Missing => None,
        }
    }
}

/// Check whether a transition carries an explicit cause identifier.
///
/// v0 only validates presence. Later versions can extend this unit to validate
/// known-cause tables, parent causes, causal chains, and committed causes.
pub fn check_cause_present(cause_id: Option<CauseId>) -> CauseCheck {
    match cause_id {
        Some(cause_id) => CauseCheck::Present(cause_id),
        None => CauseCheck::Missing,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cause_unit_accepts_present_cause() {
        let check = check_cause_present(Some(101));

        assert_eq!(check, CauseCheck::Present(101));
        assert_eq!(check.cause_id(), Some(101));
    }

    #[test]
    fn cause_unit_rejects_missing_cause() {
        let check = check_cause_present(None);

        assert_eq!(check, CauseCheck::Missing);
        assert_eq!(check.cause_id(), None);
    }
}
