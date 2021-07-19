`include "mycpu.h"

module exe_stage(
    input                          clk            ,
    input                          reset          ,
    //allowin
    input                          ms_allowin     ,
    output                         es_allowin     ,
    //from ds
    input                          ds_to_es_valid ,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus   ,
    //to ms
    output                         es_to_ms_valid ,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus   ,
    // to ds
    output [`ES_TO_DS_BUS_WD -1:0] es_to_ds_bus   ,
    // flush
    input                          exc_flush      ,
    input                          ms_ex          ,
    // data sram interface
    output  reg                    data_sram_req  ,
    output                         data_sram_wr   ,
    output [ 1:0]                  data_sram_size ,
    output [31:0]                  data_sram_addr ,
    output [ 3:0]                  data_sram_wstrb,
    output [31:0]                  data_sram_wdata,
    input                          data_sram_addr_ok, //in
    // tlb
    output  [18:0]                 s1_vpn2        ,
    output                         s1_odd_page    ,
    input                          s1_found       ,
    input   [ 3:0]                 s1_index       ,
    input   [19:0]                 s1_pfn         ,
    input                          s1_d           ,
    input                          s1_v           ,
    input   [31:0]                 c0_entryhi
);

/*  DECLARATION  */

reg  es_valid;
wire es_ready_go;

wire es_hilo_we;

reg [31:0] hi;
reg [31:0] lo;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;

wire        es_of_valid;
wire [31:0] es_badvaddr;

wire es_inst_mtc0;
wire es_inst_mfc0;
wire inst_store  ;

wire es_inst_eret  ;
wire es_exc_sysc   ;
wire es_exc_bp     ;
wire es_exc_ri     ;
wire es_exc_of     ;
wire es_exc_adel_if;
wire es_exc_adel_ld;
wire es_exc_ades   ;

wire [11:0] es_alu_op     ;
wire        es_mem_re     ;
wire        es_src1_is_sa ;
wire        es_src1_is_pc ;
wire        es_src2_is_imm;
wire        es_src2_is_8  ;
wire        es_gpr_we     ;
wire        es_mem_we     ;
wire [ 4:0] es_dest       ;
wire [15:0] es_imm        ;
wire [31:0] es_rs_value   ;
wire [31:0] es_rt_value   ;
wire [31:0] es_pc         ;

wire es_divs_fi;
wire es_mems_fi;

wire es_ignore;
wire es_ex;
wire es_bd;
wire es_res_valid;

wire es_inst_mtlo;
wire es_inst_mthi;
wire es_inst_mflo;
wire es_inst_mfhi;
wire es_op_divu  ;
wire es_op_div   ;
wire es_op_multu ;
wire es_op_mult  ;

wire [31:0] es_alu_src1  ;
wire [31:0] es_alu_src2  ;
wire [31:0] es_alu_result;
wire [31:0] es_res_r     ;
wire [31:0] es_hi_res    ;
wire [31:0] es_lo_res    ;
wire        es_alu_of    ;

wire        es_src2_is_uimm;
wire [31:0] es_alu_src2_imm;

wire [32:0] es_mult_a;
wire [32:0] es_mult_b;
wire [65:0] es_mult_result;
wire [31:0] es_dividend;
wire [31:0] es_divisor;

wire [63:0] es_div_dout;
wire        es_div_end_ready;
wire        es_div_sor_ready;
wire        es_div_out_valid;
wire        es_div_in_ready;
reg         es_div_end_valid;
reg         es_div_sor_valid;
reg         es_div_in_flag;

wire [63:0] es_divu_dout;
wire        es_divu_end_ready;
wire        es_divu_sor_ready;
wire        es_divu_out_valid;
wire        es_divu_in_ready;
reg         es_divu_end_valid;
reg         es_divu_sor_valid;
reg         es_divu_in_flag;

wire [3:0] write_strb_swr;
wire [3:0] write_strb_swl;
wire [3:0] write_strb_sh;
wire [3:0] write_strb_sb;

wire [31:0] write_data_swr;
wire [31:0] write_data_swl;
wire [31:0] write_data_sh;
wire [31:0] write_data_sb;

wire [ 3:0] wstrb_bits;
wire [ 3:0] write_strb;
wire [31:0] write_data;

wire [2:0] es_sel;
wire [4:0] es_rd;

wire [5:0] es_ls_type;
wire [1:0] es_lad  ;
wire [3:0] es_lad_d;

