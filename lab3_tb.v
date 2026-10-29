// Testbench and Library for Northwestern - CompEng 361 - Lab3
// Version: 2.0 (2026-FA-RV32I-TRACE)
//
// Sampling design note:
// All architectural state elements (Reg, RegFile, Mem) update on negedge CLK
// using nonblocking assignments (<=). Combinational logic settles after the
// previous negedge CLK (and across posedge CLK). Tracing samples signals in
// the Active event region of negedge CLK, immediately before nonblocking
// state updates take effect in the NBA region. This guarantees identical
// traces across arbitrary clock periods and accurately captures both normal
// instruction retirement and any stray state writes in the halting cycle.

`define CHAR_WIDTH 8
`define MAX_CHAR 256
`define MEM_BYTES 16384

module tb;
    parameter HALF_PERIOD = 5;
    parameter MAX_CYCLES  = 100000;

    reg clk, rst;
    reg exit;
    reg trace_en;
    wire halt;

    reg [`CHAR_WIDTH*`MAX_CHAR-1:0] mem_in_fname, mem_out_fname, regs_in_fname, regs_out_fname;
    reg [`CHAR_WIDTH*`MAX_CHAR-1:0] signal_dump_fname, trace_out_fname;

    integer cycle_count;
    integer max_cycles;
    integer trace_fd;
    integer check_fd;
    integer init_i;
    integer no_vcd;

    // Signals mirrored from Mem and RegFile ports while trace_en is active
    reg [31:0] tr_inst_addr;
    reg [31:0] tr_inst_out;
    reg [31:0] tr_data_addr;
    reg [1:0]  tr_data_size;
    reg [31:0] tr_data_in;
    reg        tr_mem_we;

    reg [4:0]  tr_rf_addr_w;
    reg [31:0] tr_rf_data_w;
    reg        tr_rf_wen;

    // Single Cycle CPU instantiation
    SingleCycleCPU CPU (halt, clk, rst);

    // Clock generation (default period = 10 time units)
    always
        #HALF_PERIOD clk = ~clk;

    // Convert a 4-bit nibble to lowercase hex character ('0'-'9', 'a'-'f', or 'x')
    function [7:0] nib_char;
        input [3:0] nib;
        begin
            if (^nib === 1'bx)
                nib_char = "x";
            else if (nib < 4'd10)
                nib_char = "0" + nib;
            else
                nib_char = "a" + (nib - 4'd10);
        end
    endfunction

    function [63:0] hex32;
        input [31:0] val;
        begin
            hex32 = {
                nib_char(val[31:28]),
                nib_char(val[27:24]),
                nib_char(val[23:20]),
                nib_char(val[19:16]),
                nib_char(val[15:12]),
                nib_char(val[11:8]),
                nib_char(val[7:4]),
                nib_char(val[3:0])
            };
        end
    endfunction

    function [31:0] hex16;
        input [15:0] val;
        begin
            hex16 = {
                nib_char(val[15:12]),
                nib_char(val[11:8]),
                nib_char(val[7:4]),
                nib_char(val[3:0])
            };
        end
    endfunction

    function [15:0] hex8;
        input [7:0] val;
        begin
            hex8 = {
                nib_char(val[7:4]),
                nib_char(val[3:0])
            };
        end
    endfunction

    // Helper task to format and write a register write field (rd=... or stray_rd=...)
    task write_rd_field;
        input is_stray;
        reg [31:0] data_val;
        begin
            data_val = (tr_rf_wen === 1'b1) ? tr_rf_data_w : 32'hxxxxxxxx;
            if (is_stray)
                $fwrite(trace_fd, " stray_rd=x");
            else
                $fwrite(trace_fd, " rd=x");

            if (^tr_rf_addr_w === 1'bx)
                $fwrite(trace_fd, "x:%s", hex32(data_val));
            else
                $fwrite(trace_fd, "%0d:%s", tr_rf_addr_w, hex32(data_val));
        end
    endtask

    // Helper task to format and write a load field (ld=<addr>:<size>)
    task write_ld_field;
        begin
            $fwrite(trace_fd, " ld=%s:", hex32(tr_data_addr));
            if (^tr_data_size === 1'bx)
                $fwrite(trace_fd, "x");
            else if (tr_data_size == 2'b00)
                $fwrite(trace_fd, "1");
            else if (tr_data_size == 2'b01)
                $fwrite(trace_fd, "2");
            else
                $fwrite(trace_fd, "4");
        end
    endtask

    // Helper task to format and write a store field (st=... or stray_st=...)
    task write_st_field;
        input is_stray;
        reg [31:0] store_val;
        begin
            store_val = (tr_mem_we === 1'b1) ? tr_data_in : 32'hxxxxxxxx;
            if (is_stray)
                $fwrite(trace_fd, " stray_st=%s:", hex32(tr_data_addr));
            else
                $fwrite(trace_fd, " st=%s:", hex32(tr_data_addr));

            if (^tr_data_size === 1'bx)
                $fwrite(trace_fd, "x:%s", hex32(32'hxxxxxxxx));
            else if (tr_data_size == 2'b00)
                $fwrite(trace_fd, "1:%s", hex8(store_val[7:0]));
            else if (tr_data_size == 2'b01)
                $fwrite(trace_fd, "2:%s", hex16(store_val[15:0]));
            else
                $fwrite(trace_fd, "4:%s", hex32(store_val[31:0]));
        end
    endtask

    // Trace sampling at negedge clk (Active region, before NBA updates)
    always @(negedge clk) begin
        if (trace_en && !exit) begin
            if (halt === 1'b1) begin
                $fwrite(trace_fd, "HALT pc=%s inst=%s", hex32(tr_inst_addr), hex32(tr_inst_out));
                if ((tr_rf_wen !== 1'b0) && (tr_rf_addr_w !== 5'd0))
                    write_rd_field(1'b1);
                if (tr_mem_we !== 1'b0)
                    write_st_field(1'b1);
                $fwrite(trace_fd, "\n");
                $fflush(trace_fd);
                exit <= 1'b1;
            end else begin
                cycle_count = cycle_count + 1;
                $fwrite(trace_fd, "%0d pc=%s inst=%s", cycle_count, hex32(tr_inst_addr), hex32(tr_inst_out));
                if ((tr_rf_wen !== 1'b0) && (tr_rf_addr_w !== 5'd0))
                    write_rd_field(1'b0);
                if (tr_inst_out[6:0] === 7'b0000011)
                    write_ld_field();
                if (tr_mem_we !== 1'b0)
                    write_st_field(1'b0);
                $fwrite(trace_fd, "\n");

                if (cycle_count >= max_cycles) begin
                    $fwrite(trace_fd, "TIMEOUT\n");
                    $fflush(trace_fd);
                    exit <= 1'b1;
                end
            end
        end
    end

    initial begin
        // Read commandline options
        if (!$value$plusargs("MEM_IN=%s", mem_in_fname))
            mem_in_fname = "mem_in.hex";
        if (!$value$plusargs("REGS_IN=%s", regs_in_fname))
            regs_in_fname = "regs_in.hex";
        if (!$value$plusargs("REGS_OUT=%s", regs_out_fname))
            regs_out_fname = "regs_out.hex";
        if (!$value$plusargs("MEM_OUT=%s", mem_out_fname))
            mem_out_fname = "mem_out.hex";
        if (!$value$plusargs("DUMP=%s", signal_dump_fname))
            signal_dump_fname = "single.vcd";
        if (!$value$plusargs("TRACE_OUT=%s", trace_out_fname))
            trace_out_fname = "trace.txt";
        if (!$value$plusargs("MAX_CYCLES=%d", max_cycles))
            max_cycles = MAX_CYCLES;
        if (!$value$plusargs("NO_VCD=%d", no_vcd))
            no_vcd = 0;

        // Deterministic initialization of memory and register file before loading hex
        for (init_i = 0; init_i < `MEM_BYTES; init_i = init_i + 1)
            CPU.MEM.Mem[init_i] = 8'h00;
        for (init_i = 0; init_i < 32; init_i = init_i + 1)
            CPU.RF.Mem[init_i] = 32'h00000000;

        trace_fd = $fopen(trace_out_fname, "w");
        if (trace_fd == 0) begin
            $display("ERROR: Could not open trace file %0s", trace_out_fname);
            $finish;
        end

        // Clock and reset setup
        #0 trace_en = 0; cycle_count = 0; rst = 1; exit = 0; clk = 0;
        #0 rst = 0;
        #0 rst = 1;

        // Load program memory and regs (if regs_in exists)
        #0 $readmemh(mem_in_fname, CPU.MEM.Mem);
        #0 check_fd = $fopen(regs_in_fname, "r");
        if (check_fd != 0) begin
            $fclose(check_fd);
            $readmemh(regs_in_fname, CPU.RF.Mem);
        end
        CPU.RF.Mem[0] = 32'h00000000;

        // Enable tracing after reset release and memory initialization
        #0 trace_en = 1;

        // Dumpfile
        if (!no_vcd) begin
            $dumpfile(signal_dump_fname);
            $dumpvars();
        end

        // Wait for halt or timeout
        wait(exit);

        // Dump memory, regs, and close trace
        #0 $writememh(regs_out_fname, CPU.RF.Mem);
        #0 $writememh(mem_out_fname, CPU.MEM.Mem);
        $fclose(trace_fd);

        $finish;
    end

