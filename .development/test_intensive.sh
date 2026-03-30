#!/usr/bin/env bash
set -euo pipefail

# Intensive test suite for check_csharp_rules.sh
# Tests correct detection, false positives, and edge cases

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/hooks/check_csharp_rules.sh"
TMPDIR_BASE=$(mktemp -d)
PASS=0
FAIL=0
TOTAL=0

cleanup() { rm -rf "$TMPDIR_BASE"; }
trap cleanup EXIT

# ── Helpers ─────────────────────────────────────────────────────────

tmpfile() {
    local name="${1:-test.cs}"
    echo "$TMPDIR_BASE/$name"
}

write_cs() {
    local file="$1"
    shift
    printf '%s\n' "$@" > "$file"
}

# Write content without trailing newline
write_cs_raw() {
    local file="$1"
    shift
    printf '%s' "$@" > "$file"
}

assert_detects() {
    local test_name="$1" rule="$2" file="$3"
    TOTAL=$((TOTAL + 1))
    local output
    output=$(bash "$SCRIPT" "$file" 2>&1) || true
    if echo "$output" | grep -q "$rule"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        echo "  FAIL  $test_name"
        echo "        Expected rule: $rule"
        echo "        Output: $(echo "$output" | head -5)"
    fi
}

assert_clean() {
    local test_name="$1" file="$2"
    TOTAL=$((TOTAL + 1))
    local output
    output=$(bash "$SCRIPT" "$file" 2>&1) || true
    if [[ -z "$output" ]]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        echo "  FAIL  $test_name"
        echo "        Expected clean, got:"
        echo "        $(echo "$output" | head -5)"
    fi
}

assert_not_detects() {
    local test_name="$1" rule="$2" file="$3"
    TOTAL=$((TOTAL + 1))
    local output
    output=$(bash "$SCRIPT" "$file" 2>&1) || true
    if echo "$output" | grep -q "$rule"; then
        FAIL=$((FAIL + 1))
        echo "  FAIL  $test_name"
        echo "        False positive for: $rule"
        echo "        Output: $(echo "$output" | head -5)"
    else
        PASS=$((PASS + 1))
    fi
}

section() {
    echo ""
    echo "── $1 ──"
}

# ═══════════════════════════════════════════════════════════════════
# NON-CS FILES AND EMPTY FILES
# ═══════════════════════════════════════════════════════════════════
section "Non-CS files and edge cases"

# Non-.cs file should be silently ignored
F=$(tmpfile "readme.txt")
echo "var x = 1;" > "$F"
assert_clean "Non-.cs file ignored" "$F"

F=$(tmpfile "script.js")
echo "var list = [];" > "$F"
assert_clean "JavaScript file ignored" "$F"

F=$(tmpfile "Program.cshtml")
echo "var x = 1;" > "$F"
assert_clean "cshtml file ignored" "$F"

# Empty .cs file
F=$(tmpfile "empty.cs")
touch "$F"
assert_clean "Empty .cs file" "$F"

# .cs file with only whitespace
F=$(tmpfile "whitespace.cs")
printf '   \n  \n' > "$F"
assert_clean "Whitespace-only .cs file" "$F"

# ═══════════════════════════════════════════════════════════════════
# R1: NO_VAR
# ═══════════════════════════════════════════════════════════════════
section "R1: NO_VAR"

