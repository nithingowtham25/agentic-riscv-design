module alu (
    input  logic [31:0] A,
    input  logic [31:0] B,
    input  logic [2:0]  ALUSelect,
    input  logic        SubArith,
    output logic [31:0] ALUResult,
    output logic [31:0] Sum
);

    //--------------------------------------------------------------------------
    // Design analysis
    //
    // 1) Inputs / outputs
    //    - A         : 32-bit input operand
    //    - B         : 32-bit input operand
    //    - ALUSelect : 3-bit operation select
    //    - SubArith  : modifies arithmetic/compare/shift behavior where defined
    //    - ALUResult : 32-bit selected ALU operation result
    //    - Sum       : independent 32-bit add/sub result
    //
    // 2) Required operations
    //    ALUSelect  SubArith  Operation
    //      000        0       ADD   -> A + B
    //      000        1       SUB   -> A - B
    //      001        0       SLL   -> A << B[4:0]
    //      010        1       SLT   -> signed(A) < signed(B)
    //      011        1       SLTU  -> A < B
    //      100        0       XOR   -> A ^ B
    //      101        0       SRL   -> A >> B[4:0]
    //      101        1       SRA   -> signed(A) >>> B[4:0]
    //      110        0       OR    -> A | B
    //      111        0       AND   -> A & B
    //
    //    Sum is always:
    //      SubArith=0 -> A + B
    //      SubArith=1 -> A - B
    //
    // 3) Corner cases
    //    - No reset: block is purely combinational.
    //    - Shift amount uses only B[4:0].
    //    - Arithmetic is 32-bit modular wraparound.
    //    - SLT is signed comparison; SLTU is unsigned comparison.
    //    - Arithmetic right shift must replicate sign bit.
    //    - For undefined ALUSelect/SubArith combinations, do not add behavior
    //      beyond the spec; drive a deterministic default value.
    //
    // 4) Combinational vs sequential
    //    - Entire block is combinational.
    //    - No always_ff, no latches, no state.
    //
    // 5) RTL structure
    //    - Compute Sum in combinational logic from SubArith.
    //    - Compute ALUResult in an always_comb case statement using ALUSelect,
    //      with SubArith checked where applicable.
    //--------------------------------------------------------------------------

    always_comb begin
        // Independent add/sub output used elsewhere in the datapath.
        if (SubArith) begin
            Sum = A - B;
        end else begin
            Sum = A + B;
        end
    end

    always_comb begin
        // Deterministic default for unspecified control combinations.
        ALUResult = 32'h00000000;

        unique case (ALUSelect)
            3'b000: begin
                // ADD / SUB
                ALUResult = Sum;
            end

            3'b001: begin
                // SLL defined for SubArith=0
                if (!SubArith) begin
                    ALUResult = A << B[4:0];
                end
            end

            3'b010: begin
                // SLT defined for SubArith=1
                if (SubArith) begin
                    ALUResult = ($signed(A) < $signed(B)) ? 32'h00000001 : 32'h00000000;
                end
            end

            3'b011: begin
                // SLTU defined for SubArith=1
                if (SubArith) begin
                    ALUResult = (A < B) ? 32'h00000001 : 32'h00000000;
                end
            end

            3'b100: begin
                // XOR defined for SubArith=0
                if (!SubArith) begin
                    ALUResult = A ^ B;
                end
            end

            3'b101: begin
                // SRL / SRA
                if (SubArith) begin
                    ALUResult = $signed(A) >>> B[4:0];
                end else begin
                    ALUResult = A >> B[4:0];
                end
            end

            3'b110: begin
                // OR defined for SubArith=0
                if (!SubArith) begin
                    ALUResult = A | B;
                end
            end

            3'b111: begin
                // AND defined for SubArith=0
                if (!SubArith) begin
                    ALUResult = A & B;
                end
            end

            default: begin
                ALUResult = 32'h00000000;
            end
        endcase
    end

endmodule