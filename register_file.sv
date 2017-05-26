module register_file(
        input	clk,
	input	reset,
	//from decode
        input 	[4:0] 	irf_read_reg_num0,
        input 	[4:0] 	irf_read_reg_num1,
	input   [4:0]   irf_hazchk_write_reg_num,
	input   [0:0]   irf_hazchk_write_the_register,
	//from wb
        input 	[0:0]	irf_write_the_register,
        input 	[4:0] 	irf_write_reg_num,
        input 	[63:0]	irf_write_data,
	input	[63:0]	irf_stackptr,
	input		irf_ldst_ec_stall,
	input		irf_br_stall,	

        output	[63:0]	orf_read_data0,
        output	[63:0]	orf_read_data1,
	output	[0:0]	orf_stall

);

	logic	[63:0]	register	[31:0];
	logic	[0:0]	busy		[31:0]; // indicates whether register at i is busy or not
	logic	[63:0]	nrf_read_data0; //input of ID/EX reg
	logic	[63:0]	nrf_read_data1; //--ditto---
	logic	[0:0]   ndbusy;
	logic   [0:0]   nwbusy;


	logic	[6:0]	iter;
	logic	[6:0]	niter;
	logic		irf_already_stalling;

        always_comb 
	begin
		irf_already_stalling=irf_ldst_ec_stall | irf_br_stall;
		if(irf_read_reg_num0 == 0)
			nrf_read_data0 = 0;
		else
			nrf_read_data0 = register[irf_read_reg_num0];
			
		if(irf_read_reg_num1 == 0)
			nrf_read_data1 = 0;
		else
			nrf_read_data1 = register[irf_read_reg_num1];
	end

	always_comb
	begin //assuming reg0 will never be busy
		if(!irf_already_stalling) begin
			if(!(busy[irf_read_reg_num0]) && !(busy[irf_read_reg_num1]) && !(busy[irf_hazchk_write_reg_num]))
				orf_stall=0;
			else
				orf_stall=1;
		end
		else
			orf_stall=0;
	end


	always_comb begin
		if(!orf_stall && irf_hazchk_write_the_register && irf_hazchk_write_reg_num)
		begin
			ndbusy=1;
		end
		else begin
			if ((irf_hazchk_write_reg_num == irf_write_reg_num) && irf_write_the_register)
				ndbusy=nwbusy;
			else
				ndbusy=busy[irf_hazchk_write_reg_num];
		end
			
	end

	always_comb begin
		if (irf_write_the_register)
			nwbusy=0;
		else
			nwbusy=busy[irf_write_reg_num];
	end


        always_ff @(posedge clk) begin
				// read registers are free to be read
		if (reset) begin
			register[2]<=irf_stackptr;
		end
		else begin
			orf_read_data0 <= nrf_read_data0;
			orf_read_data1 <= nrf_read_data1;

			if (!irf_already_stalling) begin
			busy[irf_hazchk_write_reg_num] <= ndbusy;
			end
			busy[irf_write_reg_num] <= nwbusy;
		
			if (irf_write_reg_num > 0)
			begin
				if (irf_write_the_register) begin
					register[irf_write_reg_num] <= irf_write_data;
				end
			// possible error dunno the behaviour of reg0 with writes
				else if (!irf_write_the_register) begin
					register[irf_write_reg_num] <= register[irf_write_reg_num];
				end
			end
			else begin
				register[irf_write_reg_num] <= register[irf_write_reg_num];
			end
		end
	end
	
	final
	begin
		foreach (register[iter]) 
		begin
			$display(">> iter %d\t%d ", iter, $signed(register[iter]));
		end
        end


	initial
	begin

		foreach (busy[iter])
		begin
			busy[iter]=0;
		end
	end

endmodule
