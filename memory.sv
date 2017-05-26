module memory
#(
	REG_WIDTH = 64
)
	
(
	input	clk,
	input   reset,
	input   [31:0]  		mem_instrux,
	input   [63:0]                  mem_pc,
	input   [0:0]                   mem_is_inst_valid,
	input				mem_is_ld_st_ecall_inst,
	
	//input	decoded,
	//input	stall,
	input   [4:0]     		mem_write_reg_num,
	//IP Signals
	input	[0:0]			mem_is_inst_regwrite,
	input   [0:0]                   mem_is_inst_memread,
	input   [0:0]                   mem_is_inst_memwrite,
	input	[2:0]			mem_data_size,	// data size for load/store
	input   [63:0]                  mem_alu_result,
	input	[63:0]			mem_alu_result2,
	input				mem_read_done,
	input				mem_write_done,
	input	[63:0]			mem_dc_read_data,
	input				mem_is_ecall_inst,
	
	//input   [0:0]                   is_pc_write,
	output  [REG_WIDTH-1:0]         omem_instrux,
	output   [0:0]                  omem_is_inst_valid,
	output   [63:0]                 omem_pc,
	output   [0:0]                  omem_is_inst_regwrite,
	output				omem_data_read_req,
	output				omem_data_write_req,
	output [63:0]			omem_dc_addr,
	output [63:0]			omem_dc_wdata,
	output [2:0]			omem_dc_data_size,

	//output	[REG_WIDTH-1:0]		mem_read_data1, //WHAT IS THIS
	output				omem_is_mem_to_reg,
	output	[4:0]			omem_wb_reg,
	output	[REG_WIDTH-1:0]		omem_result,
	output  [REG_WIDTH-1:0]		omem_ld_result,
	output  			omem_alu_dfme,
	output				omem_is_ld_st_ecall_inst,
	output	[2:0]			omem_dpw_size,
	output	[63:0]			omem_dpw_addr,
	output	[63:0]			omem_dpw_val,
	output				omem_dpw_is_inst_memwrite,
	output				omem_is_ecall_inst
);


