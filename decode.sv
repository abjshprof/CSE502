`include "operation.defs"
`include "instruction_types.sv"

module decode
(
	input   clk,
	input	[31:0]	dc_instrux,
	input	[63:0]	dc_pc,
	input   [0:0]   dc_is_inst_valid,
	input   [0:0]   dc_stall,
	input		dc_undo_ldst_ec_stall,

	output		odc_ldst_ec_stall,
	output  [31:0]  odc_instrux,
	output	[63:0]  od_pc,
	output  [0:0]   od_is_inst_valid,

	output	[4:0]	od_nread_reg0_num,
	output	[4:0]	od_nread_reg1_num,
	output  [4:0]   od_nwrite_reg_num,
	output  [0:0]   od_nis_inst_regwrite, 
	output	[4:0]	od_write_reg_num,
	output	[63:0]	od_imm,
	output  [10:0]	od_operation,
	
	output	[0:0]	od_is_inst_regwrite,
	output  [0:0]   od_is_inst_memread,
	output  [0:0]   od_is_inst_memwrite,
	output		od_is_ld_st_ecall_inst,
	output		odc_is_ecall_inst
);

//// ======ALL DECLARATIONS========

//jalr and loads
//maybe addi
/******************
HANDLE SIGN EXTENDED IMMEDIATEs
****************/
        always_ff @ (posedge clk) begin
		//$display ("decode: %x %x\n", dc_pc, dc_instrux);
		//if(dc_is_inst_valid)
		 //$display ("decode: %x %x",dc_pc, dc_instrux);
        end


	logic [6:0] nopcode;
	logic [4:0] nwrite_reg;
	logic [63:0] nimm;
	logic [10:0] noperation;
	logic [0:0] nis_inst_regwrite, nldst_ec_stall, nis_ld_st_ecall_inst;
	logic [0:0] nis_inst_memread, nodc_is_ecall_inst;
	logic [0:0] nis_inst_memwrite;		

	
	bit signed [11:0] offset;
	bit signed [19:0] offset_jali;
	bit signed [32:0] pcs;

	generic_instr instr=dc_instrux;
	load_instr loadi;
	arith_instr arithi;
	shmt_instr1 shmt1i;
	shmt_instr2 shmt2i;
	jal_instr jali;
	store_instr storei;
	load_instr_imm loadimmi;
	branch_instr bri;


