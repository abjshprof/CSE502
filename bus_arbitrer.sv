
module bus_arbitrer
#(
	BUS_DATA_WIDTH = 64,
	BUS_TAG_WIDTH = 13
 )

(
 	input				clk,
 					reset,
	input	[63:0]			entry,
	
	input				ba_icache_assert_bus,
	input				ba_dcache_assert_bus,

 	input   			ba_bus_respcyc,
 	input   			ba_bus_reqack,
 	input   [BUS_DATA_WIDTH-1:0] 	ba_bus_resp,
 	input   [BUS_TAG_WIDTH-1:0] 	ba_bus_resptag,

 	output  			ba_bus_reqcyc,
 	output				ba_bus_respack,
 	output	[BUS_DATA_WIDTH-1:0]	ba_bus_req,
 	output  [BUS_TAG_WIDTH-1:0] 	ba_bus_reqtag,


 	output   			ba_ic_bus_respcyc,
 	output   			ba_ic_bus_reqack,
 	output   [BUS_DATA_WIDTH-1:0] 	ba_ic_bus_resp,
 	output   [BUS_TAG_WIDTH-1:0] 	ba_ic_bus_resptag,

 	input	  			ba_ic_bus_reqcyc,
 	input				ba_ic_bus_respack,
 	input	[BUS_DATA_WIDTH-1:0]	ba_ic_bus_req,
 	input   [BUS_TAG_WIDTH-1:0] 	ba_ic_bus_reqtag,


 	output   			ba_dc_bus_respcyc,
 	output   			ba_dc_bus_reqack,
 	output   [BUS_DATA_WIDTH-1:0] 	ba_dc_bus_resp,
 	output   [BUS_TAG_WIDTH-1:0] 	ba_dc_bus_resptag,

 	input	  			ba_dc_bus_reqcyc,
 	input				ba_dc_bus_respack,
 	input	[BUS_DATA_WIDTH-1:0]	ba_dc_bus_req,
 	input  [BUS_TAG_WIDTH-1:0] 	ba_dc_bus_reqtag,

	output				oba_icache_has_bus,
	output				oba_dcache_has_bus
 );


 enum {
	IDLE=2'b00,
	ICACHE_HAS_BUS=2'b01,
	DCACHE_HAS_BUS= 2'b10
 } state, next_state;

enum {
	DCACHE=1'b0,
	ICACHE=1'b1
}last_bus_holder, nlast_bus_holder;

  always @ (posedge clk)
    if (reset) begin
	state<=IDLE;
	last_bus_holder <= DCACHE;
    end 
    else begin
	state<=next_state;
	last_bus_holder <= nlast_bus_holder;
	//$display("BA: In state %d and ba_bus_reqcyc %d oba_dcache_has_bus %d oba_icache_has_bus %d\n", state, ba_bus_reqcyc, oba_dcache_has_bus, oba_icache_has_bus);
    end

	always_comb begin
		case (state)
			IDLE: begin
				if(ba_icache_assert_bus && ba_dcache_assert_bus) begin//prefernce to icache
					if(last_bus_holder == ICACHE)
						next_state=DCACHE_HAS_BUS;
					else
						next_state=ICACHE_HAS_BUS;
				end
				else if (!ba_icache_assert_bus && ba_dcache_assert_bus)
					next_state=DCACHE_HAS_BUS;
				else if (ba_icache_assert_bus && !ba_dcache_assert_bus)
					next_state=ICACHE_HAS_BUS;
				else
					next_state=IDLE;
			end
			ICACHE_HAS_BUS:begin
				if(ba_icache_assert_bus && ba_dcache_assert_bus)
					next_state=ICACHE_HAS_BUS;
				else if (!ba_icache_assert_bus && ba_dcache_assert_bus)
					next_state=DCACHE_HAS_BUS;
				else if (ba_icache_assert_bus && !ba_dcache_assert_bus)
					next_state=ICACHE_HAS_BUS;
				else
					next_state=IDLE;
			end
			DCACHE_HAS_BUS:begin
				if(ba_icache_assert_bus && ba_dcache_assert_bus)
					next_state=DCACHE_HAS_BUS;
				else if (!ba_icache_assert_bus && ba_dcache_assert_bus)
					next_state=DCACHE_HAS_BUS;
				else if (ba_icache_assert_bus && !ba_dcache_assert_bus)
					next_state=ICACHE_HAS_BUS;
				else
					next_state=IDLE;
			end
		endcase
	end

	always_comb begin
		case(next_state)
			ICACHE_HAS_BUS:begin
				oba_icache_has_bus=1;
				oba_dcache_has_bus=0;
				nlast_bus_holder=ICACHE;
			end
			DCACHE_HAS_BUS: begin
				oba_dcache_has_bus=1;
				oba_icache_has_bus=0;
				nlast_bus_holder=DCACHE;
			end
			IDLE: begin
				oba_icache_has_bus=0;
				oba_dcache_has_bus=0;
				nlast_bus_holder=last_bus_holder;
			end
		endcase
	end

	always_comb begin
		if (oba_icache_has_bus)begin
 	   		ba_ic_bus_respcyc=ba_bus_respcyc;
 	   		ba_ic_bus_reqack = ba_bus_reqack;
 	 		ba_ic_bus_resp = ba_bus_resp;
 	 		ba_ic_bus_resptag = ba_bus_resptag;

 		  	ba_bus_reqcyc=ba_ic_bus_reqcyc;
 			ba_bus_respack=ba_ic_bus_respack;
 			ba_bus_req= ba_ic_bus_req;
 		  	ba_bus_reqtag= ba_ic_bus_reqtag;
		end
		else if (oba_dcache_has_bus) begin
 	   		ba_dc_bus_respcyc=ba_bus_respcyc;
 	   		ba_dc_bus_reqack = ba_bus_reqack;
 	 		ba_dc_bus_resp = ba_bus_resp;
 	 		ba_dc_bus_resptag = ba_bus_resptag;

 		  	ba_bus_reqcyc=ba_dc_bus_reqcyc;
 			ba_bus_respack=ba_dc_bus_respack;
 			ba_bus_req= ba_dc_bus_req;
 		  	ba_bus_reqtag= ba_dc_bus_reqtag;
		end
		else begin
 		  	ba_bus_reqcyc=0;
 			ba_bus_respack=0;
 			ba_bus_req= 0;
 		  	ba_bus_reqtag= 0;
		end
	end

endmodule
