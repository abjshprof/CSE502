// Arithmetic Logic Unit Module
// called by top module after reading the register file to perform alu_operations

`include "operation.defs"

module alu
#(
	REG_WIDTH = 64
)
(
	input	clk,
	input   [31:0]  		alu_instrux,
	input   [63:0]                  alu_pc,
	output	[63:0]			alu_npc,
	input   [0:0]                   alu_is_inst_valid,
	input				alu_is_ld_st_ecall_inst,
	input				alu_mem_dfme,
	
	//input	decoded,
	//input	stall,
	input	[REG_WIDTH-1:0] 	alu_read_data0,
	input	[REG_WIDTH-1:0] 	alu_read_data1,
	input	[REG_WIDTH-1:0]		alu_imm,
	input	[10:0] 			alu_operation,
	input   [4:0]     		alu_write_reg_num,

	//IP Signals
	input	[0:0]			alu_is_inst_regwrite,
	input   [0:0]                   alu_is_inst_memread,
	input   [0:0]                   alu_is_inst_memwrite,
	input				alu_is_ecall_inst,
	//input   [0:0]                   is_pc_write,
	output  [REG_WIDTH-1:0]         oalu_instrux,
	output   [0:0]                  oalu_is_inst_valid,
	output   [63:0]                 oalu_pc,
	output	 [0:0]			oalu_is_inst_regwrite,
	output   [0:0]                  oalu_is_inst_memread,
	output   [0:0]                  oalu_is_inst_memwrite,

	output	[2:0]			oalu_data_size,	// size of load/store
	output	[4:0]			oalu_wb_reg,
	output	[REG_WIDTH-1:0]		oalu_result,
	output  [REG_WIDTH-1:0]		oalu_result2,
	output				oalu_is_ld_st_ecall_inst,
	output				oalu_is_branch_taken,
	output	[REG_WIDTH-1:0]		oalu_branch_target,
	output				oalu_is_ecall_inst
);

	enum	{
		NA 		= 	3'b000,
		BYTE		=	3'b001,
		HALF_WORD	=	3'b010,
		WORD 		= 	3'b011,
		DOUBLE_WORD	= 	3'b100
	} data_size;

	wire signed	[31:0] 		sword;
	wire signed	[63:0]		signed_imm;
	wire unsigned	[63:0]		unsigned_imm;
	wire signed	[63:0]		intermediate_value;
	wire signed	[63:0]		signed_src1, signed_src2;
	wire unsigned	[63:0]		unsigned_src1, unsigned_src2;

	logic		[127:0] 	upper_xlen;
	logic		[REG_WIDTH-1:0] src1, src2;
	logic		[0:0]		nalu_is_reg_write;
	logic		[63:0]		nalu_result, nalu_result2;

	always_comb	
	begin

		src1 = alu_read_data0;
		src2 = alu_read_data1;
		

		case (alu_operation)
			`ADD: // 1		
			begin
				oalu_is_branch_taken=0;
				nalu_result = src1 + src2;
				
			end
			
			`SUB : 	// 2
			begin
				oalu_is_branch_taken=0;
				nalu_result = src1 - src2;
				
			end
			
			`MUL : 	// 3
			begin
				oalu_is_branch_taken=0;
				upper_xlen = src1 * src2;
				nalu_result = upper_xlen[63:0];
				
			end
			
			`DIV	: // 4	
			begin
				oalu_is_branch_taken=0;
				signed_src1 = $signed(src1);
				signed_src2 = $signed(src2);
				intermediate_value = signed_src1 / signed_src2;
				nalu_result = $signed(intermediate_value);
				
			end
			
			`ADDI: // 5
			begin
				oalu_is_branch_taken=0;
				signed_imm = $signed(alu_imm[11:0]);
                                nalu_result = src1 + signed_imm;
				
			end
			
			`ADDW : // 6
			begin
				oalu_is_branch_taken=0;
				sword =src1[31:0] + src2[31:0];
				nalu_result = $signed(sword[31:0]);
				
			end
			
			`ADDIW : // 7
			begin
				oalu_is_branch_taken=0;
				signed_imm = $signed(alu_imm[11:0]);
				sword = src1[31:0] + signed_imm[31:0];
				nalu_result = $signed(sword[31:0]);				
			
			end
			
			`SUBI: // 8		
			begin 
				oalu_is_branch_taken=0;
				signed_imm = $signed(alu_imm[11:0]);
				nalu_result = src1 - signed_imm;
				
			end
			
			`SUBW:	// 9
			begin
				oalu_is_branch_taken=0;
				sword = src1[31:0] - src2[31:0];
				nalu_result = $signed(sword[31:0]);
				
			end
			
			`SUBIW:	// 10	
			begin
				oalu_is_branch_taken=0;
				signed_imm = $signed(alu_imm[11:0]);
				sword = src1[31:0] - signed_imm[31:0];
				nalu_result = $signed(sword[31:0]);
				
			end
			
			
			`MULHU:	// 11	
			begin
				oalu_is_branch_taken=0;
				upper_xlen = $unsigned(src1) * $unsigned(src2);
				nalu_result = upper_xlen[127:64];
			end
			
			`MULW:	// 12	
			begin
				oalu_is_branch_taken=0;
				sword = src1[31:0] * src2[31:0];
				nalu_result = $signed(sword[31:0]);
				
			end
			
			`MULH:	// 13	
			begin
				oalu_is_branch_taken=0;
				upper_xlen = $signed(src1) * $signed(src2);
				nalu_result = upper_xlen[127:64];
			end
			
			`DIVU	: // 14	
			begin
				oalu_is_branch_taken=0;
				nalu_result = $unsigned(src1) / $unsigned(src2);
				
			end
	
			`DIVW	: // 15	
			begin
				oalu_is_branch_taken=0;
				sword = $signed(src1[31:0]) / $signed(src2[31:0]);
				nalu_result = $signed(sword);
				
			end
			
			`DIVUW	: // 16	
			begin
				oalu_is_branch_taken=0;
				sword = $unsigned(src1[31:0]) / $unsigned(src2[31:0]);
				nalu_result = $signed(sword);
				
			end

			`AND: // 17
			begin
				oalu_is_branch_taken=0;
				nalu_result = src1 & src2;
				
			end

			`ANDI: // 18
			begin
				oalu_is_branch_taken=0;
				signed_imm = $signed(alu_imm[11:0]);
				nalu_result = src1 & $signed(signed_imm);
				
			end
			
			`SLLI: // 19
			begin
				oalu_is_branch_taken=0;
				nalu_result = src1 << alu_imm;
				
			end
			
			`SRLI	: // 20
			begin
				oalu_is_branch_taken=0;
				nalu_result = src1 >> alu_imm;
			end
			
			`SRAI	: // 21 needs testing, unsure about sign bit propagating to all bits
			begin
				oalu_is_branch_taken=0;
				intermediate_value = src1 >> alu_imm;
				upper_xlen = $signed(intermediate_value);
				nalu_result = upper_xlen[63:0];
			end
			
			
			`SLTI	: // 22
			begin
				oalu_is_branch_taken=0;
				signed_imm = $signed(alu_imm);
				signed_src1 = $signed(src1);
				if (signed_src1 < signed_imm)
					nalu_result = 1;
				else
					nalu_result = 0;
				
			end
			

			`SLTIU	: // 23
			begin
				oalu_is_branch_taken=0;
				unsigned_imm = $unsigned(alu_imm);
				unsigned_src1 = $unsigned(src1);

				if (unsigned_src1 < unsigned_imm)
					nalu_result = 1;
				else
					nalu_result = 0;
			end
			
			`XORI	: // 24
			begin
				oalu_is_branch_taken=0;
				signed_imm = $signed(alu_imm);
				nalu_result = src1 ^ signed_imm;
			end
			
			`ORI	: // 25
			begin
				oalu_is_branch_taken=0;
				signed_imm = $signed(alu_imm);
				nalu_result = src1 | signed_imm;
			end
			
			`SLL	: // 26
			begin
				oalu_is_branch_taken=0;
				nalu_result = src1 << src2;
			end

			
			`SLT	: // 27
			begin
				oalu_is_branch_taken=0;
				signed_src1 = $signed(src1);
				signed_src2 = $signed(src2);
				if (signed_src1 < signed_src2)
					nalu_result = 1;
				else
					nalu_result = 0;
			end

			
			
			`SLTU	: // 28
			begin
				oalu_is_branch_taken=0;
				unsigned_src1 = $unsigned(src1);
				unsigned_src2 = $unsigned(src2);

				if (unsigned_src1 == 0) begin
					if (unsigned_src2 == 0)
						nalu_result = 1;
					else
						nalu_result = 0;
				end
				else begin
					if (unsigned_src1 < unsigned_src2)
						nalu_result = 1;
					else
						nalu_result = 0;
				end
				
			end
		
			`XOR	: // 29
			begin
				nalu_result = src1 ^ src2;
				oalu_is_branch_taken=0;
			end
			
			`SRL	: // 30
			begin
				nalu_result = src1 >> src2;
				oalu_is_branch_taken=0;
			end
			
			`SRA	: // 31
			begin
				nalu_result = src1 >> src2;
				oalu_is_branch_taken=0;
			end

			
			`OR	: // 32
			begin
				nalu_result = src1 | src2;
				oalu_is_branch_taken=0;
			end
			
			`LUI	: // 33
			begin
				sword[31:12] = alu_imm[31:12];
				sword[11:0] = 12'b000000000000;
				nalu_result = sword;
				oalu_is_branch_taken=0;
			end
				
			`AUIPC	: // 34
			begin
				sword[31:12] = alu_imm[31:12];
				sword[11:0] = 12'b000000000000;
				nalu_result = alu_pc + sword;
				oalu_is_branch_taken=0;
				
			end
			
			`SLLIW	: // 35
			begin
				intermediate_value = src1 << alu_imm;
				sword = intermediate_value[31:0];
				nalu_result = $signed(sword);
				oalu_is_branch_taken=0;
			end			

			`SRLIW	: // 36
			begin
				intermediate_value = src1 >> alu_imm;
				sword = intermediate_value[31:0];
				nalu_result = $signed(sword);
				oalu_is_branch_taken=0;
			end

			`SRAIW	: // 37
			begin
				intermediate_value = src1 >> alu_imm;
				sword = $signed(intermediate_value[31:0]);
				nalu_result = sword;
				oalu_is_branch_taken=0;
			end
			
			`SLLW	: // 38
			begin
				intermediate_value = src1[31:0] << src2[4:0];
				sword = $signed(intermediate_value[31:0]);
				nalu_result = sword;
				oalu_is_branch_taken=0;
			end
			
			`REMW	: // 39
			begin
				signed_src1 = $signed(src1);
				signed_src2 = $signed(src2);
				intermediate_value = signed_src1 % signed_src2;
				sword = $signed(intermediate_value[31:0]);
				nalu_result = sword;
				oalu_is_branch_taken=0;
			end
			
			
			`SRLW	: // 40
			begin
				intermediate_value = src1[31:0] >> src2[4:0];
				sword = $signed(intermediate_value[31:0]);
				nalu_result = sword;
				oalu_is_branch_taken=0;
			end

			`SRAW	: // 41
			begin
				intermediate_value = src1[31:0] >> src2[4:0];
				sword = $signed(intermediate_value[31:0]);
				nalu_result = sword;
				oalu_is_branch_taken=0;
			end
			
			`REMUW	: // 42
			begin
				unsigned_src1 = $unsigned(src1);
				unsigned_src2 = $unsigned(src2);
				intermediate_value = unsigned_src1 % unsigned_src2;
				sword = intermediate_value[31:0];
				nalu_result = $signed(sword);
				oalu_is_branch_taken=0;
			end
			
			`REM	: // 43
			begin
				signed_src1 = $signed(src1);
				signed_src2 = $signed(src2);
				intermediate_value = signed_src1 % signed_src2;
				nalu_result = $signed(intermediate_value);
				oalu_is_branch_taken=0;
			end

			`REMU	: // 44
			begin
				unsigned_src1 = $unsigned(src1);
				unsigned_src2 = $unsigned(src2);
				intermediate_value = unsigned_src1 % unsigned_src2;
				nalu_result = $unsigned(intermediate_value);
				oalu_is_branch_taken=0;
			end
			
			`MULHSU	: // 45
			begin
				signed_src1 = $signed(src1);
				unsigned_src2 = $unsigned(src2);
				upper_xlen = signed_src1 * unsigned_src2;
				nalu_result = upper_xlen[127:64];
				oalu_is_branch_taken=0;
			end
			`JALR 	: // 46
			begin
				signed_imm = $signed(alu_imm[11:0]);
				intermediate_value = src1 + signed_imm;
				intermediate_value[0] = 0;
				oalu_branch_target = intermediate_value-4;
				oalu_is_branch_taken=1;
				nalu_result = alu_pc + 4;	// write this value to the register
				
			end
			
			`JAL 	: // 47
			begin
				signed_imm = $signed(alu_imm[11:0]);
				oalu_branch_target = alu_pc + signed_imm -4;
				oalu_is_branch_taken=1;
				nalu_result = alu_pc + 4;
			end
			
			`LB 	: // 48
			begin
				data_size = BYTE;
				signed_imm = $signed(alu_imm);
				nalu_result = src1 + signed_imm;	// address from where to load data
				oalu_is_branch_taken=0;
			end
			
			`LH	: // 49
			begin
				data_size = HALF_WORD;
				signed_imm = $signed(alu_imm);
				nalu_result = src1 + signed_imm;	// address from where to load data
				oalu_is_branch_taken=0;
			end
			
			`LW	: // 50
			begin
				data_size = WORD;
				signed_imm = $signed(alu_imm);
				nalu_result = src1 + signed_imm;	// address from where to load data
				oalu_is_branch_taken=0;
			end
			
			`LD : // 51
			begin
				data_size = DOUBLE_WORD;
				signed_imm = $signed(alu_imm);
				nalu_result = src1 + signed_imm;	// address from where to load data
				oalu_is_branch_taken=0;
			end
			
			`LBU : // 52
			begin
				data_size = BYTE;
				signed_imm = $signed(alu_imm);
				nalu_result = src1 + signed_imm;	// address from where to load data
				oalu_is_branch_taken=0;
			end
			
			`LHU : // 53
			begin
				data_size = HALF_WORD;
				signed_imm = $signed(alu_imm);
				nalu_result = src1 + signed_imm;	// address from where to load data
				oalu_is_branch_taken=0;
			end
			
			`LWU : // 54
			begin
				data_size = WORD;
				signed_imm = $signed(alu_imm);
				nalu_result = src1 + signed_imm;	// address from where to load data
				oalu_is_branch_taken=0;
			end
			
			`SB : // 55
			begin
				data_size = BYTE;
				signed_imm = $signed(alu_imm);
				nalu_result = src1 + signed_imm;	// address of where to store data
				nalu_result2 = src2;
				oalu_is_branch_taken=0;
			end
			
			`SH : // 56
			begin
				data_size = HALF_WORD;
				signed_imm = $signed(alu_imm);
				nalu_result = src1 + signed_imm;	// address of where to store data
				nalu_result2 = src2;
				oalu_is_branch_taken=0;
			end
			
			`SW : // 57
			begin
				data_size = WORD;
				signed_imm = $signed(alu_imm);
				nalu_result = src1 + signed_imm;	// address of where to store data
				nalu_result2 = src2;
				oalu_is_branch_taken=0;
			end
			
			`SD : // 58
			begin
				data_size = DOUBLE_WORD;
				signed_imm = $signed(alu_imm);
				nalu_result = src1 + signed_imm;	// address of where to store data
				nalu_result2 = src2;
				oalu_is_branch_taken=0;
			end
			
			`BEQ : // 59
			begin
				if (src1 == src2)	begin
					signed_imm = $signed(alu_imm[11:0]);
					oalu_branch_target = alu_pc + signed_imm -4;
					oalu_is_branch_taken=1;
				end
				else begin
					oalu_branch_target = alu_pc;
					oalu_is_branch_taken=0;
				end
			end
			
			`BNE : // 60
			begin
				if (src1 != src2)	begin
					signed_imm = $signed(alu_imm[11:0]);
					oalu_branch_target = alu_pc + signed_imm -4;
					oalu_is_branch_taken=1;
				end
				else	begin
					oalu_branch_target = alu_pc;
					oalu_is_branch_taken=0;
				end
			end
			
			`BLT : // 61
			begin
				signed_src1 = $signed(src1);
				signed_src2 = $signed(src2);
				
				if (signed_src1 < signed_src2)	begin
					signed_imm = $signed(alu_imm[11:0]);
					oalu_branch_target = alu_pc + signed_imm -4;	// address of next instruction
					oalu_is_branch_taken=1;
				end
				else	begin
					oalu_branch_target = alu_pc;
					oalu_is_branch_taken=0;
				end

			end
			
			`BGE : // 62
			begin
				signed_src1 = $signed(src1);
				signed_src2 = $signed(src2);
				
				if (signed_src1 >= signed_src2)	begin
					signed_imm = $signed(alu_imm[11:0]);
					oalu_branch_target = alu_pc + signed_imm -4;		// address of next instruction
					oalu_is_branch_taken=1;
				end
				else	begin
					oalu_branch_target = alu_pc;
					oalu_is_branch_taken=0;
				end
			
			end
			
			`BLTU : // 63
			begin
				unsigned_src1 = $unsigned(src1);
				unsigned_src2 = $unsigned(src2);
				
				if (unsigned_src1 < unsigned_src2)	begin
					signed_imm = $signed(alu_imm[11:0]);
					oalu_branch_target = alu_pc + signed_imm -4;	// address of next instruction
					oalu_is_branch_taken=1;
				end
				else	begin
					oalu_is_branch_taken=0;
					oalu_branch_target = alu_pc;
				end
			end
			
			`BGEU : // 64
			begin
				unsigned_src1 = $unsigned(src1);
				unsigned_src2 = $unsigned(src2);
				
				if (unsigned_src1 >= unsigned_src2)	begin
					signed_imm = $signed(alu_imm[11:0]);
					oalu_is_branch_taken=1;
					oalu_branch_target = alu_pc + signed_imm -4;		// address of next instruction
				end
				else	begin
					oalu_is_branch_taken=0;
					oalu_branch_target = alu_pc;
				end
			end
			`ECALL:
			begin
				oalu_is_branch_taken=0;
			end
			
			default : 	begin
				//$display("default");
				nalu_result = 0;
				oalu_is_branch_taken=0;
			end
		endcase

	end

	// EX/MEM pipeline
	always_ff @ (posedge clk) begin
		//if (alu_is_inst_valid)
			//$display("alu_pc %x", alu_pc);
		if(!alu_mem_dfme) begin
		oalu_instrux <= alu_instrux;
		oalu_pc <= alu_pc;
		oalu_is_inst_valid<=alu_is_inst_valid;
		oalu_wb_reg <= alu_write_reg_num;
		oalu_result <= nalu_result;
		oalu_result2 <= nalu_result2;
		oalu_data_size <= data_size;
		//signals
		oalu_is_inst_regwrite<=alu_is_inst_regwrite;
		oalu_is_inst_memread<=alu_is_inst_memread;
		oalu_is_inst_memwrite<=alu_is_inst_memwrite;
		oalu_is_ld_st_ecall_inst<=alu_is_ld_st_ecall_inst;
		oalu_is_ecall_inst<=alu_is_ecall_inst;
		end
		else begin
		oalu_instrux <= oalu_instrux;
		oalu_pc <= oalu_pc;
		oalu_is_inst_valid<=oalu_is_inst_valid;
		oalu_wb_reg <= oalu_wb_reg;
		oalu_result <= oalu_result;
		oalu_result2 <= oalu_result2;
		oalu_data_size <= oalu_data_size;
		//signals
		oalu_is_inst_regwrite<=oalu_is_inst_regwrite;
		oalu_is_inst_memread<=oalu_is_inst_memread;
		oalu_is_inst_memwrite<=oalu_is_inst_memwrite;
		oalu_is_ld_st_ecall_inst<=oalu_is_ld_st_ecall_inst;
		oalu_is_ecall_inst<=oalu_is_ecall_inst;
		end

		//if(alu_is_inst_valid)
		  //$display ("alu: %x %x",alu_pc, alu_instrux);

	end
	
	initial
	begin
		data_size = NA;
	end

endmodule : alu

