`include "Sysbus.defs"
`include "operation.defs"

enum {
	IDLE = 2'b00,
	REQUESTING = 2'b01,
	READING = 2'b10
} state, next_state;

// type of data to fetch from memory, instruction or data
// return 32 bit value from icache
// return 64 bit value from the dcache
enum	{
	NONE=2'b00,		// don't fetch anything
	INSTRUCTION=2'b01,	// fetch 32 bit instruction
	DATA=2'b10		// fetch 64 bit data
} ifm_fetch_type;

module top
#(
  BUS_DATA_WIDTH = 64,
  BUS_TAG_WIDTH = 13
)
(
  input  clk,
         reset,

  // 64-bit addresses of the program entry point and initial stack pointer
  input  [63:0] entry,
  input  [63:0] stackptr,
  input  [63:0] satp,
  
  // interface to connect to the bus
  output bus_reqcyc,
  output bus_respack,
  output [BUS_DATA_WIDTH-1:0] bus_req,
  output [BUS_TAG_WIDTH-1:0] bus_reqtag,
  input  bus_respcyc,
  input  bus_reqack,
  input  [BUS_DATA_WIDTH-1:0] bus_resp,
  input  [BUS_TAG_WIDTH-1:0] bus_resptag
);

logic [63:0] pc;
logic [63:0] npc;


// fetch from memory module definition begins here
// fetch from memory parameters
// generally common to both caches
logic	[63:0]	ifm_addr;
logic	[63:0]	ofm_data;

logic		ocache_fetch_from_memory_done;	// memory busy
logic		icache_write_to_cache;	// which cache to write to
logic	[63:0]	icache_addr;		// address in the cache
logic	[63:0]	icache_data;		// data fetched from memory

// fetch from memory module instantiation
fetch_from_memory_module fetch_from_memory_inst(
			.clk(clk), .reset(reset), .start_addr(ifm_addr),
			.fetch_type(ifm_fetch_type),
			.bus_reqcyc(bus_reqcyc),
			.bus_respack(bus_respack),
  			.bus_req(bus_req), .bus_reqtag(bus_reqtag),
			.bus_respcyc(bus_respcyc),
			.bus_reqack(bus_reqack), .bus_resp(bus_resp),
			.bus_resptag(bus_resptag),
			.ofm_fetch_from_memory_done(ocache_fetch_from_memory_done),
			.ofm_write_to_cache(icache_write_to_cache),
			.ofm_addr(icache_addr), .ofm_data(icache_data)
);
// fetch from memory module definition ends here

// instruction cache instantiation begins here
// icache parameters
logic	[63:0]	oicache_pc;
logic         	oicache_hit;
logic	[31:0]	oicache_instrux;
logic		oicache_is_inst_valid;
logic		ocache_membusy;

icache icache_inst(
	.clk(clk),
	.cache_pc(pc),
	.ncache_write_to_cache(icache_write_to_cache),
	.ncache_write_addr(icache_addr),
	.ncache_write_data(icache_data),
	.membusy(ocache_membusy),
	.fetch_from_memory_done(ocache_fetch_from_memory_done),
	.ncache_hit(oicache_hit),
	.cache_fetch_type(ifm_fetch_type),
	.ncache_instrux(oicache_instrux)
);

// instruction cache instantiation ends here

logic [31:0] id_instrux;
logic [63:0] id_pc;
logic [0:0]  id_is_inst_valid;
logic [0:0]  is_stall;


