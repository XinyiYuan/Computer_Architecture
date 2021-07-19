`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //from es raw
    input  [`ES_TO_DS_BUS_WD -1:0] es_to_ds_bus  ,
    //from ms raw
    input  [`MS_TO_DS_BUS_WD -1:0] ms_to_ds_bus  ,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    // flush
    input                          exc_flush     ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus
);

/*  DECLARATION  */

reg  ds_valid   ;
wire ds_ready_go;

reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;

wire [31:0] fs_pc  ;
wire [31:0] ds_inst;
wire [31:0] ds_pc  ;

wire [31:0] ds_badvaddr;

reg  ds_bd;

wire        rf_we   ;
wire        rf_we_t ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;

wire        br_stall;
wire        br_taken;
wire [31:0] br_target;

wire [11:0] alu_op;
wire        src1_is_sa;
wire        src1_is_pc;
wire        src2_is_imm;
wire        src2_is_8;
wire        mem_re;
wire        gpr_we;
wire        mem_we;
wire [ 4:0] dest;
wire [15:0] imm;
wire [31:0] rs_value;
wire [31:0] rt_value;

wire [ 5:0] op;
wire [ 4:0] rs;
wire [ 4:0] rt;
wire [ 4:0] rd;
wire [ 4:0] sa;
wire [ 5:0] func;
wire [25:0] jidx;

wire [63:0] op_d;
wire [31:0] rs_d;
wire [31:0] rt_d;
wire [31:0] rd_d;
wire [31:0] sa_d;
wire [63:0] func_d;

// INST DECODING
wire        inst_addu; // arithmetical
wire        inst_addiu;
wire        inst_add;
wire        inst_addi;
wire        inst_subu;
wire        inst_sub;
wire        inst_sll;
wire        inst_srl;
wire        inst_sra;
wire        inst_sllv;
wire        inst_srav;
wire        inst_srlv;
wire        inst_slt;
wire        inst_sltu;
wire        inst_slti;
wire        inst_sltiu;
wire        inst_lui;
wire        inst_and; // logical
wire        inst_or;
wire        inst_xor;
wire        inst_nor;
wire        inst_andi;
wire        inst_ori;
wire        inst_xori;
wire        inst_mult; // hilo
wire        inst_multu;
wire        inst_div;
wire        inst_divu;
wire        inst_mfhi;
wire        inst_mflo;
wire        inst_mthi;
wire        inst_mtlo;
wire        inst_lw; // load
wire        inst_lb;
wire        inst_lbu;
wire        inst_lh;
wire        inst_lhu;
wire        inst_lwl;
wire        inst_lwr;
wire        inst_sw; // store
wire        inst_sb;
wire        inst_sh;
wire        inst_swl;
wire        inst_swr;
wire        inst_beq; // branch
wire        inst_bne;
wire        inst_bgez;
wire        inst_bgtz;
wire        inst_blez;
wire        inst_bltz;
wire        inst_bltzal;
wire        inst_bgezal;
wire        inst_jal; // jump
wire        inst_jr;
wire        inst_j;
wire        inst_jalr;

wire        inst_mtc0;
wire        inst_mfc0;
wire        inst_eret;
wire        inst_sysc;
wire        inst_bp  ;

wire [ 5:0] ls_type;

wire        dst_is_r31;
wire        dst_is_rt;

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

// set for branch cond
wire        rs_eq_rt;
wire        rs_be_0;
wire        rs_bt_0;
wire        rs_se_0;
wire        rs_st_0;
// dests and reses
wire [ 4:0] es_dest;
wire [ 4:0] ms_dest;
wire [ 4:0] ws_dest;
wire [31:0] es_res;
wire [31:0] ms_res;
// if res is valid
wire es_res_valid;
wire ms_res_valid;
// if reg/dest == 0 ?
wire rs_neq_0;
wire rt_neq_0;
wire es_dest_neq_0;
wire ms_dest_neq_0;
wire ws_dest_neq_0;
// if a_rx == b_dest ?
wire rs_eq_es_dest;
wire rt_eq_es_dest;
wire rs_eq_ms_dest;
wire rt_eq_ms_dest;
wire rs_eq_ws_dest;
wire rt_eq_ws_dest;
wire st_eq_es_dest; //st(@es)
wire st_eq_ms_dest; //st(@ms)
// if current type (i.e. at decode stage) has any src from reg
wire type_st;
wire type_rs;
wire type_rt;
wire type_nr;
// if rx == dests?
wire rs_eq_dests;
wire rt_eq_dests;
wire ds_no_crash_es;
wire ds_no_crash_ms;

wire exc_ri;
wire ds_of_valid;
wire exc_adel_if;

wire [2:0] sel;
wire [7:0] in10_3;

wire inst_arith;
wire inst_logic;
wire inst_hilo;
wire inst_load;
wire inst_store;
wire inst_jump;
wire inst_branch;
wire inst_privi;

wire inst_jxr;
wire inst_jnr;

/*  LOGIC  */

assign fs_pc = fs_to_ds_bus[31:0];

assign {ds_badvaddr , //96:65
        exc_adel_if , //64
        ds_inst     , //63:32
        ds_pc         //31:0
       } = fs_to_ds_bus_r;

assign {rf_we   , //37:37
        rf_waddr, //36:32
        rf_wdata  //31:0
       } = ws_to_rf_bus;
assign rf_we_t = rf_we;
assign ws_dest = rf_waddr & {5{rf_we_t}};

assign {es_res_valid, //37
        es_dest     , //36:32
        es_res        //31:0
        } = es_to_ds_bus;

assign {ms_res_valid, //37
        ms_dest     , //36:32
        ms_res        //31:0
        } = ms_to_ds_bus;

assign br_bus = {ds_to_es_valid, //34
                 br_stall, //33
                 br_taken, //32
                 br_target //31:0
                 };

assign ds_to_es_bus = {ds_of_valid,  //198
                       exc_adel_if,  //197
                       exc_ri     ,  //196
                       inst_bp    ,  //195
                       inst_eret  ,  //194
                       inst_sysc  ,  //193
                       inst_mfc0  ,  //192
                       inst_mtc0  ,  //191
                       ds_bd      ,  //190
                       sel        ,  //189:187
                       rd         ,  //186:182
                       ls_type    ,  //181:176
                       inst_mtlo  ,  //175
                       inst_mthi  ,  //174
                       inst_mflo  ,  //173
                       inst_mfhi  ,  //172
                       inst_divu  ,  //171
                       inst_div   ,  //170
                       inst_multu ,  //169
                       inst_mult  ,  //168
                       alu_op     ,  //167:156
                       mem_re     ,  //155
                       src1_is_sa ,  //154
                       src1_is_pc ,  //153
                       src2_is_imm,  //152
                       src2_is_8  ,  //151
                       gpr_we     ,  //150
                       mem_we     ,  //149
                       dest       ,  //148:144
                       imm        ,  //143:128
                       rs_value   ,  //127:96
                       rt_value   ,  //95:64
                       ds_badvaddr,  //63:32
                       ds_pc         //31:0
                      };

assign ds_allowin     = !ds_valid
                      || ds_ready_go & es_allowin;
assign ds_to_es_valid = ds_valid && ds_ready_go;

always @(posedge clk) begin
    if (reset || exc_flush) begin
        ds_valid <= 1'b0;
    end
    else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end

    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

always @(posedge clk) begin
    if(reset || exc_flush) begin
        ds_bd <= 1'b0;
    end
    else if (ds_valid) begin
        ds_bd <= (inst_branch | inst_jxr | inst_jnr) ;
    end
end


/* DECODING begin */
assign op     = ds_inst[31:26];
assign rs     = ds_inst[25:21];
assign rt     = ds_inst[20:16];
assign rd     = ds_inst[15:11];
assign sa     = ds_inst[10: 6];
assign func   = ds_inst[ 5: 0];
assign imm    = ds_inst[15: 0];
assign jidx   = ds_inst[25: 0];
assign sel    = ds_inst[ 2: 0];
assign in10_3 = ds_inst[10: 3];

decoder_6_64 u_dec0(.in(op  ), .out(op_d  ));
decoder_6_64 u_dec1(.in(func), .out(func_d));
decoder_5_32 u_dec2(.in(rs  ), .out(rs_d  ));
decoder_5_32 u_dec3(.in(rt  ), .out(rt_d  ));
decoder_5_32 u_dec4(.in(rd  ), .out(rd_d  ));
decoder_5_32 u_dec5(.in(sa  ), .out(sa_d  ));

// SINGLE INST DECODE
assign inst_addu   = op_d[6'h00] & func_d[6'h21] & sa_d[5'h00]; // arithmetical
assign inst_addiu  = op_d[6'h09];
assign inst_add    = op_d[6'h00] & func_d[6'h20] & sa_d[5'h00];
assign inst_addi   = op_d[6'h08];
assign inst_sub    = op_d[6'h00] & func_d[6'h22] & sa_d[5'h00];
assign inst_subu   = op_d[6'h00] & func_d[6'h23] & sa_d[5'h00];
assign inst_slt    = op_d[6'h00] & func_d[6'h2a] & sa_d[5'h00];
assign inst_sltu   = op_d[6'h00] & func_d[6'h2b] & sa_d[5'h00];
assign inst_slti   = op_d[6'h0a];
assign inst_sltiu  = op_d[6'h0b];
assign inst_sll    = op_d[6'h00] & func_d[6'h00] & rs_d[5'h00];
assign inst_srl    = op_d[6'h00] & func_d[6'h02] & rs_d[5'h00];
assign inst_sra    = op_d[6'h00] & func_d[6'h03] & rs_d[5'h00];
assign inst_sllv   = op_d[6'h00] & func_d[6'h04] & sa_d[5'h00];
assign inst_srav   = op_d[6'h00] & func_d[6'h07] & sa_d[5'h00];
assign inst_srlv   = op_d[6'h00] & func_d[6'h06] & sa_d[5'h00];
assign inst_lui    = op_d[6'h0f] & rs_d[5'h00];
assign inst_and    = op_d[6'h00] & func_d[6'h24] & sa_d[5'h00]; // logical
assign inst_or     = op_d[6'h00] & func_d[6'h25] & sa_d[5'h00];
assign inst_xor    = op_d[6'h00] & func_d[6'h26] & sa_d[5'h00];
assign inst_nor    = op_d[6'h00] & func_d[6'h27] & sa_d[5'h00];
assign inst_andi   = op_d[6'h0c];
assign inst_ori    = op_d[6'h0d];
assign inst_xori   = op_d[6'h0e];
assign inst_lw     = op_d[6'h23]; // load
assign inst_lb     = op_d[6'h20];
assign inst_lbu    = op_d[6'h24];
assign inst_lh     = op_d[6'h21];
assign inst_lhu    = op_d[6'h25];
assign inst_lwl    = op_d[6'h22];
assign inst_lwr    = op_d[6'h26];
assign inst_sw     = op_d[6'h2b]; // store
assign inst_sb     = op_d[6'h28];
assign inst_sh     = op_d[6'h29];
assign inst_swl    = op_d[6'h2a];
assign inst_swr    = op_d[6'h2e];
assign inst_beq    = op_d[6'h04]; // branch
assign inst_bne    = op_d[6'h05];
assign inst_bgez   = op_d[6'h01] & rt_d[5'h01];
assign inst_bgtz   = op_d[6'h07] & rt_d[5'h00];
assign inst_blez   = op_d[6'h06] & rt_d[5'h00];
assign inst_bltz   = op_d[6'h01] & rt_d[5'h00];
assign inst_bltzal = op_d[6'h01] & rt_d[5'h10];
assign inst_bgezal = op_d[6'h01] & rt_d[5'h11];
assign inst_jal    = op_d[6'h03]; // jump
assign inst_jr     = op_d[6'h00] & func_d[6'h08] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_j      = op_d[6'h02];
assign inst_jalr   = op_d[6'h00] & func_d[6'h09] & rt_d[5'h00] & sa_d[5'h00];
assign inst_mult   = op_d[6'h00] & func_d[6'h18] & sa_d[5'h00]; // mult/div
assign inst_multu  = op_d[6'h00] & func_d[6'h19] & sa_d[5'h00];
assign inst_div    = op_d[6'h00] & func_d[6'h1a] & sa_d[5'h00];
assign inst_divu   = op_d[6'h00] & func_d[6'h1b] & sa_d[5'h00];
assign inst_mfhi   = op_d[6'h00] & func_d[6'h10] & sa_d[5'h00] & rs_d[5'h00] & rt_d[5'h00];
assign inst_mflo   = op_d[6'h00] & func_d[6'h12] & sa_d[5'h00] & rs_d[5'h00] & rt_d[5'h00];
assign inst_mthi   = op_d[6'h00] & func_d[6'h11] & sa_d[5'h00] & rd_d[5'h00] & rt_d[5'h00];
assign inst_mtlo   = op_d[6'h00] & func_d[6'h13] & sa_d[5'h00] & rd_d[5'h00] & rt_d[5'h00];
assign inst_mtc0   = op_d[6'h10] & rs_d[5'h04] & sa_d[5'h00] & ~|func[5:3]; // privil
assign inst_mfc0   = op_d[6'h10] & rs_d[5'h00] & sa_d[5'h00] & ~|func[5:3];
assign inst_eret   = op_d[6'h10] & rs_d[5'h10] & rt_d[5'h00] & rd_d[5'h00]
                   & sa_d[5'h00] & func_d[6'h18];
assign inst_sysc   = op_d[6'h00] & func_d[6'h0c];
assign inst_bp      = op_d[6'h00] & func_d[6'h0d];

// SORT: 61 except: tlbp, tlbr, tlbwi, cache
assign inst_arith  = inst_add  | inst_addu
                   | inst_addi | inst_addiu
                   | inst_sub  | inst_subu
                   | inst_sll  | inst_sllv
                   | inst_srl  | inst_srlv
                   | inst_sra  | inst_srav
                   | inst_slt  | inst_sltu
                   | inst_slti | inst_sltiu
                   | inst_lui  ;//17
assign inst_logic  = inst_and  | inst_andi
                   | inst_or   | inst_ori
                   | inst_xor  | inst_xori
                   | inst_nor  ;//7
assign inst_hilo   = inst_mult | inst_multu
                   | inst_div  | inst_divu
                   | inst_mfhi | inst_mflo
                   | inst_mthi | inst_mtlo;//8
assign inst_load   = inst_lw
                   | inst_lb   | inst_lbu
                   | inst_lh   | inst_lhu
                   | inst_lwl
                   | inst_lwr  ;//7
assign inst_store  = inst_sw
                   | inst_sb
                   | inst_sh
                   | inst_swl
                   | inst_swr  ;//5
assign inst_jump   = inst_jxr
                   | inst_jnr  ;//4
assign inst_branch = inst_beq  | inst_bne
                   | inst_bgez | inst_bgezal
                   | inst_blez
                   | inst_bgtz
                   | inst_bltz | inst_bltzal;//8
assign inst_privi  = inst_mtc0 | inst_mfc0
                   | inst_eret | inst_sysc
                   | inst_bp   ;//5

assign inst_jxr    = inst_jr
                   | inst_jalr ;
assign inst_jnr    = inst_j
                   | inst_jal  ;

assign exc_ri      = ~|{inst_arith ,
                        inst_logic ,
                        inst_hilo  ,
                        inst_load  ,
                        inst_store ,
                        inst_jump  ,
                        inst_branch,
                        inst_privi};

// load/store type
assign ls_type = {inst_lhu | inst_lbu ,          // [5] unsigned extension
                  inst_lwr | inst_swr ,          // [4] l/s word right
                  inst_lwl | inst_swl ,          // [3] l/s word left
                  inst_lh  | inst_lhu | inst_sh, // [2] l/s halfword
                  inst_lb  | inst_lbu | inst_sb, // [1] l/s byte
                  inst_lw  | inst_sw             // [0] l/s word
                  };

//alu_op
assign alu_op[ 0] = |{inst_addu, inst_addiu, inst_add, inst_addi,
                      inst_load, //7*load
                      inst_store, //5*store
                      inst_bgezal, inst_bltzal,
                      inst_jal, inst_jalr
                     };
assign alu_op[ 1] = inst_subu | inst_sub  ;
assign alu_op[ 2] = inst_slt  | inst_slti ;
assign alu_op[ 3] = inst_sltu | inst_sltiu;
assign alu_op[ 4] = inst_and  | inst_andi ;
assign alu_op[ 5] = inst_nor  ;
assign alu_op[ 6] = inst_or   | inst_ori  ;
assign alu_op[ 7] = inst_xor  | inst_xori ;
assign alu_op[ 8] = inst_sll  | inst_sllv ;
assign alu_op[ 9] = inst_srl  | inst_srlv ;
assign alu_op[10] = inst_sra  | inst_srav ;
assign alu_op[11] = inst_lui  ;

assign src1_is_sa  = inst_sll
                   | inst_srl
                   | inst_sra;
assign src1_is_pc  = inst_jal
                   | inst_bltzal
                   | inst_bgezal
                   | inst_jalr;
assign src2_is_imm = |{inst_addiu, inst_lui,
                       inst_addi, inst_slti, inst_sltiu,
                       inst_andi, inst_xori, inst_ori,  // note: uimm as imm
                       inst_load, //7*load
                       inst_store //5*store
                      };
assign src2_is_8   = inst_jal
                   | inst_bltzal
                   | inst_bgezal
                   | inst_jalr;
assign dst_is_r31  = inst_jal
                   | inst_bltzal
                   | inst_bgezal ;
assign dst_is_rt   = |{inst_addiu, inst_addi, inst_slti, inst_sltiu,
                       inst_andi, inst_ori, inst_xori,
                       inst_lui,
                       inst_load, //7*load
                       inst_mfc0
                      };
assign gpr_we      = ~|{inst_store, //5*store
                        inst_beq, inst_bne, inst_bgez, inst_bgtz, inst_blez, inst_bltz,
                        inst_jr, inst_j,
                        inst_mult, inst_multu,
                        inst_div, inst_divu,
                        inst_mthi, inst_mtlo,
                        inst_mtc0
                       };

assign mem_re = inst_load;
assign mem_we = inst_sw
              | inst_sb
              | inst_sh
              | inst_swl
              | inst_swr;
assign dest   = dst_is_r31 ? 5'd31 :
                dst_is_rt  ? rt    :
                             rd    ;

assign ds_of_valid = inst_add | inst_addi | inst_sub;

/* DECODING end */

assign rf_raddr1 = rs;
assign rf_raddr2 = rt;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we_t  ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

// Fowarding(Bypass)
assign rs_value = rs_eq_es_dest ? es_res   :
                  rs_eq_ms_dest ? ms_res   :
                  rs_eq_ws_dest ? rf_wdata :
                                  rf_rdata1;
assign rt_value = rt_eq_es_dest ? es_res   :
                  rt_eq_ms_dest ? ms_res   :
                  rt_eq_ws_dest ? rf_wdata :
                                  rf_rdata2;

assign rs_eq_rt = (rs_value == rt_value);
assign rs_be_0  = ~rs_value[31] ;
assign rs_bt_0  = ~rs_value[31] & ( |rs_value);
assign rs_se_0  =  rs_value[31] | (~|rs_value);
assign rs_st_0  =  rs_value[31] ;

// br info
assign br_stall =~es_res_valid
                &(rt_eq_es_dest & (inst_beq|inst_bne)
                 |rs_eq_es_dest &  inst_branch);
assign br_taken   =(inst_beq    &  rs_eq_rt
                  | inst_bne    & ~rs_eq_rt
                  | inst_bgez   &  rs_be_0
                  | inst_bgtz   &  rs_bt_0
                  | inst_blez   &  rs_se_0
                  | inst_bltz   &  rs_st_0
                  | inst_bltzal &  rs_st_0
                  | inst_bgezal &  rs_be_0
                  | inst_jal
                  | inst_jalr
                  | inst_j
                  | inst_jr
                  ) & ds_valid;
assign br_target   = {32{inst_branch}} & (fs_pc + {{14{imm[15]}}, imm[15:0], 2'b0})
                   | {32{inst_jxr}}    &  rs_value
                   | {32{inst_jnr}}    & {fs_pc[31:28], jidx[25:0], 2'b0};

/* Need block? begin */
// if(|a=0) neq=0
assign rs_neq_0 = |rs;
assign rt_neq_0 = |rt;
assign es_dest_neq_0 = |es_dest;
assign ms_dest_neq_0 = |ms_dest;
assign ws_dest_neq_0 = |ws_dest;
// if(ab!=0 && a==b) eq=1
assign rs_eq_es_dest = (rs_neq_0 & es_dest_neq_0) && (rs == es_dest); // rs
assign rs_eq_ms_dest = (rs_neq_0 & ms_dest_neq_0) && (rs == ms_dest);
assign rs_eq_ws_dest = (rs_neq_0 & ws_dest_neq_0) && (rs == ws_dest);
assign rt_eq_es_dest = (rt_neq_0 & es_dest_neq_0) && (rt == es_dest); // rt
assign rt_eq_ms_dest = (rt_neq_0 & ms_dest_neq_0) && (rt == ms_dest);
assign rt_eq_ws_dest = (rt_neq_0 & ws_dest_neq_0) && (rt == ws_dest);
assign st_eq_es_dest = rs_eq_es_dest | rt_eq_es_dest;                 // st(@es)
assign st_eq_ms_dest = rs_eq_ms_dest | rt_eq_ms_dest;                 // st(@ms)
// Type define for block situation
                            // src from rs & rt
assign type_st = inst_addu  // (op)[rs, rt] -> rd
               | inst_add   // ...
               | inst_subu  // ...
               | inst_sub   // ...
               | inst_and   // ...
               | inst_nor   // ...
               | inst_or    // ...
               | inst_xor   // ...
               | inst_slt   // ...
               | inst_sltu  // ...
               | inst_sllv  // ...
               | inst_srav  // ...
               | inst_srlv  // ...
               | inst_beq   // (op)[rs, rt] -> br_taken
               | inst_bne   // ...
               | inst_mult  // (op)[rs, rt] -> HI, LO
               | inst_multu // ...
               | inst_div   // ...
               | inst_divu;
                            // src from rs
assign type_rs = inst_addiu // (op)[rs] -> rt
               | inst_addi  // ...
               | inst_slti  // ...
               | inst_sltiu // ...
               | inst_andi  // ...
               | inst_ori   // ...
               | inst_xori  // ...
               | inst_lw    // ...
               | inst_jr    // j [rs]
               | inst_mthi  // mov [rs] -> HI, LO
               | inst_mtlo; // ...
                            // src from rt
assign type_rt = inst_sw    // (op)[rt] -> mem
               | inst_sll   // (op)[rt] -> rd
               | inst_sra   // ...
               | inst_srl;  // ...
                            // No src from reg
assign type_nr = inst_lui   // (op)imm -> rt
               | inst_jal   // (op)PC+8 -> GPR[31]
               | inst_mfhi  // (op)()->rd
               | inst_mflo; // (op)()->rd
// rs+rt=st
assign rs_eq_dests = rs_eq_es_dest | rs_eq_ms_dest | rs_eq_ws_dest;
assign rt_eq_dests = rt_eq_es_dest | rt_eq_ms_dest | rt_eq_ws_dest;
assign st_eq_dests = rs_eq_dests   | rt_eq_dests   ;
// signal generate in ds_ready_go
// With Bypass Tech: only block when src_reg crash with a load inst(@es)
assign ds_no_crash_es = ~(rs_eq_es_dest & type_rs
                        | rt_eq_es_dest & type_rt
                        | st_eq_es_dest & type_st
                        );
assign ds_no_crash_ms = ~(rs_eq_ms_dest & type_rs
                        | rt_eq_ms_dest & type_rt
                        | st_eq_ms_dest & type_st
                        );
assign ds_ready_go = (es_res_valid || ds_no_crash_es)
                  && (ms_res_valid || ds_no_crash_ms)
                  ;

/* Need block? end */

endmodule