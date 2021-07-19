module cache(
    input          clk      ,
    input          resetn   ,
    // cpu
    input          valid    ,
    input          op       , // 1:write, 0:read
    input  [  7:0] index    , // addr[11:4]
    input  [ 19:0] tag      , // addr[31:12]
    input  [  3:0] offset   , // addr[3:0]
    input  [  3:0] wstrb    ,
    input  [ 31:0] wdata    ,
    output         addr_ok  ,
    output         data_ok  ,
    output [ 31:0] rdata    ,
    // axi r
    output         rd_req   ,
    output [  2:0] rd_type  , // 3'b000:BYTE, 3'b001:HALFWORD, 3'b010:WORD, 3'b100:CacheRow
    output [ 31:0] rd_addr  ,
    input          rd_rdy   ,
    input          ret_valid,
    input          ret_last ,
    input  [ 31:0] ret_data ,
    // axi w
    output         wr_req   ,
    output [  2:0] wr_type  ,
    output [ 31:0] wr_addr  ,
    output [  3:0] wr_wstrb ,
    output [127:0] wr_data  ,
    input          wr_rdy   );

/**********DECLARATION**********/
// --- STATE MACHINE ---
reg [2:0] cstate;
reg [2:0] nstate;
reg     w_cstate;
reg     w_nstate;
parameter IDLE    = 3'd0;
parameter LOOKUP  = 3'd1;
parameter MISS    = 3'd2;
parameter REPLACE = 3'd3;
parameter REFILL  = 3'd4;
parameter W_IDLE  = 1'd0;
parameter W_WRITE = 1'd1;
parameter OP_READ = 1'b0;
parameter OP_WRITE = 1'b1;

// --- Request Buffer ---
wire  [68:0]  request_buffer;
reg   [68:0]  request_buffer_r;
wire          op_r;
wire  [ 7:0]  index_r;
wire  [19:0]  tag_r;
wire  [ 3:0]  offset_r;
wire  [ 3:0]  wstrb_r;
wire  [31:0]  wdata_r;
wire  [127:0] replace_data_r;

// --- Tag Compare ---
wire way0_hit;
wire way1_hit;
wire cache_hit;

// --- Data Select ---
wire [31:0]	way0_load_word;
wire [31:0]	way1_load_word;
wire [31:0]	load_result;
wire sel_bank0;
wire sel_bank1;
wire sel_bank2;
wire sel_bank3;

// --- Miss Buffer ---
wire replace_way;
reg [1:0] ret_count;
reg [31:0] miss_bank0;
reg [31:0] miss_bank1;
reg [31:0] miss_bank2;
reg [31:0] miss_bank3;

// --- Write Buffer ---
wire [49:0] write_buffer;
reg  [49:0]	write_buffer_r;
wire        hit_write;
wire 		hw_sel_way;
wire [ 3:0]	hw_wstrb;
wire [31:0]	hw_wdata;
wire [ 1:0] hw_sel_bank;

// --- LFSR ---
reg  [22:0] pseudo_random_23;

// --- CACHE ---
wire [31:0] refill_rdata;
wire [31:0] refill_bank_data;
wire [ 3:0] refill_bank_wstrb;

wire        way0_tagv_en;
wire        way0_tagv_we;
wire [ 7:0] way0_tagv_addr;
wire [20:0] way0_tagv_wdata;
wire [20:0] way0_tagv_rdata;
wire        way0_v;
wire [19:0] way0_tag;
wire 		way0_data_bank0_en;
wire [ 3:0] way0_data_bank0_we;
wire [ 7:0] way0_data_bank0_addr;
wire [31:0] way0_data_bank0_wdata;
wire [31:0] way0_data_bank0_rdata;
wire        way0_data_bank1_en;
wire [ 3:0] way0_data_bank1_we;
wire [ 7:0] way0_data_bank1_addr;
wire [31:0] way0_data_bank1_wdata;
wire [31:0] way0_data_bank1_rdata;
wire        way0_data_bank2_en;
wire [ 3:0] way0_data_bank2_we;
wire [ 7:0] way0_data_bank2_addr;
wire [31:0] way0_data_bank2_wdata;
wire [31:0] way0_data_bank2_rdata;
wire        way0_data_bank3_en;
wire [ 3:0] way0_data_bank3_we;
wire [ 7:0] way0_data_bank3_addr;
wire [31:0] way0_data_bank3_wdata;
wire [31:0] way0_data_bank3_rdata;

