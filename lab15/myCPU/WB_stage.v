`include "mycpu.h"

module wb_stage(
    input                           clk             ,
    input                           reset           ,
    //allowin
    output                          ws_allowin      ,
    //from ms
    input                           ms_to_ws_valid  ,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus    ,
    //to fs
    output [`WS_TO_FS_BUS_WD -1:0]  ws_to_fs_bus    ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus    ,
    // flush
    output                          exc_flush       ,
    output [31:0]                   ws_pc_gen_exc   ,
    //trace debug interface
    output [31:0]                   debug_wb_pc     ,
    output [ 3:0]                   debug_wb_rf_wen ,
    output [ 4:0]                   debug_wb_rf_wnum,
    output [31:0]                   debug_wb_rf_wdata,
    //tlb
    input  [18:0]                  s0_vpn2,
    input                          s0_odd_page,
    output                         s0_found,
    output [ 3:0]                  s0_index,
    output [19:0]                  s0_pfn,
    output [ 2:0]                  s0_c,
    output                         s0_d,
    output                         s0_v,
    input  [18:0]                  s1_vpn2,
    input                          s1_odd_page,
    output                         s1_found,
    output [ 3:0]                  s1_index,
    output [19:0]                  s1_pfn,
    output [ 2:0]                  s1_c,
    output                         s1_d,
    output                         s1_v,
    output [31:0]                  c0_entryhi
);

/*  DECLARATION  */

reg         ws_valid;
wire        ws_ready_go;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;

wire        ws_gpr_we;
wire        ws_gpr_we_t;
wire [ 4:0] ws_dest;
wire [31:0] ws_final_result;
wire [31:0] ws_pc;

wire        rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;

wire ws_cp0_valid;

wire ws_inst_mtc0;
wire ws_inst_mfc0;

wire ws_inst_eret;
wire ws_ex;
wire ws_bd;

wire ws_exc_sysc;
wire ws_exc_bp;
wire ws_exc_ri;
wire ws_exc_of;
wire ws_exc_adel_if;
wire ws_exc_adel_ld;
wire ws_exc_ades;
wire ws_exc_intr;

// lab14 added tlb exc
wire ws_exc_tlbl;
wire ws_exc_tlbs;
wire ws_exc_modify;

wire ws_exc_tlbl_ld_r;
wire ws_exc_tlbl_ld_i;
wire ws_exc_tlbs_r;
wire ws_exc_tlbs_i;
wire ws_exc_tlbl_if_r;
wire ws_exc_tlbl_if_i;

wire ws_exc_tlb_refill;

reg  ws_has_int;
wire ws_c0_has_int;

wire [ 2:0] ws_sel;
wire [ 4:0] ws_rd;
wire [31:0] ws_c0_wdata;
wire [31:0] ws_c0_rdata;
wire [ 5:0] ws_ext_int_in;
wire [ 4:0] ws_excode;
wire [31:0] ws_badvaddr;

wire [31:0] c0_rdata_or_refetch_pc;

reg to_refetch;

// lab14 added
wire [ 3:0] c0_index;
wire [31:0] c0_entrylo0;
wire [31:0] c0_entrylo1;
wire [ 3:0] index;

// tlb
    // write port
wire [ 3:0] w_index;
wire        we;     //w(rite) e(nable)
wire [18:0] w_vpn2;
wire [ 7:0] w_asid;
wire        w_g;
wire [19:0] w_pfn0;
wire [ 2:0] w_c0;
wire        w_d0;
wire        w_v0;
wire [19:0] w_pfn1;
wire [ 2:0] w_c1;
wire        w_d1;
wire        w_v1;
   // read port
wire  [3:0] r_index;
wire [18:0] r_vpn2;
wire [ 7:0] r_asid;
wire  r_g;
wire [19:0] r_pfn0;
wire [ 2:0] r_c0;
wire  r_d0;
wire  r_v0;
wire [19:0] r_pfn1;
wire [ 2:0] r_c1;
wire  r_d1;
wire  r_v1;

/*  LOGIC  */

assign {ws_exc_tlbl_ld_r, //136
        ws_exc_tlbl_ld_i,
        ws_exc_tlbs_r   ,
        ws_exc_tlbs_i   ,
        ws_exc_tlbl_if_r,
        ws_exc_tlbl_if_i,
        ws_exc_modify   , //130
        ws_refetch        , //129
        index          , //128:125
        tlbp_found     , //124
        inst_tlbp      , //123
        inst_tlbr      , //122
        inst_tlbwi     , //121
        ws_exc_of      , //120
        ws_exc_ades    , //119
        ws_exc_adel_if , //118
        ws_exc_adel_ld , //117
        ws_exc_ri      , //116
        ws_exc_bp      , //115
        ws_inst_eret   , //114
        ws_exc_sysc    , //113
        ws_inst_mfc0   , //112
        ws_inst_mtc0   , //111
        ws_bd          , //110
        ws_sel         , //109:107
        ws_rd          , //106:102
        ws_gpr_we      , //101
        ws_dest        , //100:96
        ws_final_result, //95:64
        ws_badvaddr    , //63:32
        ws_pc            //31:0
       } = ms_to_ws_bus_r;

