export class InMemoryExecutor {
  execute(effectPlan) {
    if (
      effectPlan.effect_type === "dispatch" &&
      typeof effectPlan.parameters?.url === "string" &&
      effectPlan.parameters.url.includes("example.invalid")
    ) {
      return {
        status: "FAIL",
        reason_code: "ABORT_INTERNAL_ERROR",
        artifacts: []
      };
    }

    return {
      status: "OK",
      reason_code: "COMMIT_EXECUTED",
      artifacts: []
    };
  }
}
