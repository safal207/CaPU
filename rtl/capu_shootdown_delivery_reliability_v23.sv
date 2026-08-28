module capu_shootdown_delivery_reliability_v23 #(
    parameter int ASID_WIDTH=3,
    parameter int EPOCH_WIDTH=4,
    parameter int VPN_WIDTH=4,
    parameter int GEN_WIDTH=4,
    parameter int ATTEMPT_WIDTH=2,
    parameter logic [ATTEMPT_WIDTH-1:0] MAX_ATTEMPTS=2'd3
) (
    input logic clk,
    input logic rst_n,
    input logic recovery_begin,
    input logic restore_valid,

    input logic shootdown_launch_valid,
    input logic [GEN_WIDTH-1:0] launch_generation,
    input logic [ASID_WIDTH-1:0] launch_asid,
    input logic [EPOCH_WIDTH-1:0] launch_epoch,
    input logic [VPN_WIDTH-1:0] launch_vpn,
    input logic [1:0] launch_required_harts,

    input logic send0_valid,
    input logic send0_lost,
    input logic [GEN_WIDTH-1:0] send0_generation,
    input logic [ASID_WIDTH-1:0] send0_asid,
    input logic [EPOCH_WIDTH-1:0] send0_epoch,
    input logic [VPN_WIDTH-1:0] send0_vpn,

    input logic send1_valid,
    input logic send1_lost,
    input logic [GEN_WIDTH-1:0] send1_generation,
    input logic [ASID_WIDTH-1:0] send1_asid,
    input logic [EPOCH_WIDTH-1:0] send1_epoch,
    input logic [VPN_WIDTH-1:0] send1_vpn,

    input logic ack0_valid,
    input logic [GEN_WIDTH-1:0] ack0_generation,
    input logic [ASID_WIDTH-1:0] ack0_asid,
    input logic [EPOCH_WIDTH-1:0] ack0_epoch,
    input logic [VPN_WIDTH-1:0] ack0_vpn,

    input logic ack1_valid,
    input logic [GEN_WIDTH-1:0] ack1_generation,
    input logic [ASID_WIDTH-1:0] ack1_asid,
    input logic [EPOCH_WIDTH-1:0] ack1_epoch,
    input logic [VPN_WIDTH-1:0] ack1_vpn,

    output logic shootdown_launch_accept,
    output logic shootdown_launch_rejected,
    output logic shootdown_pending,
    output logic [GEN_WIDTH-1:0] pending_generation,
    output logic [ASID_WIDTH-1:0] pending_asid,
    output logic [EPOCH_WIDTH-1:0] pending_epoch,
    output logic [VPN_WIDTH-1:0] pending_vpn,
    output logic [1:0] required_harts,
    output logic [1:0] delivered_bitmap,
    output logic [1:0] ack_bitmap,
    output logic [ATTEMPT_WIDTH-1:0] attempts0,
    output logic [ATTEMPT_WIDTH-1:0] attempts1,
    output logic send0_accept,
    output logic send0_rejected,
    output logic send1_accept,
    output logic send1_rejected,
    output logic delivery0_observed,
    output logic delivery1_observed,
    output logic ack0_accept,
    output logic ack0_rejected,
    output logic ack1_accept,
    output logic ack1_rejected,
    output logic quorum_complete,
    output logic global_translation_authority_ready,
    output logic speculation_kill
);
    logic send0_exact, send1_exact;
    logic ack0_exact, ack1_exact;
    logic [1:0] accepted_acks_now;
    logic [1:0] effective_ack_bitmap;

    assign shootdown_launch_accept = shootdown_launch_valid && !shootdown_pending &&
                                      (launch_required_harts != 2'b00) &&
                                      !recovery_begin && !restore_valid;
    assign shootdown_launch_rejected = shootdown_launch_valid && !shootdown_launch_accept;

    assign send0_exact = shootdown_pending && required_harts[0] && !ack_bitmap[0] &&
                         attempts0 < MAX_ATTEMPTS &&
                         send0_generation == pending_generation &&
                         send0_asid == pending_asid && send0_epoch == pending_epoch &&
                         send0_vpn == pending_vpn;
    assign send1_exact = shootdown_pending && required_harts[1] && !ack_bitmap[1] &&
                         attempts1 < MAX_ATTEMPTS &&
                         send1_generation == pending_generation &&
                         send1_asid == pending_asid && send1_epoch == pending_epoch &&
                         send1_vpn == pending_vpn;

    assign send0_accept = send0_valid && send0_exact && !recovery_begin && !restore_valid;
    assign send1_accept = send1_valid && send1_exact && !recovery_begin && !restore_valid;
    assign send0_rejected = send0_valid && !send0_accept;
    assign send1_rejected = send1_valid && !send1_accept;
    assign delivery0_observed = send0_accept && !send0_lost;
    assign delivery1_observed = send1_accept && !send1_lost;

    assign ack0_exact = shootdown_pending && required_harts[0] && delivered_bitmap[0] && !ack_bitmap[0] &&
                        ack0_generation == pending_generation &&
                        ack0_asid == pending_asid && ack0_epoch == pending_epoch &&
                        ack0_vpn == pending_vpn;
    assign ack1_exact = shootdown_pending && required_harts[1] && delivered_bitmap[1] && !ack_bitmap[1] &&
                        ack1_generation == pending_generation &&
                        ack1_asid == pending_asid && ack1_epoch == pending_epoch &&
                        ack1_vpn == pending_vpn;

    assign ack0_accept = ack0_valid && ack0_exact && !recovery_begin && !restore_valid;
    assign ack1_accept = ack1_valid && ack1_exact && !recovery_begin && !restore_valid;
    assign ack0_rejected = ack0_valid && !ack0_accept;
    assign ack1_rejected = ack1_valid && !ack1_accept;

    assign accepted_acks_now = {ack1_accept,ack0_accept};
    assign effective_ack_bitmap = ack_bitmap | accepted_acks_now;
    assign quorum_complete = shootdown_pending && required_harts != 2'b00 &&
                             ((effective_ack_bitmap & required_harts) == required_harts) &&
                             !recovery_begin && !restore_valid;

    assign global_translation_authority_ready = !shootdown_pending && !shootdown_launch_valid &&
                                                !recovery_begin && !restore_valid;
    assign speculation_kill = recovery_begin || restore_valid || shootdown_launch_valid || shootdown_pending ||
                              send0_rejected || send1_rejected || ack0_rejected || ack1_rejected || quorum_complete;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            shootdown_pending <= 1'b0;
            pending_generation <= '0;
            pending_asid <= '0;
            pending_epoch <= '0;
            pending_vpn <= '0;
            required_harts <= 2'b00;
            delivered_bitmap <= 2'b00;
            ack_bitmap <= 2'b00;
            attempts0 <= '0;
            attempts1 <= '0;
        end else if(recovery_begin || restore_valid) begin
            shootdown_pending <= 1'b0;
            required_harts <= 2'b00;
            delivered_bitmap <= 2'b00;
            ack_bitmap <= 2'b00;
            attempts0 <= '0;
            attempts1 <= '0;
        end else if(shootdown_launch_accept) begin
            shootdown_pending <= 1'b1;
            pending_generation <= launch_generation;
            pending_asid <= launch_asid;
            pending_epoch <= launch_epoch;
            pending_vpn <= launch_vpn;
            required_harts <= launch_required_harts;
            delivered_bitmap <= 2'b00;
            ack_bitmap <= 2'b00;
            attempts0 <= '0;
            attempts1 <= '0;
        end else if(shootdown_pending) begin
            if(send0_accept) attempts0 <= attempts0 + 1'b1;
            if(send1_accept) attempts1 <= attempts1 + 1'b1;
            if(delivery0_observed) delivered_bitmap[0] <= 1'b1;
            if(delivery1_observed) delivered_bitmap[1] <= 1'b1;
            ack_bitmap <= effective_ack_bitmap;
            if(quorum_complete) begin
                shootdown_pending <= 1'b0;
                required_harts <= 2'b00;
                delivered_bitmap <= 2'b00;
                ack_bitmap <= 2'b00;
                attempts0 <= '0;
                attempts1 <= '0;
            end
        end
    end
endmodule