endmodule // tb


module Mem(InstAddr, InstOut,
         DataAddr, DataSize, DataIn, DataOut, WE, CLK);
    input [31:0] InstAddr, DataAddr;
    input [1:0]  DataSize;
    input [31:0] DataIn;
    output [31:0] InstOut, DataOut;
    input      WE, CLK;
    reg [7:0]  Mem[0:`MEM_BYTES-1];

    wire [31:0] DataAddrH, DataAddrW, InstAddrW;

    // Instruction Addresses are word aligned
    assign InstAddrW = InstAddr & 32'hfffffffc;

    assign DataAddrH = DataAddr & 32'hfffffffe;
    assign DataAddrW = DataAddr & 32'hfffffffc;

    // Little endian
    assign InstOut = {Mem[InstAddrW+3], Mem[InstAddrW+2],
        Mem[InstAddrW+1], Mem[InstAddrW]};

    // Little endian
    assign DataOut = (DataSize == 2'b00) ? {4{Mem[DataAddr]}} :
           ((DataSize == 2'b01) ? {2{Mem[DataAddrH+1],Mem[DataAddrH]}} :
        {Mem[DataAddrW+3], Mem[DataAddrW+2], Mem[DataAddrW+1], Mem[DataAddrW]});

    // Mirror port signals to testbench trace observer when tracing is enabled
    always @(posedge CLK or InstAddr or InstOut or DataAddr or DataSize or DataIn or WE or tb.trace_en) begin
        if (tb.trace_en) begin
            tb.tr_inst_addr = InstAddr;
            tb.tr_inst_out  = InstOut;
            tb.tr_data_addr = DataAddr;
            tb.tr_data_size = DataSize;
            tb.tr_data_in   = DataIn;
            tb.tr_mem_we    = WE;
        end
    end

    always @ (negedge CLK)
        if (WE) begin
            case (DataSize)
            2'b00: begin // Write byte
                Mem[DataAddr] <= DataIn[7:0];
            end
            2'b01: begin  // Write halfword
                Mem[DataAddrH] <= DataIn[7:0];
                Mem[DataAddrH+1] <= DataIn[15:8];
            end
            2'b10, 2'b11: begin // Write word
                Mem[DataAddrW] <= DataIn[7:0];
                Mem[DataAddrW+1] <= DataIn[15:8];
                Mem[DataAddrW+2] <= DataIn[23:16];
                Mem[DataAddrW+3] <= DataIn[31:24];
            end
            endcase // case (Size)
        end
endmodule // Mem


module RegFile(AddrA, DataOutA,
           AddrB, DataOutB,
           AddrW, DataInW, WenW, CLK);
    input [4:0] AddrA, AddrB, AddrW;
    output [31:0] DataOutA, DataOutB;
    input [31:0]  DataInW;
    input         WenW, CLK;
    reg [31:0]    Mem[0:31];

    assign DataOutA = (AddrA == 0) ? 32'h00000000 : Mem[AddrA];
    assign DataOutB = (AddrB == 0) ? 32'h00000000 : Mem[AddrB];

    // Mirror port signals to testbench trace observer when tracing is enabled
    always @(posedge CLK or AddrW or DataInW or WenW or tb.trace_en) begin
        if (tb.trace_en) begin
            tb.tr_rf_addr_w = AddrW;
            tb.tr_rf_data_w = DataInW;
            tb.tr_rf_wen    = WenW;
        end
    end

    always @ (negedge CLK) begin
        if (WenW) begin
            Mem[AddrW] <= DataInW;
        end
        Mem[0] <= 0; // Enforce the invariant that x0 = 0
    end

endmodule // RegFile


module Reg(Din, Qout, WE, CLK, RST);
    parameter width = 32;
    parameter init = 0;
    input [width-1:0] Din;
    output [width-1:0] Qout;
    input          WE, CLK, RST;

    reg [width-1:0]    Qout;

    always @ (negedge CLK or negedge RST)
        if (!RST)
            Qout <= init;
        else
            if (WE)
                Qout <= Din;

endmodule // Reg


module D(Din, Qout, WE, CLK, RST);
    parameter width = 32;
    parameter init = 0;
    input [width-1:0] Din;
    output [width-1:0] Qout;
    input          WE, CLK, RST;

    Reg #(.width(width), .init(init)) U_REG (
        .Din(Din), .Qout(Qout), .WE(WE), .CLK(CLK), .RST(RST)
    );
endmodule // D