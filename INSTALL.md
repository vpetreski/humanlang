# Building humanlang

humanlang is a **ghost language** — distributed as a specification, not code. There is no compiler. There is no interpreter. There is only a spec, tests, and you talking to an AI agent.

## Quick Start

Give your AI coding agent (Claude, Codex, Cursor, etc.) this prompt:

```
Build a humanlang interpreter in [LANGUAGE].

1. Read SPEC.md for the complete language specification
2. Parse tests.yaml and generate a test file
3. Implement a lexer, parser, and tree-walk interpreter
4. The entry point should accept a .hl file path as a command-line argument
5. Run tests until all pass
6. Place implementation in [LOCATION]

All tests.yaml test cases must pass. See SPEC.md for grammar and semantics.
```

Pick your language. Pick your location. Copy, paste, go.

## What the Agent Will Do

1. **Read SPEC.md** — Understand the grammar, types, operators, control flow
2. **Parse tests.yaml** — Load all test cases (programs + expected outputs)
3. **Build a lexer** — Tokenize humanlang source, handling multi-word keywords
4. **Build a parser** — Produce an AST using recursive descent
5. **Build an interpreter** — Tree-walk execution of the AST
6. **Run and iterate** — Fix failures until all tests pass

## Files

| File | Purpose |
|------|---------|
| SPEC.md | Complete language specification with EBNF grammar |
| tests.yaml | Language-agnostic test cases (program → expected output) |
| examples/ | Example humanlang programs |

## Verification

After generation, run the test suite. All tests must pass:

- 7 printing tests
- 5 variable tests
- 12 arithmetic tests
- 9 string tests
- 9 comparison tests
- 5 logical operator tests
- 6 conditional tests
- 8 loop tests
- 8 function tests
- 8 list tests
- 4 type conversion tests
- 5 combined/complex tests

**Total: 86 test cases.**

## Why a Ghost Language?

Traditional languages ship compilers. You install a binary, manage versions, debug toolchain issues.

humanlang ships a specification. Your AI agent builds the interpreter locally, in whatever language you prefer. You can audit every line. No supply chain. No version conflicts. The spec is the single source of truth.

This isn't just a gimmick. It's a proof of concept:

**If an AI can build a complete programming language interpreter from a spec, what else can it build from a well-written specification?**

The answer: almost anything.
