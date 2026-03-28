# humanlang Specification v0.1.0

## Overview

humanlang is a programming language where the syntax is natural English. There is no compiler. There is no interpreter. There is only this specification, a set of tests, and you — talking to an AI agent that builds the implementation.

humanlang proves a thesis: **human language is the best programming language.**

---

## Design Principles

1. **English syntax.** Code reads like natural English sentences.
2. **Words over symbols.** `plus` not `+`, `is greater than` not `>`, `and` not `&&`.
3. **Pure specification.** This document IS the language. No reference implementation exists.
4. **Deterministic.** Given the same program, any correct implementation produces identical output.
5. **Minimal.** The language is intentionally small. It proves a concept, not competes with Python.

---

## File Extension

`.hl` (humanlang)

---

## Lexical Structure

### Comments

Lines starting with `--` are comments. Inline comments are not supported.

```
-- This is a comment
print "Hello"
```

### Whitespace

- Indentation defines blocks (like Python).
- One indent level = **4 spaces**. Tabs are not allowed.
- Blank lines are ignored.
- Trailing whitespace is ignored.

### String Literals

Strings are enclosed in double quotes. Supported escape sequences:

| Escape | Meaning |
|--------|---------|
| `\"` | Literal double quote |
| `\\` | Literal backslash |
| `\n` | Newline |
| `\t` | Tab |

### Number Literals

- Integers: `42`, `-7`, `0`
- Decimals: `3.14`, `-0.5`, `0.0`
- No scientific notation in v0.1.

### Boolean Literals

`true` and `false` (lowercase only).

### List Literals

Square brackets with comma-separated values:

```
[1, 2, 3]
["a", "b", "c"]
[true, false, true]
[1, "mixed", true]
[]
```

### Nothing Literal

`nothing` represents the absence of a value.

---

## Data Types

| Type | Examples | Notes |
|------|----------|-------|
| number | `42`, `3.14`, `-7` | 64-bit float internally |
| string | `"hello"`, `""` | UTF-8, immutable |
| boolean | `true`, `false` | |
| list | `[1, 2, 3]` | Ordered, mutable, mixed types allowed |
| nothing | `nothing` | Null/nil equivalent |

---

## Variables

### Assignment

```
set x to 10
set name to "World"
set flag to true
set items to [1, 2, 3]
set empty to nothing
```

Variable names: lowercase letters, digits, and underscores. Must start with a letter.

Valid: `x`, `my_var`, `count2`
Invalid: `_x`, `2count`, `MyVar`, `my-var`

### Reassignment

Variables can be reassigned to any type:

```
set x to 10
set x to "now a string"
```

### Scope

Variables are lexically scoped. Function bodies create a new scope. Variables from outer scopes are readable but not writable from inner scopes.

---

## Output

### Print

```
print "Hello, World!"
print x
print 42
print true
print [1, 2, 3]
```

`print` outputs the value's string representation followed by a newline.

### Output Formatting

| Type | Format | Example |
|------|--------|---------|
| number (integer) | No decimal point | `42` |
| number (decimal) | Up to 6 decimal places, no trailing zeros | `3.14`, `0.333333` |
| string | Raw text, no quotes | `hello` |
| boolean | Lowercase | `true`, `false` |
| list | Bracket notation | `[1, 2, 3]` |
| nothing | The word | `nothing` |

A number is printed as an integer if it has no fractional part: `10.0` prints as `10`.

---

## Expressions

### Arithmetic

| Operation | Syntax | Example |
|-----------|--------|---------|
| Addition | `a plus b` | `10 plus 5` → `15` |
| Subtraction | `a minus b` | `10 minus 3` → `7` |
| Multiplication | `a times b` | `4 times 6` → `24` |
| Division | `a divided by b` | `20 divided by 4` → `5` |
| Modulo | `a modulo b` | `17 modulo 5` → `2` |

**Precedence** (highest to lowest):
1. Parenthesized expressions: `(a plus b)`
2. `times`, `divided by`, `modulo`
3. `plus`, `minus`

Left-to-right associativity within the same precedence level.

Division by zero is a runtime error.

### Comparison