F=$(tmpfile "r1_detect.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            var list = new List<int>();" \
    "        }" \
    "    }" \
    "}"
assert_detects "var basic" "NO_VAR" "$F"

F=$(tmpfile "r1_detect2.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            var x = 5;" \
    "            var y = \"hello\";" \
    "        }" \
    "    }" \
    "}"
assert_detects "var multiple" "NO_VAR" "$F"

# False positives
F=$(tmpfile "r1_clean.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            List<int> list = new List<int>();" \
    "            string variable = \"hello\";" \
    "        }" \
    "    }" \
    "}"
assert_not_detects "explicit type no false positive" "NO_VAR" "$F"

F=$(tmpfile "r1_varname.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private string varName = \"test\";" \
    "        private int myvar = 5;" \
    "        private string invariant = \"x\";" \
    "    }" \
    "}"
assert_not_detects "variable names containing 'var' substring" "NO_VAR" "$F"

# ═══════════════════════════════════════════════════════════════════
# R2: NO_RAW_EXCEPTION
# ═══════════════════════════════════════════════════════════════════
section "R2: NO_RAW_EXCEPTION"

F=$(tmpfile "r2_detect.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            throw new Exception(\"error\");" \
    "        }" \
    "    }" \
    "}"
assert_detects "throw new Exception" "NO_RAW_EXCEPTION" "$F"

F=$(tmpfile "r2_spaces.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            throw   new   Exception  (\"error\");" \
    "        }" \
    "    }" \
    "}"
assert_detects "throw new Exception with extra spaces" "NO_RAW_EXCEPTION" "$F"

F=$(tmpfile "r2_clean.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            throw new ArgumentNullException(\"param\");" \
    "            throw new InvalidOperationException(\"msg\");" \
    "            throw new CustomBusinessException();" \
    "        }" \
    "    }" \
    "}"
assert_not_detects "custom exceptions no false positive" "NO_RAW_EXCEPTION" "$F"

# ═══════════════════════════════════════════════════════════════════
# R3: DATETIME_KIND
# ═══════════════════════════════════════════════════════════════════
section "R3: DATETIME_KIND"

F=$(tmpfile "r3_detect.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            DateTime dt = new DateTime(2024, 1, 1);" \
    "        }" \
    "    }" \
    "}"
assert_detects "DateTime without Kind" "DATETIME_KIND" "$F"

F=$(tmpfile "r3_detect2.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            DateTime dt = new DateTime(2024, 6, 15, 10, 30, 0);" \
    "        }" \
    "    }" \
    "}"
assert_detects "DateTime with time but no Kind" "DATETIME_KIND" "$F"

F=$(tmpfile "r3_clean.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            DateTime dt = new DateTime(2024, 1, 1, 0, 0, 0, DateTimeKind.Utc);" \
    "            DateTime dt2 = new DateTime(2024, 1, 1, 0, 0, 0, DateTimeKind.Unspecified);" \
    "            DateTime now = DateTime.Now;" \
    "            DateTime utc = DateTime.UtcNow;" \
    "        }" \
    "    }" \
    "}"
assert_not_detects "DateTime with Kind no false positive" "DATETIME_KIND" "$F"

# ═══════════════════════════════════════════════════════════════════
# R4: NO_EQUALS_TRUE
# ═══════════════════════════════════════════════════════════════════
section "R4: NO_EQUALS_TRUE"

F=$(tmpfile "r4_detect.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            bool r = collection?.Any() == true;" \
    "        }" \
    "    }" \
    "}"
assert_detects "== true" "NO_EQUALS_TRUE" "$F"

F=$(tmpfile "r4_detect2.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            if (flag ==  true)" \
    "            {" \
    "            }" \
    "        }" \
    "    }" \
    "}"
assert_detects "== true with extra space" "NO_EQUALS_TRUE" "$F"

F=$(tmpfile "r4_clean.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            bool r = collection?.Any() ?? false;" \
    "            bool x = flag;" \
    "            bool y = !flag;" \
    "        }" \
    "    }" \
    "}"
assert_not_detects "?? false no false positive" "NO_EQUALS_TRUE" "$F"

# ═══════════════════════════════════════════════════════════════════
# R5: NO_GETALL_FIRST
# ═══════════════════════════════════════════════════════════════════
section "R5: NO_GETALL_FIRST"

F=$(tmpfile "r5_detect.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            ENTITY e = service.GetAll().FirstOrDefault(x => x.Id == 1);" \
    "        }" \
    "    }" \
    "}"
assert_detects "GetAll().FirstOrDefault()" "NO_GETALL_FIRST" "$F"

F=$(tmpfile "r5_clean.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            ENTITY e = service.FirstOrDefault(x => x.Id == 1);" \
    "            List<ENTITY> all = service.GetAll();" \
    "        }" \
    "    }" \
    "}"
assert_not_detects "direct FirstOrDefault no false positive" "NO_GETALL_FIRST" "$F"

# ═══════════════════════════════════════════════════════════════════
# R6: NO_COMMENTS
# ═══════════════════════════════════════════════════════════════════
section "R6: NO_COMMENTS"

F=$(tmpfile "r6_detect.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        // This is a prohibited comment" \
    "        private void M() { }" \
    "    }" \
    "}"
assert_detects "single-line comment" "NO_COMMENTS" "$F"

F=$(tmpfile "r6_detect2.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        //" \
    "        private void M() { }" \
    "    }" \
    "}"
assert_detects "empty // comment" "NO_COMMENTS" "$F"

F=$(tmpfile "r6_clean.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    /// <summary>" \
    "    /// XML doc comment" \
    "    /// </summary>" \
    "    public class C" \
    "    {" \
    "        private void M() { }" \
    "    }" \
    "}"
assert_not_detects "/// XML doc comments allowed" "NO_COMMENTS" "$F"

F=$(tmpfile "r6_url.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private string url = \"https://example.com\";" \
    "    }" \
    "}"
assert_not_detects "URL in string no false positive" "NO_COMMENTS" "$F"

# ═══════════════════════════════════════════════════════════════════
# R7: TRAILING_NEWLINE
# ═══════════════════════════════════════════════════════════════════
section "R7: TRAILING_NEWLINE"

F=$(tmpfile "r7_detect_none.cs")
write_cs_raw "$F" "namespace Test { }"
assert_detects "no trailing newline" "TRAILING_NEWLINE" "$F"

F=$(tmpfile "r7_detect_multi.cs")
printf 'namespace Test { }\n\n\n' > "$F"
assert_detects "multiple trailing newlines" "TRAILING_NEWLINE" "$F"

F=$(tmpfile "r7_clean.cs")
printf 'namespace Test { }\n' > "$F"
assert_clean "exactly one trailing newline" "$F"

# CRLF handling
F=$(tmpfile "r7_crlf.cs")
printf 'namespace Test { }\r\n' > "$F"
assert_not_detects "CRLF ending no false positive" "TRAILING_NEWLINE" "$F"

F=$(tmpfile "r7_crlf_multi.cs")
printf 'namespace Test { }\r\n\r\n\r\n' > "$F"
assert_detects "multiple CRLF trailing newlines" "TRAILING_NEWLINE" "$F"

# ═══════════════════════════════════════════════════════════════════
# R8: NO_BLANK_AFTER_ATTR
# ═══════════════════════════════════════════════════════════════════
section "R8: NO_BLANK_AFTER_ATTR"

F=$(tmpfile "r8_detect.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    [Table(\"TEST\")]" \
    "" \
    "    public class C { }" \
    "}"
assert_detects "blank after attribute" "NO_BLANK_AFTER_ATTR" "$F"

F=$(tmpfile "r8_clean.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    [Table(\"TEST\")]" \
    "    [Title(\"Test\")]" \
    "    public class C { }" \
    "}"
assert_not_detects "attributes adjacent no false positive" "NO_BLANK_AFTER_ATTR" "$F"

F=$(tmpfile "r8_array.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            int[] arr = new int[] { 1, 2, 3 };" \
    "" \
    "            Process(arr);" \
    "        }" \
    "    }" \
    "}"
assert_not_detects "array initializer ] not treated as attribute" "NO_BLANK_AFTER_ATTR" "$F"

# ═══════════════════════════════════════════════════════════════════
# R9: BRACELESS_CONDITIONAL
# ═══════════════════════════════════════════════════════════════════
section "R9: BRACELESS_CONDITIONAL"

F=$(tmpfile "r9_detect_if.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            if (x > 0)" \
    "                DoSomething();" \
    "        }" \
    "    }" \
    "}"
assert_detects "braceless if" "BRACELESS_CONDITIONAL" "$F"

F=$(tmpfile "r9_detect_for.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            for (int i = 0; i < 10; i++)" \
    "                list.Add(i);" \
    "        }" \
    "    }" \
    "}"
assert_detects "braceless for" "BRACELESS_CONDITIONAL" "$F"

F=$(tmpfile "r9_detect_foreach.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            foreach (int i in list)" \
    "                Process(i);" \
    "        }" \
    "    }" \
    "}"
assert_detects "braceless foreach" "BRACELESS_CONDITIONAL" "$F"

F=$(tmpfile "r9_detect_while.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            while (running)" \
    "                Poll();" \
    "        }" \
    "    }" \
    "}"
assert_detects "braceless while" "BRACELESS_CONDITIONAL" "$F"

F=$(tmpfile "r9_detect_else.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            if (x > 0)" \
    "            {" \
    "                A();" \
    "            }" \
    "            else" \
    "                B();" \
    "        }" \
    "    }" \
    "}"
assert_detects "braceless else" "BRACELESS_CONDITIONAL" "$F"

F=$(tmpfile "r9_clean.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            if (x > 0)" \
    "            {" \
    "                DoSomething();" \
    "            }" \
    "            else" \
    "            {" \
    "                DoOther();" \
    "            }" \
    "            for (int i = 0; i < 10; i++)" \
    "            {" \
    "                list.Add(i);" \
    "            }" \
    "            foreach (int i in list)" \
    "            {" \
    "                Process(i);" \
    "            }" \
    "            while (running)" \
    "            {" \
    "                Poll();" \
    "            }" \
    "        }" \
    "    }" \
    "}"
assert_not_detects "braced conditionals no false positive" "BRACELESS_CONDITIONAL" "$F"

# else if should NOT be flagged as braceless else
F=$(tmpfile "r9_elseif.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            if (x > 0)" \
    "            {" \
    "                A();" \
    "            }" \
    "            else if (x < 0)" \
    "            {" \
    "                B();" \
    "            }" \
    "        }" \
    "    }" \
    "}"
assert_not_detects "else if not treated as braceless else" "BRACELESS_CONDITIONAL" "$F"

# ═══════════════════════════════════════════════════════════════════
# R10: TAB_INDENT
# ═══════════════════════════════════════════════════════════════════
section "R10: TAB_INDENT"

F=$(tmpfile "r10_detect.cs")
printf 'namespace Test\n{\n\tprivate void M() { }\n}\n' > "$F"
assert_detects "tab indentation" "TAB_INDENT" "$F"

F=$(tmpfile "r10_clean.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M() { }" \
    "    }" \
    "}"
assert_not_detects "space indentation no false positive" "TAB_INDENT" "$F"

# Tabs inside strings should still be caught (grep matches line-start tabs)
F=$(tmpfile "r10_midline_tab.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private string s = \"has\ta\ttab\";" \
    "    }" \
    "}"
assert_not_detects "tab inside string (not at line start) no false positive" "TAB_INDENT" "$F"

# ═══════════════════════════════════════════════════════════════════
# R11: VISIBILITY_ORDER
# ═══════════════════════════════════════════════════════════════════
section "R11: VISIBILITY_ORDER"

F=$(tmpfile "r11_detect.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        public void PublicFirst() { }" \
    "        private void PrivateAfter() { }" \
    "    }" \
    "}"
assert_detects "public before private" "VISIBILITY_ORDER" "$F"

F=$(tmpfile "r11_detect2.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        protected void ProtectedFirst() { }" \
    "        private void PrivateAfter() { }" \
    "    }" \
    "}"
assert_detects "protected before private" "VISIBILITY_ORDER" "$F"

F=$(tmpfile "r11_clean.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void PrivateFirst() { }" \
    "        private void PrivateSecond() { }" \
    "        protected void ProtectedMethod() { }" \
    "        public void PublicLast() { }" \
    "    }" \
    "}"
assert_not_detects "correct visibility order" "VISIBILITY_ORDER" "$F"

# Fields should not be considered as methods
F=$(tmpfile "r11_fields.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        public readonly string Name = \"test\";" \
    "        private void M() { }" \
    "    }" \
    "}"
assert_not_detects "readonly field before private method no false positive" "VISIBILITY_ORDER" "$F"

# Reset per class
F=$(tmpfile "r11_multiclass.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class A" \
    "    {" \
    "        private void M1() { }" \
    "        public void M2() { }" \
    "    }" \
    "    public class B" \
    "    {" \
    "        private void M3() { }" \
    "        public void M4() { }" \
    "    }" \
    "}"
assert_not_detects "visibility resets per class" "VISIBILITY_ORDER" "$F"

# ═══════════════════════════════════════════════════════════════════
# R12: HARDCODED_SN
# ═══════════════════════════════════════════════════════════════════
section "R12: HARDCODED_SN"

F=$(tmpfile "r12_detect_s.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            if (entity.HABITUAL == \"S\")" \
    "            {" \
    "            }" \
    "        }" \
    "    }" \
    "}"
assert_detects "hardcoded S" "HARDCODED_SN" "$F"

F=$(tmpfile "r12_detect_n.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            if (entity.ACTIVE == \"N\")" \
    "            {" \
    "            }" \
    "        }" \
    "    }" \
    "}"
assert_detects "hardcoded N" "HARDCODED_SN" "$F"

F=$(tmpfile "r12_detect_reversed.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            if (\"S\" == entity.HABITUAL)" \
    "            {" \
    "            }" \
    "        }" \
    "    }" \
    "}"
assert_detects "reversed S comparison" "HARDCODED_SN" "$F"

F=$(tmpfile "r12_clean.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            if (entity.HABITUAL == YesNoEnum.Si.Key)" \
    "            {" \
    "            }" \
    "            string name = \"Santiago\";" \
    "            string msg = \"No data\";" \
    "        }" \
    "    }" \
    "}"
assert_not_detects "YesNoEnum and longer strings no false positive" "HARDCODED_SN" "$F"

# ═══════════════════════════════════════════════════════════════════
# R13: NO_FIRST_LAST
# ═══════════════════════════════════════════════════════════════════
section "R13: NO_FIRST_LAST"

F=$(tmpfile "r13_detect_first.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            ENTITY e = list.First();" \
    "        }" \
    "    }" \
    "}"
assert_detects ".First()" "NO_FIRST_LAST" "$F"

F=$(tmpfile "r13_detect_last.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            ENTITY e = list.Last();" \
    "        }" \
    "    }" \
    "}"
assert_detects ".Last()" "NO_FIRST_LAST" "$F"

F=$(tmpfile "r13_clean.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            ENTITY e = list[0];" \
    "            ENTITY l = list[list.Count - 1];" \
    "            ENTITY f = list.FirstOrDefault(x => x.Id > 0);" \
    "            ENTITY la = list.LastOrDefault(x => x.Id > 0);" \
    "        }" \
    "    }" \
    "}"
assert_not_detects "indexer and predicate versions no false positive" "NO_FIRST_LAST" "$F"

# ═══════════════════════════════════════════════════════════════════
# R14: NO_BLOCK_COMMENT
# ═══════════════════════════════════════════════════════════════════
section "R14: NO_BLOCK_COMMENT"

F=$(tmpfile "r14_detect.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        /* block comment */" \
    "        private void M() { }" \
    "    }" \
    "}"
assert_detects "block comment" "NO_BLOCK_COMMENT" "$F"

F=$(tmpfile "r14_detect_multi.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    /*" \
    "     * Multi-line" \
    "     * block comment" \
    "     */" \
    "    public class C { }" \
    "}"
assert_detects "multi-line block comment" "NO_BLOCK_COMMENT" "$F"

F=$(tmpfile "r14_clean.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    /// <summary>" \
    "    /// XML doc" \
    "    /// </summary>" \
    "    public class C { }" \
    "}"
assert_not_detects "XML doc comments no false positive" "NO_BLOCK_COMMENT" "$F"

# ═══════════════════════════════════════════════════════════════════
# R15: RAW_SQL_WARNING
# ═══════════════════════════════════════════════════════════════════
section "R15: RAW_SQL_WARNING"

F=$(tmpfile "r15_detect.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            IQueryable<ROW> rows = uow.ExecuteRawQuery<ROW>(ContextType.Company, \"SELECT 1\");" \
    "        }" \
    "    }" \
    "}"
assert_detects "ExecuteRawQuery" "RAW_SQL_WARNING" "$F"

F=$(tmpfile "r15_clean.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            IQueryable<ROW> rows = rowService.Where(r => ids.Contains(r.COLUMN1));" \
    "        }" \
    "    }" \
    "}"
assert_not_detects "service query no false positive" "RAW_SQL_WARNING" "$F"

# ═══════════════════════════════════════════════════════════════════
# COMPLETELY CLEAN FILES — no rules should fire
# ═══════════════════════════════════════════════════════════════════
section "Completely clean files"

F=$(tmpfile "clean_full.cs")
write_cs "$F" \
    "using System;" \
    "using System.Collections.Generic;" \
    "" \
    "namespace MyCompany.Domain" \
    "{" \
    "    [Table(\"EMPLOYEES\")]" \
    "    [Title(\"Employee Entity\")]" \
    "    public class EmployeeService : BaseService" \
    "    {" \
    "        private readonly IEntityService<Employee> employeeService;" \
    "" \
    "        private void ValidateEmployee(Employee emp)" \
    "        {" \
    "            if (emp.IsActive == YesNoEnum.Si.Key)" \
    "            {" \
    "                DateTime startDate = new DateTime(2024, 1, 1, 0, 0, 0, DateTimeKind.Utc);" \
    "                List<Employee> employees = employeeService.Where(e => e.StartDate > startDate);" \
    "                if (employees.Count > 0)" \
    "                {" \
    "                    Employee first = employees[0];" \
    "                    Employee last = employees[employees.Count - 1];" \
    "                    bool hasRecords = employees?.Any() ?? false;" \
    "                }" \
    "            }" \
    "            else" \
    "            {" \
    "                throw new EmployeeInactiveException();" \
    "            }" \
    "        }" \
    "" \
    "        protected void ProcessBatch()" \
    "        {" \
    "            foreach (Employee emp in employeeService.GetAll())" \
    "            {" \
    "                ValidateEmployee(emp);" \
    "            }" \
    "        }" \
    "" \
    "        /// <summary>" \
    "        /// Retrieves employee by ID." \
    "        /// </summary>" \
    "        public Employee GetById(int id)" \
    "        {" \
    "            Employee emp = employeeService.FirstOrDefault(e => e.Id == id);" \
    "            return emp;" \
    "        }" \
    "    }" \
    "}"
assert_clean "complete clean C# file" "$F"

F=$(tmpfile "clean_minimal.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class Empty { }" \
    "}"
assert_clean "minimal clean C# file" "$F"

F=$(tmpfile "clean_interface.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public interface IMyService" \
    "    {" \
    "        Employee GetById(int id);" \
    "        List<Employee> GetAll();" \
    "    }" \
    "}"
assert_clean "interface definition clean" "$F"

F=$(tmpfile "clean_enum.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public enum Status" \
    "    {" \
    "        Active," \
    "        Inactive," \
    "        Pending" \
    "    }" \
    "}"
assert_clean "enum definition clean" "$F"

# ═══════════════════════════════════════════════════════════════════
# EDGE CASES — tricky content that should NOT break the hook
# ═══════════════════════════════════════════════════════════════════
section "Edge cases — content that should not break the hook"

# String content that looks like violations — known regex limitation
# Patterns inside string literals MAY trigger rules. This is expected behavior
# for a grep-based checker. The trade-off is acceptable because:
# 1. It's rare to have violation-like patterns in string literals
# 2. A full parser would be too heavy for a PostToolUse hook
# We only test patterns that should reliably NOT trigger:
F=$(tmpfile "edge_strings.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private string url = \"https://example.com/path\";" \
    "        private string name = \"Variable assignment test\";" \
    "    }" \
    "}"
assert_clean "safe string content" "$F"

# Long file with many methods - should not crash or hang
F=$(tmpfile "edge_long.cs")
{
    echo "namespace Test"
    echo "{"
    echo "    public class BigClass"
    echo "    {"
    for i in $(seq 1 100); do
        echo "        private void Method${i}()"
        echo "        {"
        echo "            int x${i} = ${i};"
        echo "        }"
        echo ""
    done
    echo "    }"
    echo "}"
} > "$F"
assert_clean "large file with 100 methods" "$F"

# File with special characters in strings
F=$(tmpfile "edge_special.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private string path = @\"C:\\Users\\test\";" \
    "        private string emoji = \"\\u2603\";" \
    "        private string quotes = \"He said \\\"hello\\\"\";" \
    "        private string nl = \"line1\\nline2\";" \
    "    }" \
    "}"
assert_clean "special characters in strings" "$F"

# File with only using statements
F=$(tmpfile "edge_usings.cs")
write_cs "$F" \
    "using System;" \
    "using System.Collections.Generic;" \
    "using System.Linq;" \
    "using System.Threading.Tasks;"
assert_clean "only using statements" "$F"

# Nested generics (brackets that look like attributes)
F=$(tmpfile "edge_generics.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private Dictionary<string, List<int>> data = new Dictionary<string, List<int>>();" \
    "" \
    "        private void M()" \
    "        {" \
    "            Tuple<int, string, List<double>> tuple = null;" \
    "        }" \
    "    }" \
    "}"
assert_not_detects "nested generics > not treated as attribute" "NO_BLANK_AFTER_ATTR" "$F"

# LINQ chains that contain First/Last with predicates (should NOT flag)
F=$(tmpfile "edge_linq.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            Employee e = list.FirstOrDefault(x => x.Active ?? false);" \
    "            Employee l = list.LastOrDefault(x => x.Active ?? false);" \
    "            Employee f = list.First(x => x.Id > 0);" \
    "        }" \
    "    }" \
    "}"
assert_not_detects "First/Last with predicates no false positive" "NO_FIRST_LAST" "$F"

# Single-line if with brace on same line
F=$(tmpfile "edge_inline_if.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            if (x > 0) { DoSomething(); }" \
    "        }" \
    "    }" \
    "}"
assert_not_detects "single-line if with braces no false positive" "BRACELESS_CONDITIONAL" "$F"

# ═══════════════════════════════════════════════════════════════════
# JSON STDIN MODE (hook mode)
# ═══════════════════════════════════════════════════════════════════
section "JSON stdin mode"

F=$(tmpfile "json_test.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            var x = 1;" \
    "        }" \
    "    }" \
    "}"

JSON_INPUT="{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$F\",\"old_string\":\"a\",\"new_string\":\"b\"}}"
TOTAL=$((TOTAL + 1))
JSON_OUTPUT=$(echo "$JSON_INPUT" | bash "$SCRIPT" 2>&1) || true
if echo "$JSON_OUTPUT" | grep -q "hookSpecificOutput"; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "  FAIL  JSON stdin mode outputs hookSpecificOutput"
    echo "        Output: $(echo "$JSON_OUTPUT" | head -3)"
fi

# JSON stdin with non-cs file should produce no output
TOTAL=$((TOTAL + 1))
JSON_INPUT2="{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"/tmp/readme.md\",\"old_string\":\"a\",\"new_string\":\"b\"}}"
JSON_OUTPUT2=$(echo "$JSON_INPUT2" | bash "$SCRIPT" 2>&1) || true
if [[ -z "$JSON_OUTPUT2" ]]; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "  FAIL  JSON stdin with non-.cs file should be silent"
    echo "        Output: $JSON_OUTPUT2"
fi

# JSON stdin with Windows-style path
F2=$(tmpfile "json_win.cs")
write_cs "$F2" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            var x = 1;" \
    "        }" \
    "    }" \
    "}"
# Escape path for JSON (replace / with \\/)
ESCAPED_PATH=$(echo "$F2" | sed 's/\//\\\//g')
JSON_INPUT3="{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$F2\"}}"
TOTAL=$((TOTAL + 1))
JSON_OUTPUT3=$(echo "$JSON_INPUT3" | bash "$SCRIPT" 2>&1) || true
if echo "$JSON_OUTPUT3" | grep -q "NO_VAR"; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "  FAIL  JSON stdin detects violations"
    echo "        Output: $(echo "$JSON_OUTPUT3" | head -3)"
fi

# ═══════════════════════════════════════════════════════════════════
# MULTIPLE VIOLATIONS IN SINGLE FILE
# ═══════════════════════════════════════════════════════════════════
section "Multiple violations in one file"

F=$(tmpfile "multi_violations.cs")
printf 'using System;\n\nnamespace Test\n{\n    public class C\n    {\n        // bad comment\n\t\tprivate void M()\n        {\n            var x = 1;\n            throw new Exception("err");\n            DateTime dt = new DateTime(2024, 1, 1);\n            bool r = flag == true;\n            ENTITY e = service.GetAll().FirstOrDefault(x => x.Id == 1);\n            if (x > 0)\n                DoSomething();\n            if (entity.HABITUAL == "S")\n            {\n            }\n            ENTITY f = list.First();\n            /* block */\n            IQueryable<ROW> rows = uow.ExecuteRawQuery<ROW>(ContextType.Company, "SELECT 1");\n        }\n\n        public void Pub() { }\n        private void Priv() { }\n    }\n}' > "$F"

OUTPUT=$(bash "$SCRIPT" "$F" 2>&1) || true

for RULE in NO_VAR NO_RAW_EXCEPTION DATETIME_KIND NO_EQUALS_TRUE NO_GETALL_FIRST NO_COMMENTS TAB_INDENT BRACELESS_CONDITIONAL HARDCODED_SN NO_FIRST_LAST NO_BLOCK_COMMENT RAW_SQL_WARNING VISIBILITY_ORDER; do
    TOTAL=$((TOTAL + 1))
    if echo "$OUTPUT" | grep -q "$RULE"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        echo "  FAIL  Multi-violation file: $RULE not detected"
    fi
done

# ═══════════════════════════════════════════════════════════════════
# EXIT CODE BEHAVIOR
# ═══════════════════════════════════════════════════════════════════
section "Exit code behavior"

# Clean file should exit 0
F=$(tmpfile "exit_clean.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class Empty { }" \
    "}"
TOTAL=$((TOTAL + 1))
if bash "$SCRIPT" "$F" > /dev/null 2>&1; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "  FAIL  Clean file should exit 0"
fi

# Violation file should exit 0 (hook outputs but doesn't fail)
F=$(tmpfile "exit_violation.cs")
write_cs "$F" \
    "namespace Test" \
    "{" \
    "    public class C" \
    "    {" \
    "        private void M()" \
    "        {" \
    "            var x = 1;" \
    "        }" \
    "    }" \
    "}"
TOTAL=$((TOTAL + 1))
if bash "$SCRIPT" "$F" > /dev/null 2>&1; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "  FAIL  Violation file should still exit 0"
fi

# Non-existent file should exit 0 (silently skip)
TOTAL=$((TOTAL + 1))
if bash "$SCRIPT" "/tmp/nonexistent_file_12345.cs" > /dev/null 2>&1; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "  FAIL  Non-existent .cs file should exit 0"
fi

# ═══════════════════════════════════════════════════════════════════
# RESULTS
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════"
echo "  RESULTS: $PASS/$TOTAL passed, $FAIL failed"
echo "════════════════════════════════════════════════════════════"

if [[ $FAIL -gt 0 ]]; then
    exit 1
else
    echo "  ALL TESTS PASSED"
    exit 0
fi