wire        way1_tagv_en;
wire        way1_tagv_we;
wire [ 7:0] way1_tagv_addr;
wire [20:0] way1_tagv_wdata;
wire [20:0] way1_tagv_rdata;
wire        way1_v;
wire [19:0] way1_tag;
wire 		way1_data_bank0_en;
wire [ 3:0] way1_data_bank0_we;
wire [ 7:0] way1_data_bank0_addr;
wire [31:0] way1_data_bank0_wdata;
wire [31:0] way1_data_bank0_rdata;
wire        way1_data_bank1_en;
wire [ 3:0] way1_data_bank1_we;
wire [ 7:0] way1_data_bank1_addr;
wire [31:0] way1_data_bank1_wdata;
wire [31:0] way1_data_bank1_rdata;
wire        way1_data_bank2_en;
wire [ 3:0] way1_data_bank2_we;
wire [ 7:0] way1_data_bank2_addr;
wire [31:0] way1_data_bank2_wdata;
wire [31:0] way1_data_bank2_rdata;
wire        way1_data_bank3_en;
wire [ 3:0] way1_data_bank3_we;
wire [ 7:0] way1_data_bank3_addr;
wire [31:0] way1_data_bank3_wdata;
wire [31:0] way1_data_bank3_rdata;

// --- AXI ---
reg wr_req_flag;

/**********LOGIC**********/
// --- STATE MACHINE ---
// main state machine
always@(posedge clk) begin
    if (!resetn) begin
        cstate <= IDLE;
    end
    else begin
        cstate <= nstate;
    end
end
always@(*) begin
    case(cstate)
        IDLE: begin
            if (valid)
                nstate = LOOKUP;
            else
                nstate = cstate;
        end

        LOOKUP:begin
            if (cache_hit)
                nstate = IDLE;
            else
                nstate = MISS;
        end

        MISS:begin
            if (wr_rdy)
                nstate = REPLACE;
            else
                nstate = cstate;
        end

        REPLACE:begin
            if (rd_rdy)
                nstate = REFILL;
            else
                nstate = cstate;
        end

        REFILL:begin
            if (ret_last)
                nstate = IDLE;
            else
                nstate = REFILL;
        end

        default:
            nstate = IDLE;
    endcase
end

//write buffer state machine
always@(posedge clk) begin
    if (!resetn) begin
        w_cstate <= W_IDLE;
    end
    else begin
        w_cstate <= w_nstate;
    end
end
always @(*) begin
    case(w_cstate)
        W_IDLE:begin
            if(hit_write)
                w_nstate <= W_WRITE;
            else begin
                w_nstate <= W_IDLE;
            end
        end
        W_WRITE:begin
            w_nstate <= W_IDLE;
        end
    endcase
end

// --- Request Buffer ---
assign request_buffer = { op,     //68
                          index,  //67:60
                          tag,    //59:40
                          offset, //39:36
                          wstrb,  //35:32
                          wdata   //31:0
                        };
assign { op_r,     //68
         index_r,  //67:60
         tag_r,    //59:40
         offset_r, //39:36
         wstrb_r,  //35:32
         wdata_r   //31:0
        } = request_buffer_r;
always@(posedge clk) begin
    if (!resetn)
        request_buffer_r <= 0;
    else if (valid & cstate==IDLE & addr_ok)
        request_buffer_r <= request_buffer;
end

// --- Tag Compare ---
assign way0_hit = way0_v && way0_tag==tag_r;
assign way1_hit = way1_v && way1_tag==tag_r;
assign cache_hit = way1_hit || way0_hit;

