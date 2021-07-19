module tlb
#(parameter TLBNUM = 16)
(
    input                       clk        ,
    // search port 0
    input  [              18:0] s0_vpn2    ,
    input                       s0_odd_page,
    input  [               7:0] s0_asid    ,
    output                      s0_found   ,
    output [$clog2(TLBNUM)-1:0] s0_index   ,
    output [              19:0] s0_pfn     ,
    output [               2:0] s0_c       ,
    output                      s0_d       ,
    output                      s0_v       ,
    // search port 1
    input  [              18:0] s1_vpn2    ,
    input                       s1_odd_page,
    input  [               7:0] s1_asid    ,
    output                      s1_found   ,
    output [$clog2(TLBNUM)-1:0] s1_index   ,
    output [              19:0] s1_pfn     ,
    output [               2:0] s1_c       ,
    output                      s1_d       ,
    output                      s1_v       ,
    // write port
    input                       we         ,
    input  [$clog2(TLBNUM)-1:0] w_index    ,
    input  [              18:0] w_vpn2     ,
    input  [               7:0] w_asid     ,
    input                       w_g        ,
    input  [              19:0] w_pfn0     ,
    input  [               2:0] w_c0       ,
    input                       w_d0       ,
    input                       w_v0       ,
    input  [              19:0] w_pfn1     ,
    input  [               2:0] w_c1       ,
    input                       w_d1       ,
    input                       w_v1       ,
    // read port
    input  [$clog2(TLBNUM)-1:0] r_index    ,
    output [              18:0] r_vpn2     ,
    output [               7:0] r_asid     ,
    output                      r_g        ,
    output [              19:0] r_pfn0     ,
    output [               2:0] r_c0       ,
    output                      r_d0       ,
    output                      r_v0       ,
    output [              19:0] r_pfn1     ,
    output [               2:0] r_c1       ,
    output                      r_d1       ,
    output                      r_v1      );

/* DECLARATION */

// TLB REGs
reg [               18:0] tlb_vpn2 [TLBNUM-1:0];
reg [                7:0] tlb_asid [TLBNUM-1:0];
reg                       tlb_g    [TLBNUM-1:0];
reg [               19:0] tlb_pfn0 [TLBNUM-1:0]; // even entry
reg [                2:0] tlb_c0   [TLBNUM-1:0];
reg                       tlb_d0   [TLBNUM-1:0];
reg                       tlb_v0   [TLBNUM-1:0];
reg [               19:0] tlb_pfn1 [TLBNUM-1:0]; // odd entry
reg [                2:0] tlb_c1   [TLBNUM-1:0];
reg                       tlb_d1   [TLBNUM-1:0];
reg                       tlb_v1   [TLBNUM-1:0];
// sp0
wire [        TLBNUM-1:0] s_match0;
wire [$clog2(TLBNUM)-1:0] s_index0;
// sp1
wire [        TLBNUM-1:0] s_match1;
wire [$clog2(TLBNUM)-1:0] s_index1;

/* LOGIC */

// sp0
assign s0_found =|s_match0;
assign s0_index = s_index0;
assign {s0_pfn, s0_c, s0_d, s0_v}
                = s0_odd_page ? {tlb_pfn1[s_index0],
                                 tlb_c1  [s_index0],
                                 tlb_d1  [s_index0],
                                 tlb_v1  [s_index0]}
                              : {tlb_pfn0[s_index0],
                                 tlb_c0  [s_index0],
                                 tlb_d0  [s_index0],
                                 tlb_v0  [s_index0]};

// sp1
assign s1_found =|s_match1;
assign s1_index = s_index1;
assign {s1_pfn, s1_c, s1_d, s1_v}
                = s1_odd_page ? {tlb_pfn1[s_index1],
                                 tlb_c1  [s_index1],
                                 tlb_d1  [s_index1],
                                 tlb_v1  [s_index1]}
                              : {tlb_pfn0[s_index1],
                                 tlb_c0  [s_index1],
                                 tlb_d0  [s_index1],
                                 tlb_v0  [s_index1]};

// wp
always @(posedge clk) begin
    if (we) begin
        tlb_vpn2[w_index] <= w_vpn2;
        tlb_asid[w_index] <= w_asid;
        tlb_g   [w_index] <= w_g   ;
        tlb_pfn0[w_index] <= w_pfn0; // even
        tlb_c0  [w_index] <= w_c0  ;
        tlb_d0  [w_index] <= w_d0  ;
        tlb_v0  [w_index] <= w_v0  ;
        tlb_pfn1[w_index] <= w_pfn1; // odd
        tlb_c1  [w_index] <= w_c1  ;
        tlb_d1  [w_index] <= w_d1  ;
        tlb_v1  [w_index] <= w_v1  ;
    end
end

// rp
assign {r_vpn2, r_asid, r_g} = {
        tlb_vpn2[r_index],
        tlb_asid[r_index],
        tlb_g   [r_index]
};
assign {r_pfn0, r_c0, r_d0, r_v0,
        r_pfn1, r_c1, r_d1, r_v1} = {
        tlb_pfn0[r_index], // even
        tlb_c0  [r_index],
        tlb_d0  [r_index],
        tlb_v0  [r_index],
        tlb_pfn1[r_index], // odd
        tlb_c1  [r_index],
        tlb_d1  [r_index],
        tlb_v1  [r_index]
};

