//cache is not affected by stalls
//caches need to support invalidations
//should cache send a reqack after which core sets transact_req to zero.

//define all ops in everything., e.g. nset
`include "dcache.defs"
module dcache
#(
	BUS_DATA_WIDTH = 64,
	BUS_TAG_WIDTH = 13
 )
(
 	input				clk,
 					reset,
	input	[63:0]			entry,

	input				dcache_has_bus,	
	input				dc_data_read_req,//cont
	input				dc_data_write_req,//cont
	input	[63:0]			dcache_memiaddr, //cont
	input	[63:0]			dcache_memidata, //cont
	input   [2:0]			dcache_data_size,
 	input   			dcache_bus_respcyc,
 	input   			dcache_bus_reqack,
 	input   [BUS_DATA_WIDTH-1:0] 	dcache_bus_resp,
 	input   [BUS_TAG_WIDTH-1:0] 	dcache_bus_resptag,

	output	[63:0]			nodcache_rdata,
	output				nodcache_read_done,
	//output				odcache_write_ready,//data wll appear on memibus after this is set.
	output				nodcache_write_done,
	output                          odcache_bus_assert,
 	output  			odcache_bus_reqcyc,
 	output				odcache_bus_respack,
 	output	[BUS_DATA_WIDTH-1:0]	odcache_bus_req,
 	output  [BUS_TAG_WIDTH-1:0] 	odcache_bus_reqtag
 );

///////////////////////////////////////

typedef struct packed   {
	bit		filler;
	bit		is_new;
	bit             valid;
	bit     [48:0]  tag;
        bit     [7:0] [63:0]  data;	// 8 instructions each of 32 bits
} cache_line;

typedef struct packed {
	bit        lrul;
	cache_line [1:0] line;
} dcache_set;
dcache_set dcache[3:0];
dcache_address dtcache_memaddr;
////////////////////////



enum {
	BYTE=3'b001,
	HWORD=3'b010,
	WORD=3'b011,
	DWORD=3'b100
} dcache_data_size;




//////////////////Give Nline to Serving read

////////////////////////////////////////
  logic ndcache_bus_reqcyc, ndcache_bus_respack, ndcache_bus_assert;
  logic [BUS_DATA_WIDTH-1:0] ndcache_bus_req;
  logic [BUS_TAG_WIDTH-1:0] ndcache_bus_reqtag;

  logic [63:0] ndcache_wdata; //nodcache_rdata;
  logic [48:0] cmp_tag, ndcache_tag;
  logic [8:0]  num_set, nset;
  logic [5:0]  ndcache_offset;
  logic nline, nevict_line, nlrul, ndcache_valid, ndcache_isnew, nodcache_write_ready;
  //logic ndcache_read_done, nodcache_write_done, ndcache_do_write, nodcache_write_ready;
  logic ndcache_do_write;
  logic [3:0] fill_count, nfill_count, evict_count, nevict_count; 

  logic [63:0] ex_byte, ex_hword, ex_word, ex_dword, ig_hword;
  logic [2:0] shift;

 enum {
        IDLE=4'b0000,
        REQUESTING_DATA=4'b0001,
        WAITING_FOR_DATA=4'b0010,
        FILLING_DATA=4'b0011,
	EVICTING=4'b0100,
	EVICT_WAITING_FOR_RESPONSE=4'b0101,
	SERVING_READ=4'b0110,
	SERVING_WRITE=4'b0111,
	WRITE_READY=4'b1000,
	INVALIDATING=4'b1001,
	REQUESTING_BUS=4'b1010
 } state, next_state;

//define dcache_data size in top

  always @ (posedge clk)
    if (reset) begin
      state <= IDLE;
    end 
   else begin
	state<=next_state;
	odcache_bus_reqcyc<=ndcache_bus_reqcyc;
	odcache_bus_respack<=ndcache_bus_respack;
	odcache_bus_req<=ndcache_bus_req;
	odcache_bus_reqtag<=ndcache_bus_reqtag;
	odcache_bus_assert<=ndcache_bus_assert;

	if(ndcache_do_write) begin
		dcache[nset].line[nline].data[ndcache_offset]<=ndcache_wdata;
		dcache[nset].line[nline].tag<=ndcache_tag;
		dcache[nset].line[nline].is_new<=ndcache_isnew;
		dcache[nset].line[nline].valid<=ndcache_valid;
		dcache[nset].lrul<=nlrul;
	end
	//will there be an else
	/*
	odcache_data<=nodcache_rdata;
	odcache_read_done<=ndcache_read_done;
	odcache_write_ready<=nodcache_write_ready;
	odcache_write_done<=nodcache_write_done;
	*/
	fill_count<=nfill_count;
	evict_count<=nevict_count;
    end

	always_comb begin
		dtcache_memaddr=dcache_memiaddr;
		//ex_lword=64'h00000000ffffffff;
		//ex_hiword=64'hffffffff00000000;
		ig_hword=64'hffffffffffffffc0;
		case(state)
			IDLE: begin
				if((dc_data_read_req)) begin //should read, write req be combinational/wires
					cmp_tag=dtcache_memaddr.tag;
					num_set=dtcache_memaddr.num_set;
					nevict_line=dcache[num_set].lrul;
					if ((dcache[num_set].line[0].tag == cmp_tag) && dcache[num_set].line[0].valid) begin
						ndcache_bus_assert=0;
						//nline=0;
						next_state = SERVING_READ;
					end
					else if ((dcache[num_set].line[1].tag == cmp_tag) && dcache[num_set].line[1].valid) begin
						//nline=1;
						ndcache_bus_assert=0;
						next_state = SERVING_READ;
					end
					else if(!(dcache[num_set].line[nevict_line].valid) || !(dcache[num_set].line[nevict_line].is_new)) 					   begin
						if (dcache_has_bus)
							next_state = REQUESTING_DATA;
						else
							next_state = REQUESTING_BUS;
					end
					else if((dcache[num_set].line[nevict_line].valid) && (dcache[num_set].line[nevict_line].is_new))   					   begin
						if (dcache_has_bus)
							next_state = EVICT_WAITING_FOR_RESPONSE;
						else
							next_state = REQUESTING_BUS;
					end
				end
				else if ((dc_data_write_req)) begin
					cmp_tag=dtcache_memaddr.tag;
					num_set=dtcache_memaddr.num_set;
					nevict_line=dcache[num_set].lrul;
					if ((dcache[num_set].line[0].tag == cmp_tag) && dcache[num_set].line[0].valid) begin
						//nline=0;
						ndcache_bus_assert=0;
						next_state = SERVING_WRITE;
					end
					else if ((dcache[num_set].line[1].tag == cmp_tag) && dcache[num_set].line[1].valid) begin
						//nline=1;
						ndcache_bus_assert=0;
						next_state = SERVING_WRITE;
					end
					else if(!(dcache[num_set].line[nevict_line].valid) || !(dcache[num_set].line[nevict_line].is_new))  					   begin
						if (dcache_has_bus)
							next_state = REQUESTING_DATA;
						else
							next_state = REQUESTING_BUS;
					end
					else if((dcache[num_set].line[nevict_line].valid) && (dcache[num_set].line[nevict_line].is_new))   					   begin
						if (dcache_has_bus)
							next_state = EVICT_WAITING_FOR_RESPONSE; //write_to_mem
						else
							next_state = REQUESTING_BUS;
					end
					//IS THERE ANY OTHER ELSE
				end
			end
			REQUESTING_DATA: begin //will ignore further reqs now?
					if (!dcache_has_bus)
						next_state = REQUESTING_BUS;
					else begin
						if (dcache_bus_reqack)
							next_state = WAITING_FOR_DATA;
						else if (!dcache_bus_reqack) begin
							next_state = REQUESTING_DATA;
						end
					end
			end
			WAITING_FOR_DATA: begin
					if (!dcache_has_bus)
						next_state = REQUESTING_BUS;
					else begin
						if(!dcache_bus_respcyc)
							next_state=WAITING_FOR_DATA;
						else
							next_state=FILLING_DATA;
					end
			end
			FILLING_DATA: begin// is there any way to get the addr of the data
					if (!dcache_has_bus)
						next_state = REQUESTING_BUS;
					else begin
						if(dcache_bus_respcyc) begin
							if(fill_count <8) begin
								next_state=FILLING_DATA;
							end
							else begin
								next_state=IDLE;//not sure, idea is to serve read/write asap
							end
						end
						else
							next_state=IDLE;
					end

			/*INVALIDATING: begin //
					if(dcache_bus_respcyc && bad_tag) begin
						//find_line;
						//set_invalid_bit=1;
						//next_state=INVALIDATING;
					end		
			end */
			end
			EVICTING: begin
					if (!dcache_has_bus)
						next_state = REQUESTING_BUS;
					else begin
						if(evict_count < 8) //hopefully we set the evict, valid, new bit correctly now
							next_state=EVICTING;
						else 
							next_state=REQUESTING_DATA;//if eviction is done, fetch this line
					end
			end
			EVICT_WAITING_FOR_RESPONSE: begin
					if (!dcache_has_bus)
						next_state = REQUESTING_BUS;
					else begin
						if(!dcache_bus_reqack)
							 next_state=EVICT_WAITING_FOR_RESPONSE;
						else
							next_state=EVICTING;
					end
			end
			SERVING_READ: begin
					next_state=IDLE;
			end
			WRITE_READY: begin
					next_state=SERVING_WRITE;
			end
			SERVING_WRITE: begin
					next_state=IDLE;
			end
			REQUESTING_BUS:	begin
					if(!dcache_has_bus)
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
		dtcache_memaddr=dcache_memiaddr;
		ex_byte=  64'h00000000000000ff;
		ex_hword= 64'h000000000000ffff;
		ex_word=  64'h00000000ffffffff;
		ig_hword= 64'hffffffffffffffc0;
		//ex_dword= 64'hffffffffffffffff;
		case(next_state)
			IDLE: begin
				ndcache_bus_reqcyc=0;
				ndcache_bus_respack=0;
				ndcache_bus_req = 0;
				ndcache_bus_reqtag = 0;
				nodcache_read_done=0;
				nodcache_write_done=0;
				nodcache_write_ready=0;
				nfill_count=0;
				nevict_count=0;
				ndcache_do_write=0;
				nset=dtcache_memaddr.num_set; //later
				nline=dcache[nset].lrul;
				ndcache_offset=dtcache_memaddr.offset[5:3];
				nodcache_rdata=dcache[nset].line[nline].data[ndcache_offset];
			end
			REQUESTING_DATA: begin
				ndcache_bus_reqcyc=1;
				ndcache_bus_respack=0;
				ndcache_bus_req=dtcache_memaddr & ig_hword;
				ndcache_bus_reqtag = `SYSBUS_READ << 12 | `SYSBUS_MEMORY << 8;
				nodcache_read_done=0;
				nodcache_write_done=0;
				nodcache_write_ready=0;
				nfill_count=0;
				nevict_count=0;
				ndcache_do_write=0;
				nset=dtcache_memaddr.num_set; //later
				nline=dcache[nset].lrul;
				ndcache_offset=dtcache_memaddr.offset[5:3];
				nodcache_rdata=dcache[nset].line[nline].data[ndcache_offset];
			end
			WAITING_FOR_DATA: begin
				ndcache_bus_reqcyc=0;
				ndcache_bus_respack=0;
				ndcache_bus_req = 0;
				ndcache_bus_reqtag = 0;
				nodcache_read_done=0;
				nodcache_write_done=0;
				nodcache_write_ready=0;
				nfill_count=0;
				nevict_count=0;
				ndcache_do_write=0;
				nset=dtcache_memaddr.num_set; //later
				nline=dcache[nset].lrul;
				ndcache_offset=dtcache_memaddr.offset[5:3];
				nodcache_rdata=dcache[nset].line[nline].data[ndcache_offset];
			end
			FILLING_DATA: begin //from mem into cache
				ndcache_bus_reqcyc=0;
				ndcache_bus_req = 0;
				ndcache_bus_reqtag = 0;
				nodcache_read_done=0;
				nodcache_write_done=0;
				nodcache_write_ready=0;
				ndcache_do_write=1;
				nset=dtcache_memaddr.num_set;
				nline=dcache[dtcache_memaddr.num_set].lrul;
				ndcache_offset=fill_count;
				ndcache_wdata=dcache_bus_resp[63:0];
				ndcache_tag=dtcache_memaddr.tag;//doesn't matter untill count is 8
				nevict_count=0;
				nfill_count=fill_count+1;
				if(nfill_count <8) begin
					ndcache_bus_respack=1;
					ndcache_valid=0;
					ndcache_isnew=0;
					nlrul=dcache[dtcache_memaddr.num_set].lrul;
				end
				else begin
					ndcache_bus_respack=0;
					ndcache_valid=1;
					ndcache_isnew=0;
					nlrul=~nline;
				end
				nodcache_rdata=dcache[nset].line[nline].data[ndcache_offset];
			end
			INVALIDATING: begin
				ndcache_bus_reqcyc=0;
				ndcache_bus_respack=0;
				ndcache_do_write=1;
				//ndcache_line=fn();
				ndcache_valid=0;
				nodcache_read_done=0;
				nodcache_write_done=0;
			end
			SERVING_READ: begin
				ndcache_bus_reqcyc=0;
				ndcache_bus_respack=0;
				ndcache_bus_req = 0;
				ndcache_bus_reqtag = 0;
				nodcache_read_done=1;
				nodcache_write_ready=0;
				nodcache_write_done=0;
				ndcache_do_write=1;
				nset=dtcache_memaddr.num_set;
				ndcache_offset=dtcache_memaddr.offset[5:3];
				ndcache_wdata=dcache[nset].line[nline].data[ndcache_offset];
				ndcache_tag=dcache[nset].line[nline].tag;
				ndcache_isnew=dcache[nset].line[nline].is_new;
				ndcache_valid=dcache[nset].line[nline].valid;
				if ((dcache[nset].line[0].tag == dtcache_memaddr.tag) && (dcache[nset].line[0].valid)) begin
					nline=0;
				end
				else if ((dcache[nset].line[1].tag == dtcache_memaddr.tag) && (dcache[nset].line[1].valid)) begin
					nline=1;
				end
				else
					$finish; //this is fatal;
				nlrul=~nline;
				shift=ndcache_offset[2:0];
				case(dcache_data_size)
					BYTE:
						nodcache_rdata=((dcache[nset].line[nline].data[ndcache_offset]) & (ex_byte <<(shift*8))) >> (shift*8);
					HWORD:
						nodcache_rdata=((dcache[nset].line[nline].data[ndcache_offset]) & (ex_hword <<(shift*8))) >> (shift*8);
					WORD:
						nodcache_rdata=((dcache[nset].line[nline].data[ndcache_offset]) & (ex_word <<(shift*8))) >> (shift*8);
					DWORD:
						nodcache_rdata=dcache[nset].line[nline].data[ndcache_offset];
				endcase
				nfill_count=0;
				nevict_count=0;
			end
			WRITE_READY: begin
				ndcache_bus_reqcyc=0;
				ndcache_bus_respack=0;
				nodcache_read_done=0;
				nodcache_write_done=0;
				nodcache_write_ready=1;
				ndcache_do_write=0;
				nfill_count=0;
				nevict_count=0;
			end
			SERVING_WRITE: begin
				ndcache_bus_reqcyc=0;
				ndcache_bus_respack=0;
				ndcache_bus_req = 0;
				ndcache_bus_reqtag = 0;
				nodcache_read_done=0;
				nodcache_write_done=1;
				nodcache_write_ready=0;
				ndcache_do_write=1;
				nset=dtcache_memaddr.num_set;
				ndcache_offset=dtcache_memaddr.offset[5:3];
				//ndcache_tag=dcache[nset].line[nline].tag; //what is it was just evicted?
				if ((dcache[nset].line[0].tag == dtcache_memaddr.tag)&& (dcache[nset].line[0].valid)) begin
					nline=0;
				end
				else if ((dcache[nset].line[1].tag == dtcache_memaddr.tag) && (dcache[nset].line[1].valid)) begin
					nline=1;
				end
				else
					$finish; //this is fatal;
				ndcache_tag=dtcache_memaddr.tag;//alwyays set to tag from mem
				ndcache_isnew=1;
				ndcache_valid=1;
				nlrul=~nline;
				shift=ndcache_offset[2:0];
				case(dcache_data_size)
					BYTE:
					   ndcache_wdata=((dcache_memidata & ex_byte)<< (shift*8)) | ((~(ex_byte << (shift*8)))& dcache[nset].line[nline].data[ndcache_offset]);
					HWORD:
					   ndcache_wdata=((dcache_memidata & ex_hword) <<(shift*8)) | ((~(ex_hword << (shift*8)))& dcache[nset].line[nline].data[ndcache_offset]);
					WORD:
					   ndcache_wdata=((dcache_memidata & ex_word) <<(shift*8)) | ((~(ex_word << (shift*8))) & dcache[nset].line[nline].data[ndcache_offset]);
					DWORD:
					   ndcache_wdata=(dcache_memidata);
				endcase
				nfill_count=0;
				nevict_count=0;
				nodcache_rdata=dcache[nset].line[nline].data[ndcache_offset];
			end
			EVICTING: begin
				ndcache_bus_reqcyc=1;
				ndcache_bus_respack=0;
				ndcache_bus_reqtag = `SYSBUS_WRITE << 12 | `SYSBUS_MEMORY << 8;
				nset=dtcache_memaddr.num_set;
				nline=dcache[nset].lrul;
				ndcache_bus_req=dcache[nset].line[nline].data[evict_count];
				//ndcache_offset=dtcache_memaddr.offset[5:3];
				ndcache_offset=evict_count;
				nodcache_read_done=0;
				nodcache_write_done=0;
				nodcache_write_ready=0;
				nfill_count=0;
				nevict_count=evict_count+1;
				if(nevict_count < 8) begin
					ndcache_do_write=0;
				end
				else begin
					ndcache_do_write=1;
					ndcache_wdata=dcache[nset].line[nline].data[evict_count];
					ndcache_tag=dcache[nset].line[nline].tag;//can't change tag now
					ndcache_valid=1; //after evicting, the line is valid(we just wrote it to mem) but not new
					ndcache_isnew=0;
					nlrul=nline; //this line must be overwritten now
				end
				nodcache_rdata=dcache[nset].line[nline].data[ndcache_offset];
			end
			EVICT_WAITING_FOR_RESPONSE: begin
				ndcache_bus_reqcyc=1;
				ndcache_bus_respack=0;
				nset=dtcache_memaddr.num_set;
				nline=dcache[nset].lrul;
				ndcache_offset=dtcache_memaddr.offset[5:3];
				ndcache_bus_req={dcache[nset].line[nline].tag, nset[8:0]};
				ndcache_bus_reqtag = `SYSBUS_WRITE << 12 | `SYSBUS_MEMORY << 8;
				nodcache_read_done=0;
				nodcache_write_done=0;
				nodcache_write_ready=0;
				ndcache_do_write=0;
				nfill_count=0;
				nevict_count=0;
				nodcache_rdata=dcache[nset].line[nline].data[ndcache_offset];
			end
			REQUESTING_BUS:	begin
				ndcache_bus_assert=1;
			end
		endcase	
	end	


  initial begin
    $display("Initializing top, entry point = 0x%x", entry);
  end
endmodule