//lab14 added
assign c0_rdata_or_refetch_pc = ws_refetch ? ws_pc : ws_c0_rdata;
assign ws_to_fs_bus = {
        ws_refetch & ws_valid, //34
        ws_ex, //33
        ws_inst_eret, //32
        c0_rdata_or_refetch_pc //31:0
};

assign ws_gpr_we_t = ws_gpr_we & ~exc_flush;

assign ws_to_rf_bus = {rf_we   ,  //37:37
                       rf_waddr,  //36:32 dest
                       rf_wdata   //31:0  wdata
                      };

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid
                   || ws_ready_go;
always @(posedge clk) begin
    if (reset || exc_flush) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

assign rf_we    = ws_gpr_we_t && ws_valid;
assign rf_waddr = {5{ws_valid}} & ws_dest;
assign rf_wdata = ws_inst_mfc0 ? ws_c0_rdata
                               : ws_final_result;

assign ws_cp0_valid = ws_valid & ~exc_flush;
assign ws_ex =( ws_exc_intr
              | ws_exc_sysc
              | ws_exc_bp
              | ws_exc_ri
              | ws_exc_adel_if
              | ws_exc_adel_ld
              | ws_exc_ades
              | ws_exc_tlbl
              | ws_exc_tlbs
              | ws_exc_modify
              | ws_exc_of)
              & ws_valid; // flushed => DO NOT CHANGE CPRs
assign ws_c0_wdata = {32{ws_inst_mtc0}} & ws_final_result;
assign ws_ext_int_in = 6'b0; // exterior INTR


assign ws_excode = ws_exc_intr      ? `EX_INTR :
                   ws_exc_adel_if   ? `EX_ADEL :
                  (ws_exc_tlbl_if_r
                  &ws_exc_tlbl_if_i)? `EX_TLBL :
                   ws_exc_ri        ? `EX_RI   :
                   ws_exc_of        ? `EX_OV   :
                   ws_exc_bp        ? `EX_BP   :
                   ws_exc_sysc      ? `EX_SYS  :
                  (ws_exc_adel_ld
                 | ws_exc_ades)    ?
               ({5{ws_exc_adel_ld}} & `EX_ADEL
               |{5{ws_exc_ades}}    & `EX_ADES):
                  (ws_exc_tlbl
                  |ws_exc_tlbs)     ?
               ({5{ws_exc_tlbl}}    & `EX_TLBL
               |{5{ws_exc_tlbs}}    & `EX_TLBS):
                   ws_exc_modify    ? `EX_MOD  :
                                       5'b0;

assign ws_pc_gen_exc = ws_inst_eret ? ws_c0_rdata
                     : (ws_exc_intr | ws_exc_adel_if) ? 32'hbfc00380
                     : ws_exc_tlbl_if_r  ? 32'hbfc00200
                     : (ws_exc_tlbl_if_i | ws_exc_ri | ws_exc_of | ws_exc_bp | ws_exc_sysc | ws_exc_adel_ld | ws_exc_ades) ? 32'hbfc00380
                     : (ws_exc_tlbl_ld_r | ws_exc_tlbs_r) ? 32'hbfc00200
                     : ws_ex        ? 32'hbfc00380
                     : to_refetch      ? ws_pc
                                    : ws_pc;

always @(posedge clk) begin
    if (reset) to_refetch <= 0;
    else if (ws_refetch && ws_valid) begin
        to_refetch <= 1;
    end
    else if (ws_valid) begin
        to_refetch <= 0;
    end
end

always @(posedge clk) begin
    if (reset) begin
        ws_has_int <= 1'b0;
    end
    else if (ws_c0_has_int) begin
        ws_has_int <= 1'b1;
    end
    else if (ws_has_int && ws_valid) begin
        ws_has_int <= 1'b0;
    end
end
assign ws_exc_intr = ws_c0_has_int
                   ||ws_has_int;
assign ws_exc_tlbl = ws_exc_tlbl_if_i | ws_exc_tlbl_if_r | ws_exc_tlbl_ld_i | ws_exc_tlbl_ld_r;
assign ws_exc_tlbs = ws_exc_tlbs_i | ws_exc_tlbs_r;