reg dr_shkhd;

wire [31:0] fs_badvaddr;
wire es_exc_tlbl_if_i;
wire es_exc_tlbl_if_r;

wire es_exc_tlb_invalid;
wire es_exc_tlb_refill;
wire es_exc_tlbl_ld_i;
wire es_exc_tlbl_ld_r;
wire es_exc_tlbs_i;
wire es_exc_tlbs_r;
wire tlb_modify_es;

wire es_refetch;
wire tlbp_found;
wire mapped;

/*  LOGIC  */

assign {es_exc_tlbl_if_i ,  //205
        es_exc_tlbl_if_r ,  //204
        es_refetch        ,  //203
        inst_tlbp      ,  //202
        inst_tlbr      ,  //201
        inst_tlbwi     ,  //200
        es_of_valid    ,  //199
        es_exc_adel_if ,  //198
        es_exc_ri      ,  //197
        es_exc_bp      ,  //196
        es_inst_eret   ,  //195
        es_exc_sysc    ,  //194
        es_inst_mfc0   ,  //193
        es_inst_mtc0   ,  //192
        es_bd          ,  //191
        es_sel         ,  //190:188
        es_rd          ,  //187:183
        es_ls_type     ,  //182:177
        es_inst_mtlo   ,  //176
        es_inst_mthi   ,  //175
        es_inst_mflo   ,  //174
        es_inst_mfhi   ,  //173
        es_op_divu     ,  //172
        es_op_div      ,  //171
        es_op_multu    ,  //170
        es_op_mult     ,  //169
        inst_store     ,  //168
        es_alu_op      ,  //167:156
        es_mem_re      ,  //155
        es_src1_is_sa  ,  //154
        es_src1_is_pc  ,  //153
        es_src2_is_imm ,  //152
        es_src2_is_8   ,  //151
        es_gpr_we      ,  //150
        es_mem_we      ,  //149
        es_dest        ,  //148:144
        es_imm         ,  //143:128
        es_rs_value    ,  //127:96
        es_rt_value    ,  //95:64
        fs_badvaddr    ,  //63:32
        es_pc             //31:0
       } = ds_to_es_bus_r;

//lab14 added
assign s1_vpn2     = inst_tlbp ? c0_entryhi[31:13]
                   : es_alu_result[31:13];
assign s1_odd_page = inst_tlbp ? 0
                   : es_alu_result[12];
assign mapped      = ~(es_alu_result[31] & ~es_alu_result[30]);
assign tlbp_found  = inst_tlbp & s1_found;

assign es_exc_tlb_invalid =  s1_found & !s1_v & mapped & (|es_ls_type);
assign es_exc_tlb_refill = !s1_found & mapped & (|es_ls_type);

assign es_exc_tlbl_ld_i = es_exc_tlb_invalid & es_gpr_we;
assign es_exc_tlbl_ld_r = es_exc_tlb_refill  & es_gpr_we;
assign es_exc_tlbs_i = es_exc_tlb_invalid & es_mem_we;
assign es_exc_tlbs_r = es_exc_tlb_refill  & es_mem_we;

assign tlb_modify_es  =  s1_found &  s1_v & !s1_d & mapped & inst_store;

assign es_exc_adel_ld = es_ls_type[2] & es_gpr_we &  data_sram_addr[0]   // l hw
                      | es_ls_type[0] & es_gpr_we & |data_sram_addr[1:0];// l w
assign es_exc_ades    = es_ls_type[2] & es_mem_we &  data_sram_addr[0]   // s hw
                      | es_ls_type[0] & es_mem_we & |data_sram_addr[1:0];// s w
/* note for ades:
 * ades use 'mem_we' instead of 'mem_we_r'
 * because ades is meaningless for to-be-flushed inst
 */

