# CompEng 361 — Lab 3: Single-Cycle RV32I Processor

## 1. Overview & Rules

In Lab 3, you will design and verify a **single-cycle 32-bit RISC-V (`RV32I`) processor in structural Verilog**:
- **Single file submission:** Name your file `<group>_lab3.v` (starting from `template_lab3.v`).
- **Structural Verilog only:** Use only continuous `assign` statements and module instantiations (`Mem`, `RegFile`, `Reg` / `D`, and your own combinational/structural submodules). Do **not** use `always`, `initial`, `reg`, procedural `if`/`case` blocks, or `` `include `` directives.
- **Unmodified library interfaces:** Do not change the module names or port lists of `SingleCycleCPU`, `Mem`, `RegFile`, or `Reg` in `lab3_tb.v`.

---

## 2. Quick Start (One-Command Workflow)

Run the entire public test suite (grouped into **Milestone A** and **Milestone B**) against your processor with a single command:

```bash
python3 run_tests.py <group>_lab3.v
```

Or using `make`:

```bash
make test CPU=<group>_lab3.v
```

### Useful Filtering Options

```bash
# Run only Milestone A tests (see Canvas for milestone deadlines):
python3 run_tests.py <group>_lab3.v --tier A

# Run a single test (also writes trace.txt and single.vcd in the current directory):
python3 run_tests.py <group>_lab3.v --test srai

# Compare any generated trace.txt against a golden trace directly:
python3 tracediff.py trace.txt tests/golden/srai.trace
```

### Manual Compilation & Simulation

You can also compile and run directly with `iverilog` as usual:

```bash
iverilog -o <group>_lab3 <group>_lab3.v lab3_tb.v
./<group>_lab3 +MEM_IN=tests/build/add.hex +REGS_IN=regs_in.hex
python3 tracediff.py trace.txt tests/golden/add.trace
```

---

## 3. ISA & Halt Specification

### Supported Instructions (`RV32I` Base Integer ISA)

- **Milestone A Tier (45 public tests):**
  - **Register-Immediate ALU (`0010011`):** `addi`, `slti`, `sltiu`, `xori`, `ori`, `andi`, `slli` (`funct7=0000000`), `srli` (`funct7=0000000`), `srai` (`funct7=0100000`)
  - **Register-Register ALU (`0110011`):** `add`, `sub`, `sll`, `slt`, `sltu`, `xor`, `srl`, `sra`, `or`, `and`
  - **Loads (`0000011`):** `lb`, `lh`, `lw`, `lbu`, `lhu`
  - **Stores (`0100011`):** `sb`, `sh`, `sw`
  - **Conditional Branches (`1100011`):** `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`
  - **Milestone A Halting Conditions:** Illegal/unsupported instructions and misaligned loads/stores.
- **Milestone B Tier (11 new public tests + all Milestone A tests):**
  - **Upper Immediates:** `lui` (`0110111`), `auipc` (`0010111`)
  - **Unconditional Jumps:** `jal` (`1101111`), `jalr` (`1100111`, `funct3=000`)
  - **Milestone B Halting Conditions:** Misaligned instruction fetch targets on taken branches, `jal`, and `jalr`.
  - **C Programs:** Full bare-metal RV32I C programs with stack frames, nested loops, and data structures.

### Exact Halt Semantics

Your CPU must assert `halt = 1` in the current clock cycle when any of the following occur:
1. **Unsupported or illegal instruction:**
   - Any opcode outside the RV32I base set above (including `ecall`, `ebreak`, CSR instructions, `fence`, and all `0000000` words). Note: normal test programs end by executing `ecall` (`0x00000073`), which causes a clean halt.
   - Any M-extension instruction (`opcode = 0110011`, `funct7 = 0000001`, such as `mul`, `div`, `rem`).
   - Any invalid `funct3` or `funct7` field for the given opcode (e.g., `jalr` with `funct3 != 000`, `slli` with `funct7 != 0000000`, load with `funct3 = 011`, store with `funct3 >= 011`, branch with `funct3 = 010` or `011`).
2. **Misaligned data load or store:**
   - Halfword accesses (`lh`, `lhu`, `sh`) require **2-byte alignment** (`DataAddr[0] == 1'b0`).
   - Word accesses (`lw`, `sw`) require **4-byte alignment** (`DataAddr[1:0] == 2'b00`).
