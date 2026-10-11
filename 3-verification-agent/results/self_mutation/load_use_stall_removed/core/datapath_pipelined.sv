// datapath_pipelined.sv: The 5-stage pipelined RV32I core you build (Task 1). Edit THIS file.
// datapath_pipelined.sv: Fetch->Decode->Execute->Memory->Writeback. The pipeline registers are wired for
// datapath_pipelined.sv: you; you fill the three TODO regions below: the forwarding unit, the load-use
// datapath_pipelined.sv: hazard-detection unit (stall), and the redirect/flush logic. As shipped, those
// datapath_pipelined.sv: TODOs are stubbed to safe defaults, so the core compiles but produces WRONG
// datapath_pipelined.sv: results until you implement them. Also replace the stub modules in submodules/
// datapath_pipelined.sv: with your own (alu/regfile/extend/controller from Assignment 1, branch_unit/memory_access
// datapath_pipelined.sv: from Assignment 2). See docs/pipeline_diagram.md, forwarding_truth_table.md, hazard_unit_spec.md.
//
// Top-level I/O: instruction memory is combinational-read at PC (Harvard), data memory is synchronous
// (same memory model as the Assignment 2 single-cycle core). Do not change the module name or its ports.
module datapath_pipelined(
    input  logic        clk, reset,
    input  logic [31:0] InstrF,          // instruction fetched at PC (combinational instr memory)
    input  logic [31:0] ReadData,        // data-memory read result (valid in Memory stage)
    output logic [31:0] PCF,             // program counter (Fetch)
    output logic [31:0] DataAdr,         // data-memory address (Memory stage)
    output logic [31:0] WriteData,       // data-memory store data (Memory stage)
    output logic [3:0]  ByteEnable,
    output logic        MemRead, MemWrite,
    output logic        IllegalInstr     // illegal instruction currently in the Execute stage
);
    // ----------------------------------------------------------------------------------
    // Fetch (F)
    // ----------------------------------------------------------------------------------
    logic [31:0] PCNextF, PCPlus4F;
    logic        StallF, StallD, FlushD, FlushE;
    assign PCPlus4F = PCF + 32'd4;

    always_ff @(posedge clk) begin
        if (reset)       PCF <= 32'b0;
        else if (StallF) PCF <= PCF;          // hold PC on a load-use stall
        else             PCF <= PCNextF;
    end

    // ----------------------------------------------------------------------------------
    // F/D pipeline register
    // ----------------------------------------------------------------------------------
    logic [31:0] InstrD, PCD, PCPlus4D;
    always_ff @(posedge clk) begin
        if (reset || FlushD) begin
            InstrD <= 32'h00000013;           // NOP (addi x0,x0,0)
            PCD <= 32'b0; PCPlus4D <= 32'b0;
        end else if (!StallD) begin
            InstrD <= InstrF; PCD <= PCF; PCPlus4D <= PCPlus4F;
        end
    end

    // ----------------------------------------------------------------------------------
    // Decode (D): control + immediate + register read
    // ----------------------------------------------------------------------------------
    logic        RegWriteD, ALUSrcAD, ALUSrcBD, BranchD, JumpD, ALUResultSrcD, SubArithD, IllegalInstrD;
    logic [2:0]  ImmSrcD, ResultSrcD, ALUSelectD;
    logic [1:0]  MemRWD;
    logic [31:0] rd1D, rd2D, ImmExtD;
    logic [4:0]  Rs1D, Rs2D, RdD;

    assign Rs1D = InstrD[19:15];
    assign Rs2D = InstrD[24:20];
    assign RdD  = InstrD[11:7];

    controller c(.InstrD(InstrD), .RegWriteD(RegWriteD), .ImmSrcD(ImmSrcD),
        .ALUSrcAD(ALUSrcAD), .ALUSrcBD(ALUSrcBD), .MemRWD(MemRWD), .ResultSrcD(ResultSrcD),
        .BranchD(BranchD), .JumpD(JumpD), .ALUResultSrcD(ALUResultSrcD),
        .ALUSelectD(ALUSelectD), .SubArithD(SubArithD), .IllegalInstrD(IllegalInstrD));
    extend ex(.InstrD(InstrD[31:7]), .ImmSrcD(ImmSrcD), .ImmExtD(ImmExtD));

    // Register file: written in Writeback (falling edge inside regfile), read in Decode.
    logic        RegWriteW;
    logic [4:0]  RdW;
    logic [31:0] WritebackDataW;
    regfile rf(.clk(clk), .reset(reset), .we3(RegWriteW),
        .a1(Rs1D), .a2(Rs2D), .a3(RdW), .wd3(WritebackDataW), .rd1(rd1D), .rd2(rd2D));

    // ----------------------------------------------------------------------------------
    // D/E pipeline register
    // ----------------------------------------------------------------------------------
    logic        RegWriteE, ALUSrcAE, ALUSrcBE, BranchE, JumpE, ALUResultSrcE, SubArithE, IllegalInstrE;
    logic [2:0]  ResultSrcE, ALUSelectE, Funct3E;
    logic [1:0]  MemRWE;
    logic [31:0] rd1E, rd2E, ImmExtE, PCE, PCPlus4E;
    logic [4:0]  Rs1E, Rs2E, RdE;
    logic [6:0]  OpcodeE;

    always_ff @(posedge clk) begin
        if (reset || FlushE) begin
            RegWriteE <= 1'b0; ALUSrcAE <= 1'b0; ALUSrcBE <= 1'b0; BranchE <= 1'b0; JumpE <= 1'b0;
            ALUResultSrcE <= 1'b0; SubArithE <= 1'b0; IllegalInstrE <= 1'b0;
            ResultSrcE <= 3'b0; ALUSelectE <= 3'b0; Funct3E <= 3'b0; MemRWE <= 2'b0;
            rd1E <= 32'b0; rd2E <= 32'b0; ImmExtE <= 32'b0; PCE <= 32'b0; PCPlus4E <= 32'b0;
            Rs1E <= 5'b0; Rs2E <= 5'b0; RdE <= 5'b0; OpcodeE <= 7'b0;
        end else begin
            RegWriteE <= RegWriteD; ALUSrcAE <= ALUSrcAD; ALUSrcBE <= ALUSrcBD;
            BranchE <= BranchD; JumpE <= JumpD; ALUResultSrcE <= ALUResultSrcD;
            SubArithE <= SubArithD; IllegalInstrE <= IllegalInstrD;
            ResultSrcE <= ResultSrcD; ALUSelectE <= ALUSelectD; Funct3E <= InstrD[14:12];
            MemRWE <= MemRWD; rd1E <= rd1D; rd2E <= rd2D; ImmExtE <= ImmExtD;
            PCE <= PCD; PCPlus4E <= PCPlus4D; Rs1E <= Rs1D; Rs2E <= Rs2D; RdE <= RdD;
            OpcodeE <= InstrD[6:0];
        end
    end

    // ----------------------------------------------------------------------------------
    // E/M pipeline register signals (declared before Execute so the forwarding muxes can read
    // ALUResultM / RdM / RegWriteM without a use-before-declaration error).
    // ----------------------------------------------------------------------------------
    logic        RegWriteM, ALUResultSrcM, JumpM;
    logic [2:0]  ResultSrcM, Funct3M;
    logic [1:0]  MemRWM;
    logic [31:0] ALUResultM, SumM, WriteDataM, ImmExtM, PCPlus4M;
    logic [4:0]  RdM;

    // ----------------------------------------------------------------------------------
    // Execute (E): forwarding, ALU, branch resolution
    // ----------------------------------------------------------------------------------
    logic [1:0]  ForwardAE, ForwardBE;   // 00 = reg, 10 = from Memory (ALU result), 01 = from Writeback
    logic [31:0] ForwardedA, ForwardedB, SrcAE, SrcBE, ALUResultE, SumE, PCTargetE;
    logic        BranchCondE, PCSrcE;

    // Forwarding muxes select the freshest value for each source operand.
    always_comb begin
        case (ForwardAE)
            2'b10:   ForwardedA = ALUResultM;      // EX/MEM ALU result
            2'b01:   ForwardedA = WritebackDataW;  // MEM/WB writeback value
            default: ForwardedA = rd1E;
        endcase
        case (ForwardBE)
            2'b10:   ForwardedB = ALUResultM;
            2'b01:   ForwardedB = WritebackDataW;
            default: ForwardedB = rd2E;
        endcase
    end

    assign SrcAE = ALUSrcAE ? PCE : ForwardedA;
    assign SrcBE = ALUSrcBE ? ImmExtE : ForwardedB;
    alu a(.A(SrcAE), .B(SrcBE), .ALUSelect(ALUSelectE), .SubArith(SubArithE),
        .ALUResult(ALUResultE), .Sum(SumE));
    // Branch/jump comparison uses the forwarded register values (not the ALU inputs).
    branch_unit bu(.A(ForwardedA), .B(ForwardedB), .Funct3(Funct3E),
        .Branch(BranchE), .Jump(JumpE), .BranchCond(BranchCondE), .PCSrc(PCSrcE));
    // Redirect target: the ALU adder ('Sum') produces PC+imm (branch/JAL) or rs1+imm (JALR),
    // because the controller sets ALUSrcA/B accordingly. JALR (opcode 1100111) masks bit 0.
    // This mirrors the Assignment 2 single-cycle datapath's PCTarget logic, one stage later.
    logic [31:0] RedirectTargetE;
    assign PCTargetE = SumE;   // adder output; naming kept for clarity
    assign RedirectTargetE = (JumpE && OpcodeE == 7'b1100111) ? {SumE[31:1],1'b0} : SumE;

    assign IllegalInstr = IllegalInstrE;

    // ----------------------------------------------------------------------------------
    // E/M pipeline register (signals declared above the Execute stage)
    // ----------------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            RegWriteM <= 1'b0; ALUResultSrcM <= 1'b0; JumpM <= 1'b0;
            ResultSrcM <= 3'b0; Funct3M <= 3'b0; MemRWM <= 2'b0;
            ALUResultM <= 32'b0; SumM <= 32'b0; WriteDataM <= 32'b0; ImmExtM <= 32'b0;
            PCPlus4M <= 32'b0; RdM <= 5'b0;
        end else begin
            RegWriteM <= RegWriteE; ALUResultSrcM <= ALUResultSrcE; JumpM <= JumpE;
            ResultSrcM <= ResultSrcE; Funct3M <= Funct3E; MemRWM <= MemRWE;
            ALUResultM <= ALUResultE; SumM <= SumE; WriteDataM <= ForwardedB; ImmExtM <= ImmExtE;
            PCPlus4M <= PCPlus4E; RdM <= RdE;
        end
    end

    // ----------------------------------------------------------------------------------
    // Memory (M): data-memory access
    // ----------------------------------------------------------------------------------
    logic [31:0] LoadDataM, IEUResultM, AltResultM;
    assign DataAdr   = SumM;
    assign MemRead   = (MemRWM == 2'b10);
    assign MemWrite  = (MemRWM == 2'b01);
    // memory_access drives the top-level WriteData (byte-lane-aligned store data); StoreData is the
    // raw register value carried from Execute (WriteDataM = the forwarded rs2 latched at E/M).
    memory_access ma(.MemRW(MemRWM), .Funct3(Funct3M), .AddrLSB(DataAdr[1:0]),
        .StoreData(WriteDataM), .ReadData(ReadData), .WriteData(WriteData),
        .ByteEnable(ByteEnable), .LoadData(LoadDataM));

    assign AltResultM = JumpM ? PCPlus4M : ImmExtM;
    assign IEUResultM = ALUResultSrcM ? AltResultM : ALUResultM;

    // ----------------------------------------------------------------------------------
    // M/W pipeline register
    // ----------------------------------------------------------------------------------
    logic [2:0]  ResultSrcW;
    logic [31:0] IEUResultW, LoadDataW;
    always_ff @(posedge clk) begin
        if (reset) begin
            RegWriteW <= 1'b0; ResultSrcW <= 3'b0; IEUResultW <= 32'b0; LoadDataW <= 32'b0; RdW <= 5'b0;
        end else begin
            RegWriteW <= RegWriteM; ResultSrcW <= ResultSrcM;
            IEUResultW <= IEUResultM; LoadDataW <= LoadDataM; RdW <= RdM;
        end
    end

    // ----------------------------------------------------------------------------------
    // Writeback (W)
    // ----------------------------------------------------------------------------------
    assign WritebackDataW = (ResultSrcW == 3'b001) ? LoadDataW : IEUResultW;

    // ==================================================================================
    // TODO 1 of 3 - FORWARDING UNIT.  See docs/forwarding_truth_table.md.
    // Set ForwardAE (source A) and ForwardBE (source B) each cycle:
    //   2'b10 = forward from the Memory stage   (producer signals: RegWriteM, RdM)
    //   2'b01 = forward from the Writeback stage (producer signals: RegWriteW, RdW)
    //   2'b00 = no forwarding (use the register value)
    // Rules: forward when an in-flight producer's destination == this operand's source register
    //   (Rs1E for A, Rs2E for B); Memory stage has priority over Writeback; never forward to x0.
    // The stub below forwards nothing (2'b00) -> RAW hazards read stale data -> the core will FAIL
    // dependent-instruction tests until you implement this correctly.
    // ----------------------------------------------------------------------------------
    always_comb begin
        if (RegWriteM && (RdM != 5'b0) && (RdM == Rs1E))
            ForwardAE = 2'b10;
        else if (RegWriteW && (RdW != 5'b0) && (RdW == Rs1E))
            ForwardAE = 2'b01;
        else
            ForwardAE = 2'b00;

        if (RegWriteM && (RdM != 5'b0) && (RdM == Rs2E))
            ForwardBE = 2'b10;
        else if (RegWriteW && (RdW != 5'b0) && (RdW == Rs2E))
            ForwardBE = 2'b01;
        else
            ForwardBE = 2'b00;
    end
    // ==================================================================================

    // ==================================================================================
    // TODO 2 of 3 - HAZARD-DETECTION UNIT (load-use stall).  See docs/hazard_unit_spec.md.
    // A load in the Execute stage (ResultSrcE == 3'b001 marks a load) whose destination RdE feeds a
    // dependent instruction in Decode cannot forward in time -> the pipeline must stall one cycle.
    // Set LoadUseHazard = 1 when: the instruction in E is a load AND its RdE (non-x0) equals Rs1D or
    // Rs2D of the instruction in D.
    // The stub below never stalls (1'b0) -> a load immediately followed by a dependent op reads stale
    // data -> the core will FAIL load-use tests until you implement this correctly.
    // ----------------------------------------------------------------------------------
    logic LoadUseHazard;
    assign LoadUseHazard = 1'b0;
    // ==================================================================================

    // ==================================================================================
    // TODO 3 of 3 - CONTROL-FLOW REDIRECT + FLUSH.  See docs/hazard_unit_spec.md.
    // A taken branch or any jump resolves in the Execute stage (PCSrcE == 1). When that happens the two
    // younger instructions already fetched (in Decode and Execute) are on the wrong path and must be
    // flushed, and the PC must be redirected to RedirectTargetE.
    // Set:
    //   RedirectE = 1 when a redirect is needed (PCSrcE already combines taken-branch | jump)
    //   PCNextF   = the redirect target when redirecting, else the sequential PC+4 (PCPlus4F)
    //   StallF, StallD = hold Fetch and Decode during a load-use stall
    //   FlushD = insert a bubble in Decode on a redirect
    //   FlushE = insert a bubble in Execute on a redirect OR a load-use stall
    // The stubs below never redirect or flush -> wrong-path instructions after a taken branch/jump will
    // execute, and load-use bubbles won't be inserted -> the core will FAIL branch/jump tests until you
    // implement this correctly.
    // ----------------------------------------------------------------------------------
    logic RedirectE;
    assign RedirectE = PCSrcE;
    assign PCNextF   = RedirectE ? RedirectTargetE : PCPlus4F;
    assign StallF    = LoadUseHazard;
    assign StallD    = LoadUseHazard;
    assign FlushD    = RedirectE;
    assign FlushE    = RedirectE || LoadUseHazard;
    // ==================================================================================
endmodule
