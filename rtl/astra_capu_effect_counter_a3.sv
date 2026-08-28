module astra_capu_effect_counter_a3 #(
  parameter COUNT_WIDTH = 16
)(
  input  logic                   clk,
  input  logic                   rst_n,
  input  logic                   load_valid,
  input  logic [COUNT_WIDTH-1:0] load_effect_count,
  input  logic                   command_valid,
  input  logic                   command_commit,
  output logic                   command_accept,
  output logic                   completion_valid,
  output logic [COUNT_WIDTH-1:0] effect_count
);

  always_comb begin
    command_accept = rst_n && command_valid;
    completion_valid = command_accept && command_commit;
  end

  always_ff @(posedge clk) begin
    if (!rst_n)
      effect_count <= '0;
    else if (load_valid)
      effect_count <= load_effect_count;
    else if (command_accept && command_commit)
      effect_count <= effect_count + {{(COUNT_WIDTH-1){1'b0}}, 1'b1};
  end

endmodule
