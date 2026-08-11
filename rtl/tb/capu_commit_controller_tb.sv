`timescale 1ns/1ps

module capu_commit_controller_tb;
    localparam int WIDTH = 32;

    logic clk = 1'b0;
    logic rst_n = 1'b0;

    logic             candidate_valid;
    logic             gate_allow;
    logic             execute_ok;
    logic             causal_valid;
    logic             commit_request;
    logic [WIDTH-1:0] result_value;

    logic [WIDTH-1:0] architectural_state;
    logic             architectural_write_enable;
    logic             rejected;

    capu_commit_controller #(.WIDTH(WIDTH)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .candidate_valid(candidate_valid),
        .gate_allow(gate_allow),
        .execute_ok(execute_ok),
        .causal_valid(causal_valid),
        .commit_request(commit_request),
        .result_value(result_value),
        .architectural_state(architectural_state),
        .architectural_write_enable(architectural_write_enable),
        .rejected(rejected)
    );

    always #5 clk = ~clk;

    task automatic drive_candidate(
        input logic             t_candidate_valid,
        input logic             t_gate_allow,
        input logic             t_execute_ok,
        input logic             t_causal_valid,
        input logic             t_commit_request,
        input logic [WIDTH-1:0] t_result_value
    );
        begin
            candidate_valid = t_candidate_valid;
            gate_allow = t_gate_allow;
            execute_ok = t_execute_ok;
            causal_valid = t_causal_valid;
            commit_request = t_commit_request;
            result_value = t_result_value;
            @(posedge clk);
            #1;
        end
    endtask

    task automatic expect_state(
        input logic [WIDTH-1:0] expected,
        input string            label
    );
        begin
            if (architectural_state !== expected) begin
                $fatal(1, "%s: expected architectural_state=%h got=%h",
                       label, expected, architectural_state);
            end
        end
    endtask

    initial begin
        candidate_valid = 1'b0;
        gate_allow = 1'b0;
        execute_ok = 1'b0;
        causal_valid = 1'b0;
        commit_request = 1'b0;
        result_value = '0;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        #1;
        expect_state('0, "reset state");

        // 1. Gate rejection: computed/proposed data must not become architectural.
        drive_candidate(1'b1, 1'b0, 1'b1, 1'b1, 1'b1, 32'h0000_0011);
        expect_state(32'h0000_0000, "gate rejection");
        if (architectural_write_enable !== 1'b0)
            $fatal(1, "gate rejection asserted architectural write enable");

        // 2. Causal validation failure: speculative result remains contained.
        drive_candidate(1'b1, 1'b1, 1'b1, 1'b0, 1'b1, 32'h0000_0022);
        expect_state(32'h0000_0000, "causal validation failure");
        if (architectural_write_enable !== 1'b0)
            $fatal(1, "causal validation failure asserted architectural write enable");

        // 3. Valid candidate without commit request: still no architectural effect.
        drive_candidate(1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 32'h0000_0033);
        expect_state(32'h0000_0000, "commit absent");
        if (architectural_write_enable !== 1'b0)
            $fatal(1, "commit absent asserted architectural write enable");

        // 4. All predicates satisfied: exactly one architectural transition.
        drive_candidate(1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 32'hCAFE_0044);
        expect_state(32'hCAFE_0044, "valid causal commit");
        if (architectural_write_enable !== 1'b1)
            $fatal(1, "valid causal commit did not assert architectural write enable");

        // Remove the candidate; state must remain at the last committed value.
        drive_candidate(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 32'hDEAD_BEEF);
        expect_state(32'hCAFE_0044, "post-commit hold");

        // 5. Execute failure after a previous valid commit must not corrupt it.
        drive_candidate(1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 32'hBAD0_0055);
        expect_state(32'hCAFE_0044, "execute failure containment");

        $display("CAPU_CORE_V0_SMOKE_PASS");
        $finish;
    end
endmodule