fetch fetch_inst(.clk(clk), .reset(reset), .entry(entry),
			.ftch_stall(is_stall),
			.icache_hit(oicache_hit),
			.pc(pc), .nof_instrux(oicache_instrux),
			.nof_is_inst_valid(oicache_is_inst_valid),
			.of_pc(id_pc), .of_instrux(id_instrux),
			.of_is_inst_valid(id_is_inst_valid)
);
/*
  //from decode
  logic   [4:0]   irf_read_reg_num0;
  logic   [4:0]   irf_read_reg_num1;
  logic   [4:0]   irf_hazchk_write_reg_num;
  logic   [0:0]   irf_hazchk_write_the_register;
  //from wb
  logic   [0:0]   irf_write_the_register;
  logic   [4:0]	  irf_write_reg_num;
  logic   [63:0]  irf_write_data;

  logic   [31:0]  ialu_instrux;
  logic   [63:0]  ialu_pc;
  logic   [0:0]   ialu_is_inst_valid;
  logic   [63:0]  ialu_read_data0;
  logic   [63:0]  ialu_read_data1;
  logic   [63:0]  ialu_imm;  //Why 64-bit
  logic   [10:0]  ialu_operation;
  logic   [4:0]   ialu_write_reg_num;
  logic   [0:0]   ialu_is_inst_regwrite;
  logic   [0:0]   ialu_is_inst_memread;
  logic   [0:0]   ialu_is_inst_memwrite;

  decode decode_inst(.clk(clk), .dc_instrux(id_instrux),
			.dc_pc(id_pc),
			.dc_is_inst_valid(id_is_inst_valid),
			.dc_stall(is_stall),
			.odc_instrux(ialu_instrux),
			.od_pc(ialu_pc),
			.od_is_inst_valid(ialu_is_inst_valid),
			.od_nread_reg0_num(irf_read_reg_num0), 
			.od_nread_reg1_num(irf_read_reg_num1),
			.od_nwrite_reg_num(irf_hazchk_write_reg_num),
			.od_nis_inst_regwrite(irf_hazchk_write_the_register),
			.od_write_reg_num(ialu_write_reg_num),
			.od_imm(ialu_imm),
			.od_operation(ialu_operation),
			.od_is_inst_regwrite(ialu_is_inst_regwrite),
			.od_is_inst_memread(ialu_is_inst_memread),
			.od_is_inst_memwrite(ialu_is_inst_memwrite)
			
  );


  register_file register_file_inst(
			.clk(clk), .irf_read_reg_num0(irf_read_reg_num0),
			.irf_read_reg_num1(irf_read_reg_num1),
			.irf_hazchk_write_reg_num(irf_hazchk_write_reg_num),
			.irf_hazchk_write_the_register(irf_hazchk_write_the_register),
			.irf_write_the_register(irf_write_the_register),
			.irf_write_reg_num(irf_write_reg_num),
			.irf_write_data(irf_write_data),
			.orf_read_data0(ialu_read_data0),
			.orf_read_data1(ialu_read_data1),
			.orf_stall(is_stall)
  );

  logic   [31:0]  imem_instrux;
  logic   [63:0]  imem_pc;
  logic   [0:0]   imem_is_inst_valid;
  logic   [4:0]   imem_write_reg_num;
  logic   [0:0]   imem_is_inst_regwrite;
  logic   [0:0]   imem_is_inst_memread;
  logic   [0:0]   imem_is_inst_memwrite;
  logic   [63:0]  imem_alu_result; 
  
  alu alu_inst(.clk(clk), .alu_instrux(ialu_instrux),
			.alu_pc(ialu_pc),
			.alu_is_inst_valid(ialu_is_inst_valid),
			.alu_read_data0(ialu_read_data0), //FROM RF
			.alu_read_data1(ialu_read_data1), //FROM RF
			.alu_imm(ialu_imm),
			.alu_operation(ialu_operation),
			.alu_write_reg_num(ialu_write_reg_num),
			.alu_is_inst_regwrite(ialu_is_inst_regwrite),
			.alu_is_inst_memread(ialu_is_inst_memread),
			.alu_is_inst_memwrite(ialu_is_inst_memwrite),

			.oalu_instrux(imem_instrux),
			.oalu_is_inst_valid(imem_is_inst_valid),
			.oalu_pc(imem_pc),
			.oalu_is_inst_regwrite(imem_is_inst_regwrite),
			.oalu_is_inst_memread(imem_is_inst_memread),
			.oalu_is_inst_memwrite(imem_is_inst_memwrite),
			.oalu_wb_reg(imem_write_reg_num),
			.oalu_result(imem_alu_result)
  );

  logic   [31:0]  iwb_instrux;
  logic   [63:0]  iwb_pc;
  logic   [0:0]   iwb_is_inst_valid;
  logic   [4:0]   iwb_write_reg_num;
  logic   [0:0]   iwb_is_inst_regwrite;
  logic   [63:0]  iwb_mem_result; 

  memory memory_inst(.clk(clk), .mem_instrux(imem_instrux),
			.mem_pc(imem_pc),
			.mem_is_inst_valid(imem_is_inst_valid),
			.mem_write_reg_num(imem_write_reg_num),
			.mem_is_inst_regwrite(imem_is_inst_regwrite),
			.mem_is_inst_memread(imem_is_inst_memread),
			.mem_is_inst_memwrite(imem_is_inst_memwrite),
			.mem_alu_result(imem_alu_result),

			.omem_instrux(iwb_instrux),
			.omem_is_inst_valid(iwb_is_inst_valid),
			.omem_pc(iwb_pc),
			.omem_is_inst_regwrite(iwb_is_inst_regwrite),
			.omem_wb_reg(iwb_write_reg_num),
			.omem_result(iwb_mem_result)
  );


  writeback writeback_inst(.clk(clk), .wb_instrux(iwb_instrux),
			.wb_pc(iwb_pc),
			.wb_is_inst_valid(iwb_is_inst_valid),
			.wb_write_reg_num(iwb_write_reg_num),
			.wb_is_inst_regwrite(iwb_is_inst_regwrite),
			.wb_mem_result(iwb_mem_result),
			.owb_result(irf_write_data),
			.owb_write_reg_num(irf_write_reg_num),
			.owb_is_inst_regwrite(irf_write_the_register)
  );
 */

always_ff @ (posedge clk)
	if (reset) begin
		pc <= entry;
		ifm_fetch_type = NONE;
		state <= REQUESTING;
	end 
	else begin
		if (pc >= 16'h120)
		$finish;
	end

	

  initial begin
    $display("Initializing top, entry point = 0x%x", entry);
  end
endmodule
