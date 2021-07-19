`include "mycpu.h"

module regs_c0(
    input         clk        ,
    input         rst        ,
    input         op_mtc0    ,
    input         op_mfc0    ,
    input         op_eret    ,
    input         op_sysc    ,
    input         wb_valid   ,
    input         wb_ex      ,
    input         wb_bd      ,
    input  [ 5:0] ext_int_in ,
    input  [ 4:0] wb_excode  ,
    input  [31:0] wb_pc      ,
    input  [31:0] wb_badvaddr,
    input  [ 4:0] wb_rd      ,
    input  [ 2:0] wb_sel     ,
    input  [31:0] c0_wdata   ,
    output        has_int    ,
    output [31:0] c0_rdata   ,
    //lab14 added
    output [31:0] c0_entryhi,
    output [31:0] c0_entrylo0,
    output [31:0] c0_entrylo1,
    output [31:0] c0_index,
    input         tlbp,
    input         tlbp_found,
    input  [3:0]  index,
    input         tlbr,
    input  [18:0] r_vpn2,
    input  [ 7:0] r_asid,
    input         r_g,
    input  [19:0] r_pfn0,
    input  [ 2:0] r_c0,
    input         r_d0,
    input         r_v0,
    input  [19:0] r_pfn1,
    input  [ 2:0] r_c1,
    input         r_d1,
    input         r_v1);

/* declarations */
wire [7:0] c0_addr;
wire       mtc0_we;
wire       eret_flush;
wire       cnt_eq_cmp;
reg        tick;

wire [31:0] c0_status      ; // c0_status
wire        c0_status_bev  ;
reg  [ 7:0] c0_status_im   ;
reg         c0_status_exl  ;
reg         c0_status_ie   ;
wire [31:0] c0_cause       ; // c0_cause
reg         c0_cause_bd    ;
reg         c0_cause_ti    ;
reg  [ 7:0] c0_cause_ip    ;
reg  [ 4:0] c0_cause_excode;
reg  [31:0] c0_epc         ; // c0_epc
reg  [31:0] c0_badvaddr    ; // c0_badvaddr
reg  [31:0] c0_compare     ; // c0_compare
reg  [31:0] c0_count       ; // c0_count

wire addr_eq_status;
wire addr_eq_cause;
wire addr_eq_epc;
wire addr_eq_count;
wire addr_eq_compare;
wire addr_eq_badvaddr;

/* pre assignments */
assign c0_addr = {wb_sel, wb_rd};

assign mtc0_we    = wb_valid && op_mtc0 && !wb_ex;
assign eret_flush = op_eret;
assign cnt_eq_cmp = (c0_count == c0_compare);

always @(posedge clk) begin
    if (rst) begin
        tick <= 1'b0;
    end
    else begin
        tick <= ~tick;
    end
end

assign addr_eq_status   = (c0_addr == `CR_STATUS   );
assign addr_eq_cause    = (c0_addr == `CR_CAUSE    );
assign addr_eq_epc      = (c0_addr == `CR_EPC      );
assign addr_eq_count    = (c0_addr == `CR_COUNT    );
assign addr_eq_compare  = (c0_addr == `CR_COMPARE  );
assign addr_eq_badvaddr = (c0_addr == `CR_BADVADDR );
assign addr_eq_entryhi  = (c0_addr == `CR_ENTRYHi  );
assign addr_eq_entrylo0 = (c0_addr == `CR_ENTRYLo0 );
assign addr_eq_entrylo1 = (c0_addr == `CR_ENTRYLo1 );
assign addr_eq_index    = (c0_addr == `CR_INDEX    );

/* outputs */
assign c0_rdata = {32{addr_eq_status}}         & c0_status
                | {32{addr_eq_cause}}          & c0_cause
                | {32{addr_eq_epc|eret_flush}} & c0_epc
                | {32{addr_eq_count}}          & c0_count
                | {32{addr_eq_compare}}        & c0_compare
                | {32{addr_eq_badvaddr}}       & c0_badvaddr
                | {32{addr_eq_entryhi}}        & c0_entryhi
                | {32{addr_eq_entrylo0}}       & c0_entrylo0
                | {32{addr_eq_entrylo1}}       & c0_entrylo1
                | {32{addr_eq_index}}       & c0_index;

assign has_int = (| (c0_cause_ip & c0_status_im))
                  &  c0_status_ie
                  & ~c0_status_exl;

/* Status */
assign c0_status = {9'b0         , //31:23
                    c0_status_bev, //22
                    6'b0         , //21:16
                    c0_status_im , //15:8
                    6'b0         , //7:2
                    c0_status_exl, //1
                    c0_status_ie}; //0
assign c0_status_bev = 1'b1; // BEV: R, always 1
always @(posedge clk) begin // IM(7~0): R&W
    if (rst) begin
        c0_status_im <= 8'b0;
    end
    else if(mtc0_we && c0_addr == `CR_STATUS) begin
        c0_status_im <= c0_wdata[15:8];
    end