3. **Misaligned instruction fetch:**
   - Current `PC` is not 4-byte aligned (`PC[1:0] != 2'b00`), OR the next PC (`NPC`) for a **taken** conditional branch, `jal`, or `jalr` is not 4-byte aligned (`NPC[1:0] != 2'b00`).
   - **Important (`jalr` target rule):** For `jalr`, clear bit 0 of `(Rdata1 + ImmI)` **first** (`target = (Rdata1 + ImmI) & ~32'd1`), then check 4-byte alignment (`target[1:0] == 2'b00`).
   - An **untaken** conditional branch proceeds to `PC + 4` and does **not** halt even if its branch offset is not a multiple of 4.
4. **No state updates on the halting instruction:**
   - The halting instruction is **not executed**: it must **not** write to the register file (`RWrEn = 0`), must **not** write to data memory (`MemWrEn = 0`), and must **not** execute further instructions.

---

## 4. Understanding the Trace Format & `tracediff.py` Messages

During simulation, `lab3_tb.v` automatically records one line per executed instruction to `trace.txt`:

```text
<n> pc=<8 hex> inst=<8 hex> [rd=x<N>:<8 hex>] [ld=<8 hex addr>:<size>] [st=<8 hex addr>:<size>:<data>]
```

- `n` is the 1-indexed instruction number.
- `rd=x<N>:<val>` shows the value written to register `x<N>` (writes to `x0` are omitted).
- `ld=<addr>:<size>` shows the effective address and byte width (`1`, `2`, or `4`) of a load.
- `st=<addr>:<size>:<data>` shows the effective address, byte width (`1`, `2`, or `4`), and size-masked store data of a store.
- When `halt` is asserted, the trace ends with:
  ```text
  HALT pc=<8 hex> inst=<8 hex>
  ```
- Unknown (`X`/`Z`) signal bits appear as `x` in the trace so uninitialized wires are immediately visible.

### What `tracediff.py` Diagnostic Messages Mean

1. **Value or Address Divergence on an Instruction:**
   ```text
   Divergence at instruction 37
     PC 0x00000090: srai x14, x1, 7
     yours:    x14 <- 0x01ffffff
     expected: x14 <- 0xffffffff
   ```
   Your CPU fetched the right instruction at `PC`, but wrote the wrong value (or wrong register, load address/size, or store address/size/data).

2. **Wrong PC Fetched (Control-Flow Divergence):**
   ```text
   Divergence at instruction 12 (wrong PC fetched)
     yours:    PC 0x00000034 (addi x1, x0, 1)
     expected: PC 0x00000030 (addi x6, x14, 0)
   ```
   The **previous** instruction (instruction 11, typically a branch, `jal`, or `jalr`) computed the wrong `NPC` or wrong branch condition.

3. **Halted Early:**
   ```text
   Halted early at instruction 15
     PC 0x00000038: srli x14, x1, 4
     yours:    HALT at PC 0x00000038 (srli x14, x1, 4)
     expected: instruction 15 to execute normally
   ```
   Your `halt` signal was asserted on a valid instruction. Check your `invalid_op` and alignment logic.

4. **Ran Past Where CPU Should Have Halted:**
   ```text
   Ran past where CPU should have halted (at step 7)
     PC 0x00000018: lw x3, 2(x1)
     yours:    executed instruction at PC 0x00000018 (lw x3, 2(x1)) [x3 <- 0x00000123, load mem[0x00001002] (4 bytes)]
     expected: HALT at PC 0x00000018 (lw x3, 2(x1))
   ```
   The instruction at `PC 0x00000018` should have triggered `halt = 1` (e.g., illegal opcode or misaligned address), but your CPU kept running.

5. **State Changed on the Halting Instruction (`stray_rd` / `stray_st`):**
   ```text
   State changed on the halting instruction
     PC 0x00000008: mul x3, x1, x2 [unsupported M-ext]
     yours:    HALT with stray register write (x3 <- 0x0000000d)
     expected: HALT with no register or memory writes
   ```
   Your CPU asserted `halt = 1` at the right instruction, **but** forgot to disable `RWrEn` or `MemWrEn` when `halt` is high (`assign RWrEn = ... && !halt;` and `assign MemWrEn = ... && !halt;`).

