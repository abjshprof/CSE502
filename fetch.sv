module fetch
#(
	BUS_DATA_WIDTH = 64,
	BUS_TAG_WIDTH = 13
 )
(
 	input				clk,
 					reset,
	input	[63:0]			entry,

	//input				stall,
 	//input 			fetcher_read,

 	// interface to connect to the bus
	input				fetch_is_branch_taken,
	inout  [63:0]			fetch_next_branch_target,
	input				fetch_read_done,
	input				fetch_cache_data_valid,
	input	[63:0]			fetch_icache_instr,
	input   [0:0]			ftch_hz_stall,
	input				ftch_ldst_ec_stall,

	output				ofetch_data_req,
	output	[63:0]			ofetch_addr,
 	output	[63:0]			of_pc,
 	output	[31:0]			of_instrux,
	output  [0:0]			of_is_inst_valid
 );




  //logic [63:0] pc, npc;
  logic [63:0] nof_pc, nofetch_addr, npc, pc;

  logic [31:0] of_instrux, nof_instrux;

  logic nof_is_inst_valid, ftch_stall;

 enum {
	IDLE=3'b00,
	READING=3'b01,
	REQUESTING=3'b010,
	STALLING=3'b011,
	DO_PENDING_READ=3'b100,
	FLUSHING=3'b101
 } fstate, next_fstate;

// SHOULD IT BE INSTANTIATED IN TOP, since it can be used by both the instruction and data caches??
// module to fetch from memory begins here
// fetch_from_memory_module parameters

  always @ (posedge clk)
    if (reset) begin
      pc <= entry;
      fstate <= IDLE;
      of_instrux<=0;
      of_is_inst_valid<=0;
    end else begin
      of_instrux <= nof_instrux;
      of_pc<=nof_pc;
      of_is_inst_valid<=nof_is_inst_valid;

      fstate <= next_fstate;
      pc<=npc;
      ofetch_addr<=nofetch_addr;
	//if (pc >= 16'hcc)
		//$finish;
	end


	always_comb begin
		ftch_stall=ftch_ldst_ec_stall | ftch_hz_stall;
		case(fstate)
			IDLE: begin
				next_fstate = REQUESTING;
			end

			REQUESTING: begin
				if (fetch_is_branch_taken)
					next_fstate=FLUSHING;
				else begin
					if(!fetch_read_done) begin
						if(ftch_stall)
							next_fstate=STALLING;
						else
							next_fstate = REQUESTING;
					end
					else if (fetch_read_done) begin
						if(ftch_stall)
							next_fstate=STALLING;
						else
							next_fstate = READING;
					end
				end
			end

			READING: begin
				if (fetch_is_branch_taken)
					next_fstate=FLUSHING;
				else begin
					if (fetch_read_done) begin
						if(ftch_stall)
							next_fstate=STALLING;
						else
							next_fstate=READING;
					end
					else if (!fetch_read_done)
						if (ftch_stall)
							next_fstate=STALLING;
						else
							next_fstate=REQUESTING;
				end
			end
			STALLING: begin
				if (fetch_is_branch_taken)
					next_fstate=FLUSHING;
				else begin
					if(ftch_stall)
						next_fstate=STALLING;
					else if(!ftch_stall) begin
						if(fetch_cache_data_valid && !fetch_read_done)
							next_fstate=DO_PENDING_READ;
						else if(!fetch_cache_data_valid && !fetch_read_done)
							next_fstate=REQUESTING;
						else if (fetch_cache_data_valid && fetch_read_done)
							next_fstate=READING;
					end
				end
			end
			DO_PENDING_READ:begin
				if (fetch_is_branch_taken)
					next_fstate=FLUSHING;
				else begin
					if(ftch_stall)
						next_fstate=STALLING;
					else if(!ftch_stall) begin
						if(fetch_cache_data_valid && !fetch_read_done)
							next_fstate=DO_PENDING_READ;
						else if(!fetch_cache_data_valid && !fetch_read_done)
							next_fstate=REQUESTING;
						else if (fetch_cache_data_valid && fetch_read_done)
							next_fstate=READING;
					end
				end
			end
			FLUSHING:begin
				next_fstate=REQUESTING;
			end
		endcase
	end


	always_comb begin
		case (next_fstate)
			IDLE: begin
				ofetch_data_req=1;
				nofetch_addr=pc;
				nof_pc=of_pc;
				npc=pc;
				nof_instrux=0;
				nof_is_inst_valid=0;
			end
			READING:begin
				ofetch_data_req=1;
				nofetch_addr=npc;
				nof_pc=pc;
				npc=pc+4;
				nof_instrux=fetch_icache_instr;
				nof_is_inst_valid=1;
			end
			REQUESTING:begin
				ofetch_data_req=1;
				nofetch_addr=npc;
				nof_pc=pc;
				npc=pc;
				nof_instrux=0;
				nof_is_inst_valid=0;
			end
			STALLING:begin
				ofetch_data_req=0;
				nofetch_addr=pc;
				nof_pc=of_pc;
				npc=pc;
				nof_instrux=of_instrux;
				nof_is_inst_valid=of_is_inst_valid;
			end
			DO_PENDING_READ:begin
				ofetch_data_req=1;
				nofetch_addr=pc;
				nof_pc=pc;
				npc=pc;
				nof_instrux=fetch_icache_instr;
				nof_is_inst_valid=1;
			end
			FLUSHING: begin
				ofetch_data_req=1;
				nofetch_addr=fetch_next_branch_target;
				nof_pc=0;
				npc=fetch_next_branch_target;//not sure
				nof_instrux=0;
				nof_is_inst_valid=0;
			end
			default: begin 
				$display("Nooooo...\n");
				$finish;
			end
		endcase	
	end

initial begin
	$display("Initializing top, entry point = 0x%x", entry);
end

endmodule : fetch
