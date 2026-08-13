module capu_generation_wrap_aba_v25 #(
    parameter int GEN_WIDTH=2,
    parameter int INC_WIDTH=3,
    parameter int ASID_WIDTH=3,
    parameter int EPOCH_WIDTH=4,
    parameter int VPN_WIDTH=4
) (
    input logic clk,
    input logic rst_n,
    input logic recovery_begin,
    input logic restore_valid,

    input logic launch_valid,
    input logic [INC_WIDTH-1:0] launch_incarnation,
    input logic [GEN_WIDTH-1:0] launch_generation,
    input logic [ASID_WIDTH-1:0] launch_asid,
    input logic [EPOCH_WIDTH-1:0] launch_epoch,
    input logic [VPN_WIDTH-1:0] launch_vpn,
    input logic [1:0] launch_required_harts,

    input logic delivery_valid,
    input logic delivery_hart,
    input logic [INC_WIDTH-1:0] delivery_incarnation,
    input logic [GEN_WIDTH-1:0] delivery_generation,
    input logic [ASID_WIDTH-1:0] delivery_asid,
    input logic [EPOCH_WIDTH-1:0] delivery_epoch,
    input logic [VPN_WIDTH-1:0] delivery_vpn,

    input logic ack_valid,
    input logic ack_hart,
    input logic [INC_WIDTH-1:0] ack_incarnation,
    input logic [GEN_WIDTH-1:0] ack_generation,
    input logic [ASID_WIDTH-1:0] ack_asid,
    input logic [EPOCH_WIDTH-1:0] ack_epoch,
    input logic [VPN_WIDTH-1:0] ack_vpn,

    output logic launch_accept,
    output logic launch_rejected,
    output logic pending,
    output logic retired_valid,
    output logic [INC_WIDTH-1:0] retired_incarnation,
    output logic [GEN_WIDTH-1:0] retired_generation,
    output logic [INC_WIDTH-1:0] pending_incarnation,
    output logic [GEN_WIDTH-1:0] pending_generation,
    output logic [ASID_WIDTH-1:0] pending_asid,
    output logic [EPOCH_WIDTH-1:0] pending_epoch,
    output logic [VPN_WIDTH-1:0] pending_vpn,
    output logic [1:0] required_harts,
    output logic [1:0] delivered_bitmap,
    output logic [1:0] ack_bitmap,
    output logic [1:0] quarantined_delivery_bitmap,
    output logic [1:0] quarantined_ack_bitmap,
    output logic delivery_accept,
    output logic delivery_quarantined,
    output logic ack_accept,
    output logic ack_quarantined,
    output logic quorum_complete,
    output logic global_translation_authority_ready,
    output logic speculation_kill
);
    logic exact_delivery, exact_ack;
    logic [1:0] ack_now, effective_ack;
    logic [GEN_WIDTH-1:0] expected_generation;
    logic wrap_transition;
    logic exact_successor_identity;

    assign expected_generation = retired_generation + {{(GEN_WIDTH-1){1'b0}},1'b1};
    assign wrap_transition = retired_valid && (&retired_generation);

    assign exact_successor_identity = !retired_valid ||
        ((!wrap_transition && launch_generation == expected_generation && launch_incarnation == retired_incarnation) ||
         (wrap_transition && launch_generation == {GEN_WIDTH{1'b0}} && launch_incarnation == retired_incarnation + {{(INC_WIDTH-1){1'b0}},1'b1}));

    assign launch_accept = launch_valid && !pending && launch_required_harts != 2'b00 &&
                           exact_successor_identity && !recovery_begin && !restore_valid;
    assign launch_rejected = launch_valid && !launch_accept;

    assign exact_delivery = pending && required_harts[delivery_hart] && !ack_bitmap[delivery_hart] &&
                            delivery_incarnation == pending_incarnation &&
                            delivery_generation == pending_generation &&
                            delivery_asid == pending_asid && delivery_epoch == pending_epoch &&
                            delivery_vpn == pending_vpn;
    assign delivery_accept = delivery_valid && exact_delivery && !recovery_begin && !restore_valid;
    assign delivery_quarantined = delivery_valid && !delivery_accept && pending && !recovery_begin && !restore_valid;

    assign exact_ack = pending && required_harts[ack_hart] && delivered_bitmap[ack_hart] && !ack_bitmap[ack_hart] &&
                       ack_incarnation == pending_incarnation && ack_generation == pending_generation &&
                       ack_asid == pending_asid && ack_epoch == pending_epoch && ack_vpn == pending_vpn;
    assign ack_accept = ack_valid && exact_ack && !recovery_begin && !restore_valid;
    assign ack_quarantined = ack_valid && !ack_accept && pending && !recovery_begin && !restore_valid;

    assign ack_now = ack_accept ? (ack_hart ? 2'b10 : 2'b01) : 2'b00;
    assign effective_ack = ack_bitmap | ack_now;
    assign quorum_complete = pending && required_harts != 2'b00 &&
                             ((effective_ack & required_harts) == required_harts) &&
                             !recovery_begin && !restore_valid;
    assign global_translation_authority_ready = !pending && !launch_valid && !recovery_begin && !restore_valid;
    assign speculation_kill = recovery_begin || restore_valid || launch_valid || pending ||
                              delivery_quarantined || ack_quarantined || quorum_complete;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            pending <= 1'b0;
            retired_valid <= 1'b0;
            retired_incarnation <= '0;
            retired_generation <= '0;
            pending_incarnation <= '0;
            pending_generation <= '0;
            pending_asid <= '0;
            pending_epoch <= '0;
            pending_vpn <= '0;
            required_harts <= 2'b00;
            delivered_bitmap <= 2'b00;
            ack_bitmap <= 2'b00;
            quarantined_delivery_bitmap <= 2'b00;
            quarantined_ack_bitmap <= 2'b00;
        end else if(recovery_begin || restore_valid) begin
            pending <= 1'b0;
            required_harts <= 2'b00;
            delivered_bitmap <= 2'b00;
            ack_bitmap <= 2'b00;
            quarantined_delivery_bitmap <= 2'b00;
            quarantined_ack_bitmap <= 2'b00;
        end else if(launch_accept) begin
            pending <= 1'b1;
            pending_incarnation <= launch_incarnation;
            pending_generation <= launch_generation;
            pending_asid <= launch_asid;
            pending_epoch <= launch_epoch;
            pending_vpn <= launch_vpn;
            required_harts <= launch_required_harts;
            delivered_bitmap <= 2'b00;
            ack_bitmap <= 2'b00;
            quarantined_delivery_bitmap <= 2'b00;
            quarantined_ack_bitmap <= 2'b00;
        end else if(pending) begin
            if(delivery_accept) delivered_bitmap[delivery_hart] <= 1'b1;
            if(delivery_quarantined) quarantined_delivery_bitmap[delivery_hart] <= 1'b1;
            if(ack_quarantined) quarantined_ack_bitmap[ack_hart] <= 1'b1;
            ack_bitmap <= effective_ack;
            if(quorum_complete) begin
                pending <= 1'b0;
                retired_valid <= 1'b1;
                retired_incarnation <= pending_incarnation;
                retired_generation <= pending_generation;
                required_harts <= 2'b00;
                delivered_bitmap <= 2'b00;
                ack_bitmap <= 2'b00;
                quarantined_delivery_bitmap <= 2'b00;
                quarantined_ack_bitmap <= 2'b00;
            end
        end
    end
endmodule
