module fetch
#(
	BUS_DATA_WIDTH = 64,
	BUS_TAG_WIDTH = 13
 )
(
 	input				clk,
 					reset,
	input	[63:0]			entry,
	output	[63:0]			pc,
	
	input   [0:0]			ftch_stall,

	// input received from the instruction cache
	input	[31:0]			nof_instrux,
	input	[0:0]			nof_is_inst_valid,
	input	[0:0]			icache_hit,	// if it was a hit

 	// actual output of the pipeline
 	output	[63:0]			of_pc,
 	output	[31:0]			of_instrux,
	output  [0:0]			of_is_inst_valid
 );

logic	[63:0]	npc;

always_ff @ (posedge clk)
begin
	if (reset) begin
		pc <= entry;
		of_pc <= entry;
		of_instrux <= 0;
		of_is_inst_valid <= 0;
    
	end else begin
		if (icache_hit) begin
			if (nof_instrux == 0)
				$finish;

			of_instrux <= nof_instrux;
			pc <= npc;
			of_pc <= pc;
			of_is_inst_valid <= 1;
			$display("%x", nof_instrux);
		end
	if (of_pc >= 16'h120)
		$finish;
	end

end	

always_comb
begin
	npc = pc + 4;
end

initial begin
	$display("Initializing top, entry point = 0x%x", entry);
end

endmodule : fetch
