module register_file(
        input	clk,
	//input		fetcher_ready,
        input 	[4:0] 	irf_read_reg_num0,
        input 	[4:0] 	irf_read_reg_num1,
        input 		irf_write_the_register,
        input 	[4:0] 	irf_write_reg_num,
        input 	[63:0]	irf_write_data,

        output	[63:0]	orf_read_data0,
        output	[63:0]	orf_read_data1
	//output		stall

);

	/*local vars*/
	logic	[63:0]	register	[31:0];
	logic	[0:0]	busy		[31:0]; // indicates whether register at i is busy or not
	logic	[6:0]	iter;
	logic	[6:0]	niter;

	logic	[63:0]	nrf_read_data0;
	logic	[63:0]	nrf_read_data1;

        always_comb 
	begin
	
		if(irf_read_reg_num0 == 0)
			nrf_read_data0 = 0;
		else
			nrf_read_data0 = register[irf_read_reg_num0]; //type casting
			
		if(irf_read_reg_num1 == 0)
			nrf_read_data1 = 0;
		else
			nrf_read_data1 = register[irf_read_reg_num1];
	end

        always_ff @(posedge clk) begin
                //$display("in register, %x , %x and rf_is_reg_write", irf_write_reg_num, register[irf_write_reg_num], irf_write_the_register);
		/*
		if (fetcher_ready) 
		begin
				
			if (busy[rf_read_reg_num0] || busy[rf_read_reg_num1] || busy[write_reg_num])
			begin
				// either of the read or write registers are being written
				stall <= 1; // stall the pipeline
			end
			
			else
			begin
		*/
				// read registers are free to be read
				orf_read_data0 <= nrf_read_data0;
				orf_read_data1 <= nrf_read_data1;
				busy[irf_write_reg_num] <= 1;
			//end
		//end	
		
		if (irf_write_the_register)	
		begin
			if (irf_write_reg_num > 0) begin
				register[irf_write_reg_num] <= irf_write_data;
				busy[irf_write_reg_num] <= 0;
			end
			//stall <= 0; // remove stall after writing the register
		end
	end
	
	final
	begin
		foreach (register[iter]) 
		begin
			$display(">> iter %d\t%d ", iter, $signed(register[iter]));
		end
        end



endmodule
