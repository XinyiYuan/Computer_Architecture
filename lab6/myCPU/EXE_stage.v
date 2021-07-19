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
    // data sram interface
    output                         data_sram_en   ,
    output [ 3:0]                  data_sram_wen  ,
    output [31:0]                  data_sram_addr ,
    output [31:0]                  data_sram_wdata
);

reg         es_valid      ;
wire        es_ready_go   ;

// register: HI, LO
reg [31:0] hi;
reg [31:0] lo;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;

/* mult/div/MTMF ops begin */
wire        es_inst_mtlo  ;
wire        es_inst_mthi  ;
wire        es_inst_mflo  ;
wire        es_inst_mfhi  ;
wire        es_op_divu    ;
wire        es_op_div     ;
wire        es_op_multu   ;
wire        es_op_mult    ;
/* mult/div/MTMF ops end */
wire [11:0] es_alu_op     ;
wire        es_load_op    ;
wire        es_src1_is_sa ;
wire        es_src1_is_pc ;
wire        es_src2_is_imm;
wire        es_src2_is_8  ;
wire        es_gr_we      ;
wire        es_mem_we     ;
wire [ 4:0] es_dest       ;
wire [15:0] es_imm        ;
wire [31:0] es_rs_value   ;
wire [31:0] es_rt_value   ;
wire [31:0] es_pc         ;
assign {es_inst_mtlo   ,  //143
        es_inst_mthi   ,  //142
        es_inst_mflo   ,  //141
        es_inst_mfhi   ,  //140
        es_op_divu     ,  //139
        es_op_div      ,  //138
        es_op_multu    ,  //137
        es_op_mult     ,  //136
        es_alu_op      ,  //135:124
        es_load_op     ,  //123:123
        es_src1_is_sa  ,  //122:122
        es_src1_is_pc  ,  //121:121
        es_src2_is_imm ,  //120:120
        es_src2_is_8   ,  //119:119
        es_gr_we       ,  //118:118
        es_mem_we      ,  //117:117
        es_dest        ,  //116:112
        es_imm         ,  //111:96
        es_rs_value    ,  //95 :64
        es_rt_value    ,  //63 :32
        es_pc             //31 :0
       } = ds_to_es_bus_r;

wire [31:0] es_alu_src1  ;
wire [31:0] es_alu_src2  ;
wire [31:0] es_alu_result;
wire [31:0] es_res_r     ;
wire [31:0] es_hi_res    ;
wire [31:0] es_lo_res    ;

wire es_hilo_we;
wire es_res_from_mem;

assign es_res_from_mem = es_load_op;
assign es_to_ms_bus = {es_res_from_mem,  //70:70
                       es_gr_we       ,  //69:69
                       es_dest        ,  //68:64
                       es_res_r       ,  //63:32 originally es_alu_result
                       es_pc             //31:0
                      };
