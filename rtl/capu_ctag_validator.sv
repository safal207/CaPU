module capu_ctag_validator #(
    parameter bit REQUIRE_WRITE_CLASS = 1'b1
) (
    input  logic [15:0] ctag,
    input  logic        metadata_valid,

    output logic        ctag_accept,
    output logic [3:0]  ctag_dom,
    output logic [3:0]  ctag_class,
    output logic [3:0]  ctag_gen,
    output logic [2:0]  ctag_lhint,
    output logic        ctag_seal
);
    localparam logic [3:0] DOM_RESERVED = 4'hF;
    localparam logic [3:0] CLASS_NONE   = 4'h0;
    localparam logic [3:0] CLASS_WRITE  = 4'h2;

    assign ctag_dom   = ctag[15:12];
    assign ctag_class = ctag[11:8];
    assign ctag_gen   = ctag[7:4];
    assign ctag_lhint = ctag[3:1];
    assign ctag_seal  = ctag[0];

    always_comb begin
        // v0.3 only performs local, mechanically checkable STORE semantics.
        // It does not authenticate lineage, recompute LHINT, or treat SEAL as
        // cryptographic evidence. GEN is an opaque 4-bit epoch at this layer.
        ctag_accept = metadata_valid;

        // RESERVED is never accepted as a concrete causal domain.
        if (ctag_dom == DOM_RESERVED)
            ctag_accept = 1'b0;

        // CLASS=NONE carries no actionable boundary semantics.
        if (ctag_class == CLASS_NONE)
            ctag_accept = 1'b0;

        // The normal CaPU STORE path is strict: a memory write must carry the
        // canonical CML WRITE class. Integrators may disable this only through
        // the explicit module parameter for a different boundary experiment.
        if (REQUIRE_WRITE_CLASS && (ctag_class != CLASS_WRITE))
            ctag_accept = 1'b0;
    end
endmodule
