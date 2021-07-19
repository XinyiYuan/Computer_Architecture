`include "mycpu.h"
module mycpu_core(
    input         clk,
    input         resetn,
    // inst sram interface
    output        inst_sram_req,
    output        inst_sram_wr,
    output [ 1:0] inst_sram_size,
    output [31:0] inst_sram_addr,
    output [ 3:0] inst_sram_wstrb,
    output [31:0] inst_sram_wdata,
    input         inst_sram_addr_ok,
    input         inst_sram_data_ok,
    input  [31:0] inst_sram_rdata,
    // data sram interface
    output        data_sram_req,
    output        data_sram_wr,
    output [ 1:0] data_sram_size,
    output [31:0] data_sram_addr,
    output [ 3:0] data_sram_wstrb,
    output [31:0] data_sram_wdata,
    input         data_sram_addr_ok,
    input         data_sram_data_ok,
    input  [31:0] data_sram_rdata,
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

reg         reset;
always @(posedge clk) reset <= ~resetn;

wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`BR_BUS_WD       -1:0] br_bus;
wire [`ES_TO_DS_BUS_WD -1:0] es_to_ds_bus;
wire [`MS_TO_DS_BUS_WD -1:0] ms_to_ds_bus;
wire [`WS_TO_FS_BUS_WD -1:0] ws_to_fs_bus;


// exc processing: flush & epc
wire [31:0] ws_pc_gen_exc;
wire        exc_flush;
wire        ms_ex;
//lab14 added
wire  [18:0] s0_vpn2;
wire         s0_odd_page;
wire  [ 7:0] s0_asid;
wire         s0_found;
wire  [ 3:0] s0_index;
wire  [19:0] s0_pfn;
wire  [ 2:0] s0_c;
wire         s0_d;
wire         s0_v;
wire  [18:0] s1_vpn2;
wire         s1_odd_page;
wire  [ 7:0] s1_asid;
wire         s1_found;
wire  [ 3:0] s1_index;
wire  [19:0] s1_pfn;
wire  [ 2:0] s1_c;
wire         s1_d;
wire         s1_v;
wire [31:0]  c0_entryhi;

// IF stage
if_stage if_stage(
    .clk             (clk               ),
    .reset           (reset             ),
    //allowin
    .ds_allowin      (ds_allowin        ),
    //brbus
    .br_bus          (br_bus            ),
    //outputs
    .fs_to_ds_valid  (fs_to_ds_valid    ),
    .fs_to_ds_bus    (fs_to_ds_bus      ),
    .ws_to_fs_bus    (ws_to_fs_bus      ),
    //flush
    .ws_pc_gen_exc   (ws_pc_gen_exc     ),
    .exc_flush       (exc_flush         ),
    // inst sram interface
    .inst_sram_req    (inst_sram_req    ),
    .inst_sram_wr     (inst_sram_wr     ),
    .inst_sram_size   (inst_sram_size   ),
    .inst_sram_addr   (inst_sram_addr   ),
    .inst_sram_wstrb  (inst_sram_wstrb  ),
    .inst_sram_wdata  (inst_sram_wdata  ),
    .inst_sram_addr_ok(inst_sram_addr_ok),
    .inst_sram_data_ok(inst_sram_data_ok),
    .inst_sram_rdata  (inst_sram_rdata  ),
    //lab14 added
    .s0_vpn2        (s0_vpn2),
    .s0_odd_page    (s0_odd_page),
    .s0_found       (s0_found),
    .s0_pfn         (s0_pfn),
    .s0_v           (s0_v)
);
// ID stage
id_stage id_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //from es raw
    .es_to_ds_bus   (es_to_ds_bus   ),
    //from ms raw
    .ms_to_ds_bus   (ms_to_ds_bus   ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to fs
    .br_bus         (br_bus         ),
    //flush
    .exc_flush      (exc_flush      ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   )
);
// EXE stage
exe_stage exe_stage(
    .clk              (clk              ),
    .reset            (reset            ),
    //allowin
    .ms_allowin       (ms_allowin       ),
    .es_allowin       (es_allowin       ),
    //from ds
    .ds_to_es_valid   (ds_to_es_valid   ),
    .ds_to_es_bus     (ds_to_es_bus     ),
    //to ms
    .es_to_ms_valid   (es_to_ms_valid   ),
    .es_to_ms_bus     (es_to_ms_bus     ),
    //to ds raw
    .es_to_ds_bus     (es_to_ds_bus     ),
    //flush
    .exc_flush        (exc_flush        ),
    .ms_ex            (ms_ex            ),
    // data sram interface
    .data_sram_req    (data_sram_req    ),
    .data_sram_wr     (data_sram_wr     ),
    .data_sram_size   (data_sram_size   ),
    .data_sram_addr   (data_sram_addr   ),
    .data_sram_wstrb  (data_sram_wstrb  ),
    .data_sram_wdata  (data_sram_wdata  ),
    .data_sram_addr_ok(data_sram_addr_ok),

    .s1_vpn2        (s1_vpn2),
    .s1_odd_page    (s1_odd_page),
    .s1_found       (s1_found),
    .s1_index       (s1_index),
    .s1_pfn         (s1_pfn),
    .s1_d           (s1_d),
    .s1_v           (s1_v),
    .c0_entryhi     (c0_entryhi)
);
// MEM stage
mem_stage mem_stage(
    .clk              (clk              ),
    .reset            (reset            ),
    //allowin
    .ws_allowin       (ws_allowin       ),
    .ms_allowin       (ms_allowin       ),
    //from es
    .es_to_ms_valid   (es_to_ms_valid   ),
    .es_to_ms_bus     (es_to_ms_bus     ),
    //to ws
    .ms_to_ws_valid   (ms_to_ws_valid   ),
    .ms_to_ws_bus     (ms_to_ws_bus     ),
    //to ds raw
    .ms_to_ds_bus     (ms_to_ds_bus     ),
    //flush
    .exc_flush        (exc_flush        ),
    .ms_ex            (ms_ex            ),
    //from data-sram
    .data_sram_data_ok(data_sram_data_ok),
    .data_sram_rdata  (data_sram_rdata  )
);
// WB stage
wb_stage wb_stage(
    .clk              (clk              ),
    .reset            (reset            ),
    //allowin
    .ws_allowin       (ws_allowin       ),
    //from ms
    .ms_to_ws_valid   (ms_to_ws_valid   ),
    .ms_to_ws_bus     (ms_to_ws_bus     ),
    //to fs
    .ws_to_fs_bus     (ws_to_fs_bus     ),
    //to rf: for write back
    .ws_to_rf_bus     (ws_to_rf_bus     ),
    //flush
    .ws_pc_gen_exc    (ws_pc_gen_exc    ),
    .exc_flush        (exc_flush        ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
    //lab14 added
    .s0_vpn2        (s0_vpn2),
    .s0_odd_page    (s0_odd_page),
    .s0_found       (s0_found),
    .s0_index       (s0_index),
    .s0_pfn         (s0_pfn),
    .s0_c           (s0_c),
    .s0_d           (s0_d),
    .s0_v           (s0_v),
    .s1_vpn2        (s1_vpn2),
    .s1_odd_page    (s1_odd_page),
    .s1_found       (s1_found),
    .s1_index       (s1_index),
    .s1_pfn         (s1_pfn),
    .s1_c           (s1_c),
    .s1_d           (s1_d),
    .s1_v           (s1_v),
    .c0_entryhi     (c0_entryhi)
);

endmodule