// --- Data Select ---
assign sel_bank0 = offset_r[3:2]==2'b00;
assign sel_bank1 = offset_r[3:2]==2'b01;
assign sel_bank2 = offset_r[3:2]==2'b10;
assign sel_bank3 = offset_r[3:2]==2'b11;
assign way0_load_word = ({32{sel_bank0}}&way0_data_bank0_rdata)
                      | ({32{sel_bank1}}&way0_data_bank1_rdata)
                      | ({32{sel_bank2}}&way0_data_bank2_rdata)
                      | ({32{sel_bank3}}&way0_data_bank3_rdata);
assign way1_load_word = ({32{sel_bank0}}&way1_data_bank0_rdata)
                      | ({32{sel_bank1}}&way1_data_bank1_rdata)
                      | ({32{sel_bank2}}&way1_data_bank2_rdata)
                      | ({32{sel_bank3}}&way1_data_bank3_rdata);
        //not consider about miss
assign load_result = {32{way0_hit}} & way0_load_word | {32{way1_hit}} & way1_load_word;

// --- Miss Buffer ---
assign replace_way = 1'b0;
always @(posedge clk) begin
    if (!resetn)
        ret_count <= 0;
    else if (ret_last)
        ret_count <= 0;
    else if (ret_valid)
        ret_count <= ret_count+1;
end

