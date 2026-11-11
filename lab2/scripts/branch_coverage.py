"""Generate a simulation-only RTL copy and summarize branch hits from ModelSim."""
import argparse
import re
from pathlib import Path

DECISIONS = {
    "read": "presetn && psel && !pwrite && !pslverr",
    "reset": "!presetn",
    "write": "pready && pwrite && !pslverr",
    "subtract": "pwdata[0]",
}
READ = ["operand1", "operand2", "control", "result", "default"]
WRITE = ["operand1", "operand2", "control", "default"]
POINTS = ([f"{name}.{value}" for name in DECISIONS for value in (0, 1)]
          + [f"read_case.{name}" for name in READ]
          + [f"write_case.{name}" for name in WRITE])


def instrument(src):
    def replace_once(old, new):
        nonlocal src
        if src.count(old) != 1:
            raise ValueError(f"expected one RTL occurrence of {old!r}")
        src = src.replace(old, new, 1)

    for name, expr in DECISIONS.items():
        replace_once(f"if ({expr})", f'if (cov_dec("{name}", {expr}))')
    for label, signal in zip(("BASE", "BASE + 4", "BASE + 8", "BASE + 12", "default"), READ):
        expr = "0" if signal == "default" else signal
        match = re.search(r"(?m)^(\s*)" + re.escape(label)
                          + r":\s+prdata = " + expr + r";", src)
        if match is None:
            raise ValueError(f"missing read case {label}")
        replace_once(match[0], f'{match[1]}{label}: begin '
                     f'$display("COV read_case.{signal}"); prdata = {expr}; end')
    for label, signal in zip(("BASE", "BASE + 4"), WRITE[:2]):
        stmt = f"{label}: {signal} <= pwdata;"
        replace_once(stmt, f'{label}: begin $display("COV write_case.{signal}"); '
                     f'{signal} <= pwdata; end')
    replace_once("BASE + 8: begin\n                    control",
                 'BASE + 8: begin\n                    $display("COV write_case.control");\n'
                 "                    control")
    replace_once("default: begin end", 'default: begin $display("COV write_case.default"); end')
    replace_once("    logic valid_addr;", """    logic valid_addr;
    function automatic logic cov_dec(input string name, input logic value);
        $display("COV %s.%b", name, value === 1'b1);
        return value;
    endfunction""")
    return src


def summarize(logs):
    hit = set()
    for path in logs:
        text = path.read_text(encoding="utf-8", errors="replace")
        if not re.search(r"(?m)^\s*#?\s*PASS:", text):
            raise ValueError(f"no successful test in {path}")
        current = set(re.findall(r"(?m)^\s*#?\s*COV ([\w.]+)\s*$", text))
        hit.update(current)
        count = sum(p in current for p in POINTS)
        print(f"{path.name}: {count}/{len(POINTS)} ({count/len(POINTS):.2%})")
    count = sum(p in hit for p in POINTS)
    print(f"Combined: {count}/{len(POINTS)} ({count/len(POINTS):.2%})")
    print("Missed:", ", ".join(p for p in POINTS if p not in hit) or "none")
    for point in POINTS:
        print(f"{'HIT' if point in hit else 'MISS':4} {point}")


parser = argparse.ArgumentParser(description=__doc__)
commands = parser.add_subparsers(dest="cmd", required=True)
generate = commands.add_parser("instrument")
generate.add_argument("src", type=Path)
generate.add_argument("out", type=Path)
report = commands.add_parser("report")
report.add_argument("logs", type=Path, nargs="+")
args = parser.parse_args()
if args.cmd == "instrument":
    args.out.write_text(instrument(args.src.read_text(encoding="utf-8-sig")), encoding="utf-8")
else:
    summarize(args.logs)
