`include "mycpu.h"

module wb_stage(
    input                           clk           ,
    input                           reset         ,
    //allowin
    output                          ws_allowin    ,
    //from ms
    input                           ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    // lab8: flush
    output                          exc_flush     ,
    output [31:0]                   ws_pc_gen_exc ,
    //trace debug interface
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_wen ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

/* ------------------------------ DECLARATION ------------------------------ */

reg         ws_valid;
wire        ws_ready_go;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
wire        ws_gr_we;
wire        ws_gr_we_r;
wire [ 4:0] ws_dest;
wire [31:0] ws_final_result;
wire [31:0] ws_pc;

wire ws_flush;
wire ms_flush;
wire ws_cp0_valid;

wire        rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;

// lab8
wire ws_inst_mtc0;
wire ws_inst_mfc0;
wire ws_inst_sysc;
wire ws_inst_eret;

wire [2:0] ws_sel;
wire [4:0] ws_rd;

wire [31:0] ws_c0_wdata;
wire [31:0] ws_c0_rdata;

wire ws_if_privil;
wire [31:0] ws_privil_res;

wire ws_ex; // report exception

wire ws_bd; // if inst is in branch-delay-slot

wire [ 5:0] ws_ext_int_in;
wire [ 4:0] ws_excode;
wire [31:0] ws_badvaddr;

/* ------------------------------ LOGIC ------------------------------ */

assign {ms_flush       ,  //83
        ws_bd          ,  //82
        ws_inst_eret   ,  //81
        ws_inst_sysc   ,  //80
        ws_inst_mfc0   ,  //79
        ws_inst_mtc0   ,  //78
        ws_sel         ,  //77:75
        ws_rd          ,  //74:70
        ws_gr_we       ,  //69:69
        ws_dest        ,  //68:64
        ws_final_result,  //63:32
        ws_pc             //31:0
       } = ms_to_ws_bus_r;
assign ws_gr_we_r = ws_gr_we & ~ws_flush;

assign ws_flush = exc_flush | ms_flush;

assign ws_to_rf_bus = {rf_we   ,  //37:37
                       rf_waddr,  //36:32 dest
                       rf_wdata   //31:0  wdata
                      };

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid
                   || ws_ready_go
                   || ws_flush;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid; //lab8
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

// lab8
assign ws_if_privil  = ws_inst_mfc0;
assign ws_privil_res = ws_c0_rdata;

assign rf_we    = ws_gr_we_r && ws_valid;
assign rf_waddr = {5{ws_valid}} & ws_dest;
assign rf_wdata = {32{~ws_if_privil}} & ws_final_result
                | {32{ ws_if_privil}} & ws_privil_res;

// lab8
assign ws_cp0_valid = ws_valid & ~ws_flush;
assign ws_ex = ws_inst_sysc; //!
assign ws_c0_wdata = {32{ws_inst_mtc0}} & ws_final_result;
assign ws_ext_int_in = 6'b0; // INTR outside is not required
assign ws_excode = {5{ws_inst_sysc}} & `EX_SYS;
assign ws_badvaddr = ws_pc; //! maybe not correct

assign ws_pc_gen_exc = {32{ws_inst_eret}} & ws_c0_rdata
                     | {32{ws_inst_sysc}} & 32'hbfc00380;

// lab8
regs_c0 u_reg_c0(
    .clk(clk),
    .rst(reset),
    .wb_valid(ws_cp0_valid),
    .op_mtc0(ws_inst_mtc0),
    .op_mfc0(ws_inst_mfc0),
    .op_eret(ws_inst_eret),
    .op_sysc(ws_inst_sysc),
    .wb_ex(ws_ex), // if ex
    .wb_rd(ws_rd),
    .wb_sel(ws_sel),
    .c0_wdata(ws_c0_wdata),
    .c0_rdata(ws_c0_rdata),
    .wb_bd(ws_bd),//if br delay slot
    .ext_int_in(ws_ext_int_in),
     .wb_excode(ws_excode),
    .wb_pc(ws_pc),
    .wb_badvaddr(ws_badvaddr)
);

assign exc_flush = (ws_inst_eret | ws_inst_sysc) & ws_valid;

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = rf_wdata;// ws_final_result;

endmodule