| Operation | Syntax |
|-----------|--------|
| Equal | `a is equal to b` |
| Not equal | `a is not equal to b` |
| Greater than | `a is greater than b` |
| Less than | `a is less than b` |
| Greater or equal | `a is at least b` |
| Less or equal | `a is at most b` |

All comparisons return a boolean.

String comparison is lexicographic. Comparing incompatible types (e.g., number to string) returns `false` for equality checks and is a runtime error for ordering comparisons.

### Logical

| Operation | Syntax |
|-----------|--------|
| And | `a and b` |
| Or | `a or b` |
| Not | `not a` |

Short-circuit evaluation: `a and b` does not evaluate `b` if `a` is false. `a or b` does not evaluate `b` if `a` is true.

**Precedence** (highest to lowest):
1. `not`
2. `and`
3. `or`

### String Operations

| Operation | Syntax | Example |
|-----------|--------|---------|
| Concatenation | `a joined with b` | `"hi" joined with " world"` → `"hi world"` |
| Uppercase | `uppercase of s` | `uppercase of "hello"` → `"HELLO"` |
| Lowercase | `lowercase of s` | `lowercase of "HELLO"` → `"hello"` |
| Length | `length of s` | `length of "hello"` → `5` |
| Contains | `s contains sub` | `"hello" contains "ell"` → `true` |
| Slice | `slice of s from i to j` | `slice of "hello" from 1 to 3` → `"el"` |

`joined with` automatically converts non-string values to their string representation:
```
"The answer is " joined with 42
-- Result: "The answer is 42"
```

`slice` uses zero-based indexing. `from` is inclusive, `to` is exclusive.

### List Operations

| Operation | Syntax | Example |
|-----------|--------|---------|
| First element | `first of list` | `first of [1, 2, 3]` → `1` |
| Last element | `last of list` | `last of [1, 2, 3]` → `3` |
| Length | `length of list` | `length of [1, 2, 3]` → `3` |
| Contains | `list contains val` | `[1, 2, 3] contains 2` → `true` |
| Slice | `slice of list from i to j` | `slice of [1,2,3,4] from 1 to 3` → `[2, 3]` |
| Element access | `item i of list` | `item 0 of [10, 20, 30]` → `10` |

`first of` and `last of` on an empty list is a runtime error.
`item` uses zero-based indexing. Out-of-bounds is a runtime error.

### Append (Statement)

```
append 4 to items
```

Modifies the list in place. Only valid on variables holding a list.

### Type Conversion

| Operation | Syntax | Example |
|-----------|--------|---------|
| To number | `expr as number` | `"42" as number` → `42` |
| To string | `expr as string` | `42 as string` → `"42"` |
| To boolean | `expr as boolean` | `0 as boolean` → `false` |

**Truthiness rules for `as boolean`:**
- Numbers: `0` and `0.0` → `false`, everything else → `true`
- Strings: `""` → `false`, everything else → `true`
- Booleans: identity
- Lists: `[]` → `false`, non-empty → `true`
- Nothing: `false`

Invalid conversions (e.g., `"abc" as number`) are runtime errors.

---

## Statements

### Conditionals

```
if condition:
    body

if condition:
    body
otherwise:
    body

if condition:
    body
otherwise if condition:
    body
otherwise:
    body
```

Conditions must evaluate to a boolean. Non-boolean conditions are a runtime error (no implicit truthiness in `if` — use `as boolean` explicitly).

### Loops

**Repeat N times:**
```
repeat 5 times:
    print "Hello!"
```

The count expression is evaluated once before the loop starts.

**For each (list iteration):**
```
for each item in items:
    print item
```

**For (counting loop):**
```
for n from 1 to 10:
    print n
```

Inclusive on both ends. The loop variable is scoped to the loop body. Only integers allowed.

**While:**
```
while x is greater than 0:
    set x to x minus 1
```

**Loop control:**
- `stop` — exits the innermost loop (equivalent to `break`)
- `skip` — jumps to the next iteration (equivalent to `continue`)

### Functions

**Definition:**
```
define greet with name:
    print "Hello, " joined with name joined with "!"
```

**Multiple parameters:**
```
define add with a and b:
    return a plus b
```

**No parameters:**
```
define say_hello:
    print "Hello!"
```

**Calling:**
```
call greet with "World"
set result to call add with 3 and 5
call say_hello
```

