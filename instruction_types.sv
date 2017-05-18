//// ======ALL DECLARATIONS========

//jalr and loads
//maybe addi
/******************
HANDLE SIGN EXTENDED IMMEDIATEs
****************/


typedef struct packed{
	bit[31:31] imm_12b;
	bit[30:25] imm_10t5b;
	bit[24:20] rs2;	
	bit[19:15] rs1;	
	bit[14:12] funct3;
	bit[11:8] imm_4t1b;
	bit[7:7] imm_11b;
	bit[6:0] opcode;		
}branch_instr;
//{imm_12b, imm_11b, imm_10t5b, imm_4t1b}
//blt rs1, rs2, imm
//blt 

typedef struct packed{
	bit signed [31:20] imm12; //offset
	bit[19:15] rs1;
	bit[14:12] func;
	bit[11:7] rd;
	bit[6:0] opcode;
} load_instr;


//generic instr
typedef struct packed{
	bit [31:7] rest;
	bit[6:0] opcode;
}generic_instr;

//jal
typedef struct packed{
	bit[31:31] imm_20b;
	bit[30:21] imm_10t1b;
	bit [20:20] imm_11b;
	bit [19:12] imm_19t12b;
	bit[11:7] rd;
	bit[6:0] opcode;
} jal_instr;

//store = store rs2 to rs1+ (sign extend) imm12hi<<5 | imm12lo
//sd 

typedef struct packed{
	bit[31:25] imm12hi;
	bit[24:20] rs2;
	bit[19:15] rs1;
	bit[14:12] func;
	bit[11:7] imm12lo;
	bit[6:0] opcode;
} store_instr;


//lui auipc
typedef struct packed{
	bit[31:12] imm20;
	bit[11:7] rd;
	bit[6:0] opcode;
} load_instr_imm;


//slli srli srai

typedef struct packed{
	bit[31:26] oc; //other code
	bit[25:20] shamt;
	bit[19:15] rs1;
	bit[14:12] func;
	bit[11:7] rd;
	bit[6:0] opcode;
} shmt_instr1;

//slliw srliw sraiw 
typedef struct packed{
	bit[31:25] oc; //other code
	bit[24:20] shamtw;
	bit[19:15] rs1;
	bit[14:12] func;
	bit[11:7] rd;
	bit[6:0] opcode;
} shmt_instr2;


//addw, subw, sllw, srlw, sraw
//mulw, diw, divuw, remw, remuw
//add
typedef struct packed{
	bit[31:25] oc; //other code
	bit[24:20] rs2;
	bit[19:15] rs1;
	bit[14:12] func;
	bit[11:7] rd;
	bit[6:0] opcode;
} arith_instr;
