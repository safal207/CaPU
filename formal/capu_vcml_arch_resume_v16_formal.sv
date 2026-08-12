module capu_vcml_arch_resume_v16_formal;
    localparam int ADDR_W = 4;
    localparam int DATA_W = 8;
    localparam int TID_W = 4;
    localparam int AUTH_W = 4;
    localparam int POLICY_W = 4;
    localparam int SLOTS = 2;
    localparam int EPOCH_W = 3;

    (* gclk *) reg clk;
    reg rst_n = 1'b0;
    always @(posedge clk) rst_n <= 1'b1;

    (* anyseq *) reg recovery_begin;
    (* anyseq *) reg restore_valid;
    (* anyseq *) reg [EPOCH_W-1:0] restore_arch_epoch;
    (* anyseq *) reg [EPOCH_W-1:0] restore_causal_epoch;
    (* anyseq *) reg [ADDR_W-1:0] restore_pc;
    (* anyseq *) reg [DATA_W-1:0] restore_gpr0;
    (* anyseq *) reg [DATA_W-1:0] restore_gpr1;
    (* anyseq *) reg [DATA_W-1:0] restore_gpr2;
    (* anyseq *) reg [DATA_W-1:0] restore_gpr3;
    (* anyseq *) reg [7:0] restore_status;
    (* anyseq *) reg [SLOTS-1:0] restore_spent_valid;
    (* anyseq *) reg [(SLOTS*AUTH_W)-1:0] restore_spent_refs;
    (* anyseq *) reg restore_causal_head_valid;
    (* anyseq *) reg [TID_W-1:0] restore_causal_head_transition_id;
    (* anyseq *) reg [3:0] restore_causal_head_gen;
    (* anyseq *) reg restore_sealed_chain;

    (* anyseq *) reg issue_valid;
    (* anyseq *) reg [ADDR_W-1:0] issue_pc;
    (* anyseq *) reg [1:0] store_addr_reg;
    (* anyseq *) reg [1:0] store_data_reg;
    (* anyseq *) reg gate_allow;
    (* anyseq *) reg execute_ok;
    (* anyseq *) reg [15:0] store_ctag;
    (* anyseq *) reg store_ctag_valid;
    (* anyseq *) reg [TID_W-1:0] store_transition_id;
    (* anyseq *) reg [TID_W-1:0] store_parent_ref;
    (* anyseq *) reg explicit_new_cause;
    (* anyseq *) reg root_authorized;
    (* anyseq *) reg [AUTH_W-1:0] root_authorization_ref;
    (* anyseq *) reg [POLICY_W-1:0] root_policy_epoch;
    (* anyseq *) reg causal_valid;
    (* anyseq *) reg commit_request;
    (* anyseq *) reg flush;

    wire memory_write_enable;
    wire [ADDR_W-1:0] memory_write_addr;
    wire [DATA_W-1:0] memory_write_data;
    wire vcml_event_valid;
    wire issue_rejected;
    wire live_execution_ready;
    wire [EPOCH_W-1:0] live_restore_epoch;
    wire [ADDR_W-1:0] live_pc;
    wire [DATA_W-1:0] live_gpr0, live_gpr1, live_gpr2, live_gpr3;
    wire [7:0] live_status;
    wire live_causal_state_ready;
    wire live_causal_head_valid;
    wire [TID_W-1:0] live_causal_head_transition_id;
    wire [3:0] live_causal_head_gen;
    wire live_sealed_chain;
    wire live_generation_exhausted;
    wire split_state_restore_rejected;
    wire architectural_restore_accept;

    capu_vcml_store_buffer_v16 #(
        .ADDR_WIDTH(ADDR_W), .DATA_WIDTH(DATA_W),
        .TRANSITION_ID_WIDTH(TID_W), .PARENT_REF_WIDTH(TID_W),
        .AUTHORIZATION_REF_WIDTH(AUTH_W), .POLICY_EPOCH_WIDTH(POLICY_W),
        .SPENT_AUTHORIZATION_SLOTS(SLOTS), .ARCH_EPOCH_WIDTH(EPOCH_W)
    ) dut (.*);

    reg expect_restore = 1'b0;
    reg [EPOCH_W-1:0] expected_epoch;
    reg [ADDR_W-1:0] expected_pc;
    reg [DATA_W-1:0] expected_gpr0, expected_gpr1, expected_gpr2, expected_gpr3;
    reg [7:0] expected_status;
    reg prev_recovery_activity = 1'b0;

    reg seen_split_reject = 1'b0;
    reg seen_good_restore = 1'b0;
    reg seen_wrong_pc_reject = 1'b0;
    reg seen_restored_register_store = 1'b0;
    reg seen_post_recovery_retire = 1'b0;

    always @(posedge clk) begin
        if (!rst_n) begin
            expect_restore <= 1'b0;
            prev_recovery_activity <= 1'b0;
            seen_split_reject <= 1'b0;
            seen_good_restore <= 1'b0;
            seen_wrong_pc_reject <= 1'b0;
            seen_restored_register_store <= 1'b0;
            seen_post_recovery_retire <= 1'b0;
        end else begin
            if (restore_valid && restore_arch_epoch != restore_causal_epoch) begin
                assert(split_state_restore_rejected);
                assert(!architectural_restore_accept);
                assert(!memory_write_enable);
                seen_split_reject <= 1'b1;
            end

            if (architectural_restore_accept) begin
                assert(restore_valid);
                assert(restore_arch_epoch == restore_causal_epoch);
                expect_restore <= 1'b1;
                expected_epoch <= restore_arch_epoch;
                expected_pc <= restore_pc;
                expected_gpr0 <= restore_gpr0;
                expected_gpr1 <= restore_gpr1;
                expected_gpr2 <= restore_gpr2;
                expected_gpr3 <= restore_gpr3;
                expected_status <= restore_status;
                seen_good_restore <= 1'b1;
            end

            if (expect_restore) begin
                assert(live_execution_ready);
                assert(live_causal_state_ready);
                assert(live_restore_epoch == expected_epoch);
                assert(live_pc == expected_pc);
                assert(live_gpr0 == expected_gpr0);
                assert(live_gpr1 == expected_gpr1);
                assert(live_gpr2 == expected_gpr2);
                assert(live_gpr3 == expected_gpr3);
                assert(live_status == expected_status);
                expect_restore <= 1'b0;
            end

            if (issue_valid && live_execution_ready && issue_pc != live_pc) begin
                assert(issue_rejected);
                seen_wrong_pc_reject <= 1'b1;
            end

            if (memory_write_enable) begin
                assert(vcml_event_valid);
                case (store_addr_reg)
                    2'd0: assert(memory_write_addr == live_gpr0[ADDR_W-1:0]);
                    2'd1: assert(memory_write_addr == live_gpr1[ADDR_W-1:0]);
                    2'd2: assert(memory_write_addr == live_gpr2[ADDR_W-1:0]);
                    2'd3: assert(memory_write_addr == live_gpr3[ADDR_W-1:0]);
                endcase
                case (store_data_reg)
                    2'd0: assert(memory_write_data == live_gpr0);
                    2'd1: assert(memory_write_data == live_gpr1);
                    2'd2: assert(memory_write_data == live_gpr2);
                    2'd3: assert(memory_write_data == live_gpr3);
                endcase
                if (seen_good_restore) begin
                    seen_restored_register_store <= 1'b1;
                    seen_post_recovery_retire <= 1'b1;
                end
            end

            if (prev_recovery_activity) begin
                assert(!memory_write_enable);
                assert(!vcml_event_valid);
            end

            if ((recovery_begin || restore_valid) && issue_valid)
                assert(issue_rejected);

            prev_recovery_activity <= recovery_begin || restore_valid;

            cover(seen_split_reject);
            cover(seen_good_restore);
            cover(seen_wrong_pc_reject);
            cover(seen_restored_register_store);
            cover(seen_post_recovery_retire);
        end
    end
endmodule