always @(posedge clk) begin
    if (!resetn)
        miss_bank0 <= 0;
    else if (ret_valid && ret_count==2'b00)
        miss_bank0 <= refill_bank_data;
end

always @(posedge clk) begin
    if (!resetn)
        miss_bank1 <= 0;
    else if (ret_valid && ret_count==2'b01)
        miss_bank1 <= refill_bank_data;
end

always @(posedge clk) begin
    if (!resetn)
        miss_bank2 <= 0;
    else if (ret_valid && ret_count==2'b10)
        miss_bank2 <= refill_bank_data;
end

always @(posedge clk) begin
    if (!resetn)
        miss_bank3 <= 0;
    else if (ret_valid && ret_count==2'b11)
        miss_bank3 <= refill_bank_data;
end

// --- Write Buffer ---
assign write_buffer = {
    index_r,//48:41
    way1_hit,//40
    wstrb_r,//39:36
    wdata_r,//35:4
    offset_r//3:0
} ;

assign hit_write = op_r==OP_WRITE && cstate==LOOKUP && cache_hit;
always @(posedge clk) begin
    if (!resetn)
        write_buffer_r <= 0;
    else if (hit_write)
        write_buffer_r <= write_buffer;
end

assign hw_sel_way = write_buffer_r[40];
assign hw_wstrb   = write_buffer_r[39:36];
assign hw_wdata   = write_buffer_r[35:4];
assign hw_sel_bank= write_buffer_r[3:2];

// --- LFSR ---
always @ (posedge clk) begin
    if (!resetn) begin
        pseudo_random_23 <= 23'b100_1010_0101_0010_1000_1010;
    end
    else
        pseudo_random_23 <= {pseudo_random_23[21:0],pseudo_random_23[22] ^ pseudo_random_23[17]};
end

// --- CACHE ---
assign addr_ok = cstate == IDLE & valid & !(hw_sel_bank == offset[3:2] && tag_r == tag && w_cstate == W_WRITE);
assign data_ok = (cache_hit & cstate == LOOKUP & op_r == OP_READ) //hit read
                | (w_cstate==W_WRITE) | ret_valid & ret_last;     //hit write
assign rdata = (ret_valid & ret_last)?refill_rdata:load_result;
assign refill_rdata = {32{offset_r[3:2] == 2'b00}} & miss_bank0
                    | {32{offset_r[3:2] == 2'b01}} & miss_bank1
                    | {32{offset_r[3:2] == 2'b10}} & miss_bank2
                    | {32{offset_r[3:2] == 2'b11}} & miss_bank3;
assign refill_bank_data = (ret_count==offset_r[3:2] & op_r==OP_WRITE)?wdata_r:ret_data;
assign refill_bank_wstrb = (ret_count == offset_r[3:2] & op_r==OP_WRITE)?wstrb_r:4'b1111;

//for way0
//tag_v
tag_v_ram way0_tagv(
    .clka(clk),
//  .ena(way0_tagv_en),
    .wea(way0_tagv_we),
    .addra(way0_tagv_addr),
    .dina(way0_tagv_wdata),
    .douta(way0_tagv_rdata)
    );
assign way0_tagv_en = valid&addr_ok|cstate == MISS & wr_rdy| ret_last & !replace_way;
assign way0_tagv_we = ret_last & !replace_way;
assign way0_tagv_addr = (way0_tagv_we)?index_r:index;
assign way0_tagv_wdata = {tag_r,1'b1};
assign way0_v = way0_tagv_rdata[0];
assign way0_tag = way0_tagv_rdata[20:1];
//data_bank
data_ram_bank way0_data_bank0(
    .clka(clk),
//  .ena(way0_data_bank0_en),
    .wea(way0_data_bank0_we),
    .addra(way0_data_bank0_addr),
    .dina(way0_data_bank0_wdata),
    .douta(way0_data_bank0_rdata)
    );
data_ram_bank way0_data_bank1(
    .clka(clk),
//  .ena(way0_data_bank1_en),
    .wea(way0_data_bank1_we),
    .addra(way0_data_bank1_addr),
    .dina(way0_data_bank1_wdata),
    .douta(way0_data_bank1_rdata)
    );
data_ram_bank way0_data_bank2(
    .clka(clk),
//  .ena(way0_data_bank2_en),
    .wea(way0_data_bank2_we),
    .addra(way0_data_bank2_addr),
    .dina(way0_data_bank2_wdata),
    .douta(way0_data_bank2_rdata)
    );
data_ram_bank way0_data_bank3(
    .clka(clk),
//  .ena(way0_data_bank3_en),
    .wea(way0_data_bank3_we),
    .addra(way0_data_bank3_addr),
    .dina(way0_data_bank3_wdata),
    .douta(way0_data_bank3_rdata)
    );

assign way0_data_bank0_en = valid&addr_ok | (w_cstate==W_WRITE & hw_sel_bank == 2'b00 & !hw_sel_way) | cstate == MISS & wr_rdy & !replace_way | ret_valid & ret_count==2'b00 & !replace_way;
assign way0_data_bank1_en = valid&addr_ok | (w_cstate==W_WRITE & hw_sel_bank == 2'b01 & !hw_sel_way) | cstate == MISS & wr_rdy & !replace_way | ret_valid & ret_count==2'b01 & !replace_way;
assign way0_data_bank2_en = valid&addr_ok | (w_cstate==W_WRITE & hw_sel_bank == 2'b10 & !hw_sel_way) | cstate == MISS & wr_rdy & !replace_way | ret_valid & ret_count==2'b10 & !replace_way;
assign way0_data_bank3_en = valid&addr_ok | (w_cstate==W_WRITE & hw_sel_bank == 2'b11 & !hw_sel_way) | cstate == MISS & wr_rdy & !replace_way | ret_valid & ret_count==2'b11 & !replace_way;
assign way0_data_bank0_we = {4{(w_cstate==W_WRITE & hw_sel_bank == 2'b00 & !hw_sel_way) | ret_valid & ret_count==2'b00 & !replace_way}} & ((ret_valid && ret_count==2'b00) ? refill_bank_wstrb : hw_wstrb);
assign way0_data_bank1_we = {4{(w_cstate==W_WRITE & hw_sel_bank == 2'b01 & !hw_sel_way) | ret_valid & ret_count==2'b01 & !replace_way}} & ((ret_valid && ret_count==2'b01) ? refill_bank_wstrb : hw_wstrb);
assign way0_data_bank2_we = {4{(w_cstate==W_WRITE & hw_sel_bank == 2'b10 & !hw_sel_way) | ret_valid & ret_count==2'b10 & !replace_way}} & ((ret_valid && ret_count==2'b10) ? refill_bank_wstrb : hw_wstrb);
assign way0_data_bank3_we = {4{(w_cstate==W_WRITE & hw_sel_bank == 2'b11 & !hw_sel_way) | ret_valid & ret_count==2'b11 & !replace_way}} & ((ret_valid && ret_count==2'b11) ? refill_bank_wstrb : hw_wstrb);
assign way0_data_bank0_addr = (ret_valid)?index_r:index;
assign way0_data_bank1_addr = (ret_valid)?index_r:index;
assign way0_data_bank2_addr = (ret_valid)?index_r:index;
assign way0_data_bank3_addr = (ret_valid)?index_r:index;
assign way0_data_bank0_wdata = (ret_valid && ret_count==2'b00) ? refill_bank_data :hw_wdata;
assign way0_data_bank1_wdata = (ret_valid && ret_count==2'b01) ? refill_bank_data :hw_wdata;
assign way0_data_bank2_wdata = (ret_valid && ret_count==2'b10) ? refill_bank_data :hw_wdata;
assign way0_data_bank3_wdata = (ret_valid && ret_count==2'b11) ? refill_bank_data :hw_wdata;
//dirty
reg way0_d[255:0];
integer	j;
always @(posedge clk) begin
    if (!resetn)
        for(j=0;j<256;j=j+1)
            way0_d[j] <= 1'b0;
    else if (w_cstate==W_WRITE&&way0_hit)
        way0_d[index_r] <= 1'b1;
    else if (cstate == REFILL && !replace_way)
        way0_d[index_r] <= op_r ;
end

//for way1
tag_v_ram way1_tagv(
    .clka(clk),
//  .ena(way1_tagv_en),
    .wea(way1_tagv_we),
    .addra(way1_tagv_addr),
    .dina(way1_tagv_wdata),
    .douta(way1_tagv_rdata)
    );
assign way1_tagv_en = valid&addr_ok|cstate == MISS & wr_rdy| ret_last & replace_way;
assign way1_tagv_we = ret_last & replace_way;
assign way1_tagv_addr = (way1_tagv_we)?index_r:index;
assign way1_tagv_wdata = {tag_r,1'b1};
assign way1_v = way1_tagv_rdata[0];
assign way1_tag = way1_tagv_rdata[20:1];
//data_bank
data_ram_bank way1_data_bank0(
    .clka(clk),
//  .ena(way1_data_bank0_en),
    .wea(way1_data_bank0_we),
    .addra(way1_data_bank0_addr),
    .dina(way1_data_bank0_wdata),
    .douta(way1_data_bank0_rdata)
    );
data_ram_bank way1_data_bank1(
    .clka(clk),
//  .ena(way1_data_bank1_en),
    .wea(way1_data_bank1_we),
    .addra(way1_data_bank1_addr),
    .dina(way1_data_bank1_wdata),
    .douta(way1_data_bank1_rdata)
    );
data_ram_bank way1_data_bank2(
    .clka(clk),
//  .ena(way1_data_bank2_en),
    .wea(way1_data_bank2_we),
    .addra(way1_data_bank2_addr),
    .dina(way1_data_bank2_wdata),
    .douta(way1_data_bank2_rdata)
    );
data_ram_bank way1_data_bank3(
    .clka(clk),
//  .ena(way1_data_bank3_en),
    .wea(way1_data_bank3_we),
    .addra(way1_data_bank3_addr),
    .dina(way1_data_bank3_wdata),
    .douta(way1_data_bank3_rdata)
    );

assign way1_data_bank0_en = valid&addr_ok | (w_cstate==W_WRITE & hw_sel_bank == 2'b00 &  hw_sel_way) | cstate == MISS & wr_rdy &  replace_way | ret_valid & ret_count==2'b00 &  replace_way;
assign way1_data_bank1_en = valid&addr_ok | (w_cstate==W_WRITE & hw_sel_bank == 2'b01 &  hw_sel_way) | cstate == MISS & wr_rdy &  replace_way | ret_valid & ret_count==2'b01 &  replace_way;
assign way1_data_bank2_en = valid&addr_ok | (w_cstate==W_WRITE & hw_sel_bank == 2'b10 &  hw_sel_way) | cstate == MISS & wr_rdy &  replace_way | ret_valid & ret_count==2'b10 &  replace_way;
assign way1_data_bank3_en = valid&addr_ok | (w_cstate==W_WRITE & hw_sel_bank == 2'b11 &  hw_sel_way) | cstate == MISS & wr_rdy &  replace_way | ret_valid & ret_count==2'b11 &  replace_way;
assign way1_data_bank0_we = {4{(w_cstate==W_WRITE & hw_sel_bank == 2'b00 & hw_sel_way) | ret_valid & ret_count==2'b00 & replace_way}} & ((ret_valid && ret_count==2'b00) ? refill_bank_wstrb : hw_wstrb);
assign way1_data_bank1_we = {4{(w_cstate==W_WRITE & hw_sel_bank == 2'b01 & hw_sel_way) | ret_valid & ret_count==2'b01 & replace_way}} & ((ret_valid && ret_count==2'b01) ? refill_bank_wstrb : hw_wstrb);
assign way1_data_bank2_we = {4{(w_cstate==W_WRITE & hw_sel_bank == 2'b10 & hw_sel_way) | ret_valid & ret_count==2'b10 & replace_way}} & ((ret_valid && ret_count==2'b10) ? refill_bank_wstrb : hw_wstrb);
assign way1_data_bank3_we = {4{(w_cstate==W_WRITE & hw_sel_bank == 2'b11 & hw_sel_way) | ret_valid & ret_count==2'b11 & replace_way}} & ((ret_valid && ret_count==2'b11) ? refill_bank_wstrb : hw_wstrb);
assign way1_data_bank0_addr = (ret_valid)?index_r:index;
assign way1_data_bank1_addr = (ret_valid)?index_r:index;
assign way1_data_bank2_addr = (ret_valid)?index_r:index;
assign way1_data_bank3_addr = (ret_valid)?index_r:index;
assign way1_data_bank0_wdata = (ret_valid && ret_count==2'b00) ? refill_bank_data :hw_wdata;
assign way1_data_bank1_wdata = (ret_valid && ret_count==2'b01) ? refill_bank_data :hw_wdata;
assign way1_data_bank2_wdata = (ret_valid && ret_count==2'b10) ? refill_bank_data :hw_wdata;
assign way1_data_bank3_wdata = (ret_valid && ret_count==2'b11) ? refill_bank_data :hw_wdata;
//dirty
reg way1_d[255:0];
//integer	j;
always @(posedge clk) begin
    if (!resetn)
        for(j=0;j<256;j=j+1)
            way1_d[j] <= 1'b0;
    else if (w_cstate==W_WRITE&&way1_hit)
        way1_d[index_r] <= 1'b1;
    else if (cstate == REFILL && !replace_way)
        way1_d[index_r] <= op_r ;
end

// --- AXI ---
// w
always @(posedge clk) begin
    if(!resetn)
        wr_req_flag <=1'b0;
    else if (wr_req_flag && cstate == REPLACE)
        wr_req_flag <= 1'b0;
    else if (!wr_req_flag && wr_rdy)
        wr_req_flag <= 1'b1;
end

assign wr_req = cstate==REPLACE && (way0_d[index_r]&!replace_way | way1_d[index_r]&replace_way) & wr_req_flag;
assign wr_type = 3'b100;
assign wr_addr = {(replace_way)?way1_tag:way0_tag,index_r,offset_r};
assign wr_wstrb = 4'b1111;
assign wr_data = (replace_way) ? {way1_data_bank3_rdata,way1_data_bank2_rdata,way1_data_bank1_rdata,way1_data_bank0_rdata}
                                : {way0_data_bank3_rdata,way0_data_bank2_rdata,way0_data_bank1_rdata,way0_data_bank0_rdata};
// r
assign rd_req = cstate == REPLACE;
assign rd_type = 3'b100;
assign rd_addr = {tag_r,index_r,offset_r};

endmodule