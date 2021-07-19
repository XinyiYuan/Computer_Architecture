`include "mycpu.h"

module wb_stage(
    input                           clk             ,
    input                           reset           ,
    //allowin
    output                          ws_allowin      ,
    //from ms
    input                           ms_to_ws_valid  ,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus    ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus    ,
    // flush
    output                          exc_flush       ,
    output [31:0]                   ws_pc_gen_exc   ,
    //trace debug interface
    output [31:0]                   debug_wb_pc     ,
    output [ 3:0]                   debug_wb_rf_wen ,
    output [ 4:0]                   debug_wb_rf_wnum,
    output [31:0]                   debug_wb_rf_wdata
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

reg  ws_has_int;
wire ws_c0_has_int;

wire [ 2:0] ws_sel;
wire [ 4:0] ws_rd;
wire [31:0] ws_c0_wdata;
wire [31:0] ws_c0_rdata;
wire [ 5:0] ws_ext_int_in;
wire [ 4:0] ws_excode;
wire [31:0] ws_badvaddr;

/*  LOGIC  */

assign {ws_exc_of      , //120
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
              | ws_exc_of)
              & ws_valid; // flushed => DO NOT CHANGE CPRs
assign ws_c0_wdata = {32{ws_inst_mtc0}} & ws_final_result;
assign ws_ext_int_in = 6'b0; // exterior INTR
assign ws_excode = ws_exc_intr      ? `EX_INTR :
                   ws_exc_adel_if   ? `EX_ADEL :
                   ws_exc_ri        ? `EX_RI   :
                   ws_exc_of        ? `EX_OV   :
                   ws_exc_bp        ? `EX_BP   :
                   ws_exc_sysc      ? `EX_SYS  :
               ({5{ws_exc_adel_ld}} & `EX_ADEL
               |{5{ws_exc_ades}}    & `EX_ADES);
assign ws_pc_gen_exc = {32{ws_inst_eret}} & ws_c0_rdata
                     | {32{ws_ex}}        & 32'hbfc00380;

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
    .c0_rdata   (ws_c0_rdata  )
);

assign exc_flush = ( ws_ex
                   | ws_inst_eret)
                   & ws_valid ;

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = rf_wdata;// ws_final_result;

endmodule
