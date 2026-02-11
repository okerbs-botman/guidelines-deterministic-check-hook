#!/usr/bin/env bash
set -euo pipefail

# Deterministic C# coding rules checker
# Usage:
#   Direct:  bash check_csharp_rules.sh path/to/File.cs
#   Hook:    Receives JSON on stdin from Claude Code PostToolUse hook

if [[ $# -ge 1 ]]; then
    FILE="$1"
else
    FILE=$(jq -r '.tool_input.file_path // empty')
fi

[[ "$FILE" == *.cs && -f "$FILE" ]] || exit 0

VIOLATIONS=""

add_violation() {
    local rule="$1" matches="$2"
    VIOLATIONS+="[$rule]"$'\n'
    while IFS= read -r line; do
        VIOLATIONS+="  $line"$'\n'
    done <<< "$matches"
    VIOLATIONS+=$'\n'
}

# ── R1: No var keyword ──────────────────────────────────────────────
MATCHES=$(grep -nP '\bvar\s+\w+' "$FILE" || true)
[[ -n "$MATCHES" ]] && add_violation "NO_VAR: Use explicit types instead of 'var'" "$MATCHES"

# ── R2: No throw new Exception() ────────────────────────────────────
MATCHES=$(grep -nP 'throw\s+new\s+Exception\s*\(' "$FILE" || true)
[[ -n "$MATCHES" ]] && add_violation "NO_RAW_EXCEPTION: Use custom exception classes, not base Exception" "$MATCHES"

# ── R3: new DateTime() without DateTimeKind ─────────────────────────
MATCHES=$(grep -nP 'new\s+DateTime\(' "$FILE" | grep -v 'DateTimeKind' || true)
[[ -n "$MATCHES" ]] && add_violation "DATETIME_KIND: new DateTime() must include DateTimeKind parameter (SonarQube S6562)" "$MATCHES"

# ── R4: == true instead of ?? false ─────────────────────────────────
MATCHES=$(grep -nP '==\s*true' "$FILE" || true)
[[ -n "$MATCHES" ]] && add_violation "NO_EQUALS_TRUE: Use '?? false' instead of '== true' for nullable bools" "$MATCHES"

# ── R5: GetAll().FirstOrDefault() ────────────────────────────────────
MATCHES=$(grep -nP '\.GetAll\(\)\s*\.FirstOrDefault\(' "$FILE" || true)
[[ -n "$MATCHES" ]] && add_violation "NO_GETALL_FIRST: Use direct FirstOrDefault(predicate) on the service" "$MATCHES"

# ── R6: Prohibited comments (only /// XML docs allowed) ─────────────
MATCHES=$(grep -nP '^\s*//($|[^/])' "$FILE" || true)
[[ -n "$MATCHES" ]] && add_violation "NO_COMMENTS: Only /// XML doc comments are allowed, remove all // comments" "$MATCHES"

# ── R7: Trailing newline ────────────────────────────────────────────
if [[ -s "$FILE" ]]; then
    LAST_BYTE=$(tail -c 1 "$FILE" | od -An -tx1 | tr -d ' \n')
    if [[ "$LAST_BYTE" != "0a" ]]; then
        VIOLATIONS+="[TRAILING_NEWLINE: File must end with exactly one newline]"$'\n'
        VIOLATIONS+="  File does not end with a newline"$'\n\n'
    else
        LAST_TWO=$(tail -c 2 "$FILE" | od -An -tx1 | tr -d ' \n')
        if [[ "$LAST_TWO" == "0a0a" ]]; then
            VIOLATIONS+="[TRAILING_NEWLINE: File must end with exactly one newline]"$'\n'
            VIOLATIONS+="  File has multiple trailing newlines"$'\n\n'
        fi
    fi
fi

# ── R8: Blank line between attributes and members ───────────────────
ATTR_BLANKS=$(awk '/\]\s*$/ { n=NR; t=$0 } /^\s*$/ && NR==n+1 { printf "  Line %d: %s (followed by blank line)\n", n, t }' "$FILE" || true)
[[ -n "$ATTR_BLANKS" ]] && VIOLATIONS+="[NO_BLANK_AFTER_ATTR: No blank lines between attributes and the member they decorate]"$'\n'"$ATTR_BLANKS"$'\n\n'

# ── R9: Braceless conditionals ──────────────────────────────────────
BRACELESS=$(awk '
/^\s*(if|else\s+if|for|foreach|while)\s*\(.*\)\s*$/ {
    n=NR; t=$0
    if (getline > 0 && $0 !~ /^\s*\{/) printf "  Line %d: %s\n", n, t
}
/^\s*else\s*$/ {
    n=NR; t=$0
    if (getline > 0 && $0 !~ /^\s*(\{|if)/) printf "  Line %d: %s\n", n, t
}' "$FILE" || true)
[[ -n "$BRACELESS" ]] && VIOLATIONS+="[BRACELESS_CONDITIONAL: Always use braces {} on if/else/for/foreach/while]"$'\n'"$BRACELESS"$'\n\n'

# ── R10: Tab indentation ────────────────────────────────────────────
MATCHES=$(grep -nP '^\t' "$FILE" || true)
[[ -n "$MATCHES" ]] && add_violation "TAB_INDENT: Use 4 spaces for indentation, not tabs" "$MATCHES"

# ── R11: Visibility order (private → protected → public) ────────────
VIS_ORDER=$(awk '
/class [A-Za-z]/ { max_vis=0 }
/^\s*(private|protected|public) / && /\(/ && !/class / && !/readonly / && !/const / {
    tmp=$0; sub(/\(.*/, "", tmp); n=split(tmp, a)
    if (n < 3) next
    if ($0 ~ /^\s*private/) v=1
    else if ($0 ~ /^\s*protected/) v=2
    else if ($0 ~ /^\s*public/) v=3
    else next
    if (v < max_vis) printf "  Line %d: %s\n", NR, $0
    if (v > max_vis) max_vis=v
}' "$FILE" || true)
[[ -n "$VIS_ORDER" ]] && VIOLATIONS+="[VISIBILITY_ORDER: Methods must be ordered private, then protected, then public]"$'\n'"$VIS_ORDER"$'\n\n'

# ── R12: Hardcoded "S"/"N" instead of YesNoEnum ─────────────────────
MATCHES=$(grep -nP '==\s*"[SN]"|"[SN]"\s*==' "$FILE" || true)
[[ -n "$MATCHES" ]] && add_violation "HARDCODED_SN: Use YesNoEnum.Si.Key / YesNoEnum.No.Key instead of \"S\"/\"N\"" "$MATCHES"

# ── R13: .First()/.Last() without predicate ─────────────────────────
MATCHES=$(grep -nP '\.(First|Last)\(\)' "$FILE" || true)
[[ -n "$MATCHES" ]] && add_violation "NO_FIRST_LAST: Use indexer [0]/[list.Count-1] instead of .First()/.Last() on lists" "$MATCHES"

# ── R14: Block comments /* */ ────────────────────────────────────────
MATCHES=$(grep -nP '/\*' "$FILE" || true)
[[ -n "$MATCHES" ]] && add_violation "NO_BLOCK_COMMENT: Block comments /* */ are prohibited, use /// XML docs only" "$MATCHES"

# ── R15: Raw SQL usage ──────────────────────────────────────────────
MATCHES=$(grep -nP 'ExecuteRawQuery' "$FILE" || true)
[[ -n "$MATCHES" ]] && add_violation "RAW_SQL_WARNING: ExecuteRawQuery is last resort only, prefer IEntityService<T>" "$MATCHES"

# ── Output ──────────────────────────────────────────────────────────

[[ -z "$VIOLATIONS" ]] && exit 0

HEADER="C# RULE VIOLATIONS in $(basename "$FILE"):"
FOOTER="Fix these violations and apply the edit again."
MSG=$(printf "%s\n\n%s%s" "$HEADER" "$VIOLATIONS" "$FOOTER")

if [[ $# -ge 1 ]]; then
    echo "$MSG"
else
    jq -n --arg ctx "$MSG" '{
        hookSpecificOutput: {
            hookEventName: "PostToolUse",
            additionalContext: $ctx
        }
    }'
fi