assign ws_exc_tlb_refill = ws_exc_tlbl_if_r | ws_exc_tlbl_ld_r | ws_exc_tlbs_r;

regs_c0 u_reg_c0(
    .clk        (clk          ),
    .rst        (reset        ),
    .op_mtc0    (ws_inst_mtc0 ),
    .op_mfc0    (ws_inst_mfc0 ),
    .op_eret    (ws_inst_eret ),
    .op_sysc    (ws_exc_sysc  ),
    .wb_valid   (ws_cp0_valid ),
    .wb_ex      (ws_ex        ),
    .wb_bd      (ws_bd        ),
    .ext_int_in (ws_ext_int_in),
    .wb_excode  (ws_excode    ),
    .wb_pc      (ws_pc        ),
    .wb_badvaddr(ws_badvaddr  ),
    .wb_rd      (ws_rd        ),
    .wb_sel     (ws_sel       ),
    .c0_wdata   (ws_c0_wdata  ),
    .has_int    (ws_c0_has_int), //out
    .c0_rdata   (ws_c0_rdata  ),
    .c0_entryhi (c0_entryhi),
    .c0_entrylo0(c0_entrylo0),
    .c0_entrylo1(c0_entrylo1),
    .c0_index   (c0_index),
    .tlbp       (inst_tlbp), //in
    .tlbp_found (tlbp_found),
    .index      (index),
    .tlbr       (inst_tlbr),
    .r_vpn2     (r_vpn2),
    .r_asid     (r_asid),
    .r_g        (r_g),
    .r_pfn0     (r_pfn0),
    .r_c0       (r_c0),
    .r_d0       (r_d0),
    .r_v0       (r_v0),
    .r_pfn1     (r_pfn1),
    .r_c1       (r_c1),
    .r_d1       (r_d1),
    .r_v1       (r_v1)
);

assign exc_flush = ( ws_ex
                   | ws_inst_eret
                   | ws_refetch
                   | to_refetch)
                   & ws_valid ;

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = rf_wdata;// ws_final_result;

assign w_vpn2 = c0_entryhi[31:13];
assign w_asid = c0_entryhi[7:0];
assign w_g    = c0_entrylo0[0] & c0_entrylo1[0];
assign w_pfn0 = c0_entrylo0[25:6];
assign w_c0   = c0_entrylo0[5:3];
assign w_d0   = c0_entrylo0[2];
assign w_v0   = c0_entrylo0[1];
assign w_pfn1 = c0_entrylo1[25:6];
assign w_c1   = c0_entrylo1[5:3];
assign w_d1   = c0_entrylo1[2];
assign w_v1   = c0_entrylo1[1];

tlb
#(.TLBNUM(16))
u_tlb(
     .clk     (clk),
    // search port 0
     .s0_vpn2        (s0_vpn2), //
     .s0_odd_page    (s0_odd_page), //
     .s0_asid        (c0_entryhi[7:0]), //
     .s0_found       (s0_found),
     .s0_index       (s0_index),
     .s0_pfn         (s0_pfn),
     .s0_c           (s0_c),
     .s0_d           (s0_d),
     .s0_v           (s0_v),

    // search port 1
     .s1_vpn2        (s1_vpn2), //
     .s1_odd_page    (s1_odd_page), //
     .s1_asid        (c0_entryhi[7:0]), //
     .s1_found       (s1_found),
     .s1_index       (s1_index),
     .s1_pfn         (s1_pfn),
     .s1_c           (s1_c),
     .s1_d           (s1_d),
     .s1_v           (s1_v),

    // write port
     .we              (inst_tlbwi),
     .w_index         (c0_index[3:0]),
     .w_vpn2          (w_vpn2),
     .w_asid          (w_asid),
     .w_g             (w_g),
     .w_pfn0          (w_pfn0),
     .w_c0            (w_c0),
     .w_d0            (w_d0),
     .w_v0            (w_v0),
     .w_pfn1          (w_pfn1),
     .w_c1            (w_c1),
     .w_d1            (w_d1),
     .w_v1            (w_v1),

     // read port
     .r_index       (c0_index[3:0]), //
     .r_vpn2        (r_vpn2),
     .r_asid        (r_asid),
     .r_g           (r_g),
     .r_pfn0        (r_pfn0),
     .r_c0          (r_c0),
     .r_d0          (r_d0),
     .r_v0          (r_v0),
     .r_pfn1        (r_pfn1),
     .r_c1          (r_c1),
     .r_d1          (r_d1),
     .r_v1          (r_v1)
     );


endmodule
