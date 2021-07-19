`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    // lab8: flush
    input  [31:0] ws_pc_gen_exc  ,
    input         exc_flush      ,
    // inst sram interface
    output        inst_sram_en   ,
    output [ 3:0] inst_sram_wen  ,
    output [31:0] inst_sram_addr ,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata
);

/* ------------------------------ DECLARATION ------------------------------ */

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;
wire        to_fs_ready_go;

wire [31:0] seq_pc;
wire [31:0] nextpc;

wire        br_stall;
wire        br_taken;
wire [31:0] br_target;

wire [31:0] fs_inst;
reg  [31:0] fs_pc;

wire        fs_flush;

/* ------------------------------ LOGIC ------------------------------ */

assign {br_stall,
        br_taken,
        br_target
       } = br_bus;

assign fs_to_ds_bus = {fs_flush,  //64
                       fs_inst ,  //63:32
                       fs_pc   }; //31: 0

// lab8
assign fs_flush = exc_flush;

// pre-IF stage
assign to_fs_ready_go = ~br_stall;
assign to_fs_valid    = ~reset & to_fs_ready_go; // edited later in axi
assign seq_pc         = fs_pc + 3'h4;
assign nextpc         = fs_flush  ? ws_pc_gen_exc
                      : br_taken  ? br_target
                                  : seq_pc;

// IF stage
assign fs_ready_go    = 1'b1;
assign fs_allowin     = !fs_valid
                      || fs_ready_go && ds_allowin
                      || fs_flush; //lab8
assign fs_to_ds_valid =  fs_valid && fs_ready_go;
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end

    if (reset) begin
        fs_pc <= 32'hbfbffffc;  //trick: to make nextpc be 0xbfc00000 during reset
    end
    else if (to_fs_valid && fs_allowin) begin
        fs_pc <= nextpc;
    end
end


assign inst_sram_en    = to_fs_valid && fs_allowin;
assign inst_sram_wen   = 4'h0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;

assign fs_inst         = inst_sram_rdata;

endmodule
