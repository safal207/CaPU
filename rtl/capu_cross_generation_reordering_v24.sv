module capu_cross_generation_reordering_v24 #(
    parameter int ASID_WIDTH=3,
    parameter int EPOCH_WIDTH=4,
    parameter int VPN_WIDTH=4,
    parameter int GEN_WIDTH=4
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

    input logic delivery0_valid,
    input logic [GEN_WIDTH-1:0] delivery0_generation,
    input logic [ASID_WIDTH-1:0] delivery0_asid,
    input logic [EPOCH_WIDTH-1:0] delivery0_epoch,
    input logic [VPN_WIDTH-1:0] delivery0_vpn,

    input logic delivery1_valid,
    input logic [GEN_WIDTH-1:0] delivery1_generation,
    input logic [ASID_WIDTH-1:0] delivery1_asid,
    input logic [EPOCH_WIDTH-1:0] delivery1_epoch,
    input logic [VPN_WIDTH-1:0] delivery1_vpn,

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
    output logic last_retired_valid,
    output logic [GEN_WIDTH-1:0] last_retired_generation,
    output logic [1:0] delivered_bitmap,
    output logic [1:0] ack_bitmap,
    output logic [1:0] quarantined_delivery_bitmap,
    output logic [1:0] quarantined_ack_bitmap,
    output logic [2:0] quarantine_events,
    output logic delivery0_accept,
    output logic delivery0_quarantined,
    output logic delivery1_accept,
    output logic delivery1_quarantined,
    output logic ack0_accept,
    output logic ack0_rejected,
    output logic ack0_quarantined,
    output logic ack1_accept,
    output logic ack1_rejected,
    output logic ack1_quarantined,
    output logic quorum_complete,
    output logic global_translation_authority_ready,
    output logic speculation_kill
);
    localparam logic [GEN_WIDTH-1:0] GEN_MAX = {GEN_WIDTH{1'b1}};

    logic launch_successor_ok;
    logic delivery0_identity_exact, delivery1_identity_exact;
    logic ack0_identity_exact, ack1_identity_exact;
    logic [1:0] accepted_acks_now;
    logic [1:0] effective_ack_bitmap;
    logic [2:0] quarantine_increment;

    assign launch_successor_ok = !last_retired_valid ||
                                 ((last_retired_generation != GEN_MAX) &&
                                  (launch_generation == (last_retired_generation + 1'b1)));

    assign shootdown_launch_accept = shootdown_launch_valid && !shootdown_pending &&
                                      (launch_required_harts != 2'b00) && launch_successor_ok &&
                                      !recovery_begin && !restore_valid;
    assign shootdown_launch_rejected = shootdown_launch_valid && !shootdown_launch_accept;

    assign delivery0_identity_exact = shootdown_pending && required_harts[0] && !ack_bitmap[0] &&
                                      delivery0_generation == pending_generation &&
                                      delivery0_asid == pending_asid && delivery0_epoch == pending_epoch &&
                                      delivery0_vpn == pending_vpn;
    assign delivery1_identity_exact = shootdown_pending && required_harts[1] && !ack_bitmap[1] &&
                                      delivery1_generation == pending_generation &&
                                      delivery1_asid == pending_asid && delivery1_epoch == pending_epoch &&
                                      delivery1_vpn == pending_vpn;

    assign delivery0_accept = delivery0_valid && delivery0_identity_exact && !recovery_begin && !restore_valid;
    assign delivery1_accept = delivery1_valid && delivery1_identity_exact && !recovery_begin && !restore_valid;
    assign delivery0_quarantined = delivery0_valid && shootdown_pending && !delivery0_identity_exact &&
                                   !recovery_begin && !restore_valid;
    assign delivery1_quarantined = delivery1_valid && shootdown_pending && !delivery1_identity_exact &&
                                   !recovery_begin && !restore_valid;

    assign ack0_identity_exact = shootdown_pending && required_harts[0] &&
                                 ack0_generation == pending_generation &&
                                 ack0_asid == pending_asid && ack0_epoch == pending_epoch &&
                                 ack0_vpn == pending_vpn;
    assign ack1_identity_exact = shootdown_pending && required_harts[1] &&
                                 ack1_generation == pending_generation &&
                                 ack1_asid == pending_asid && ack1_epoch == pending_epoch &&
                                 ack1_vpn == pending_vpn;

    assign ack0_accept = ack0_valid && ack0_identity_exact && delivered_bitmap[0] && !ack_bitmap[0] &&
                         !recovery_begin && !restore_valid;
    assign ack1_accept = ack1_valid && ack1_identity_exact && delivered_bitmap[1] && !ack_bitmap[1] &&
                         !recovery_begin && !restore_valid;
    assign ack0_quarantined = ack0_valid && shootdown_pending && !ack0_identity_exact &&
                              !recovery_begin && !restore_valid;
    assign ack1_quarantined = ack1_valid && shootdown_pending && !ack1_identity_exact &&
                              !recovery_begin && !restore_valid;
    assign ack0_rejected = ack0_valid && !ack0_accept && !ack0_quarantined;
    assign ack1_rejected = ack1_valid && !ack1_accept && !ack1_quarantined;

    assign accepted_acks_now = {ack1_accept, ack0_accept};
    assign effective_ack_bitmap = ack_bitmap | accepted_acks_now;
    assign quorum_complete = shootdown_pending && required_harts != 2'b00 &&
                             ((effective_ack_bitmap & required_harts) == required_harts) &&
                             !recovery_begin && !restore_valid;

    assign quarantine_increment = {2'b00, delivery0_quarantined} +
                                  {2'b00, delivery1_quarantined} +
                                  {2'b00, ack0_quarantined} +
                                  {2'b00, ack1_quarantined};

    assign global_translation_authority_ready = !shootdown_pending && !shootdown_launch_valid &&
                                                !recovery_begin && !restore_valid;
    assign speculation_kill = recovery_begin || restore_valid || shootdown_launch_valid || shootdown_pending ||
                              delivery0_quarantined || delivery1_quarantined ||
                              ack0_rejected || ack1_rejected || ack0_quarantined || ack1_quarantined ||
                              quorum_complete;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            shootdown_pending <= 1'b0;
            pending_generation <= '0;
            pending_asid <= '0;
            pending_epoch <= '0;
            pending_vpn <= '0;
            required_harts <= 2'b00;
            last_retired_valid <= 1'b0;
            last_retired_generation <= '0;
            delivered_bitmap <= 2'b00;
            ack_bitmap <= 2'b00;
            quarantined_delivery_bitmap <= 2'b00;
            quarantined_ack_bitmap <= 2'b00;
            quarantine_events <= 3'b000;
        end else if(recovery_begin || restore_valid) begin
            shootdown_pending <= 1'b0;
            required_harts <= 2'b00;
            delivered_bitmap <= 2'b00;
            ack_bitmap <= 2'b00;
            quarantined_delivery_bitmap <= 2'b00;
            quarantined_ack_bitmap <= 2'b00;
            quarantine_events <= 3'b000;
        end else if(shootdown_launch_accept) begin
            shootdown_pending <= 1'b1;
            pending_generation <= launch_generation;
            pending_asid <= launch_asid;
            pending_epoch <= launch_epoch;
            pending_vpn <= launch_vpn;
            required_harts <= launch_required_harts;
            delivered_bitmap <= 2'b00;
            ack_bitmap <= 2'b00;
            quarantined_delivery_bitmap <= 2'b00;
            quarantined_ack_bitmap <= 2'b00;
            quarantine_events <= 3'b000;
        end else if(shootdown_pending) begin
            if(delivery0_accept) delivered_bitmap[0] <= 1'b1;
            if(delivery1_accept) delivered_bitmap[1] <= 1'b1;
            if(delivery0_quarantined) quarantined_delivery_bitmap[0] <= 1'b1;
            if(delivery1_quarantined) quarantined_delivery_bitmap[1] <= 1'b1;
            if(ack0_quarantined) quarantined_ack_bitmap[0] <= 1'b1;
            if(ack1_quarantined) quarantined_ack_bitmap[1] <= 1'b1;
            if(quarantine_increment != 3'b000) quarantine_events <= quarantine_events + quarantine_increment;
            ack_bitmap <= effective_ack_bitmap;
            if(quorum_complete) begin
                last_retired_valid <= 1'b1;
                last_retired_generation <= pending_generation;
                shootdown_pending <= 1'b0;
                required_harts <= 2'b00;
                delivered_bitmap <= 2'b00;
                ack_bitmap <= 2'b00;
                quarantined_delivery_bitmap <= 2'b00;
                quarantined_ack_bitmap <= 2'b00;
                quarantine_events <= 3'b000;
            end
        end
    end
endmodule
