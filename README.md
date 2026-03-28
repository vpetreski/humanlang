# humanlang

**A programming language with no compiler.**

> *"Human language is the best programming language in the future."* — Jensen Huang

![humanlang](https://vanja.io/content/images/2026/03/humanlang.png)

---

humanlang is a programming language where the syntax is natural English. There is no compiler. There is no interpreter. There is only a [specification](SPEC.md), a set of [tests](tests.yaml), and you — talking to an AI agent that builds the implementation.

**[Read the full article →](https://vanja.io/programming-language-no-compiler/)**

---

## What Does It Look Like?

```
-- FizzBuzz in humanlang

for n from 1 to 100:
    if n modulo 15 is equal to 0:
        print "FizzBuzz"
    otherwise if n modulo 3 is equal to 0:
        print "Fizz"
    otherwise if n modulo 5 is equal to 0:
        print "Buzz"
    otherwise:
        print n
```

```
-- Functions and lists

define greet with name:
    return "Hello, " joined with name joined with "!"

set guests to ["Alice", "Bob", "Charlie"]
for each guest in guests:
    print call greet with guest
```

```
-- Recursion

define factorial with n:
    if n is at most 1:
        return 1
    return n times (call factorial with (n minus 1))

print call factorial with 10
```

---

## What's in This Repo?

| File | What It Is |
|------|------------|
| [SPEC.md](SPEC.md) | Complete language specification with EBNF grammar |
| [tests.yaml](tests.yaml) | 86 language-agnostic test cases |
| [INSTALL.md](INSTALL.md) | Instructions for building humanlang (a prompt) |
| [examples/](examples/) | Example programs in `.hl` format |

**What's NOT in this repo:** code. Not a single line.

---

## Install

Give your AI coding agent this prompt:

```
Build a humanlang interpreter in [LANGUAGE].

1. Read SPEC.md for the complete language specification
2. Parse tests.yaml and generate a test file
3. Implement a lexer, parser, and tree-walk interpreter
4. The entry point should accept a .hl file path as a command-line argument
5. Run tests until all pass
6. Place implementation in [LOCATION]
```

Pick your language. Pick your location. Copy, paste, go.

---

## The Language

humanlang supports:

- **Variables** — `set x to 10`
- **Arithmetic** — `plus`, `minus`, `times`, `divided by`, `modulo`
- **Strings** — `joined with`, `uppercase of`, `lowercase of`, `contains`
- **Comparisons** — `is equal to`, `is greater than`, `is at most`, etc.
- **Logic** — `and`, `or`, `not`
- **Conditionals** — `if` / `otherwise if` / `otherwise`
- **Loops** — `repeat N times`, `for each`, `for N from X to Y`, `while`
- **Functions** — `define`, `call`, `return`, recursion
- **Lists** — `first of`, `last of`, `append`, `item N of`, `contains`
- **Type conversion** — `as number`, `as string`, `as boolean`

See [SPEC.md](SPEC.md) for the complete grammar and semantics.

---

## Why?

Ghost libraries — software distributed as specifications rather than code — are gaining traction. A spec and tests that any AI agent can implement in any language. But a library is small.

What if a spec could replace a compiler?

The answer is yes.

humanlang is a complete programming language — variables, functions, loops, recursion, lists — that exists entirely as a specification. No binary. No runtime. No dependency. Just a document that describes how English becomes computation.

**The spec IS the compiler. The AI agent IS the build tool. Human language IS the programming language.**

---

## License

MIT
