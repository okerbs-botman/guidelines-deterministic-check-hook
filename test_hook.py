#!/usr/bin/env python3
"""Tests that check_csharp_rules.sh detects all 15 deterministic violations in test_violations.cs"""
import subprocess
import sys

SCRIPT = ".claude/hooks/check_csharp_rules.sh"
TEST_FILE = "test_violations.cs"

EXPECTED = [
    "NO_VAR",
    "NO_RAW_EXCEPTION",
    "DATETIME_KIND",
    "NO_EQUALS_TRUE",
    "NO_GETALL_FIRST",
    "NO_COMMENTS",
    "TRAILING_NEWLINE",
    "NO_BLANK_AFTER_ATTR",
    "BRACELESS_CONDITIONAL",
    "TAB_INDENT",
    "VISIBILITY_ORDER",
    "HARDCODED_SN",
    "NO_FIRST_LAST",
    "NO_BLOCK_COMMENT",
    "RAW_SQL_WARNING",
]

result = subprocess.run(
    ["bash", SCRIPT, TEST_FILE],
    capture_output=True, text=True,
    cwd="/home/octokerbs/guidelines-deterministic-check-hook"
)

output = result.stdout
passed = 0
failed = 0

print("Hook output:")
print("-" * 60)
print(output)
print("-" * 60)
print()

for rule in EXPECTED:
    if rule in output:
        print(f"  PASS  {rule}")
        passed += 1
    else:
        print(f"  FAIL  {rule} - not detected")
        failed += 1

print(f"\n{passed}/{len(EXPECTED)} rules detected")

if failed:
    print("FAILED")
    sys.exit(1)
else:
    print("ALL RULES DETECTED")
