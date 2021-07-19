`include "mycpu.h"

module mem_stage(
    input                          clk              ,
    input                          reset            ,
    //allowin
    input                          ws_allowin       ,
    output                         ms_allowin       ,
    //from es
    input                          es_to_ms_valid   ,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus     ,
    //to ws
    output                         ms_to_ws_valid   ,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus     ,
    // to ds
    output [`MS_TO_DS_BUS_WD -1:0] ms_to_ds_bus     ,
    // flush
    input                          exc_flush        ,
    output                         ms_ex            ,
    //from data-sram
    input                          data_sram_data_ok,
    input  [31:0]                  data_sram_rdata
);

/*  DECLARATION  */

reg         ms_valid;
wire        ms_ready_go;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;

wire [31:0] ms_rt_value;
wire [ 1:0] ms_lad;
wire [ 5:0] ms_ls_type;
wire        ms_mem_re;
wire        ms_mem_we;
wire        ms_gpr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;

wire [31:0] mem_result;
wire [31:0] ms_final_result;

wire [31:0] ms_badvaddr;

wire ms_mems_fi;

wire ms_bd;
wire ms_res_valid;

wire [ 2:0] ms_sel;
wire [ 4:0] ms_rd;
wire [ 3:0] ms_lad_d;

wire mem_res_s_07; // prepare hight bit in byte
wire mem_res_s_15;
wire mem_res_s_23;
wire mem_res_s_31;
wire [31:0] mem_res_lwr; // prepare mem_res selection
wire [31:0] mem_res_lwl;
wire [31:0] mem_res_lhg;
wire [31:0] mem_res_lbg;

wire ms_type_lwr;
wire ms_type_lwl;
wire ms_type_lhu;
wire ms_type_lh;
wire ms_type_lbu;
wire ms_type_lb;
wire ms_type_lw;

wire ms_inst_mtc0;
wire ms_inst_mfc0;
wire ms_inst_eret;
wire ms_exc_sysc;
wire ms_exc_ri;
wire ms_exc_bp;
wire ms_exc_adel_if;
wire ms_exc_adel_ld;
wire ms_exc_ades;
wire ms_exc_of;

reg         mdata_buf_valid;

wire [31:0] mdata_now;
reg  [31:0] mdata_buf;


/*  LOGIC  */

assign {ms_exc_of      , //161
        ms_exc_ades    , //160
        ms_exc_adel_ld , //159
        ms_exc_adel_if , //158
        ms_exc_ri      , //157
        ms_exc_bp      , //156
        ms_inst_eret   , //155
        ms_exc_sysc    , //154
        ms_inst_mfc0   , //153
        ms_inst_mtc0   , //152
        ms_bd          , //151
        ms_sel         , //150:148
        ms_rd          , //147:143
        ms_rt_value    , //142:111
        ms_lad         , //110:109
        ms_ls_type     , //108:103
        ms_mem_re      , //102
        ms_gpr_we      , //101
        ms_dest        , //100:96
        ms_alu_result  , //95:64
        ms_badvaddr    , //63:32
        ms_pc            //31:0
       } = es_to_ms_bus_r;

assign ms_mem_we = (|ms_ls_type) & ~ms_mem_re; //store

assign ms_res_valid =~ms_inst_mfc0
                    & ms_to_ws_valid;

assign ms_to_ws_bus = {ms_exc_of      , //120
                       ms_exc_ades    , //119
                       ms_exc_adel_if , //118
                       ms_exc_adel_ld , //117
                       ms_exc_ri      , //116
                       ms_exc_bp      , //115
                       ms_inst_eret   , //114
                       ms_exc_sysc    , //113
                       ms_inst_mfc0   , //112
                       ms_inst_mtc0   , //111
                       ms_bd          , //110
                       ms_sel         , //109:107
                       ms_rd          , //106:102
                       ms_gpr_we      , //101
                       ms_dest        , //100:96
                       ms_final_result, //95:64
                       ms_badvaddr    , //63:32
                       ms_pc            //31: 0
                      };

assign ms_ex =(ms_exc_of
             | ms_exc_sysc
             | ms_exc_ri
             | ms_exc_bp
             | ms_exc_adel_if
             | ms_exc_adel_ld
             | ms_exc_ades
             | ms_inst_eret) & ms_valid;

