# Deterministic C# Rule Checker — Claude Code PostToolUse Hook

A PostToolUse hook that automatically checks C# files for coding standard violations after every `Edit`/`Write` and reports them back to Claude for immediate correction.

## How it works

1. Claude edits a `.cs` file
2. The hook runs `check_csharp_rules.sh` on the modified file
3. If violations are found, they're reported back to Claude as context
4. Claude fixes the violations automatically

## Installation

Copy `.claude/` into your project root. The hook is configured in `.claude/settings.json`.

## Demo

```bash
# Run the checker directly on the test file
bash .claude/hooks/check_csharp_rules.sh test_violations.cs

# Run the Python test to verify all 9 rules are detected
python3 test_hook.py
```

To demo with Claude Code: open the project, tell Claude to add a comment to `test_violations.cs`. After the edit, the hook fires and Claude will fix all violations.

---

## Rules

### R1: NO_VAR — No `var` keyword

Use explicit types everywhere for readability.

**Detection:** `\bvar\s+\w+`

```csharp
// BAD
var list = new List<int>();

// GOOD
List<int> list = new List<int>();
```

### R2: NO_RAW_EXCEPTION — Custom exception classes only

Never throw base `Exception`. Create specific exception classes per business case.

**Detection:** `throw\s+new\s+Exception\s*\(`

```csharp
// BAD
throw new Exception("Something went wrong");

// GOOD
throw new PlanTarjetaException();
```

### R3: DATETIME_KIND — DateTime must include DateTimeKind

When creating `DateTime` with constructor, always provide `DateTimeKind` (SonarQube S6562).

**Detection:** Lines with `new DateTime(` that don't contain `DateTimeKind`

```csharp
// BAD
DateTime dt = new DateTime(2024, 1, 1);

// GOOD
DateTime dt = new DateTime(2024, 1, 1, 0, 0, 0, DateTimeKind.Unspecified);
```

### R4: NO_EQUALS_TRUE — Use `?? false` not `== true`

For nullable bools from `?.` operator, use `?? false` instead of `== true`.

**Detection:** `==\s*true`

```csharp
// BAD
bool result = collection?.Any() == true;

// GOOD
bool result = collection?.Any() ?? false;
```

### R5: NO_GETALL_FIRST — Direct FirstOrDefault on service

Use `FirstOrDefault(predicate)` directly on the service, not `GetAll().FirstOrDefault()`.

**Detection:** `\.GetAll\(\)\s*\.FirstOrDefault\(`

```csharp
// BAD
ENTITY e = service.GetAll().FirstOrDefault(x => x.Id == 1);

// GOOD
ENTITY e = service.FirstOrDefault(x => x.Id == 1);
```

### R6: NO_COMMENTS — Only `///` XML docs allowed

All `//` comments are prohibited. Only `///` XML documentation on public helper methods is allowed.

**Detection:** Lines starting with `//` that are not `///`

```csharp
// BAD
// This is a comment
// int oldCode = 0;

// GOOD (only on public helper methods)
/// <summary>
/// Valida que el legajo no tenga partes pendientes.
/// </summary>
public static void ValidarSinPartesPendientes(int idLegajo) { }
```

### R7: TRAILING_NEWLINE — Exactly one trailing newline

Every file must end with exactly one newline. No more, no less.

**Detection:** Checks last bytes of file with `od`

### R8: NO_BLANK_AFTER_ATTR — No blank lines between attributes and members

Attributes must be directly adjacent to the member they decorate.

**Detection:** Lines ending with `]` followed by a blank line

```csharp
// BAD
[Table("TEST01")]

[Title("Test Entity")]
public class MyEntity { }

// GOOD
[Table("TEST01")]
[Title("Test Entity")]
public class MyEntity { }
```

### R9: BRACELESS_CONDITIONAL — Always use braces

All `if`/`else`/`for`/`foreach`/`while` must have braces `{}`.

**Detection:** Conditional line ending with `)` where the next line doesn't start with `{`

```csharp
// BAD
if (condition)
    DoSomething();

// GOOD
if (condition)
{
    DoSomething();
}
```

---

## File structure

```
.claude/
  settings.json                  # Hook configuration
  hooks/
    check_csharp_rules.sh        # The checker (105 lines)
test_violations.cs               # Test file with all 9 violations
test_hook.py                     # Python test verifying detection
README.md                        # This file
```
