`include "icache.defs"
module icache
#(
	BUS_DATA_WIDTH = 64,
	BUS_TAG_WIDTH = 13
 )
(
 	input				clk,
 					reset,
	input	[63:0]			entry,
	
	input				data_read_req,
	input   [63:0]			icache_memaddr,
 	input   			icache_bus_respcyc,
 	input   			icache_bus_reqack,
 	input   [BUS_DATA_WIDTH-1:0] 	icache_bus_resp,
 	input   [BUS_TAG_WIDTH-1:0] 	icache_bus_resptag,
	input				icache_has_bus,

	output				oicache_bus_assert,
	output	[63:0]			oicache_data,
	output				nicache_read_done,
	output				oicache_data_valid,
 	output  			icache_bus_reqcyc,
 	output				icache_bus_respack,
 	output	[BUS_DATA_WIDTH-1:0]	icache_bus_req,
 	output  [BUS_TAG_WIDTH-1:0] 	icache_bus_reqtag
 );

////////////////////////////////////////////

typedef struct packed   {
	bit	[1:0]	filler;
	bit             valid;
	bit     [48:0]  tag;
        bit     [7:0] [63:0]  data;	// 8 instructions each of 32 bits
} cache_line;

typedef struct packed {
	bit        lrul;
	cache_line [1:0] line;
} cache_set;
cache_set icache[511:0];
icache_address itcache_memaddr;

//////////////////////////////////////////////////
  logic nicache_bus_reqcyc, nicache_bus_respack,nicache_data_valid, xyz;
  logic [BUS_DATA_WIDTH-1:0] nicache_bus_req;
  logic [BUS_TAG_WIDTH-1:0] nicache_bus_reqtag;

  logic [63:0] nicache_wdata, nicache_rdata;
  logic [48:0] cmp_tag, nicache_tag;
  logic [8:0]  num_set, nset;
  logic [5:0]  nicache_offset;
  logic nline, nlrul, nicache_valid, nevict_line;
  logic nicache_read_done, nicache_write_done, nicache_do_write, nicache_write_ready;
  logic nicache_bus_assert;
  logic [3:0] fill_count, nfill_count; 
  logic [63:0] ex_hword, ex_lword ,ig_hword;
   

 enum {
        IDLE=3'b00,
        REQUESTING_DATA=3'b01,
        WAITING_FOR_DATA=3'b010,
        FILLING_DATA=3'b011,
	SERVING_READ=3'b100,
	REQUESTING_BUS=3'b101
 } state, next_state;


  always @ (posedge clk)
    if (reset) begin
      state <= IDLE;
    end 
    else begin
	//$display("icache: in state %d, icache_bus_reqcyc %d nicache_bus_reqcyc %d nicache_bus_reqtag %x\n", state, icache_bus_reqcyc, nicache_bus_reqcyc, nicache_bus_reqtag);
	state<=next_state;
	icache_bus_reqcyc<=nicache_bus_reqcyc;
	icache_bus_respack<=nicache_bus_respack;
	icache_bus_req<=nicache_bus_req;
	icache_bus_reqtag<=nicache_bus_reqtag;
	oicache_bus_assert<=nicache_bus_assert;

	if(nicache_do_write) begin
		icache[nset].line[nline].data[nicache_offset]<=nicache_wdata;
		icache[nset].line[nline].tag<=nicache_tag;
		icache[nset].line[nline].valid<=nicache_valid;
		icache[nset].lrul<=nlrul;
	end
	//will there be an else
	oicache_data<=nicache_rdata;
	oicache_data_valid<=nicache_data_valid;
	//oicache_read_done<=nicache_read_done;
	fill_count<=nfill_count;
    end


/////////////////////////////

			//		DEFINE NSET EVERYWHERE!!!
				///exword bug
				//ig_hword bug


///////////////////////////

	always_comb begin
		itcache_memaddr=icache_memaddr;
		ex_lword=64'h00000000ffffffff;
		ex_hword=64'hffffffff00000000;
		ig_hword=64'hffffffffffffffc0;
		case(state)
			IDLE: begin
				if((data_read_req)) begin
					cmp_tag=itcache_memaddr.tag;
					num_set=itcache_memaddr.num_set;
					nevict_line=icache[num_set].lrul; //this will be evicted
					if ((icache[num_set].line[0].tag == cmp_tag) && icache[num_set].line[0].valid) begin
						nline=0;
						next_state = SERVING_READ;
					end
					else if ((icache[num_set].line[1].tag == cmp_tag) && icache[num_set].line[1].valid) begin
						nline=1;
						next_state = SERVING_READ;
					end
					else begin//at what pt. to mark this line as invalid
						if (icache_has_bus)
							next_state = REQUESTING_DATA;
						else
							next_state = REQUESTING_BUS;
					end
				end
				else
					next_state=IDLE;
			end
			REQUESTING_DATA: begin
					if(!icache_has_bus)
						next_state = REQUESTING_BUS;
					else begin 
						if (icache_bus_reqack)
							next_state = WAITING_FOR_DATA;
						else if (!icache_bus_reqack)
							next_state = REQUESTING_DATA;
					end
			end
			WAITING_FOR_DATA: begin
					if (!icache_has_bus)
						next_state = REQUESTING_BUS;
					else begin
						if(!icache_bus_respcyc)
							next_state=WAITING_FOR_DATA;
						else
							next_state=FILLING_DATA;
					end
			end
			FILLING_DATA: begin// is there any way to get the addr of the data
					if (!icache_has_bus)
						next_state = REQUESTING_BUS;
					else begin
						if(icache_bus_respcyc) begin
							if(fill_count <8)
								next_state=FILLING_DATA;
							else begin
								nicache_bus_assert=0; //just filled the data, so yield
								next_state=IDLE;//not sure, idea is to serve read/write asap
							end
						end
					end
			end
			SERVING_READ: begin
						if(data_read_req) begin
							if ((icache[itcache_memaddr.num_set].line[0].tag == itcache_memaddr.tag)								   && icache[itcache_memaddr.num_set].line[0].valid) begin
								nicache_bus_assert=0;
								next_state=SERVING_READ;
							end
							else if ((icache[itcache_memaddr.num_set].line[1].tag == itcache_memaddr.tag) 								   && icache[itcache_memaddr.num_set].line[1].valid) begin
								nicache_bus_assert=0;
								next_state=SERVING_READ;
							end
							else
								next_state=IDLE;
						end
						else if(!data_read_req)
							next_state=IDLE;
			end
			REQUESTING_BUS: begin
				if (!icache_has_bus)
					next_state = REQUESTING_BUS;
				else
					next_state = IDLE;
			end
			default: begin 
				$display("Nooooo...\n");
				$finish;
			end
		endcase	
	end


	always_comb begin
		itcache_memaddr=icache_memaddr;	
		case(next_state)
			IDLE: begin
				nicache_bus_reqcyc=0;
				nicache_bus_respack=0;
				nicache_read_done=0;
				nicache_do_write=0;
				nfill_count=0;
				if(!data_read_req)begin
					nicache_rdata=oicache_data;
					nicache_data_valid=oicache_data_valid;
				end
				else begin
					 nicache_rdata=0;
					 nicache_data_valid=0;
				end
			end
			REQUESTING_DATA: begin
				nicache_bus_reqcyc=1;
				nicache_bus_respack=0;
				nicache_bus_req = (itcache_memaddr & ig_hword); //hoping the correct address has appeared
				nicache_bus_reqtag = `SYSBUS_READ << 12 | `SYSBUS_MEMORY << 8;
				nicache_read_done=0;
				nicache_do_write=0;
				nfill_count=0;
				if(!data_read_req) begin
					nicache_rdata=oicache_data;
					nicache_data_valid=oicache_data_valid;
				end
				else begin 
					 nicache_rdata=0;
					 nicache_data_valid=0;
				end
			end
			WAITING_FOR_DATA: begin
				nicache_bus_reqcyc=0;
				nicache_bus_respack=0;
				nicache_read_done=0;
				nicache_write_done=0;
				nicache_do_write=0;
				nfill_count=0;
				if(!data_read_req)begin
					nicache_rdata=oicache_data;
					nicache_data_valid=oicache_data_valid;
				end
				else begin
					 nicache_rdata=0;
					 nicache_data_valid=0;
				end
				
			end
			FILLING_DATA: begin //from mem into icache
				nicache_bus_reqcyc=0;
				nicache_bus_respack=1;
				nicache_read_done=0;
				nicache_write_done=0;
				nicache_tag=itcache_memaddr.tag;
				nline=icache[itcache_memaddr.num_set].lrul;
				nicache_offset=fill_count;
				nset=itcache_memaddr.num_set;
				nicache_wdata=icache_bus_resp[63:0];
				nfill_count=fill_count+1;
				if(nfill_count <8) begin
					nicache_valid=0;
					nlrul=icache[itcache_memaddr.num_set].lrul;
				end
				else begin
					nicache_valid=1;
					nlrul=~nline;
				end
				nicache_do_write=1;
				if(!data_read_req) begin
					nicache_data_valid=oicache_data_valid;
					nicache_rdata=oicache_data;
				end
				else begin
					 nicache_rdata=0;
					 nicache_data_valid=0;
				end
			end
			SERVING_READ: begin
				if ((icache[itcache_memaddr.num_set].line[0].tag == itcache_memaddr.tag) && icache[itcache_memaddr.num_set].line[0].valid) begin
					nline=0;
				end
				else if ((icache[itcache_memaddr.num_set].line[1].tag == itcache_memaddr.tag) && icache[itcache_memaddr.num_set].line[1].valid) begin
					nline=1;
				end
				nicache_bus_reqcyc=0;
				nicache_bus_respack=0;
				nset=itcache_memaddr.num_set;
				nicache_offset=itcache_memaddr.offset[5:3];
				nicache_read_done=1;
				nicache_write_done=0;
				nicache_do_write=1;
				nlrul=~nline;
				nicache_data_valid=1;
				nicache_valid=icache[nset].line[nline].valid;
				nicache_wdata=icache[nset].line[nline].data[nicache_offset];
				//nline=//needed;
				if(itcache_memaddr.offset[2])
				nicache_rdata=(icache[nset].line[nline].data[nicache_offset] & ex_hword) >> 16'd32;
				else
				nicache_rdata=icache[nset].line[nline].data[nicache_offset] & ex_lword;
				nfill_count=0;
			end
			REQUESTING_BUS: begin
				nicache_bus_assert=1;
				if(!data_read_req) begin
					nicache_data_valid=oicache_data_valid;
					nicache_rdata=oicache_data;
				end
				else begin
					 nicache_rdata=0;
					 nicache_data_valid=0;
				end
			end
		endcase	
	end	


  initial begin
    $display("Initializing top, entry point = 0x%x", entry);
  end
endmodule