6. **Simulation Timed Out (`TIMEOUT`):**
   Your CPU ran for 100,000 cycles without asserting `halt` (either stuck in an infinite branch/PC loop, or `halt` was never asserted on `ecall`).

---

## 5. Golden Trace Reference Model & Pinned Tool Versions

### Why the Cycle-Accurate RV32I Reference Model (Not Raw Spike) Defines the Golden Traces

In Lab 3, the hardware testbench (`lab3_tb.v`) resets `PC` directly to `0x00000000` with all 32 registers (`x0`..`x31`) initialized to `0x00000000`, using a flat 16 KiB memory at `0x00000000..0x00003fff` and no CSR/privilege instructions (`Zicsr`).

By contrast, Spike (`riscv-isa-sim`) hardcodes its internal Debug Module at `0x00000000..0x00000fff` and its Boot ROM at `0x00001000..0x00001fff` (which executes `auipc`, `addi`, `csrr a0, mhartid`, `lw`, `jr` before jumping to user code, modifying `x5` and `x11` and requiring `Zicsr`), and treats `fence` as a valid instruction rather than halting. Therefore, the golden traces in `tests/golden/*.trace` are generated by the Lab 3 cycle-accurate RV32I reference model (`tools/rv32i_ref.py`) at base `0x00000000`, and independently cross-checked against:
1. All 37 unmodified self-checking `riscv-tests` `rv32ui` pass/fail programs (`RVTEST_PASS` / `RVTEST_FAIL`).
2. Spike (`--isa=rv32i -m0x100000:0x10000 --pc=0x100000 -l --log-commits`) relocated to `DRAM_BASE = 0x00100000` (`DRAM_END = 0x00110000`):
   - **Note (a) — Milestone A `la` macro difference:** For Milestone A tests (which expand `la` using `addi` + `slli` + `addi` instead of `auipc`), the Spike verification binary is compiled with `-DSPIKE_RUN=1` so the first `addi` of `la` loads high page `0x101` (for `.data` at `0x00101000`) instead of `0x001` (for `.data` at `0x00001000`). Consequently, the Spike verification binary is not byte-identical to the shipped `0x00000000` binary on those `la` instructions.
   - **Note (b) — Exact value-range rules for Spike offset correction (`- 0x00100000`):**
     - **PC & load/store addresses (`ld=`, `st=`):** Subtract `0x00100000` when the address is in `[0x00100000, 0x00110000)`.
     - **`auipc` (`opcode = 0010111`):** Always subtract `0x00100000` from `rd`. In `auipc.S`, a wider window `[0x000fc000, 0x00110000)` (`[DRAM_BASE - 0x4000, DRAM_END)`) is used so negative `addi` offsets applied to an `auipc` base near `0x00100000` are also adjusted by `- 0x00100000`.
     - **Milestone A `la` macro (`rd=`):** When `inst_zero != inst_spk` and `val == 0x101`, normalize to `0x001`; for the shifted/offset `.data` pointer in `[0x00100f00, 0x00102000)`, subtract `0x00100000`.
     - **`jal`/`jalr` link values, code-label pointers, and C stack/data pointers:** Subtract `0x00100000` when the value is in `[0x00100000, 0x00110000)`.

### Pinned Tool Versions (Wilkinson EECS Environment)

- **Library & Testbench Version:** `2.0 (2026-FA-RV32I-TRACE)`
- **Icarus Verilog (`iverilog`):** `14.0 (devel) (s20260301-154-gcc86f69a8)`
- **RISC-V GNU Toolchain (`riscv64-unknown-elf-gcc`):** `/opt/riscv64/bin/riscv64-unknown-elf-gcc`
- **Spike ISA Simulator (`riscv-isa-sim`):** `1.1.1-dev` (commit `9c190a07c6838f6392bafa4ad83acea462c7f759`)
- **Upstream `riscv-tests` Commit:** `d081949d96d374949e3ac5b849608dda251825d0`
- **Python:** `Python 3.6+` (pure standard library, no third-party packages required)
