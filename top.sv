/* verilator lint_off UNOPTFLAT */
`include "Sysbus.defs"
`include "operation.defs"
`include "icache.sv"
`include "bus_arbitrer.sv"
enum {
	IDLE = 2'b00,
	REQUESTING = 2'b01,
	READING = 2'b10
} state, next_state;

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

 enum {
	IDLE=3'b00,
	READING=3'b01,
	REQUESTING=3'b010,
	READING_NEXT_8=3'b011
 } state, next_state;


  logic nbus_reqcyc;
  logic nbus_respack;
  logic [4:0] count, ncount;
  logic have_read_first_word;
  logic nhave_read_first_word;
  logic [BUS_DATA_WIDTH-1:0] nbus_req;
  logic [BUS_TAG_WIDTH-1:0] nbus_reqtag;
  
  logic [31:0] id_instrux;
  logic [63:0] id_pc;
  logic [0:0]  id_is_inst_valid;
  logic [0:0]  is_hzstall;


 icache icache_inst(.clk(clk), .reset(reset), .entry(entry),
			.icache_bus_reqcyc(ba_ic_bus_reqcyc),
			.icache_bus_respack(ba_ic_bus_respack),
  			.icache_bus_req(ba_ic_bus_req),.icache_bus_reqtag(ba_ic_bus_reqtag),
			.icache_bus_respcyc(ba_ic_bus_respcyc),
			.icache_bus_reqack(ba_ic_bus_reqack), .icache_bus_resp(ba_ic_bus_resp),
			.icache_bus_resptag(ba_ic_bus_resptag),
			.data_read_req(icache_data_req),
			.icache_memaddr(icache_fetch_addr),
			.icache_has_bus(ba_icache_has_bus),
			.oicache_bus_assert(ba_icache_assert_bus),
			.oicache_data(ifetch_icache_data),
			.oicache_data_valid(ifetch_cache_data_valid),
			.nicache_read_done(ifetch_read_done)
  );


   logic ba_ic_bus_respcyc, ba_ic_bus_reqack, ba_ic_bus_reqcyc, ba_ic_bus_respack, ba_dc_bus_respcyc, ba_dc_bus_reqack, ba_dc_bus_reqcyc, ba_dc_bus_respack, ba_icache_has_bus, ba_icache_assert_bus, ba_dcache_has_bus, ba_dcache_assert_bus;
   logic [63:0]  ba_ic_bus_req, ba_ic_bus_resp, ba_dc_bus_resp, ba_dc_bus_req;
    logic [BUS_TAG_WIDTH-1:0] ba_ic_bus_resptag, ba_ic_bus_reqtag, ba_dc_bus_resptag, ba_dc_bus_reqtag;


 bus_arbitrer bus_arb(.clk(clk), .reset(reset), .entry(entry),
		.ba_bus_reqcyc(bus_reqcyc), .ba_bus_respack(bus_respack), 
		.ba_bus_req(bus_req), .ba_bus_reqtag(bus_reqtag), 
		.ba_bus_respcyc(bus_respcyc),
		.ba_bus_reqack(bus_reqack), .ba_bus_resp(bus_resp),
		.ba_bus_resptag(bus_resptag),

		.ba_icache_assert_bus(ba_icache_assert_bus),
		.ba_dcache_assert_bus(ba_dcache_assert_bus),

		.ba_ic_bus_reqcyc(ba_ic_bus_reqcyc),
		.ba_ic_bus_respack(ba_ic_bus_respack),
  		.ba_ic_bus_req(ba_ic_bus_req),.ba_ic_bus_reqtag(ba_ic_bus_reqtag),
		.ba_ic_bus_respcyc(ba_ic_bus_respcyc),
		.ba_ic_bus_reqack(ba_ic_bus_reqack), .ba_ic_bus_resp(ba_ic_bus_resp),
		.ba_ic_bus_resptag(ba_ic_bus_resptag),

		
		.ba_dc_bus_reqcyc(ba_dc_bus_reqcyc),
		.ba_dc_bus_respack(ba_dc_bus_respack),
  		.ba_dc_bus_req(ba_dc_bus_req),.ba_dc_bus_reqtag(ba_dc_bus_reqtag),
		.ba_dc_bus_respcyc(ba_dc_bus_respcyc),
		.ba_dc_bus_reqack(ba_dc_bus_reqack), .ba_dc_bus_resp(ba_dc_bus_resp),
		.ba_dc_bus_resptag(ba_dc_bus_resptag),

		.oba_icache_has_bus(ba_icache_has_bus),
		.oba_dcache_has_bus(ba_dcache_has_bus)
  );


 logic mem_dcache_read_req, mem_dcache_write_req;
 logic [63:0] mem_dcache_iaddr, mem_dcache_idata;
 logic [2:0] mem_dcache_data_size;
 
 dcache dcache_inst(.clk(clk), .reset(reset), .entry(entry),
			.odcache_bus_reqcyc(ba_dc_bus_reqcyc),
			.odcache_bus_respack(ba_dc_bus_respack),
  			.odcache_bus_req(ba_dc_bus_req),
			.odcache_bus_reqtag(ba_dc_bus_reqtag),

			.dcache_bus_respcyc(ba_dc_bus_respcyc),
			.dcache_bus_reqack(ba_dc_bus_reqack), 
			.dcache_bus_resp(ba_dc_bus_resp),
			.dcache_bus_resptag(ba_dc_bus_resptag),

			.dcache_has_bus(ba_dcache_has_bus),
			.dc_data_read_req(mem_dcache_read_req),
			.dc_data_write_req(mem_dcache_write_req),
			.dcache_memiaddr(mem_dcache_iaddr),
			.dcache_memidata(mem_dcache_idata),
			.dcache_data_size(mem_dcache_data_size),
			.nodcache_rdata(mem_dcache_rdata),
			//.odcache_data_valid(ifetch_cache_data_valid),
			.nodcache_read_done(mem_dcache_read_done),
			.nodcache_write_done(mem_dcache_write_done),
			.odcache_bus_assert(ba_dcache_assert_bus)
  );

 logic mem_dcache_read_done, mem_dcache_write_done;
 logic [63:0] mem_dcache_rdata;

 logic ifetch_read_done, ifetch_cache_data_valid;
 logic [63:0] ifetch_icache_data;
 logic ftch_ldst_ec_stall, fetch_is_branch_taken;

 logic icache_data_req;
 logic [63:0] icache_fetch_addr, fetch_next_branch_target;
 fetch fetch_inst(.clk(clk), .reset(reset), .entry(entry),
			.fetch_is_branch_taken(fetch_is_branch_taken),
			.fetch_next_branch_target(fetch_next_branch_target),
			.fetch_read_done(ifetch_read_done),
			.fetch_icache_instr(ifetch_icache_data),
			.fetch_cache_data_valid(ifetch_cache_data_valid),
			.ftch_hz_stall(is_hzstall),
			.ftch_ldst_ec_stall(ftch_ldst_ec_stall),
			.ofetch_data_req(icache_data_req),
			.ofetch_addr(icache_fetch_addr),
			.of_pc(id_pc),
			.of_instrux(id_instrux),
			.of_is_inst_valid(id_is_inst_valid)
 );



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
  logic   [0:0]   ialu_is_inst_memwrite, dc_undo_ldst_ec_stall;

  decode decode_inst(.clk(clk), .dc_instrux(id_instrux),
			.dc_pc(id_pc),
			.dc_is_inst_valid(id_is_inst_valid),
			.dc_stall(is_hzstall),
			.dc_undo_ldst_ec_stall(dc_undo_ldst_ec_stall),
			.odc_ldst_ec_stall(ftch_ldst_ec_stall),
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
			.od_is_inst_memwrite(ialu_is_inst_memwrite),
			.od_is_ld_st_ecall_inst(alu_is_ld_st_ecall_inst),
			.odc_is_ecall_inst(alu_is_ecall_inst)
			
  );


  register_file register_file_inst(
			.clk(clk), .reset(reset), .irf_read_reg_num0(irf_read_reg_num0),
			.irf_stackptr(stackptr),
			.irf_read_reg_num1(irf_read_reg_num1),
			.irf_hazchk_write_reg_num(irf_hazchk_write_reg_num),
			.irf_hazchk_write_the_register(irf_hazchk_write_the_register),
			.irf_write_the_register(irf_write_the_register),
			.irf_write_reg_num(irf_write_reg_num),
			.irf_write_data(irf_write_data),
			.orf_read_data0(ialu_read_data0),
			.orf_read_data1(ialu_read_data1),
			.orf_stall(is_hzstall)
  );

  logic   [31:0]  imem_instrux;
  logic   [63:0]  imem_pc;
  logic	  [2:0]	  imem_data_size;
  logic   [0:0]   imem_is_inst_valid;
  logic   [4:0]   imem_write_reg_num;
  logic   [0:0]   imem_is_inst_regwrite;
  logic   [0:0]   imem_is_inst_memread, alu_is_ecall_inst;
  logic   [0:0]   imem_is_inst_memwrite,alu_is_ld_st_ecall_inst,alu_mem_dfme;
  logic   [63:0]  imem_alu_result;
  logic   [63:0]  imem_alu_result2;
  
  alu alu_inst(.clk(clk), .alu_instrux(ialu_instrux),
			.alu_pc(ialu_pc),
			.alu_npc(npc),
			.alu_is_inst_valid(ialu_is_inst_valid),
			.alu_read_data0(ialu_read_data0), //FROM RF
			.alu_read_data1(ialu_read_data1), //FROM RF
			.alu_imm(ialu_imm),
			.alu_operation(ialu_operation),
			.alu_write_reg_num(ialu_write_reg_num),
			.alu_is_inst_regwrite(ialu_is_inst_regwrite),
			.alu_is_inst_memread(ialu_is_inst_memread),
			.alu_is_inst_memwrite(ialu_is_inst_memwrite),
			.alu_is_ld_st_ecall_inst(alu_is_ld_st_ecall_inst),
			.alu_mem_dfme(alu_mem_dfme),
			.alu_is_ecall_inst(alu_is_ecall_inst),

			.oalu_instrux(imem_instrux),
			.oalu_is_inst_valid(imem_is_inst_valid),
			.oalu_pc(imem_pc),
			.oalu_is_inst_regwrite(imem_is_inst_regwrite),
			.oalu_is_inst_memread(imem_is_inst_memread),
			.oalu_is_inst_memwrite(imem_is_inst_memwrite),
			.oalu_data_size(imem_data_size),
			.oalu_wb_reg(imem_write_reg_num),
			.oalu_result(imem_alu_result),
			.oalu_result2(imem_alu_result2),
			.oalu_is_ld_st_ecall_inst(mem_is_ld_st_ecall_inst),
			.oalu_is_branch_taken(fetch_is_branch_taken),
			.oalu_branch_target(fetch_next_branch_target),
			.oalu_is_ecall_inst(mem_is_ecall_inst)
  );

  logic   [31:0]  iwb_instrux;
  logic   [63:0]  iwb_pc;
  logic   [0:0]   iwb_is_inst_valid;
  logic   [4:0]   iwb_write_reg_num;
  logic   [0:0]   iwb_is_inst_regwrite,mem_is_ld_st_ecall_inst, mem_is_ecall_inst;
  logic   [63:0]  iwb_mem_result; 

  memory memory_inst(.clk(clk), .reset(reset), .mem_instrux(imem_instrux),
			.mem_pc(imem_pc),
			.mem_is_inst_valid(imem_is_inst_valid),
			.mem_is_ld_st_ecall_inst(mem_is_ld_st_ecall_inst),
			.mem_write_reg_num(imem_write_reg_num),
			.mem_is_inst_regwrite(imem_is_inst_regwrite),
			.mem_is_inst_memread(imem_is_inst_memread),
			.mem_is_inst_memwrite(imem_is_inst_memwrite),
			.mem_data_size(imem_data_size),
			.mem_alu_result(imem_alu_result),
			.mem_alu_result2(imem_alu_result2),
			.mem_read_done(mem_dcache_read_done),
			.mem_write_done(mem_dcache_write_done),
			.mem_dc_read_data(mem_dcache_rdata),
			.mem_is_ecall_inst(mem_is_ecall_inst),

			.omem_instrux(iwb_instrux),
			.omem_is_inst_valid(iwb_is_inst_valid),
			.omem_pc(iwb_pc),
			.omem_is_inst_regwrite(iwb_is_inst_regwrite),
			.omem_wb_reg(iwb_write_reg_num),
			.omem_is_mem_to_reg(wb_is_mem_to_reg),
			.omem_result(wb_mem_nold_result),
			.omem_data_read_req(mem_dcache_read_req),
			.omem_data_write_req(mem_dcache_write_req),
			.omem_dc_addr(mem_dcache_iaddr),
			.omem_dc_wdata(mem_dcache_idata),
			.omem_dc_data_size(mem_dcache_data_size),
			.omem_ld_result(wb_mem_ld_result),
			.omem_is_ld_st_ecall_inst(wb_is_ld_st_ecall_inst),
			.omem_alu_dfme(alu_mem_dfme),
			.omem_dpw_size(wb_dpw_mem_size),
			.omem_dpw_addr(wb_dpw_mem_addr),
			.omem_dpw_val(wb_dpw_mem_val),
			.omem_dpw_is_inst_memwrite(wb_dpw_is_inst_memwrite),
			.omem_is_ecall_inst(wb_is_ecall_inst)
  );


  logic [63:0] wb_mem_ld_result, wb_mem_nold_result, wb_dpw_mem_addr, wb_dpw_mem_val;
  logic wb_is_mem_to_reg, wb_undo_ldst_ec_stall,wb_is_ld_st_ecall_inst, wb_dpw_is_inst_memwrite, wb_is_ecall_inst;
  logic [2:0] wb_dpw_mem_size;

  writeback writeback_inst(.clk(clk), .wb_instrux(iwb_instrux),
			.wb_pc(iwb_pc),
			.wb_is_inst_valid(iwb_is_inst_valid),
			.wb_is_ld_st_ecall_inst(wb_is_ld_st_ecall_inst),
			.wb_write_reg_num(iwb_write_reg_num),
			.wb_is_inst_regwrite(iwb_is_inst_regwrite),
			.wb_is_mem_to_reg(wb_is_mem_to_reg),
			.wb_mem_ld_result(wb_mem_ld_result),
			.wb_mem_nold_result(wb_mem_nold_result),
			.wb_dpw_mem_size(wb_dpw_mem_size),
			.wb_dpw_mem_addr(wb_dpw_mem_addr),
			.wb_dpw_mem_val(wb_dpw_mem_val),
			.wb_dpw_is_inst_memwrite(wb_dpw_is_inst_memwrite),
			.wb_is_ecall_inst(wb_is_ecall_inst),
			.owb_result(irf_write_data),
			.owb_write_reg_num(irf_write_reg_num),
			.owb_is_inst_regwrite(irf_write_the_register),
			.owb_undo_ldst_ec_stall(dc_undo_ldst_ec_stall)
  );
 
  always @ (posedge clk)
    if (reset) begin
      pc <= entry;
      have_read_first_word<=0;
      state <= REQUESTING;
      count <=0;
    end else begin
	//$display("top: bus_reqcyc %d \n", bus_reqcyc);
      //$finish;
    end

	

  initial begin
    $display("Initializing top, entry point = 0x%x", entry);
  end
endmodule