///-----------------------------------------------------------

	always_comb begin
	generic_instr instr=dc_instrux;
	nopcode = dc_instrux[6:0];
	case(instr.opcode)
		7'h13: begin //6..2=0x04 . addi, xori, ori, andi or slli, srli, srai
			//@@loadi	 SEXT MAY BE NEEDED	
			nodc_is_ecall_inst=0;
			od_nread_reg0_num = dc_instrux[19:15];
			od_nread_reg1_num = 0;
			od_nwrite_reg_num = dc_instrux[11:7];

			nis_inst_regwrite = 1;
			nis_inst_memread=0;
			nis_inst_memwrite=0;
			nwrite_reg = dc_instrux[11:7];
			nldst_ec_stall=0;

			case (instr[14:12])
				3'h1: begin
				nimm = dc_instrux[25:20];
				noperation = `SLLI;
				end
				
				3'h5: begin
				case (instr[31:26])
					//shmt1
					6'h0: begin
					nimm = dc_instrux[25:20];
					noperation = `SRLI;
					end
					
					6'h10: begin
					nimm = dc_instrux[25:20];
					noperation = `SRAI;
					end
				endcase
				
				end
				
				3'h0: begin
				//loadi
				nimm = dc_instrux[31:20];
				noperation=`ADDI;
				end
				
				3'h2: begin
				nimm = dc_instrux[31:20];
				noperation = `SLTI;
				end
				3'h3: begin
				//NOTE that SLTIU compares the numbers as unsigned nums
				nimm = dc_instrux[31:20];
				noperation = `SLTIU;
				end

				3'h4: begin
				nimm = dc_instrux[31:20];
				noperation = `XORI;
				end
				3'h6: begin
				nimm = dc_instrux[31:20];
				noperation = `ORI;
				end
				3'h7: begin
				nimm = dc_instrux[31:20];
				noperation = `ANDI;
				end
				
				default:  begin end
			endcase
		end

		7'h67: begin  //jalr 6..2=0x19
			//============ADD THE FREAKING PC=============				//Possible error: is this of type load
			nodc_is_ecall_inst=0;
			case(instr[14:12])
				3'h0: begin
				nldst_ec_stall=0;
				noperation = `JALR;
				od_nread_reg0_num = dc_instrux[19:15];
				od_nread_reg1_num = 0;
				od_nwrite_reg_num = dc_instrux[11:7];

				nis_inst_regwrite = 1;
				nis_inst_memread=0;
				nis_inst_memwrite=0;
				nimm=dc_instrux[31:20];
				nwrite_reg = dc_instrux[11:7];
				end	
				default:  begin end
			endcase
		end

		7'h6f:begin //jal 6..2=0x1b sext needed NOTE: Offset is in multiple of 2
			//============ADD THE FREAKING PC AND SEXT. NOTE: CHECK IF cCONCAT WORKS AND ADD PC
			//temp:$display("\njal: instr[14:12]   %x\n\n", instr[14:12]);
			//jali=instr;
			//offset_jali={jali.imm_20b, jali.imm_19t12b, jali.imm_11b, jali.imm_10t1b};

			//jali=instr; tricky, very possible erro
			//offset is jali.rd, pcs + 2*offset_jali
			nldst_ec_stall=0;
			nodc_is_ecall_inst=0;
			noperation = `JAL;
			od_nread_reg0_num = 0;
			od_nread_reg1_num = 0;
			od_nwrite_reg_num = dc_instrux[11:7];
			nis_inst_regwrite = 1;
			nis_inst_memread=0;
			nis_inst_memwrite=0;
			nimm={dc_instrux[31:31], dc_instrux[19:12], dc_instrux[20:20], dc_instrux[30:21]}*2;

			nwrite_reg = dc_instrux[11:7];
			offset_jali = {dc_instrux[31:31], dc_instrux[19:12], dc_instrux[20:20], dc_instrux[30:21]};
			//pcs=pc_value;
		end
		
		
		7'h33:begin
			nldst_ec_stall=0;
			nodc_is_ecall_inst=0;
			od_nread_reg0_num = dc_instrux[19:15];
			od_nread_reg1_num = dc_instrux[24:20];
			od_nwrite_reg_num = dc_instrux[11:7];
			nis_inst_regwrite = 1;
			nis_inst_memread=0;
			nis_inst_memwrite=0;
			nimm=0;
			nwrite_reg = dc_instrux[11:7];

			//arithi
			case(instr[14:12])
				3'h0: begin
					case(instr[31:25])
						7'h0: begin
						noperation = `ADD;
						end
						
						7'h1: begin
						noperation = `MUL;
						end
	
						7'h20: begin
						noperation = `SUB;
						end
					endcase
				end

				3'h1: begin // bits [14:12] = 1
					//arithi
					case (instr[31:25])
						7'h0: begin // bits [31:25] = 0
							noperation = `SLL;
						end	

						7'h1: begin
							noperation = `MULH;
						end

					endcase

				end
				
				3'h2: begin // bits [14:12] = 2
				
					case (instr[31:25])
						7'h0: begin
							noperation = `SLT;
						end							
						7'h1: begin
							noperation = `MULHSU;
						end
					endcase
				end
				
				3'h3: begin // bits [14:12] = 3
					//arithi
					case (instr[31:25])
						7'h0: begin 
							noperation = `SLTU;
						end

						7'h1: begin
							noperation = `MULHU;
							
						end
					endcase
				end
				
				3'h4: begin
					//arithi
					case (instr [31:25])
						7'h0: begin
							noperation = `XOR;
						end
						
						7'h1: begin
							noperation = `DIV;
						end

					endcase
				end
				3'h5:begin
					//arithi
					case(instr[31:25])
						7'h0: begin
						noperation = `SRL;
						end
						
						7'h1: begin
							noperation = `DIVU;
						
						end

						7'h20: begin
						noperation = `SRA;
						end
					endcase		
				end
				
				3'h6: begin
					//arithi
					case (instr [31:25])
						7'h0: begin
							noperation = `OR;
						end

						7'h1: begin			
							noperation = `REM;
						end
					endcase
				end
				
				3'h7: begin
					//addi
					case (instr [31:25])
						7'h0: begin
							noperation = `AND;
						end
					
						7'h1: begin
							noperation = `REMU;
						end
					endcase
				end
			default:  begin end
			endcase
		end
	

		7'h3: begin //6..2=0x00 , lw   a4,-32(s0) has imm12; lw rd, (sext.imm12)(rs1)
			nldst_ec_stall=1;
			nodc_is_ecall_inst=0;
			od_nread_reg0_num = dc_instrux[19:15];
			od_nread_reg1_num = 0;
			od_nwrite_reg_num = dc_instrux[11:7];
			nis_inst_regwrite = 1;
			nis_inst_memread=1;
			nis_inst_memwrite=0;
			nimm=dc_instrux[31:20];
			nwrite_reg = dc_instrux[11:7];

			case (instr[14:12])
				//loadi
				3'h0: begin 
					noperation = `LB;
				end
				3'h1: begin
					noperation = `LH; 
				end
				3'h2: begin 
					noperation = `LW;
				end
				3'h3: begin 
					noperation = `LD;
				end
				3'h4: begin 
					noperation = `LBU;
				end
				3'h5: begin
					noperation = `LHU; 
				end
				3'h6: begin 
					noperation = `LWU;
				end
				default: begin end
			endcase	
		end

		7'h23: begin //6..2=0x08 , sb ,sh, sw, sd  has imm;  sw rs2, imm(rs1)
			nldst_ec_stall=1;
			nodc_is_ecall_inst=0;
			od_nread_reg0_num = dc_instrux[19:15];
			od_nread_reg1_num = dc_instrux[24:20];
			od_nwrite_reg_num = 0;
			nis_inst_regwrite = 0;
			nis_inst_memread=0;
			nis_inst_memwrite=1;
			nimm={dc_instrux[31:25],dc_instrux[11:7]};
			nwrite_reg = 0;

			offset = {dc_instrux[31:25],dc_instrux[11:7]};
			//$display ("STORE NOT IMPLEMENTED");
			//$finish;
			case (instr[14:12])
				//storei
				3'h0: begin
					noperation = `SB;
				end
				3'h1: begin 
					noperation = `SH;
				end
				3'h2: begin 
					noperation = `SW;
				end
				3'h3: begin 
					noperation = `SD;
				end
				default: begin end
			endcase
		end

		7'h37: begin //6..2=0x0D lui; has imm; lui     a5,0x2
			//loadimmi, possible error what does it mean
			nldst_ec_stall=0;
			nodc_is_ecall_inst=0;
			od_nread_reg0_num = 0;
			od_nread_reg1_num = 0;
			od_nwrite_reg_num = dc_instrux[11:7];
			nis_inst_regwrite = 1;
			nis_inst_memread=0;
			nis_inst_memwrite=0;
			nimm=dc_instrux[31:12];
			nwrite_reg = dc_instrux[11:7];
			noperation = `LUI;
		end

		7'h17: begin //6..2=0x05 auipc; has imm;  auipc   t1,0x0
			//loadimmi
			nldst_ec_stall=0;
			nodc_is_ecall_inst=0;
			od_nread_reg0_num = 0;
			od_nread_reg1_num = 0;
			od_nwrite_reg_num = dc_instrux[11:7];
			nis_inst_regwrite = 1;
			nis_inst_memread=0;
			nis_inst_memwrite=0;
			nimm=dc_instrux[31:12];
			nwrite_reg = dc_instrux[11:7];
			noperation = `AUIPC;	
		end

		//Sext needed in addiw
		7'h1b: begin //6..2=0x06 sliw, srlw, sraiw; slliw   a5,a5,0x2; has shamt; not sure about ordering - mayb slliw rd, rs1, shamtw
			//both loadi and shmt2i
			nldst_ec_stall=0;
			nodc_is_ecall_inst=0;
			case(instr[14:12]) //QUERY: SHOULD WE DO THIS
				3'h0:begin

					od_nread_reg0_num = dc_instrux[19:15];
					od_nread_reg1_num = 0;
					od_nwrite_reg_num = dc_instrux[11:7];
					nis_inst_regwrite = 1;
					nis_inst_memread=0;
					nis_inst_memwrite=0;
					nimm=dc_instrux[31:20];
					nwrite_reg = dc_instrux[11:7];
					//loadi=instr;
					noperation = `ADDIW;
				end
				3'h1: begin
					//shmt2i

					od_nread_reg0_num = dc_instrux[19:15];
					od_nread_reg1_num = 0;
					od_nwrite_reg_num = dc_instrux[11:7];
					nis_inst_regwrite = 1;
					nis_inst_memread=0;
					nis_inst_memwrite=0;
					nimm=dc_instrux[24:20];
					nwrite_reg = dc_instrux[11:7];
					noperation = `SLLIW;
				end
				3'h5: begin
					//shmt2i.rd


					od_nread_reg0_num = dc_instrux[19:15];
					od_nread_reg1_num = 0;
					od_nwrite_reg_num = dc_instrux[11:7];
					nis_inst_regwrite = 1;
					nis_inst_memread=0;
					nis_inst_memwrite=0;
					nimm=dc_instrux[24:20];
					nwrite_reg = dc_instrux[11:7];
					case(instr[31:25])
						7'h0: begin
						noperation = `SRLIW;
						end
						
						7'h20: begin
						noperation = `SRAIW;
						end
					endcase
				end
				default: begin end
				//$display("323: 7'h1b NOT FOUND\n");
			endcase	
		end

		7'h3b: begin  //6..2=0x0E assw, subw, sllw, srlw, sraw , format: addw rd, rs1, rs2
			nodc_is_ecall_inst=0;
			nldst_ec_stall=0;
			od_nread_reg0_num = dc_instrux[19:15];
			od_nread_reg1_num = dc_instrux[24:20];
			od_nwrite_reg_num = dc_instrux[11:7];
			nis_inst_regwrite = 1;
			nis_inst_memread=0;
			nis_inst_memwrite=0;
			nimm=0;
			nwrite_reg = dc_instrux[11:7];

			case(instr[14:12])
				//arithi
				3'h0: begin
					case(instr[31:25]) //QUERY: SHOULD WE DO THIS or access bits of arithi
						7'h0: begin
						noperation = `ADDW;
						end
						
						7'h20: begin
						noperation = `SUBW;
						end
						
						7'h1: begin
						noperation = `MULW;
						end
					endcase
				end
				//arithi
				3'h1: begin
				noperation = `SLLW;
				end
				3'h4: begin
				noperation = `DIVW;
				end
				3'h6: begin
				noperation = `REMW;
				end
				
				3'h7: begin
				noperation = `REMUW;
				end
				3'h5: begin
					//arithi
					case(instr[31:25]) //QUERY: SHOULD WE DO THIS or access bits of arithi
						7'h0: begin
						noperation = `SRLW;
						end
						
						7'h20: begin
						noperation = `SRAW;
						end

						7'h1: begin
						noperation = `DIVW;
						end
					endcase
				end
				3'h7: begin
				//arithi
				noperation = `REMUW;
				end

				default: begin end
			endcase

		end

		//TBD: NEED SEXT NOTE: Offset is in multiples of 2
		7'h63:  begin// 6..2=0x18  sext is needed; beq, bne,blt..; blt     a4,a5,0xd4; format blt rs1, rs2, imm 
			//Possible error
			nldst_ec_stall=0;
			nodc_is_ecall_inst=0;
			od_nread_reg0_num = dc_instrux[19:15];
			od_nread_reg1_num = dc_instrux[24:20];
			od_nwrite_reg_num = 0;
			nis_inst_regwrite = 0;
			nis_inst_memread=0;
			nis_inst_memwrite=0;
			nimm={dc_instrux[31:31], dc_instrux[7:7],dc_instrux[30:25],dc_instrux[11:8]};
			nwrite_reg = 0;

			offset = {dc_instrux[31:31], dc_instrux[7:7], dc_instrux[30:25],dc_instrux[11:8]};
			//pcs = pc_value;
			$display("BRANCH NOT IMPLEMENTED\n");
			$finish;
			case(instr[14:12])
				3'h0: begin
					noperation = `BEQ;
				end
				3'h1: begin
					noperation = `BNE;
				end

			// ===========NOTE: ADD THE FREAKING PC  BLTU DOES UNSIGNED COMP,=================

				3'h4: begin
					noperation = `BLT;
				end
				3'h5: begin 	
					noperation = `BGE;
				end
				3'h6: begin 
					noperation = `BLTU;
				end
				3'h7: begin 
					noperation = `BGEU;
				end
				default: begin end
			endcase
		/*
		'h73:	begin
			//implementation of ecall
		end
		*/
		end
		7'h73: begin
			nodc_is_ecall_inst=1;
			nldst_ec_stall=1;
			od_nread_reg0_num = 0;
			od_nread_reg1_num = 0;
			od_nwrite_reg_num = 0;
			nis_inst_regwrite = 0;
			nis_inst_memread=0;
			nis_inst_memwrite=0;
			nimm=0;
			nwrite_reg = 0;
			noperation = `ECALL;
		end
 
		default:  begin
			nldst_ec_stall=0;
			nopcode = 0;
			od_nread_reg0_num = 0;
			od_nread_reg1_num = 0;
			od_nwrite_reg_num=0;
			nwrite_reg = 0;
			noperation = 0;
			nimm = 0;
			nis_inst_regwrite = 0;
			nis_inst_memwrite=0;
			nis_inst_memread=0;
			nldst_ec_stall=0;
		end

		
	endcase //decode_blk
	
	end //always_comb


	always_comb begin //hazard error?
		od_nis_inst_regwrite = nis_inst_regwrite;
	end

	always_ff @ (posedge clk)
	begin
		if (dc_instrux) begin
			$display("decode: %x %x",dc_pc, dc_instrux);
			//if (!dc_stall)
			//$display("decode: %x %x", dc_pc, dc_instrux);
			//else
			//$display("Decode: Stall at %x %x", dc_pc, dc_instrux);
		end
		if (!dc_stall  && !odc_ldst_ec_stall) begin
			odc_is_ecall_inst<=nodc_is_ecall_inst;
			od_is_inst_valid<=dc_is_inst_valid;
			od_pc <= dc_pc;
			odc_instrux<= dc_instrux;
			od_write_reg_num <= nwrite_reg;
			od_imm <= nimm;
			od_operation <= noperation;
			od_is_inst_regwrite<= nis_inst_regwrite;
			od_is_inst_memread<=nis_inst_memread;
	        	od_is_inst_memwrite<=nis_inst_memwrite;
			odc_ldst_ec_stall<=nldst_ec_stall;
			od_is_ld_st_ecall_inst<=nldst_ec_stall;
		end	
		else if (dc_stall || odc_ldst_ec_stall)
		begin
			od_is_inst_valid<=0;
			odc_is_ecall_inst<=0;
			od_pc<=32'h0;
			odc_instrux<=0;
			od_write_reg_num <= 0;
			od_imm <= 0;
			od_operation <= 0;
			od_is_inst_regwrite<= 0;
			od_is_inst_memread<=0;
	        	od_is_inst_memwrite<=0;
			od_is_ld_st_ecall_inst<=0;
			if (dc_undo_ldst_ec_stall)
				odc_ldst_ec_stall<=0;
			else
				odc_ldst_ec_stall<=odc_ldst_ec_stall;
		end
	end

	initial 
	begin
		od_write_reg_num = 0;
		od_operation = 0;
		od_imm = 0;
		od_is_inst_regwrite = 0;
	end

endmodule : decoder