// lad decoded one-hot
assign es_lad      =  es_alu_result[1:0];
assign es_lad_d[3] = (es_lad==2'b11);
assign es_lad_d[2] = (es_lad==2'b10);
assign es_lad_d[1] = (es_lad==2'b01);
assign es_lad_d[0] = (es_lad==2'b00);

assign es_ex    = es_inst_eret
                | es_exc_adel_if
                | es_exc_ri
                | es_exc_of
                | es_exc_bp
                | es_exc_sysc
                | es_exc_adel_ld
                | es_exc_ades
                | es_exc_tlbl_if_r
                | es_exc_tlbl_if_i
                | es_exc_tlbl_ld_r
                | es_exc_tlbl_ld_i
                | es_exc_tlbs_r
                | es_exc_tlbs_i
                | tlb_modify_es;

assign es_res_valid = ~es_mem_re
                    & ~es_inst_mfc0;

assign es_to_ms_bus = {es_exc_tlbl_ld_r, //177
                       es_exc_tlbl_ld_i,
                       es_exc_tlbs_r   ,
                       es_exc_tlbs_i   ,
                       es_exc_tlbl_if_r, //173
                       es_exc_tlbl_if_i, //172
                       tlb_modify_es , //171
                       es_refetch & ~exc_flush, //170
                       s1_index      , //169:166
                       tlbp_found    , //165
                       inst_tlbp     , //164
                       inst_tlbr     , //163
                       inst_tlbwi    , //162
                       es_exc_of     , //161
                       es_exc_ades   , //160
                       es_exc_adel_ld, //159
                       es_exc_adel_if, //158
                       es_exc_ri     , //157
                       es_exc_bp     , //156
                       es_inst_eret  , //155
                       es_exc_sysc   , //154
                       es_inst_mfc0  , //153
                       es_inst_mtc0  , //152
                       es_bd         , //151
                       es_sel        , //150:148
                       es_rd         , //147:143
                       es_rt_value   , //142:111
                       es_lad        , //110:109
                       es_ls_type    , //108:103
                       es_mem_re     , //102
                       es_gpr_we     , //101
                       es_dest       , //100:96
                       es_res_r      , //95:64
                       es_badvaddr   , //63:32
                       es_pc           //31:0
                      };

assign es_to_ds_bus = {`ES_TO_DS_BUS_WD{ es_valid & es_gpr_we}}
                    & {es_res_valid, //37    es_res_valid
                       es_dest,      //36:32 es_dest
                       es_res_r      //31: 0 es_res_r
                       };

always @(posedge clk) begin
    if (reset) begin
        dr_shkhd <= 1'b0;
    end
    else if (dr_shkhd
          && es_to_ms_valid && ms_allowin) begin
        dr_shkhd <= 1'b0;
    end
    else if (data_sram_req && data_sram_addr_ok) begin
        dr_shkhd <= 1'b1;
    end
end

assign es_divs_fi =!(es_op_div||es_op_divu)
                  || es_hilo_we;
assign es_mems_fi =!(es_mem_re||es_mem_we)
                  || dr_shkhd
                  || es_exc_adel_ld
                  || es_exc_ades
                  || es_exc_tlb_refill
                  || es_exc_tlb_invalid;

assign es_ready_go    = es_divs_fi && es_mems_fi;
assign es_allowin     =!es_valid
                      ||es_ready_go && ms_allowin;
assign es_to_ms_valid = es_valid && es_ready_go;
always @(posedge clk) begin
    if (reset || exc_flush) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

// results
assign es_res_r  = {32{  es_inst_mfhi}}  & hi
                 | {32{  es_inst_mflo}}  & lo
                 | {32{~(es_inst_mfhi
                        |es_inst_mflo)}} & es_alu_result ;
assign es_exc_of = es_of_valid & es_alu_of;

/* data_sram */

assign wstrb_bits = write_strb[3]
                  + write_strb[2]
                  + write_strb[1]
                  + write_strb[0];

assign data_sram_wr = es_mem_we
                    &~es_ignore;
assign data_sram_size = wstrb_bits == 3'h1 ? 2'h0
                      : wstrb_bits == 3'h2 ? 2'h1
                      : 2'h2;
assign data_sram_wstrb = {4{data_sram_wr}} & write_strb;
assign data_sram_wdata = write_data;

// req
always @(posedge clk) begin
    if (reset) begin
        data_sram_req <= 1'b0;
    end
    else if (es_ignore) begin
        data_sram_req <= 1'b0;
    end
    else if (data_sram_req && data_sram_addr_ok) begin
        data_sram_req <= 1'b0;
    end else if (!data_sram_req
               &&!dr_shkhd) begin // ~es_ignored
        data_sram_req <= (es_mem_re|es_mem_we) & es_valid;
    end
end

assign data_sram_addr  = mapped ? {s1_pfn,{es_alu_result[11:0]}}
                       : es_alu_result; //lab14 edited

assign es_badvaddr = (es_exc_adel_if|es_exc_tlbl_if_r|es_exc_tlbl_if_i) ? fs_badvaddr
                   : data_sram_addr;

assign write_strb = {4{ es_ls_type[4]}} & write_strb_swr // SWR
                  | {4{ es_ls_type[3]}} & write_strb_swl // SWL
                  | {4{ es_ls_type[2]}} & write_strb_sh  // SH
                  | {4{ es_ls_type[1]}} & write_strb_sb  // SB
                  | {4{ es_ls_type[0]}} & 4'b1111;       // SW
assign write_data = {32{es_ls_type[4]}} & write_data_swr // SWR
                  | {32{es_ls_type[3]}} & write_data_swl // SWL
                  | {32{es_ls_type[2]}} & write_data_sh  // SH
                  | {32{es_ls_type[1]}} & write_data_sb  // SB
                  | {32{es_ls_type[0]}} & es_rt_value;   // SW

/*** calculators ***/

/* alu */
assign es_src2_is_uimm = es_src2_is_imm & (es_alu_op[4]
                                          |es_alu_op[6]
                                          |es_alu_op[7]
                                          ); // alu_src2=imm (andi, ori, xori)
assign es_alu_src2_imm = {{16{~es_src2_is_uimm & es_imm[15]}},
                          es_imm[15:0]};

assign es_alu_src1 = es_src1_is_sa  ? {27'b0, es_imm[10:6]} :
                     es_src1_is_pc  ? es_pc[31:0]           :
                                      es_rs_value           ;
assign es_alu_src2 = es_src2_is_imm ? es_alu_src2_imm       :
                     es_src2_is_8   ? 32'd8                 :
                                      es_rt_value           ;

/* 33-bit multiplier */
assign es_mult_a      = {es_op_mult & es_alu_src1[31], es_alu_src1};
assign es_mult_b      = {es_op_mult & es_alu_src2[31], es_alu_src2};
assign es_mult_result = $signed(es_mult_a) * $signed(es_mult_b)    ;

/* 32-bit dividers (my_div, my_divu) */
// Gerneral input
assign es_dividend = {32{es_op_div|es_op_divu}} & es_alu_src1;
assign es_divisor  = {32{es_op_div|es_op_divu}} & es_alu_src2;
// div input sending valid
assign es_div_in_ready = es_div_end_ready & es_div_sor_ready;
always @(posedge clk ) begin
    if (reset) begin                                   // reset
        es_div_end_valid <= 1'b0;
        es_div_sor_valid <= 1'b0;
        es_div_in_flag   <= 1'b0;
    end
    else if (~es_div_in_flag & es_op_div) begin       // valid: require ready
        es_div_end_valid <= 1'b1;
        es_div_sor_valid <= 1'b1;
        es_div_in_flag   <= 1'b1;
    end
    else if (es_div_in_flag & es_div_in_ready) begin  // ready & flag
        es_div_end_valid <= 1'b0;
        es_div_sor_valid <= 1'b0;
    end
    else if (es_div_in_flag & es_div_out_valid) begin // flag set to 1'b0
        es_div_in_flag   <= 1'b0;
    end
end
// divu input sending valid
assign es_divu_in_ready = es_divu_end_ready & es_divu_sor_ready;
always @(posedge clk ) begin
    if (reset) begin                                     // reset
        es_divu_end_valid <= 1'b0;
        es_divu_sor_valid <= 1'b0;
        es_divu_in_flag   <= 1'b0;
    end
    else if (~es_divu_in_flag & es_op_divu) begin       // valid: require ready
        es_divu_end_valid <= 1'b1;
        es_divu_sor_valid <= 1'b1;
        es_divu_in_flag   <= 1'b1;
    end
    else if (es_divu_in_flag & es_divu_in_ready) begin  // ready & flag
        es_divu_end_valid <= 1'b0;
        es_divu_sor_valid <= 1'b0;
    end
    else if (es_divu_in_flag & es_divu_out_valid) begin // flag set to 1'b0
        es_divu_in_flag  <= 1'b0;
    end
end

/* HI, LO R&W */
assign es_hilo_we   = es_op_mult
                    | es_op_multu
                    | es_op_div  &  es_div_out_valid
                    | es_op_divu &  es_divu_out_valid;
assign es_ignore = exc_flush | ms_ex | es_ex;

assign es_hi_res    = {32{es_op_mult|es_op_multu}} & es_mult_result[63:32]
                    | {32{es_op_div             }} & es_div_dout[31:0]
                    | {32{es_op_divu            }} & es_divu_dout[31:0];
assign es_lo_res    = {32{es_op_mult|es_op_multu}} & es_mult_result[31:0]
                    | {32{es_op_div             }} & es_div_dout[63:32]
                    | {32{es_op_divu            }} & es_divu_dout[63:32];

always @(posedge clk) begin
    if (reset) begin
        hi <= 32'b0;
        lo <= 32'b0;
    end
    else if (es_hilo_we && !es_ignore && es_valid) begin // mult/div
        hi <= es_hi_res;
        lo <= es_lo_res;
    end
    else if (es_inst_mthi && !es_ignore && es_valid) begin // mthi
        hi <= es_rs_value;
    end
    else if (es_inst_mtlo && !es_ignore && es_valid) begin // mtlo
        lo <= es_rs_value;
    end
end

/* instantiation */
my_div inst_my_div(
    // clk
    .aclk                   (clk            ), //in
    // dividend
    .s_axis_dividend_tdata (es_dividend     ), //in
    .s_axis_dividend_tvalid(es_div_end_valid), //in
    .s_axis_dividend_tready(es_div_end_ready), //out
    // divisor
    .s_axis_divisor_tdata  (es_divisor      ), //in
    .s_axis_divisor_tvalid (es_div_sor_valid), //in
    .s_axis_divisor_tready (es_div_sor_ready), //out
    // res
    .m_axis_dout_tdata     (es_div_dout     ), //out
    .m_axis_dout_tvalid    (es_div_out_valid)  //out
);
my_divu inst_my_divu(
    // clk
    .aclk                   (clk             ), //in
    // dividend
    .s_axis_dividend_tdata (es_dividend      ), //in
    .s_axis_dividend_tvalid(es_divu_end_valid), //in
    .s_axis_dividend_tready(es_divu_end_ready), //out
    // divisor
    .s_axis_divisor_tdata  (es_divisor       ), //in
    .s_axis_divisor_tvalid (es_divu_sor_valid), //in
    .s_axis_divisor_tready (es_divu_sor_ready), //out
    // res
    .m_axis_dout_tdata     (es_divu_dout     ), //out
    .m_axis_dout_tvalid    (es_divu_out_valid)  //out
);

alu u_alu(
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ),
    .alu_src2   (es_alu_src2  ),
    .alu_result (es_alu_result),
    .alu_of     (es_alu_of    )
    );

/*  Generate write_strb & write data  */
// prepare write_strb selection
assign write_strb_swr = {4{ es_lad_d[0]}} & 4'b1111 // SWR
                      | {4{ es_lad_d[1]}} & 4'b1110
                      | {4{ es_lad_d[2]}} & 4'b1100
                      | {4{ es_lad_d[3]}} & 4'b1000;
assign write_strb_swl = {4{ es_lad_d[0]}} & 4'b0001 // SWL
                      | {4{ es_lad_d[1]}} & 4'b0011
                      | {4{ es_lad_d[2]}} & 4'b0111
                      | {4{ es_lad_d[3]}} & 4'b1111;
assign write_strb_sh  = {4{~es_lad[1]  }} & 4'b0011 // SH
                      | {4{ es_lad[1]  }} & 4'b1100;
assign write_strb_sb  = {4{ es_lad_d[0]}} & 4'b0001 // SB
                      | {4{ es_lad_d[1]}} & 4'b0010
                      | {4{ es_lad_d[2]}} & 4'b0100
                      | {4{ es_lad_d[3]}} & 4'b1000;
// prepare write_data selection
assign write_data_swr = {32{es_lad_d[0]}} &  es_rt_value                // SWR
                      | {32{es_lad_d[1]}} & {es_rt_value[23:0],  8'b0}
                      | {32{es_lad_d[2]}} & {es_rt_value[15:0], 16'b0}
                      | {32{es_lad_d[3]}} & {es_rt_value[ 7:0], 24'b0};
assign write_data_swl = {32{es_lad_d[0]}} & {24'b0, es_rt_value[31:24]} // SWL
                      | {32{es_lad_d[1]}} & {16'b0, es_rt_value[31:16]}
                      | {32{es_lad_d[2]}} & { 8'b0, es_rt_value[31: 8]}
                      | {32{es_lad_d[3]}} &  es_rt_value;
assign write_data_sh = {2{es_rt_value[15:0]}};                          // SH
assign write_data_sb = {4{es_rt_value[ 7:0]}};                          // SB

endmodule