**Return values:**

Functions return `nothing` by default. Use `return` to return a value:

```
define square with n:
    return n times n

set x to call square with 4
-- x is 16
```

`return` immediately exits the function.

Functions must be defined before they are called. Recursion is supported.

---

## Error Handling

humanlang has no try/catch mechanism. Runtime errors halt the program and print an error message to stderr. The format is:

```
Error on line N: description
```

Common runtime errors:
- Division by zero
- Invalid type conversion
- Index out of bounds
- Accessing first/last of empty list
- Calling undefined function
- Wrong number of arguments
- Non-boolean condition in `if`/`while`
- Using `stop`/`skip` outside a loop

---

## Complete Grammar (EBNF-style)

```
program        = { statement }
statement      = print_stmt | set_stmt | if_stmt | while_stmt
               | for_each_stmt | for_from_stmt | repeat_stmt
               | define_stmt | call_stmt | return_stmt
               | append_stmt | stop_stmt | skip_stmt | comment

comment        = "--" { any character } newline

print_stmt     = "print" expression
set_stmt       = "set" identifier "to" expression
append_stmt    = "append" expression "to" identifier

if_stmt        = "if" expression ":" block
                 { "otherwise if" expression ":" block }
                 [ "otherwise:" block ]

while_stmt     = "while" expression ":" block
for_each_stmt  = "for each" identifier "in" expression ":" block
for_from_stmt  = "for" identifier "from" expression "to" expression ":" block
repeat_stmt    = "repeat" expression "times:" block

define_stmt    = "define" identifier [ "with" param_list ] ":" block
param_list     = identifier { "and" identifier }
call_expr      = "call" identifier [ "with" arg_list ]
arg_list       = expression { "and" expression }

return_stmt    = "return" [ expression ]
stop_stmt      = "stop"
skip_stmt      = "skip"

block          = newline INDENT { statement } DEDENT

expression     = or_expr
or_expr        = and_expr { "or" and_expr }
and_expr       = not_expr { "and" not_expr }
not_expr       = "not" not_expr | comparison
comparison     = addition { comp_op addition }
comp_op        = "is equal to" | "is not equal to"
               | "is greater than" | "is less than"
               | "is at least" | "is at most"
addition       = multiplication { ( "plus" | "minus" ) multiplication }
multiplication = unary { ( "times" | "divided by" | "modulo" ) unary }
unary          = [ "negative" ] postfix
postfix        = primary { "joined with" primary | "as" type_name
               | "contains" primary }
primary        = number | string | boolean | "nothing"
               | identifier | list_literal | call_expr
               | "(" expression ")"
               | "uppercase of" primary | "lowercase of" primary
               | "length of" primary | "first of" primary
               | "last of" primary
               | "item" expression "of" primary
               | "slice of" primary "from" expression "to" expression

type_name      = "number" | "string" | "boolean"
identifier     = letter { letter | digit | "_" }
list_literal   = "[" [ expression { "," expression } ] "]"
```

---

## Testing

The file `tests.yaml` contains structured test cases. Each test specifies a humanlang program and its expected stdout output.

**Test format:**
```yaml
- name: "descriptive test name"
  program: |
    humanlang code here
  output: |
    expected stdout here
```

An implementation passes if, for every test case, running the program produces output that matches exactly (byte-for-byte, including trailing newlines).

**To generate tests in your target language:**
1. Parse `tests.yaml`
2. For each test: write the program to a temp file, run the interpreter, compare stdout to expected output
3. Report pass/fail with test names

---

## Implementation Notes

This section is non-normative guidance for AI agents building an interpreter.

1. **Start with a lexer** that tokenizes humanlang into tokens (keywords, identifiers, literals, operators, indentation).
2. **Build a parser** that produces an AST from the token stream. The grammar above is designed to be parseable with a recursive descent parser.
3. **Write a tree-walk interpreter** that executes the AST. This is the simplest approach for a language this size.
4. **Handle indentation** like Python: track indent levels with a stack. Emit INDENT/DEDENT tokens.
5. **Multi-word keywords** (`divided by`, `is equal to`, `for each`, etc.) should be recognized as single tokens by the lexer.
6. **The entry point** should accept a `.hl` file path as a command-line argument and execute it.
