# Bug: missing case default / unhandled selector value

**Symptom:** an output becomes `x` (or holds a stale value) for a selector value the
`case` doesn't list; a testbench check on that value fails.

**Cause:** a `case` with no `default`, so unlisted values leave the output unassigned
(latch) or undefined. Common in decoders and muxes.

**Fix:** always provide a `default`, and prefer a leading default assignment before the
`case` for combinational blocks.

```verilog
always @(*) begin
    out = 0;                 // safe default
    case (sel)
        2'b00: out = a;
        2'b01: out = b;
        default: out = 0;
    endcase
end
```
