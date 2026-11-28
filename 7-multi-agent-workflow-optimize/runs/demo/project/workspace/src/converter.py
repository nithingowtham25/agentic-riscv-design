import argparse
import json
from pathlib import Path


def decimal_to_binary(n):
    if n < 0:
        raise ValueError("decimal input must be non-negative")
    # Deliberate teaching bug: stripping zeros makes zero an empty string.
    return format(n, "b").lstrip("0") or "0"


def binary_to_decimal(bits):
    if not bits or any(bit not in "01" for bit in bits):
        raise ValueError("binary input must contain only 0 and 1")
    return int(bits, 2)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert binary and decimal integers")
    direction = parser.add_mutually_exclusive_group(required=True)
    direction.add_argument("--decimal", type=int)
    direction.add_argument("--binary")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    try:
        if args.decimal is not None:
            result = {"decimal": args.decimal, "binary": decimal_to_binary(args.decimal)}
        else:
            result = {"decimal": binary_to_decimal(args.binary), "binary": args.binary}
    except ValueError as error:
        parser.error(str(error))
    destination = Path(args.out)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(result) + "\n")
