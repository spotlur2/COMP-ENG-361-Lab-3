// Template for Northwestern - CompEng 361 - Lab3 -- Version 1.1
// Groupname: Group 2
// NetIDs: ETW0214, KAF0208

// Some useful defines...please add your own
`define WORD_WIDTH 32
`define NUM_REGS 32
`define OPCODE_COMPUTE    7'b0110011
`define OPCODE_IMM        7'b0010011
`define OPCODE_BRANCH     7'b1100011
`define OPCODE_LOAD       7'b0000011
`define OPCODE_STORE      7'b0100011 
`define FUNC_ADD      3'b000
`define FUNC_SLL      3'b001
`define FUNC_SLT      3'b010
`define FUNC_SLTU     3'b011
`define FUNC_XOR      3'b100
`define FUNC_SR       3'b101
`define FUNC_OR       3'b110
`define FUNC_AND      3'b111
`define AUX_FUNC_ADD  7'b0000000
`define AUX_FUNC_SUB  7'b0100000
`define SIZE_BYTE  2'b00
`define SIZE_HWORD 2'b01
`define SIZE_WORD  2'b10

module SingleCycleCPU(halt, clk, rst);
   output halt;
   input clk, rst;

   wire [`WORD_WIDTH-1:0] PC, InstWord;
   wire [`WORD_WIDTH-1:0] DataAddr, StoreData, DataWord;
   wire [1:0]  MemSize;
   wire        MemWrEn;
   
   wire [4:0]  Rsrc1, Rsrc2, Rdst;
   wire [`WORD_WIDTH-1:0] Rdata1, Rdata2, RWrdata;
   wire        RWrEn;

   wire [`WORD_WIDTH-1:0] NPC, PC_Plus_4;
   wire [6:0]  opcode;

   wire [6:0]  funct7;
   wire [2:0]  funct3;

   wire invalid_op;
   
   // Opcode Decode
   wire is_rtype  = (opcode == `OPCODE_COMPUTE);
   wire is_itype  = (opcode == `OPCODE_IMM);
   wire is_load   = (opcode == `OPCODE_LOAD);
   wire is_store  = (opcode == `OPCODE_STORE);
   wire is_branch = (opcode == `OPCODE_BRANCH);

   // Checks
   wire valid_rtype_f7 = ((funct3 == `FUNC_ADD) || (funct3 == `FUNC_SR)) ?
                         ((funct7 == `AUX_FUNC_ADD) || (funct7 == `AUX_FUNC_SUB)) :
                         (funct7 == `AUX_FUNC_ADD);
   wire valid_rtype    = is_rtype & valid_rtype_f7;

   wire valid_itype_f7 = (funct3 == `FUNC_SLL) ? (funct7 == `AUX_FUNC_ADD) :
                         (funct3 == `FUNC_SR)  ? ((funct7 == `AUX_FUNC_ADD) || (funct7 == `AUX_FUNC_SUB)) :
                         1'b1;
   wire valid_itype    = is_itype & valid_itype_f7;

   wire valid_load     = is_load & ((funct3 == 3'b000) || (funct3 == 3'b001) || (funct3 == 3'b010) ||
                                    (funct3 == 3'b100) || (funct3 == 3'b101));
   wire valid_store    = is_store & ((funct3 == 3'b000) || (funct3 == 3'b001) || (funct3 == 3'b010));
   wire valid_branch   = is_branch & ((funct3 == 3'b000) || (funct3 == 3'b001) || (funct3 == 3'b100) ||
                                      (funct3 == 3'b101) || (funct3 == 3'b110) || (funct3 == 3'b111));

   assign invalid_op   = !(valid_rtype || valid_itype || valid_load || valid_store || valid_branch);

   // Immediate Generation
   wire [`WORD_WIDTH-1:0] imm_i = {{20{InstWord[31]}}, InstWord[31:20]};
   wire [`WORD_WIDTH-1:0] imm_s = {{20{InstWord[31]}}, InstWord[31:25], InstWord[11:7]};
   wire [`WORD_WIDTH-1:0] imm_b = {{19{InstWord[31]}}, InstWord[31], InstWord[7], InstWord[30:25], InstWord[11:8], 1'b0};

   // Memory Address
   assign DataAddr  = Rdata1 + (is_store ? imm_s : imm_i);
   assign StoreData = Rdata2;
   assign MemSize   = funct3[1:0];

   wire mem_access      = valid_load || valid_store;
   wire misaligned_half = (MemSize == `SIZE_HWORD) && DataAddr[0];
   wire misaligned_word = (MemSize == `SIZE_WORD)  && (|DataAddr[1:0]);
   wire misaligned_mem  = mem_access && (misaligned_half || misaligned_word);

   // Only support R-TYPE ADD and SUB
   assign halt = invalid_op || misaligned_mem;
     
   // System State 
   Mem   MEM(.InstAddr(PC), .InstOut(InstWord), 
            .DataAddr(DataAddr), .DataSize(MemSize), .DataIn(StoreData), .DataOut(DataWord), .WE(MemWrEn), .CLK(clk));

   RegFile RF(.AddrA(Rsrc1), .DataOutA(Rdata1), 
	      .AddrB(Rsrc2), .DataOutB(Rdata2), 
	      .AddrW(Rdst), .DataInW(RWrdata), .WenW(RWrEn), .CLK(clk));

   Reg PC_REG(.Din(NPC), .Qout(PC), .WE(!halt), .CLK(clk), .RST(rst));

   // Instruction Decode
   assign opcode = InstWord[6:0];   
   assign Rdst = InstWord[11:7]; 
   assign Rsrc1 = InstWord[19:15]; 
   assign Rsrc2 = InstWord[24:20];
   assign funct3 = InstWord[14:12];  // R-Type, I-Type, S-Type
   assign funct7 = InstWord[31:25];  // R-Type

   assign MemWrEn = valid_store && !halt;
   assign RWrEn   = (valid_rtype || valid_itype || valid_load) && !halt;

   // Hardwired to support R-Type instructions -- please add muxes and other control signals
   wire [`WORD_WIDTH-1:0] eu_opB  = is_rtype ? Rdata2 : imm_i;
   wire [6:0]             eu_aux  = is_rtype ? funct7 :
                                    ((is_itype && (funct3 == `FUNC_SR)) ? funct7 : `AUX_FUNC_ADD);
   wire [`WORD_WIDTH-1:0] alu_out;

   ExecutionUnit EU(.out(alu_out), .opA(Rdata1), .opB(eu_opB), .func(funct3), .auxFunc(eu_aux));

   // Load Data Formatting (sign/zero extension)
   wire [`WORD_WIDTH-1:0] load_data = (funct3 == 3'b000) ? {{24{DataWord[7]}},  DataWord[7:0]}  :
                                      (funct3 == 3'b001) ? {{16{DataWord[15]}}, DataWord[15:0]} :
                                      (funct3 == 3'b010) ? DataWord                             :
                                      (funct3 == 3'b100) ? {24'b0, DataWord[7:0]}               :
                                      (funct3 == 3'b101) ? {16'b0, DataWord[15:0]}              :
                                                           DataWord;

   assign RWrdata = valid_load ? load_data : alu_out;

   // Branch Comparison & Fetch Address Datapath
   wire [`WORD_WIDTH-1:0] br_diff = Rdata1 - Rdata2;
   wire br_eq  = (Rdata1 == Rdata2);
   wire br_lt  = (Rdata1[31] != Rdata2[31]) ? Rdata1[31] : br_diff[31];
   wire br_ltu = (Rdata1 < Rdata2);

   wire br_taken = (funct3 == 3'b000) ?  br_eq  :
                   (funct3 == 3'b001) ? !br_eq  :
                   (funct3 == 3'b100) ?  br_lt  :
                   (funct3 == 3'b101) ? !br_lt  :
                   (funct3 == 3'b110) ?  br_ltu :
                   (funct3 == 3'b111) ? !br_ltu :
                                        1'b0;

   // Fetch Address Datapath
   assign PC_Plus_4 = PC + 4;
   assign NPC = (valid_branch && br_taken) ? (PC + imm_b) : PC_Plus_4;
   
endmodule // SingleCycleCPU


// Incomplete version of Lab2 execution unit
// You will need to extend it. Feel free to modify the interface also
module ExecutionUnit(out, opA, opB, func, auxFunc);
   output [`WORD_WIDTH-1:0] out;
   input [`WORD_WIDTH-1:0]  opA, opB;
   input [2:0] 	 func;
   input [6:0] 	 auxFunc;

   wire [`WORD_WIDTH-1:0] 	 addSub;

   //add and subtract
   assign addSub = (auxFunc == 7'b0100000) ? (opA - opB) : (opA + opB);
   wire [4:0]               shamt = opB[4:0];
   
   // SLT and SLTU
   wire [`WORD_WIDTH-1:0] diff        = opA - opB;
   wire                   lt_signed   = (opA[31] != opB[31]) ? opA[31] : diff[31];
   wire                   lt_unsigned = (opA < opB);
   wire [`WORD_WIDTH-1:0] slt_res     = {31'b0, lt_signed};
   wire [`WORD_WIDTH-1:0] sltu_res    = {31'b0, lt_unsigned};

   // Bitwise
   wire [`WORD_WIDTH-1:0] xor_res = opA ^ opB;
   wire [`WORD_WIDTH-1:0] or_res  = opA | opB;
   wire [`WORD_WIDTH-1:0] and_res = opA & opB;

   // SLL, SRL, SRA
   wire [`WORD_WIDTH-1:0] sll_res = opA << shamt;
   wire [`WORD_WIDTH-1:0] srl_res = opA >> shamt;

   wire                   sign_bit = opA[31];
   wire [`WORD_WIDTH-1:0] sra_s0   = shamt[0] ? {sign_bit,       opA[31:1]}     : opA;
   wire [`WORD_WIDTH-1:0] sra_s1   = shamt[1] ? {{2{sign_bit}},  sra_s0[31:2]}  : sra_s0;
   wire [`WORD_WIDTH-1:0] sra_s2   = shamt[2] ? {{4{sign_bit}},  sra_s1[31:4]}  : sra_s1;
   wire [`WORD_WIDTH-1:0] sra_s3   = shamt[3] ? {{8{sign_bit}},  sra_s2[31:8]}  : sra_s2;
   wire [`WORD_WIDTH-1:0] sra_res  = shamt[4] ? {{16{sign_bit}}, sra_s3[31:16]} : sra_s3;

   wire [`WORD_WIDTH-1:0] sr_res   = (auxFunc == 7'b0100000) ? sra_res : srl_res;

   assign out = (func == 3'b000) ? addSub   :
                (func == 3'b001) ? sll_res  :
                (func == 3'b010) ? slt_res  :
                (func == 3'b011) ? sltu_res :
                (func == 3'b100) ? xor_res  :
                (func == 3'b101) ? sr_res   :
                (func == 3'b110) ? or_res   :
                                   and_res;
   
endmodule // ExecutionUnit