/* Enc & Dec */
// sp0
assign s_match0 = {
    (s0_vpn2==tlb_vpn2[15]) && ((s0_asid==tlb_asid[15]) || tlb_g[15]),
    (s0_vpn2==tlb_vpn2[14]) && ((s0_asid==tlb_asid[14]) || tlb_g[14]),
    (s0_vpn2==tlb_vpn2[13]) && ((s0_asid==tlb_asid[13]) || tlb_g[13]),
    (s0_vpn2==tlb_vpn2[12]) && ((s0_asid==tlb_asid[12]) || tlb_g[12]),
    (s0_vpn2==tlb_vpn2[11]) && ((s0_asid==tlb_asid[11]) || tlb_g[11]),
    (s0_vpn2==tlb_vpn2[10]) && ((s0_asid==tlb_asid[10]) || tlb_g[10]),
    (s0_vpn2==tlb_vpn2[ 9]) && ((s0_asid==tlb_asid[ 9]) || tlb_g[ 9]),
    (s0_vpn2==tlb_vpn2[ 8]) && ((s0_asid==tlb_asid[ 8]) || tlb_g[ 8]),
    (s0_vpn2==tlb_vpn2[ 7]) && ((s0_asid==tlb_asid[ 7]) || tlb_g[ 7]),
    (s0_vpn2==tlb_vpn2[ 6]) && ((s0_asid==tlb_asid[ 6]) || tlb_g[ 6]),
    (s0_vpn2==tlb_vpn2[ 5]) && ((s0_asid==tlb_asid[ 5]) || tlb_g[ 5]),
    (s0_vpn2==tlb_vpn2[ 4]) && ((s0_asid==tlb_asid[ 4]) || tlb_g[ 4]),
    (s0_vpn2==tlb_vpn2[ 3]) && ((s0_asid==tlb_asid[ 3]) || tlb_g[ 3]),
    (s0_vpn2==tlb_vpn2[ 2]) && ((s0_asid==tlb_asid[ 2]) || tlb_g[ 2]),
    (s0_vpn2==tlb_vpn2[ 1]) && ((s0_asid==tlb_asid[ 1]) || tlb_g[ 1]),
    (s0_vpn2==tlb_vpn2[ 0]) && ((s0_asid==tlb_asid[ 0]) || tlb_g[ 0])
};
encoder_16_4 u_enc0(.in(s_match0), .out(s_index0));
// sp1
assign s_match1 = {
    (s1_vpn2==tlb_vpn2[15]) && ((s1_asid==tlb_asid[15]) || tlb_g[15]),
    (s1_vpn2==tlb_vpn2[14]) && ((s1_asid==tlb_asid[14]) || tlb_g[14]),
    (s1_vpn2==tlb_vpn2[13]) && ((s1_asid==tlb_asid[13]) || tlb_g[13]),
    (s1_vpn2==tlb_vpn2[12]) && ((s1_asid==tlb_asid[12]) || tlb_g[12]),
    (s1_vpn2==tlb_vpn2[11]) && ((s1_asid==tlb_asid[11]) || tlb_g[11]),
    (s1_vpn2==tlb_vpn2[10]) && ((s1_asid==tlb_asid[10]) || tlb_g[10]),
    (s1_vpn2==tlb_vpn2[ 9]) && ((s1_asid==tlb_asid[ 9]) || tlb_g[ 9]),
    (s1_vpn2==tlb_vpn2[ 8]) && ((s1_asid==tlb_asid[ 8]) || tlb_g[ 8]),
    (s1_vpn2==tlb_vpn2[ 7]) && ((s1_asid==tlb_asid[ 7]) || tlb_g[ 7]),
    (s1_vpn2==tlb_vpn2[ 6]) && ((s1_asid==tlb_asid[ 6]) || tlb_g[ 6]),
    (s1_vpn2==tlb_vpn2[ 5]) && ((s1_asid==tlb_asid[ 5]) || tlb_g[ 5]),
    (s1_vpn2==tlb_vpn2[ 4]) && ((s1_asid==tlb_asid[ 4]) || tlb_g[ 4]),
    (s1_vpn2==tlb_vpn2[ 3]) && ((s1_asid==tlb_asid[ 3]) || tlb_g[ 3]),
    (s1_vpn2==tlb_vpn2[ 2]) && ((s1_asid==tlb_asid[ 2]) || tlb_g[ 2]),
    (s1_vpn2==tlb_vpn2[ 1]) && ((s1_asid==tlb_asid[ 1]) || tlb_g[ 1]),
    (s1_vpn2==tlb_vpn2[ 0]) && ((s1_asid==tlb_asid[ 0]) || tlb_g[ 0])
};
encoder_16_4 u_enc1(.in(s_match1), .out(s_index1));

endmodule
