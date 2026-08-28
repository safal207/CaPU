`timescale 1ns/1ps

module astra_capu_effect_counter_a3_tb;
  logic clk = 1'b0;
  logic rst_n;
  logic load_valid;
  logic [15:0] load_effect_count;
  logic command_valid;
  logic command_commit;
  logic command_accept;
  logic completion_valid;
  logic [15:0] effect_count;

  string op;
  string state_file;
  integer commit_arg;
  integer drop_receipt_arg;
  integer persisted_count;
  integer fd;
  integer scan_rc;
  integer plusarg_rc;
  integer accepted;
  integer completed;
  integer receipt_visible;

  always #5 clk = ~clk;

  astra_capu_effect_counter_a3 dut (
    .clk(clk),
    .rst_n(rst_n),
    .load_valid(load_valid),
    .load_effect_count(load_effect_count),
    .command_valid(command_valid),
    .command_commit(command_commit),
    .command_accept(command_accept),
    .completion_valid(completion_valid),
    .effect_count(effect_count)
  );

  task automatic write_state(input integer value);
    begin
      fd = $fopen(state_file, "w");
      if (fd == 0) begin
        $display("A3_ERROR unable_to_open_state_for_write path=%s", state_file);
        $fatal(1);
      end
      $fwrite(fd, "%0d\n", value);
      $fclose(fd);
    end
  endtask

  initial begin
    op = "readback";
    state_file = "astra-capu-a3-device-state.txt";
    commit_arg = 0;
    drop_receipt_arg = 0;
    persisted_count = 0;
    accepted = 0;
    completed = 0;
    receipt_visible = 0;

    plusarg_rc = $value$plusargs("OP=%s", op);
    plusarg_rc = $value$plusargs("STATE_FILE=%s", state_file);
    plusarg_rc = $value$plusargs("COMMIT=%d", commit_arg);
    plusarg_rc = $value$plusargs("DROP_RECEIPT=%d", drop_receipt_arg);

    fd = $fopen(state_file, "r");
    if (fd != 0) begin
      scan_rc = $fscanf(fd, "%d", persisted_count);
      $fclose(fd);
      if (scan_rc != 1)
        persisted_count = 0;
    end

    if (op == "reset") begin
      write_state(0);
      $display("A3_EVENT op=reset count=0");
      $display("ASTRA_CAPU_V1_A3_ICARUS_DEVICE_PASS");
      $finish;
    end

    rst_n = 1'b0;
    load_valid = 1'b0;
    load_effect_count = '0;
    command_valid = 1'b0;
    command_commit = 1'b0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    load_effect_count = persisted_count;
    load_valid = 1'b1;
    @(posedge clk);
    #1;
    load_valid = 1'b0;

    if (op == "readback") begin
      $display("A3_EVENT op=readback count=%0d", effect_count);
    end else if (op == "dispatch") begin
      command_commit = (commit_arg != 0);
      command_valid = 1'b1;
      @(posedge clk);
      #1;
      accepted = command_accept;
      completed = completion_valid;
      receipt_visible = completed && (drop_receipt_arg == 0);
      command_valid = 1'b0;
      command_commit = 1'b0;
      write_state(effect_count);
      $display(
        "A3_EVENT op=dispatch accept=%0d committed=%0d receipt=%0d count=%0d",
        accepted,
        commit_arg != 0,
        receipt_visible,
        effect_count
      );
    end else begin
      $display("A3_ERROR unsupported_op=%s", op);
      $fatal(1);
    end

    $display("ASTRA_CAPU_V1_A3_ICARUS_DEVICE_PASS");
    $finish;
  end
endmodule