assign es_to_ds_bus = {`ES_TO_DS_BUS_WD{ es_valid
                                       & es_gr_we}} & {~es_res_from_mem, //37    es_res_valid
                                                        es_dest,         //36:32 es_dest
                                                        es_res_r         //31: 0 es_res_r
                                                        };
// es_ready_go change from 1'b1
assign es_ready_go    = es_hilo_we | (~|{es_op_div,  // wait div to end
                                         es_op_divu
                                         });
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;
always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

// es_alu_src2: imm
wire es_src2_is_uimm;
wire [31:0] es_alu_src2_imm;
assign es_src2_is_uimm = es_src2_is_imm & (es_alu_op[4] // andi
                                          |es_alu_op[6] // ori
                                          |es_alu_op[7] // xori
                                          );
assign es_alu_src2_imm[15: 0] = es_imm[15:0];
assign es_alu_src2_imm[31:16] = {16{~es_src2_is_uimm // not uimm: imm[15]
                                   & es_imm[15]}};   //     uimm: 0

assign es_alu_src1 = es_src1_is_sa  ? {27'b0, es_imm[10:6]} :
                     es_src1_is_pc  ? es_pc[31:0]           :
                                      es_rs_value           ;
assign es_alu_src2 = es_src2_is_imm ? es_alu_src2_imm       :
                     es_src2_is_8   ? 32'd8                 :
                                      es_rt_value           ;


/* 33-bit multiplier: begin */
wire [32:0] es_mult_a;
wire [32:0] es_mult_b;
wire [65:0] es_mult_result;

assign es_mult_a    = {es_op_mult & es_alu_src1[31], es_alu_src1};
assign es_mult_b    = {es_op_mult & es_alu_src2[31], es_alu_src2};
assign es_mult_result = $signed(es_mult_a) * $signed(es_mult_b);
/* 33-bit multiplier: end */


/* 32-bit dividers (my_div, my_divu): begin */
// Gerneral input
wire [31:0] es_dividend;
wire [31:0] es_divisor;
assign es_dividend = {32{es_op_div|es_op_divu}} & es_alu_src1;
assign es_divisor  = {32{es_op_div|es_op_divu}} & es_alu_src2;

/* div begin */
wire [63:0] es_div_dout;
reg es_div_end_valid; // valid & ready
wire es_div_end_ready;
reg es_div_sor_valid;
wire es_div_sor_ready;
wire es_div_out_valid;
reg es_div_in_shkhd; // shakehand
// div input sending valid
wire es_div_in_ready;
assign es_div_in_ready = es_div_end_ready & es_div_sor_ready;

always @(posedge clk ) begin
    if (reset) begin                                   // reset
        es_div_end_valid <= 1'b0;
        es_div_sor_valid <= 1'b0;
        es_div_in_shkhd  <= 1'b0;
    end
    else if (~es_div_in_shkhd & es_op_div) begin       // valid: require ready
        es_div_end_valid <= 1'b1;
        es_div_sor_valid <= 1'b1;
        es_div_in_shkhd  <= 1'b1;
    end
    else if (es_div_in_shkhd & es_div_in_ready) begin  // ready & shkhd
        es_div_end_valid <= 1'b0;
        es_div_sor_valid <= 1'b0;
    end
    else if (es_div_in_shkhd & es_div_out_valid) begin // shkhd set to 1'b0
        es_div_in_shkhd <= 1'b0;
    end
end
/* div end */

/* divu begin */
wire [63:0] es_divu_dout;
reg es_divu_end_valid; // valid & ready
wire es_divu_end_ready;
reg es_divu_sor_valid;
wire es_divu_sor_ready;
wire es_divu_out_valid;
reg es_divu_in_shkhd; // shakehand
// divu input sending valid
wire es_divu_in_ready;
assign es_divu_in_ready = es_divu_end_ready & es_divu_sor_ready;

always @(posedge clk ) begin
    if (reset) begin                                     // reset
        es_divu_end_valid <= 1'b0;
        es_divu_sor_valid <= 1'b0;
        es_divu_in_shkhd  <= 1'b0;
    end
    else if (~es_divu_in_shkhd & es_op_divu) begin       // valid: require ready
        es_divu_end_valid <= 1'b1;
        es_divu_sor_valid <= 1'b1;
        es_divu_in_shkhd  <= 1'b1;
    end
    else if (es_divu_in_shkhd & es_divu_in_ready) begin  // ready & shkhd
        es_divu_end_valid <= 1'b0;
        es_divu_sor_valid <= 1'b0;
    end
    else if (es_divu_in_shkhd & es_divu_out_valid) begin // shkhd set to 1'b0
        es_divu_in_shkhd <= 1'b0;
    end
end
/* divu end */

/* 32-bit dividers (my_div, my_divu): end */


/* HI, LO R&W: begin */
assign es_hilo_we = es_op_mult
                  | es_op_multu
                  | es_op_div  & es_div_out_valid
                  | es_op_divu & es_divu_out_valid;
assign es_hi_res = {32{es_op_mult|es_op_multu}} & es_mult_result[63:32]
                 | {32{es_op_div             }} & es_div_dout[31:0]
                 | {32{es_op_divu            }} & es_divu_dout[31:0];
assign es_lo_res = {32{es_op_mult|es_op_multu}} & es_mult_result[31:0]
                 | {32{es_op_div             }} & es_div_dout[63:32]
                 | {32{es_op_divu            }} & es_divu_dout[63:32];

always @(posedge clk) begin
    if (reset) begin
        hi <= 32'b0;
        lo <= 32'b0;
    end
    else if (es_hilo_we) begin // mult/div
        hi <= es_hi_res;
        lo <= es_lo_res;
    end
    else if (es_inst_mthi) begin // mthi
        hi <= es_rs_value;
    end
    else if (es_inst_mtlo) begin // mtlo
        lo <= es_rs_value;
    end
end

/* HI, LO R&W: end */


/* instantiated: begin */
my_div inst_my_div(
    // clk
    .aclk                   (clk),             //in
    // dividend
    .s_axis_dividend_tdata (es_dividend),      //in
    .s_axis_dividend_tvalid(es_div_end_valid), //in
    .s_axis_dividend_tready(es_div_end_ready), //out
    // divisor
    .s_axis_divisor_tdata  (es_divisor),       //in
    .s_axis_divisor_tvalid (es_div_sor_valid), //in
    .s_axis_divisor_tready (es_div_sor_ready), //out
    // res
    .m_axis_dout_tdata     (es_div_dout),      //out
    .m_axis_dout_tvalid    (es_div_out_valid)  //out
);
my_divu inst_my_divu(
    // clk
    .aclk                   (clk),             //in
    // dividend
    .s_axis_dividend_tdata (es_dividend),      //in
    .s_axis_dividend_tvalid(es_divu_end_valid), //in
    .s_axis_dividend_tready(es_divu_end_ready), //out
    // divisor
    .s_axis_divisor_tdata  (es_divisor),       //in
    .s_axis_divisor_tvalid (es_divu_sor_valid), //in
    .s_axis_divisor_tready (es_divu_sor_ready), //out
    // res
    .m_axis_dout_tdata     (es_divu_dout),      //out
    .m_axis_dout_tvalid    (es_divu_out_valid)  //out
);
/* instantiated: end */


alu u_alu(
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ),
    .alu_src2   (es_alu_src2  ),
    .alu_result (es_alu_result)
    );

assign es_res_r = {32{  es_inst_mfhi}}  & hi
                | {32{  es_inst_mflo}}  & lo
                | {32{~(es_inst_mfhi
                       |es_inst_mflo)}} & es_alu_result ;

assign data_sram_en    = 1'b1;
assign data_sram_wen   = es_mem_we && es_valid ? 4'hf : 4'h0;
assign data_sram_addr  = es_alu_result; // note: do not change because addr can only be an alu_result
assign data_sram_wdata = es_rt_value;

endmodule