assign ms_to_ds_bus = {`MS_TO_DS_BUS_WD{ ms_valid & ms_gpr_we}}
                    & {ms_res_valid,    // 37
                       ms_dest,         // 36:32
                       ms_final_result  // 31: 0
                      };

assign ms_mems_fi = data_sram_data_ok && ws_allowin
                  ||mdata_buf_valid
                  ||ms_exc_ades
                  ||ms_exc_adel_ld;

assign ms_ready_go    =!(ms_mem_re||ms_mem_we)
                      || ms_mems_fi;
assign ms_allowin     = !ms_valid
                      || ms_ready_go && ws_allowin
                      ;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset || exc_flush) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r <= es_to_ms_bus;
    end
end

/* data_sram */

assign mdata_now = data_sram_data_ok ? data_sram_rdata
                                     : mdata_buf     ;
always @(posedge clk) begin
    if (reset) begin
        mdata_buf <= 32'b0;
    end
    else if (data_sram_data_ok) begin
        mdata_buf <= data_sram_rdata;
    end

    if (reset) begin
        mdata_buf_valid <= 1'b0;
    end
    else if (ms_to_ws_valid && ws_allowin) begin
        mdata_buf_valid <= 1'b0;
    end
    else if (data_sram_data_ok) begin
        mdata_buf_valid <= 1'b1;
    end
end

assign mem_result = {32{ms_type_lwr}} & mem_res_lwr // LWR
                  | {32{ms_type_lwl}} & mem_res_lwl // LWL
                  | {32{ms_type_lhg}} & mem_res_lhg // LH/LHU
                  | {32{ms_type_lbg}} & mem_res_lbg // LB/LBU
                  | {32{ms_type_lw }} & mdata_now; // LW

assign ms_final_result = ms_inst_mtc0 ? ms_rt_value
                       : ms_mem_re    ? mem_result
                       : ms_alu_result;

/* Generate mem_res */
// lad decoded one-hot
assign ms_lad_d[3] = (ms_lad==2'b11);
assign ms_lad_d[2] = (ms_lad==2'b10);
assign ms_lad_d[1] = (ms_lad==2'b01);
assign ms_lad_d[0] = (ms_lad==2'b00);
// prepare load type
assign ms_type_lwr =  ms_ls_type[4];
assign ms_type_lwl =  ms_ls_type[3];
assign ms_type_lhg =  ms_ls_type[2]; // lh/lhu
assign ms_type_lbg =  ms_ls_type[1]; // lb/lbu
assign ms_type_lw  =  ms_ls_type[0];
// prepare hight bit in byte
assign mem_res_s_07 = ~ms_ls_type[5] & mdata_now[ 7];
assign mem_res_s_15 = ~ms_ls_type[5] & mdata_now[15];
assign mem_res_s_23 = ~ms_ls_type[5] & mdata_now[23];
assign mem_res_s_31 = ~ms_ls_type[5] & mdata_now[31];
// prepare mem_res selection
assign mem_res_lwr = {32{ms_lad_d[0]}} &  mdata_now[31:0]                       // LWR
                   | {32{ms_lad_d[1]}} & {ms_rt_value[31:24], mdata_now[31: 8]}
                   | {32{ms_lad_d[2]}} & {ms_rt_value[31:16], mdata_now[31:16]}
                   | {32{ms_lad_d[3]}} & {ms_rt_value[31: 8], mdata_now[31:24]};
assign mem_res_lwl = {32{ms_lad_d[0]}} & {mdata_now[ 7:0], ms_rt_value[23:0]}   // LWL
                   | {32{ms_lad_d[1]}} & {mdata_now[15:0], ms_rt_value[15:0]}
                   | {32{ms_lad_d[2]}} & {mdata_now[23:0], ms_rt_value[ 7:0]}
                   | {32{ms_lad_d[3]}} &  mdata_now;
assign mem_res_lhg = {32{~ms_lad[1] }} & {{16{mem_res_s_15}}, mdata_now[15: 0]} // LH/LHU
                   | {32{ ms_lad[1] }} & {{16{mem_res_s_31}}, mdata_now[31:16]};
assign mem_res_lbg = {32{ms_lad_d[0]}} & {{24{mem_res_s_07}}, mdata_now[ 7: 0]} // LB/LBU
                   | {32{ms_lad_d[1]}} & {{24{mem_res_s_15}}, mdata_now[15: 8]}
                   | {32{ms_lad_d[2]}} & {{24{mem_res_s_23}}, mdata_now[23:16]}
                   | {32{ms_lad_d[3]}} & {{24{mem_res_s_31}}, mdata_now[31:24]};

endmodule
