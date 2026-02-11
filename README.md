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

# Run the Python test to verify all 15 rules are detected
python3 test_hook.py
```

To demo with Claude Code: open the project, tell Claude to add a comment to `test_violations.cs`. After the edit, the hook fires and Claude will fix all violations.

---

## Rules

### Coding Standards (from CSharpCodingRules.md + CodingGuidelines.md)

#### R1: NO_VAR — No `var` keyword

Use explicit types everywhere for readability.

**Detection:** `\bvar\s+\w+`

```csharp
// BAD
var list = new List<int>();
// GOOD
List<int> list = new List<int>();
```

#### R2: NO_RAW_EXCEPTION — Custom exception classes only

Never throw base `Exception`. Create specific exception classes per business case.

**Detection:** `throw\s+new\s+Exception\s*\(`

```csharp
// BAD
throw new Exception("Something went wrong");
// GOOD
throw new PlanTarjetaException();
```

#### R3: DATETIME_KIND — DateTime must include DateTimeKind

When creating `DateTime` with constructor, always provide `DateTimeKind` (SonarQube S6562).

**Detection:** Lines with `new DateTime(` that don't contain `DateTimeKind`

```csharp
// BAD
DateTime dt = new DateTime(2024, 1, 1);
// GOOD
DateTime dt = new DateTime(2024, 1, 1, 0, 0, 0, DateTimeKind.Unspecified);
```

#### R6: NO_COMMENTS — Only `///` XML docs allowed

All `//` comments are prohibited. Only `///` XML documentation on public helper methods is allowed.

**Detection:** Lines starting with `//` that are not `///`

```csharp
// BAD
// This is a comment
// GOOD (only on public helper methods)
/// <summary>
/// Valida que el legajo no tenga partes pendientes.
/// </summary>
```

#### R7: TRAILING_NEWLINE — Exactly one trailing newline

Every file must end with exactly one newline. No more, no less.

**Detection:** Checks last bytes of file with `od`

#### R8: NO_BLANK_AFTER_ATTR — No blank lines between attributes and members

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

#### R9: BRACELESS_CONDITIONAL — Always use braces

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

#### R10: TAB_INDENT — Use 4 spaces, not tabs

Indentation must use 4 spaces. Tab characters are not allowed.

**Detection:** `^\t`

#### R11: VISIBILITY_ORDER — private, then protected, then public

Methods within a class must be ordered: private first, then protected, then public.

**Detection:** awk tracks method visibility declarations; flags when order goes backwards (e.g. `private` after `public`)

```csharp
// BAD
public void PublicFirst() { }
private void PrivateAfterPublic() { }
// GOOD
private void PrivateFirst() { }
public void PublicLast() { }
```

#### R14: NO_BLOCK_COMMENT — No `/* */` block comments

Block comments are prohibited. Use `///` XML doc comments only.

**Detection:** `/\*`

```csharp
// BAD
/* this is a block comment */
// GOOD (only on public helper methods)
/// <summary>
/// Valida condiciones.
/// </summary>
```

### Data Access Standards (from data-access.md + CodingGuidelines.md)

#### R4: NO_EQUALS_TRUE — Use `?? false` not `== true`

For nullable bools from `?.` operator, use `?? false` instead of `== true`.

**Detection:** `==\s*true`

```csharp
// BAD
bool result = collection?.Any() == true;
// GOOD
bool result = collection?.Any() ?? false;
```

#### R5: NO_GETALL_FIRST — Direct FirstOrDefault on service

Use `FirstOrDefault(predicate)` directly on the service, not `GetAll().FirstOrDefault()`.

**Detection:** `\.GetAll\(\)\s*\.FirstOrDefault\(`

```csharp
// BAD
ENTITY e = service.GetAll().FirstOrDefault(x => x.Id == 1);
// GOOD
ENTITY e = service.FirstOrDefault(x => x.Id == 1);
```

#### R13: NO_FIRST_LAST — Use indexer instead of `.First()`/`.Last()`

Use `[0]`/`[list.Count - 1]` instead of parameterless `.First()`/`.Last()` on lists.

**Detection:** `\.(First|Last)\(\)`

```csharp
// BAD
ENTITY first = list.First();
ENTITY last = list.Last();
// GOOD
ENTITY first = list[0];
ENTITY last = list[list.Count - 1];
```

### Domain Standards (from CSharpCodingRules.md Enumerados + CodingGuidelines.md)

#### R12: HARDCODED_SN — Use YesNoEnum instead of `"S"`/`"N"`

Comparisons against `"S"` or `"N"` must use `YesNoEnum.Si.Key` / `YesNoEnum.No.Key`.

**Detection:** `==\s*"[SN]"` or `"[SN]"\s*==`

```csharp
// BAD
if (entity.HABITUAL == "S")
// GOOD
if (entity.HABITUAL == YesNoEnum.Si.Key)
```

### Service Standards (from ServicesImplementationGuide.md)

#### R15: RAW_SQL_WARNING — ExecuteRawQuery is last resort

Raw SQL should only be used when `IEntityService<T>` cannot be made to work.

**Detection:** `ExecuteRawQuery`

```csharp
// BAD (avoid)
IQueryable<ROW> rows = uow.ExecuteRawQuery<ROW>(ContextType.Company, "SELECT * FROM T");
// GOOD (preferred)
IQueryable<ROW> rows = rowService.Where(r => ids.Contains(r.COLUMN1));
```

---

## File structure

```
.claude/
  settings.json                  # Hook configuration
  hooks/
    check_csharp_rules.sh        # The checker (~120 lines)
test_violations.cs               # Test file with all 15 violations
test_hook.py                     # Python test verifying detection
README.md                        # This file
```