end
always @(posedge clk) begin // EXL: R&W
    if (rst) begin
        c0_status_exl <= 1'b0;
    end
    else if (wb_ex) begin
        c0_status_exl <= 1'b1;
    end
    else if (eret_flush) begin
        c0_status_exl <= 1'b0;
    end
    else if (mtc0_we && c0_addr == `CR_STATUS) begin
        c0_status_exl <= c0_wdata[1];
    end
end
always@(posedge clk) begin // IE
    if (rst) begin
        c0_status_ie <= 1'b0;
    end
    else if (mtc0_we && c0_addr == `CR_STATUS) begin
        c0_status_ie <= c0_wdata[0];
    end
end

/* Cause */
assign c0_cause = {c0_cause_bd    , //31
                   c0_cause_ti    , //30
                   14'b0          , //29:16
                   c0_cause_ip    , //15:8
                   1'b0           , //7
                   c0_cause_excode, //6:2
                   2'b0          }; //1:0
always@(posedge clk) begin // BD
    if (rst) begin
        c0_cause_bd <= 1'b0;
    end
    else if (wb_ex && !c0_status_exl) begin
        c0_cause_bd <= wb_bd;
    end
end
always@(posedge clk) begin // TI
    if (rst) begin
        c0_cause_ti <= 1'b0;
    end
    else if (mtc0_we && c0_addr == `CR_COMPARE) begin
        c0_cause_ti <= 1'b0;
    end
    else if (cnt_eq_cmp) begin
        c0_cause_ti <= 1'b1;
    end
end
always @(posedge clk) begin // IP7~2
    if (rst) begin
        c0_cause_ip[ 7:2] <= 6'b0;
    end
    else begin
        c0_cause_ip[7]   <= ext_int_in[5] | c0_cause_ti;
        c0_cause_ip[6:2] <= ext_int_in[4:0];
    end
end
always @(posedge clk) begin // IP1~0
    if (rst) begin
        c0_cause_ip[1:0] <= 2'b0;
    end
    else if (mtc0_we && c0_addr==`CR_CAUSE) begin
        c0_cause_ip[1:0] <= c0_wdata[9:8];
    end
end
always @(posedge clk) begin // Excode
    if (rst) begin
        c0_cause_excode <= 5'b0;
    end
    else if (wb_ex) begin
        c0_cause_excode <= wb_excode;
    end
end

/* EPC */
always @(posedge clk) begin // c0_epc
    if (rst) begin
        c0_epc <= 32'b0;
    end
    else if (wb_ex && !c0_status_exl) begin
        c0_epc <= wb_bd ? wb_pc - 3'h4 : wb_pc;
    end
    else if (mtc0_we && c0_addr == `CR_EPC) begin
        c0_epc <= c0_wdata;
    end
end

/* BadVAddr */
always @(posedge clk) begin // c0_badvaddr
    if (rst) begin
        c0_badvaddr <= 32'b0;
    end
    else if (wb_ex && (wb_excode == `EX_ADEL || wb_excode == `EX_ADES)) begin
        c0_badvaddr <= wb_badvaddr;
    end
end

/* Count */
always @(posedge clk) begin // c0_count
    if (rst) begin
        c0_count <= 32'b0;
    end
    else if (mtc0_we && c0_addr == `CR_COUNT) begin
        c0_count <= c0_wdata;
    end
    else if (tick) begin
        c0_count <= c0_count + 1'b1;
    end
end

/* Compare */
always @(posedge clk) begin
    if (rst) begin
        c0_compare <= 32'b0;
    end
    else if (mtc0_we && c0_addr == `CR_COMPARE) begin
        c0_compare <= c0_wdata;
    end
end

//lab14 added

//entryhi
reg  [18:0]c0_entryhi_vpn2;
wire [4:0] c0_entryhi_12_8;
reg  [7:0] c0_entryhi_asid;

assign c0_entryhi = {
            c0_entryhi_vpn2,
            c0_entryhi_12_8,
            c0_entryhi_asid
            };
assign c0_entryhi_12_8 = 0;
always @(posedge clk) begin
    if(rst) begin
        c0_entryhi_vpn2 <= 19'h0;
        c0_entryhi_asid <= 8'h0;
    end
    if(mtc0_we && c0_addr == `CR_ENTRYHi) begin
        c0_entryhi_vpn2 <= c0_wdata[31:13];
        c0_entryhi_asid <= c0_wdata[7:0];
    end
    if(tlbr) begin
        c0_entryhi_vpn2 <= r_vpn2;
        c0_entryhi_asid <= r_asid;
    end
    if((wb_excode==5'h01||wb_excode==5'h02||wb_excode==5'h03)&&wb_ex)
        //c0_entryhi_vpn2<= wb_badvaddr[31:12];
        c0_entryhi_vpn2<= wb_badvaddr[31:13];
end

//entrylo 0
wire [5:0] c0_entrylo0_31_26;
reg  [19:0]c0_entrylo0_pfn2;
reg  [5:0] c0_entrylo0_C_D_V_G;

assign c0_entrylo0 = {
            c0_entrylo0_31_26,
            c0_entrylo0_pfn2,
            c0_entrylo0_C_D_V_G
            };
assign c0_entrylo0_31_26 = 0;
always @(posedge clk) begin
    if(rst) begin
        c0_entrylo0_pfn2 <= 20'h0;
        c0_entrylo0_C_D_V_G <= 6'h0;
    end
    if(mtc0_we && c0_addr == `CR_ENTRYLo0) begin
        c0_entrylo0_pfn2 <= c0_wdata[25:6];
        c0_entrylo0_C_D_V_G <= c0_wdata[5:0];
    end
    if(tlbr) begin
        c0_entrylo0_pfn2 <= r_pfn0;
        c0_entrylo0_C_D_V_G <= {r_c0,r_d0,r_v0,r_g};
    end
end

//entrylo 1
wire [5:0] c0_entrylo1_31_26;
reg  [19:0]c0_entrylo1_pfn2;
reg  [5:0] c0_entrylo1_C_D_V_G;

assign c0_entrylo1 = {
            c0_entrylo1_31_26,
            c0_entrylo1_pfn2,
            c0_entrylo1_C_D_V_G
            };
assign c0_entrylo1_31_26 = 0;
always @(posedge clk) begin
    if(rst) begin
        c0_entrylo1_pfn2 <= 20'h0;
        c0_entrylo1_C_D_V_G <= 6'h0;
    end
    if(mtc0_we && c0_addr == `CR_ENTRYLo1) begin
        c0_entrylo1_pfn2 <= c0_wdata[25:6];
        c0_entrylo1_C_D_V_G <= c0_wdata[5:0];
    end
    if(tlbr) begin
        c0_entrylo1_pfn2 <= r_pfn1;
        c0_entrylo1_C_D_V_G <= {r_c1,r_d1,r_v1,r_g};
    end
end

//index
reg        c0_index_p;
wire [26:0]c0_index_30_4;
reg  [3:0] c0_index_index;

assign c0_index_30_4 = 0;
assign c0_index = {
            c0_index_p,
            c0_index_30_4,
            c0_index_index
            };
always@(posedge clk) begin
    if(rst) begin
        c0_index_p <= 1'b0;
        c0_index_index <= 4'h0;
    end
    if(mtc0_we && c0_addr == `CR_INDEX  )
        c0_index_index <= c0_wdata[3:0];
    if(tlbp & ~tlbp_found)
        c0_index_p <= 1;
    if(tlbp & tlbp_found) begin
        c0_index_p <= 0;
        c0_index_index <= index;
    end
end
endmodule
