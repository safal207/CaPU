use super::transition::{Boundary, Transition, TransitionType};

/// Route a decoded transition type to the invariant boundary that should govern it.
///
/// This is the first software reference version of the CaPU Boundary Router.
/// It is intentionally deterministic and table-like so future fixture decoders
/// and sidecar APIs can share the same routing semantics.
pub fn route_boundary(transition_type: TransitionType) -> Boundary {
    match transition_type {
        TransitionType::MemoryWrite => Boundary::WriteAuthorization,
        TransitionType::MemoryRead => Boundary::ReadAuthorization,
        TransitionType::Effect => Boundary::EffectCommitBoundary,
        TransitionType::PersonaMemory => Boundary::PersonaMemoryRequiresCause,
        TransitionType::PersonaStateChange => Boundary::PersonaStateChangeRequiresAuthorization,
        TransitionType::ExternalAction => Boundary::ActionRequiresCommit,
        TransitionType::Introspection => Boundary::IntrospectionRequiresHypothesisLabel,
    }
}

/// Check whether a transition's stored boundary matches the canonical route.
pub fn boundary_matches_route(transition: &Transition) -> bool {
    transition.boundary == route_boundary(transition.transition_type)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn routes_external_action_to_p6_action_commit_boundary() {
        assert_eq!(
            route_boundary(TransitionType::ExternalAction),
            Boundary::ActionRequiresCommit
        );
    }

    #[test]
    fn routes_persona_memory_to_p1_boundary() {
        assert_eq!(
            route_boundary(TransitionType::PersonaMemory),
            Boundary::PersonaMemoryRequiresCause
        );
    }

    #[test]
    fn routes_persona_state_change_to_p2_boundary() {
        assert_eq!(
            route_boundary(TransitionType::PersonaStateChange),
            Boundary::PersonaStateChangeRequiresAuthorization
        );
    }

    #[test]
    fn routes_introspection_to_p7_boundary() {
        assert_eq!(
            route_boundary(TransitionType::Introspection),
            Boundary::IntrospectionRequiresHypothesisLabel
        );
    }

    #[test]
    fn external_action_transition_matches_canonical_route() {
        let transition = Transition::external_action("p6", "send_email", Some(101), true);

        assert!(boundary_matches_route(&transition));
        assert_eq!(transition.boundary.as_str(), "action_requires_commit");
    }
}