enum {
	NOMEM=3'b001,
	WAITING_FOR_MEM= 3'b010,
	MEM_READ_DONE=3'b011,
	MEM_WRITE_DONE=3'b100
}mem_state, next_mem_state;

	logic[63:0] nmem_pc;
	logic [31:0] nmem_instrux;
	logic nmem_is_inst_valid, nmem_is_inst_regwrite, ndpw_mem_is_inst_memwrite, nis_mem_to_reg, nomem_is_ecall_inst, nmem_is_ld_st_ecall_inst;

	always_ff @ (posedge clk) begin
		if(reset) 
			mem_state<=NOMEM;
		else begin
		omem_is_ld_st_ecall_inst<=nmem_is_ld_st_ecall_inst;
		mem_state<=next_mem_state;
		omem_instrux <= nmem_instrux;
		omem_pc <= nmem_pc;
		omem_is_inst_valid<=nmem_is_inst_valid;
		//alu_read_data1 <= read_data1;
		omem_wb_reg <= mem_write_reg_num;

		omem_is_inst_regwrite<=nmem_is_inst_regwrite;
		omem_is_mem_to_reg<=nis_mem_to_reg;
		omem_result <= mem_alu_result;
		omem_ld_result<=mem_dc_read_data;
		omem_dpw_size<=mem_data_size;
		omem_dpw_addr<=mem_alu_result;
		omem_dpw_val<=mem_alu_result2;
		omem_dpw_is_inst_memwrite<=ndpw_mem_is_inst_memwrite;
		omem_is_ecall_inst<=omem_is_ecall_inst;
		end
		//if(mem_is_inst_valid)
		 //$display ("memory: %x %x",mem_pc, mem_instrux);
	end


	always_comb begin
		omem_data_read_req=mem_is_inst_memread;
		omem_data_write_req=mem_is_inst_memwrite;
		omem_dc_data_size=mem_data_size;
		omem_dc_addr=mem_alu_result; //from alu, 
		omem_dc_wdata=mem_alu_result2; //from alu(for writes) - assuming store values are left as is

		case (mem_state)
			NOMEM: begin
				if(mem_is_inst_memread || mem_is_inst_memwrite) begin
					if ((!mem_read_done) && (!mem_write_done)) 
						next_mem_state=WAITING_FOR_MEM;
					else if(mem_read_done)
						 next_mem_state=MEM_READ_DONE;
					else if (mem_write_done)
						 next_mem_state=MEM_WRITE_DONE;
				end
				else
					next_mem_state=NOMEM;
			end
			WAITING_FOR_MEM:begin
				if(mem_read_done)
					next_mem_state=MEM_READ_DONE;
				else if (mem_write_done)
					next_mem_state=MEM_WRITE_DONE;
				else
					next_mem_state=WAITING_FOR_MEM;
			end	
			MEM_READ_DONE:begin
				if(mem_is_inst_memread || mem_is_inst_memwrite) begin
					if ((!mem_read_done) && (!mem_write_done)) 
						next_mem_state=WAITING_FOR_MEM;
					else if(mem_read_done)
						 next_mem_state=MEM_READ_DONE;
					else if (mem_write_done)
						 next_mem_state=MEM_WRITE_DONE;
				end
				else
					next_mem_state=NOMEM;
			end
			MEM_WRITE_DONE:begin
				if(mem_is_inst_memread || mem_is_inst_memwrite) begin
					if ((!mem_read_done) && (!mem_write_done)) 
						next_mem_state=WAITING_FOR_MEM;
					else if(mem_read_done)
						 next_mem_state=MEM_READ_DONE;
					else if (mem_write_done)
						 next_mem_state=MEM_WRITE_DONE;
				end
				else
					next_mem_state=NOMEM;
			end
		endcase
	end

	always_comb begin
		case (next_mem_state)
			WAITING_FOR_MEM:begin
				nmem_is_ld_st_ecall_inst=0;
				nmem_is_inst_regwrite=0;
				nis_mem_to_reg=0;
				nmem_is_inst_valid=0;
				nmem_instrux=0;
				nmem_pc=0;
				omem_alu_dfme=1;
				ndpw_mem_is_inst_memwrite=0;
				nomem_is_ecall_inst=0;
			end
			MEM_READ_DONE:begin
				nmem_is_ld_st_ecall_inst=mem_is_ld_st_ecall_inst;
				nmem_is_inst_regwrite=mem_is_inst_regwrite;
				nis_mem_to_reg=1;
				nmem_is_inst_valid=mem_is_inst_valid;
				nmem_instrux=mem_instrux;
				nmem_pc=mem_pc;
				omem_alu_dfme=0;
				ndpw_mem_is_inst_memwrite=mem_is_inst_memwrite;
				nomem_is_ecall_inst=mem_is_ecall_inst;
			end
			MEM_WRITE_DONE: begin
				nmem_is_ld_st_ecall_inst=mem_is_ld_st_ecall_inst;
				nmem_is_inst_regwrite=mem_is_inst_regwrite;
				nis_mem_to_reg=0;
				nmem_is_inst_valid=mem_is_inst_valid;
				nmem_instrux=mem_instrux;
				nmem_pc=mem_pc;
				omem_alu_dfme=0;
				ndpw_mem_is_inst_memwrite=mem_is_inst_memwrite;
				nomem_is_ecall_inst=mem_is_ecall_inst;
			end
			NOMEM:begin
				nmem_is_ld_st_ecall_inst=mem_is_ld_st_ecall_inst;
				nmem_is_inst_regwrite=mem_is_inst_regwrite;
				nis_mem_to_reg=0;
				nmem_is_inst_valid=mem_is_inst_valid;
				nmem_instrux=mem_instrux;
				nmem_pc=mem_pc;
				omem_alu_dfme=0;
				ndpw_mem_is_inst_memwrite=mem_is_inst_memwrite;
				nomem_is_ecall_inst=mem_is_ecall_inst;
			end
		endcase
	end

endmodule : memory
