
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
