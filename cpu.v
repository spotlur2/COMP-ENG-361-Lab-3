
module SingleCycleCPU();
    output halt;
    input clk, rst;

    // Fetch 
    wire [31:0] pc, pc_next, pc_plus4, inst;


    // PC 
    assign pc_plus4 = pc + 32'd4;
    assign pc_next = pc_plus4;

    D #(.width(32), .init(0)) PC_REG(
        .Din(pc_next), .Qout(pc), .WE(~halt), .RST(rst)
    );

    // instructions
    wire [4:0] rd = inst[11:7];
    wire [4:0] rs1 = inst[19:15];
    wire [4:0] rs2 = inst[24:20];

