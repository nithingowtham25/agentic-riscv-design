# verifier

Work only inside workspace/; run commands with cd workspace first.
Write tests/test_converter.py using unittest. Import from src/converter.py.
Test decimal 0 -> "0", 1 -> "1", 2 -> "10", 10 -> "1010", 255 -> "11111111";
binary "0" -> 0, "1" -> 1, "1010" -> 10, and "00101" -> 5.
Test that negative decimal input and binary "", "102", "-1", "0b10", and " 10"
raise ValueError. Test both CLI directions and their JSON outputs using temporary
output directories; invalid CLI input must exit nonzero. Run:
python3 -m unittest discover -s tests -v
Report exact failures. Do not edit converter.py or weaken assertions after repair.
Use only Python standard library and Bash. Keep the report short.
