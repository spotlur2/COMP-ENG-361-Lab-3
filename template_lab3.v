// Template for Northwestern - CompEng 361 - Lab3 -- Version 1.1
// Groupname:
// NetIDs:

// Some useful defines...please add your own
`define WORD_WIDTH 32
`define NUM_REGS 32
`define OPCODE_COMPUTE    7'b0110011
`define OPCODE_BRANCH     7'b1100011
`define OPCODE_LOAD       7'b0000011
`define OPCODE_STORE      7'b0100011 
`define FUNC_ADD      3'b000
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
   
   // Only support R-TYPE ADD and SUB
   assign halt = invalid_op;
   assign invalid_op = !((opcode == `OPCODE_COMPUTE) && (funct3 == `FUNC_ADD) &&
		      ((funct7 == `AUX_FUNC_ADD) || (funct7 == `AUX_FUNC_SUB)));
     
   // System State 
   Mem   MEM(.InstAddr(PC), .InstOut(InstWord), 
            .DataAddr(DataAddr), .DataSize(MemSize), .DataIn(StoreData), .DataOut(DataWord), .WE(MemWrEn), .CLK(clk));

   RegFile RF(.AddrA(Rsrc1), .DataOutA(Rdata1), 
	      .AddrB(Rsrc2), .DataOutB(Rdata2), 
	      .AddrW(Rdst), .DataInW(RWrdata), .WenW(RWrEn), .CLK(clk));

   Reg PC_REG(.Din(NPC), .Qout(PC), .WE(1'b1), .CLK(clk), .RST(rst));

   // Instruction Decode
   assign opcode = InstWord[6:0];   
   assign Rdst = InstWord[11:7]; 
   assign Rsrc1 = InstWord[19:15]; 
   assign Rsrc2 = InstWord[24:20];
   assign funct3 = InstWord[14:12];  // R-Type, I-Type, S-Type
   assign funct7 = InstWord[31:25];  // R-Type

   assign MemWrEn = 1'b0; // Change this to allow stores
   assign RWrEn = 1'b1;  // At the moment every instruction will write to the register file

   // Hardwired to support R-Type instructions -- please add muxes and other control signals
   ExecutionUnit EU(.out(RWrdata), .opA(Rdata1), .opB(Rdata2), .func(funct3), .auxFunc(funct7));

   // Fetch Address Datapath
   assign PC_Plus_4 = PC + 4;
   assign NPC = PC_Plus_4;
   
endmodule // SingleCycleCPU


// Incomplete version of Lab2 execution unit
// You will need to extend it. Feel free to modify the interface also
module ExecutionUnit(out, opA, opB, func, auxFunc);
   output [`WORD_WIDTH-1:0] out;
   input [`WORD_WIDTH-1:0]  opA, opB;
   input [2:0] 	 func;
   input [6:0] 	 auxFunc;

   wire [`WORD_WIDTH-1:0] 	 addSub;

   // Only supports add and subtract
   assign addSub = (auxFunc == 7'b0100000) ? (opA - opB) : (opA + opB);
   assign out = (func == 3'b000) ? addSub : 32'hXXXXXXXX;
   
endmodule // ExecutionUnit
