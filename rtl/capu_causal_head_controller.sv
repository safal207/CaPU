module capu_causal_head_controller #(
    parameter int TRANSITION_ID_WIDTH = 64,
    parameter bit ENABLE_RESTORE = 1'b0
) (
    input  logic                           clk,
    input  logic                           rst_n,
    input  logic                           committed_event,
    input  logic [TRANSITION_ID_WIDTH-1:0] committed_transition_id,
    input  logic [3:0]                     committed_gen,

    // v0.15 optional recovery path. Older instances keep ENABLE_RESTORE=0,
    // so their behavior remains retirement-only.
    input  logic                           restore_valid,
    input  logic                           restore_head_valid,
    input  logic [TRANSITION_ID_WIDTH-1:0] restore_transition_id,
    input  logic [3:0]                     restore_gen,

    output logic                           head_valid,
    output logic [TRANSITION_ID_WIDTH-1:0] causal_head_transition_id,
    output logic [3:0]                     causal_head_gen
);
    logic restore_active;

    assign restore_active = ENABLE_RESTORE && (restore_valid === 1'b1);

    // v0.15 treats an accepted recovery snapshot as another source of
    // authoritative committed state. Restore has priority over a simultaneous
    // retirement because recovery must establish the exact checkpointed state
    // before new execution can resume.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            head_valid                <= 1'b0;
            causal_head_transition_id <= '0;
            causal_head_gen           <= 4'h0;
        end else if (restore_active) begin
            head_valid                <= restore_head_valid;
            causal_head_transition_id <= restore_head_valid ? restore_transition_id : '0;
            causal_head_gen           <= restore_head_valid ? restore_gen : 4'h0;
        end else if (committed_event) begin
            head_valid                <= 1'b1;
            causal_head_transition_id <= committed_transition_id;
            causal_head_gen           <= committed_gen;
        end
    end
endmodule
