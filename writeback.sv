module writeback
#(
	REG_WIDTH = 64
)
(
	input	clk,
	input   [31:0]  		wb_instrux,
	input   [63:0]                  wb_pc,
	input   [0:0]                   wb_is_inst_valid,
	input				wb_is_ld_st_ecall_inst,
	
	input   [4:0]     		wb_write_reg_num,
	//IP Signals
	input	[0:0]			wb_is_inst_regwrite,
	input				wb_is_mem_to_reg,
	input   [63:0]                  wb_mem_ld_result,
	input   [63:0]			wb_mem_nold_result,
	input	[2:0]			wb_dpw_mem_size,
	input   [63:0]			wb_dpw_mem_addr,
	input	[63:0]			wb_dpw_mem_val,
	input				wb_dpw_is_inst_memwrite,
	input				wb_is_ecall_inst,

	output[63:0]			owb_result,
	output [4:0]			owb_write_reg_num,
	output 				owb_is_inst_regwrite,
	output				owb_undo_ldst_ec_stall
);
	always_comb
	begin
		owb_undo_ldst_ec_stall=wb_is_ld_st_ecall_inst;
		if (wb_is_mem_to_reg)
			owb_result = wb_mem_ld_result;
		else
			owb_result = wb_mem_nold_result;

		owb_is_inst_regwrite = wb_is_inst_regwrite;
		owb_write_reg_num = wb_write_reg_num;
	end
	
	always_ff @ (posedge clk) begin
		///if (wb_pc >= 16'h74)
			//$finish;
		//owb_is_inst_regwrite <= 0;
		//if(wb_is_inst_valid)
		//$display ("wb: %x %x",wb_pc, wb_instrux);
		if (wb_dpw_is_inst_memwrite) begin
			do_pending_write(wb_dpw_mem_addr, wb_dpw_mem_val, wb_dpw_mem_size);
		end
		//do_ecall(a7, a0, a1, a2, a3, a4, a5, a6, a0);
		if(wb_is_ecall_inst) begin
			do_ecall(register_file_inst.register[17], register_file_inst.register[10], register_file_inst.register[11], register_file_inst.register[12], register_file_inst.register[13], register_file_inst.register[14], register_file_inst.register[15], register_file_inst.register[16], register_file_inst.register[10]);	
		end
	end
	
endmodule : writeback
