#!/usr/bin/env npx tsx

// humanlang interpreter — lexer, parser, tree-walk interpreter
// Implements the humanlang v0.1.0 specification

import * as fs from "fs";
import * as path from "path";

// ============================================================
// Token Types
// ============================================================

enum TokenType {
  // Literals
  NUMBER,
  STRING,
  TRUE,
  FALSE,
  NOTHING,

  // Identifiers
  IDENTIFIER,

  // Keywords / statements
  PRINT,
  SET,
  TO,
  IF,
  OTHERWISE,
  OTHERWISE_IF,
  WHILE,
  FOR_EACH,
  FOR,
  FROM,
  IN,
  REPEAT,
  DEFINE,
  WITH,
  CALL,
  RETURN,
  APPEND,
  STOP,
  SKIP,

  // Arithmetic operators
  PLUS,
  MINUS,
  TIMES_OP, // "times" as multiplication
  DIVIDED_BY,
  MODULO,

  // Comparison operators
  IS_EQUAL_TO,
  IS_NOT_EQUAL_TO,
  IS_GREATER_THAN,
  IS_LESS_THAN,
  IS_AT_LEAST,
  IS_AT_MOST,

  // Logical operators
  AND,
  OR,
  NOT,

  // String/list operators
  JOINED_WITH,
  CONTAINS,
  UPPERCASE_OF,
  LOWERCASE_OF,
  LENGTH_OF,
  FIRST_OF,
  LAST_OF,
  SLICE_OF,
  OF,

  // Type conversion
  AS,
  NUMBER_TYPE,
  STRING_TYPE,
  BOOLEAN_TYPE,

  // Prefix
  NEGATIVE,

  // Delimiters
  COLON,
  LPAREN,
  RPAREN,
  LBRACKET,
  RBRACKET,
  COMMA,

  // Indentation
  INDENT,
  DEDENT,
  NEWLINE,

  // End
  EOF,
}

interface Token {
  type: TokenType;
  value: string;
  line: number;
}

// ============================================================
// Lexer
// ============================================================

class Lexer {
  private source: string;
  private pos: number = 0;
  private line: number = 1;
  private tokens: Token[] = [];
  private indentStack: number[] = [0];
  private atLineStart: boolean = true;

  constructor(source: string) {
    this.source = source;
  }

  tokenize(): Token[] {
    const lines = this.source.split("\n");
    // Track whether we've emitted any real content yet
    let emittedContent = false;

    for (let i = 0; i < lines.length; i++) {
      this.line = i + 1;
      const rawLine = lines[i];

      // Strip trailing whitespace
      const line = rawLine.replace(/\s+$/, "");

      // Skip empty lines and comment lines
      if (line.length === 0) continue;
      if (line.trimStart().startsWith("--")) continue;

      // Count leading spaces
      let spaces = 0;
      while (spaces < line.length && line[spaces] === " ") spaces++;

      // Handle indentation changes
      const currentIndent = this.indentStack[this.indentStack.length - 1];
      if (spaces > currentIndent) {
        this.indentStack.push(spaces);
        this.tokens.push({ type: TokenType.INDENT, value: "", line: this.line });
      } else if (spaces < currentIndent) {
        while (
          this.indentStack.length > 1 &&
          this.indentStack[this.indentStack.length - 1] > spaces
        ) {
          this.indentStack.pop();
          this.tokens.push({ type: TokenType.DEDENT, value: "", line: this.line });
        }
      }

      // Tokenize the content portion of the line
      this.tokenizeLine(line, spaces);

      // Add NEWLINE token
      this.tokens.push({ type: TokenType.NEWLINE, value: "\\n", line: this.line });
      emittedContent = true;
    }

    // Close remaining indent levels
    while (this.indentStack.length > 1) {
      this.indentStack.pop();
      this.tokens.push({ type: TokenType.DEDENT, value: "", line: this.line });
    }

    this.tokens.push({ type: TokenType.EOF, value: "", line: this.line });
    return this.tokens;
  }

  private tokenizeLine(line: string, startPos: number): void {
    let pos = startPos;

    while (pos < line.length) {
      // Skip spaces within a line
      if (line[pos] === " ") {
        pos++;
        continue;
      }

      // String literal
      if (line[pos] === '"') {
        pos = this.readString(line, pos);
        continue;
      }

      // Number literal
      if (line[pos] >= "0" && line[pos] <= "9") {
        pos = this.readNumber(line, pos);
        continue;
      }

      // Punctuation
      if (line[pos] === ":") {
        this.tokens.push({ type: TokenType.COLON, value: ":", line: this.line });
        pos++;
        continue;
      }
      if (line[pos] === "(") {
        this.tokens.push({ type: TokenType.LPAREN, value: "(", line: this.line });
        pos++;
        continue;
      }
      if (line[pos] === ")") {
        this.tokens.push({ type: TokenType.RPAREN, value: ")", line: this.line });
        pos++;
        continue;
      }
      if (line[pos] === "[") {
        this.tokens.push({ type: TokenType.LBRACKET, value: "[", line: this.line });
        pos++;
        continue;
      }
      if (line[pos] === "]") {
        this.tokens.push({ type: TokenType.RBRACKET, value: "]", line: this.line });
        pos++;
        continue;
      }
      if (line[pos] === ",") {
        this.tokens.push({ type: TokenType.COMMA, value: ",", line: this.line });
        pos++;
        continue;
      }

      // Words (identifiers and keywords)
      if ((line[pos] >= "a" && line[pos] <= "z") || (line[pos] >= "A" && line[pos] <= "Z") || line[pos] === "_") {
        pos = this.readWord(line, pos);
        continue;
      }

      // Skip unknown characters
      pos++;
    }
  }

  private readString(line: string, pos: number): number {
    pos++; // skip opening quote
    let value = "";
    while (pos < line.length && line[pos] !== '"') {
      if (line[pos] === "\\") {
        pos++;
        if (pos < line.length) {
          switch (line[pos]) {
            case "n":
              value += "\n";
              break;
            case "t":
              value += "\t";
              break;
            case "\\":
              value += "\\";
              break;
            case '"':
              value += '"';
              break;
            default:
              value += "\\" + line[pos];
          }
        }
      } else {
        value += line[pos];
      }
      pos++;
    }
    if (pos < line.length) pos++; // skip closing quote
    this.tokens.push({ type: TokenType.STRING, value, line: this.line });
    return pos;
  }

  private readNumber(line: string, pos: number): number {
    let num = "";
    while (pos < line.length && ((line[pos] >= "0" && line[pos] <= "9") || line[pos] === ".")) {
      num += line[pos];
      pos++;
    }
    this.tokens.push({ type: TokenType.NUMBER, value: num, line: this.line });
    return pos;
  }

  private readWord(line: string, startPos: number): number {
    let pos = startPos;
    let word = "";
    while (pos < line.length && ((line[pos] >= "a" && line[pos] <= "z") || (line[pos] >= "A" && line[pos] <= "Z") || (line[pos] >= "0" && line[pos] <= "9") || line[pos] === "_")) {
      word += line[pos];
      pos++;
    }

    // Try to match multi-word keywords
    const rest = line.substring(pos);

    // Check for multi-word keywords (order matters: longest match first)
    const multiWordResult = this.tryMultiWord(word, rest, pos);
    if (multiWordResult) {
      return multiWordResult;
    }

    // Single-word keywords
    switch (word) {
      case "print":
        this.tokens.push({ type: TokenType.PRINT, value: word, line: this.line });
        break;
      case "set":
        this.tokens.push({ type: TokenType.SET, value: word, line: this.line });
        break;
      case "to":
        this.tokens.push({ type: TokenType.TO, value: word, line: this.line });
        break;
      case "if":
        this.tokens.push({ type: TokenType.IF, value: word, line: this.line });
        break;
      case "otherwise":
        this.tokens.push({ type: TokenType.OTHERWISE, value: word, line: this.line });
        break;
      case "while":
        this.tokens.push({ type: TokenType.WHILE, value: word, line: this.line });
        break;
      case "for":
        this.tokens.push({ type: TokenType.FOR, value: word, line: this.line });
        break;
      case "from":
        this.tokens.push({ type: TokenType.FROM, value: word, line: this.line });
        break;
      case "in":
        this.tokens.push({ type: TokenType.IN, value: word, line: this.line });
        break;
      case "repeat":
        this.tokens.push({ type: TokenType.REPEAT, value: word, line: this.line });
        break;
      case "times":
        this.tokens.push({ type: TokenType.TIMES_OP, value: word, line: this.line });
        break;
      case "define":
        this.tokens.push({ type: TokenType.DEFINE, value: word, line: this.line });
        break;
      case "with":
        this.tokens.push({ type: TokenType.WITH, value: word, line: this.line });
        break;
      case "call":
        this.tokens.push({ type: TokenType.CALL, value: word, line: this.line });
        break;
      case "return":
        this.tokens.push({ type: TokenType.RETURN, value: word, line: this.line });
        break;
      case "append":
        this.tokens.push({ type: TokenType.APPEND, value: word, line: this.line });
        break;
      case "stop":
        this.tokens.push({ type: TokenType.STOP, value: word, line: this.line });
        break;
      case "skip":
        this.tokens.push({ type: TokenType.SKIP, value: word, line: this.line });
        break;
      case "plus":
        this.tokens.push({ type: TokenType.PLUS, value: word, line: this.line });
        break;
      case "minus":
        this.tokens.push({ type: TokenType.MINUS, value: word, line: this.line });
        break;
      case "modulo":
        this.tokens.push({ type: TokenType.MODULO, value: word, line: this.line });
        break;
      case "and":
        this.tokens.push({ type: TokenType.AND, value: word, line: this.line });
        break;
      case "or":
        this.tokens.push({ type: TokenType.OR, value: word, line: this.line });
        break;
      case "not":
        this.tokens.push({ type: TokenType.NOT, value: word, line: this.line });
        break;
      case "contains":
        this.tokens.push({ type: TokenType.CONTAINS, value: word, line: this.line });
        break;
      case "of":
        this.tokens.push({ type: TokenType.OF, value: word, line: this.line });
        break;
      case "as":
        this.tokens.push({ type: TokenType.AS, value: word, line: this.line });
        break;
      case "negative":
        this.tokens.push({ type: TokenType.NEGATIVE, value: word, line: this.line });
        break;
      case "true":
        this.tokens.push({ type: TokenType.TRUE, value: word, line: this.line });
        break;
      case "false":
        this.tokens.push({ type: TokenType.FALSE, value: word, line: this.line });
        break;
      case "nothing":
        this.tokens.push({ type: TokenType.NOTHING, value: word, line: this.line });
        break;
      case "number":
        this.tokens.push({ type: TokenType.NUMBER_TYPE, value: word, line: this.line });
        break;
      case "string":
        this.tokens.push({ type: TokenType.STRING_TYPE, value: word, line: this.line });
        break;
      case "boolean":
        this.tokens.push({ type: TokenType.BOOLEAN_TYPE, value: word, line: this.line });
        break;
      default:
        this.tokens.push({ type: TokenType.IDENTIFIER, value: word, line: this.line });
        break;
    }
    return pos;
  }

  private tryMultiWord(word: string, rest: string, pos: number): number | null {
    // "otherwise if"
    if (word === "otherwise" && rest.match(/^\s+if(?:\s|:|$)/)) {
      const m = rest.match(/^(\s+if)/);
      if (m) {
        this.tokens.push({ type: TokenType.OTHERWISE_IF, value: "otherwise if", line: this.line });
        return pos + m[1].length;
      }
    }

    // "for each"
    if (word === "for" && rest.match(/^\s+each\s/)) {
      const m = rest.match(/^(\s+each)/);
      if (m) {
        this.tokens.push({ type: TokenType.FOR_EACH, value: "for each", line: this.line });
        return pos + m[1].length;
      }
    }

    // "divided by"
    if (word === "divided" && rest.match(/^\s+by\s/)) {
      const m = rest.match(/^(\s+by)/);
      if (m) {
        this.tokens.push({ type: TokenType.DIVIDED_BY, value: "divided by", line: this.line });
        return pos + m[1].length;
      }
    }

    // "is not equal to"
    if (word === "is" && rest.match(/^\s+not\s+equal\s+to\s/)) {
      const m = rest.match(/^(\s+not\s+equal\s+to)/);
      if (m) {
        this.tokens.push({ type: TokenType.IS_NOT_EQUAL_TO, value: "is not equal to", line: this.line });
        return pos + m[1].length;
      }
    }

    // "is equal to"
    if (word === "is" && rest.match(/^\s+equal\s+to\s/)) {
      const m = rest.match(/^(\s+equal\s+to)/);
      if (m) {
        this.tokens.push({ type: TokenType.IS_EQUAL_TO, value: "is equal to", line: this.line });
        return pos + m[1].length;
      }
    }

    // "is greater than"
    if (word === "is" && rest.match(/^\s+greater\s+than\s/)) {
      const m = rest.match(/^(\s+greater\s+than)/);
      if (m) {
        this.tokens.push({ type: TokenType.IS_GREATER_THAN, value: "is greater than", line: this.line });
        return pos + m[1].length;
      }
    }

    // "is less than"
    if (word === "is" && rest.match(/^\s+less\s+than\s/)) {
      const m = rest.match(/^(\s+less\s+than)/);
      if (m) {
        this.tokens.push({ type: TokenType.IS_LESS_THAN, value: "is less than", line: this.line });
        return pos + m[1].length;
      }
    }

    // "is at least"
    if (word === "is" && rest.match(/^\s+at\s+least\s/)) {
      const m = rest.match(/^(\s+at\s+least)/);
      if (m) {
        this.tokens.push({ type: TokenType.IS_AT_LEAST, value: "is at least", line: this.line });
        return pos + m[1].length;
      }
    }

    // "is at most"
    if (word === "is" && rest.match(/^\s+at\s+most\s/)) {
      const m = rest.match(/^(\s+at\s+most)/);
      if (m) {
        this.tokens.push({ type: TokenType.IS_AT_MOST, value: "is at most", line: this.line });
        return pos + m[1].length;
      }
    }

    // "joined with"
    if (word === "joined" && rest.match(/^\s+with\s/)) {
      const m = rest.match(/^(\s+with)/);
      if (m) {
        this.tokens.push({ type: TokenType.JOINED_WITH, value: "joined with", line: this.line });
        return pos + m[1].length;
      }
    }

    // "uppercase of"
    if (word === "uppercase" && rest.match(/^\s+of\s/)) {
      const m = rest.match(/^(\s+of)/);
      if (m) {
        this.tokens.push({ type: TokenType.UPPERCASE_OF, value: "uppercase of", line: this.line });
        return pos + m[1].length;
      }
    }

    // "lowercase of"
    if (word === "lowercase" && rest.match(/^\s+of\s/)) {
      const m = rest.match(/^(\s+of)/);
      if (m) {
        this.tokens.push({ type: TokenType.LOWERCASE_OF, value: "lowercase of", line: this.line });
        return pos + m[1].length;
      }
    }

    // "length of"
    if (word === "length" && rest.match(/^\s+of\s/)) {
      const m = rest.match(/^(\s+of)/);
      if (m) {
        this.tokens.push({ type: TokenType.LENGTH_OF, value: "length of", line: this.line });
        return pos + m[1].length;
      }
    }

    // "first of"
    if (word === "first" && rest.match(/^\s+of\s/)) {
      const m = rest.match(/^(\s+of)/);
      if (m) {
        this.tokens.push({ type: TokenType.FIRST_OF, value: "first of", line: this.line });
        return pos + m[1].length;
      }
    }

    // "last of"
    if (word === "last" && rest.match(/^\s+of\s/)) {
      const m = rest.match(/^(\s+of)/);
      if (m) {
        this.tokens.push({ type: TokenType.LAST_OF, value: "last of", line: this.line });
        return pos + m[1].length;
      }
    }

    // "slice of"
    if (word === "slice" && rest.match(/^\s+of\s/)) {
      const m = rest.match(/^(\s+of)/);
      if (m) {
        this.tokens.push({ type: TokenType.SLICE_OF, value: "slice of", line: this.line });
        return pos + m[1].length;
      }
    }

    return null;
  }
}

// ============================================================
// AST Node Types
// ============================================================

type Stmt =
  | PrintStmt
  | SetStmt
  | IfStmt
  | WhileStmt
  | ForEachStmt
  | ForFromStmt
  | RepeatStmt
  | DefineStmt
  | CallStmt
  | ReturnStmt
  | AppendStmt
  | StopStmt
  | SkipStmt
  | ExprStmt;

interface PrintStmt {
  kind: "print";
  expr: Expr;
  line: number;
}

interface SetStmt {
  kind: "set";
  name: string;
  expr: Expr;
  line: number;
}

interface IfStmt {
  kind: "if";
  condition: Expr;
  body: Stmt[];
  elseIfs: { condition: Expr; body: Stmt[] }[];
  elseBody: Stmt[] | null;
  line: number;
}

interface WhileStmt {
  kind: "while";
  condition: Expr;
  body: Stmt[];
  line: number;
}

interface ForEachStmt {
  kind: "for_each";
  variable: string;
  iterable: Expr;
  body: Stmt[];
  line: number;
}

interface ForFromStmt {
  kind: "for_from";
  variable: string;
  from: Expr;
  to: Expr;
  body: Stmt[];
  line: number;
}

interface RepeatStmt {
  kind: "repeat";
  count: Expr;
  body: Stmt[];
  line: number;
}

interface DefineStmt {
  kind: "define";
  name: string;
  params: string[];
  body: Stmt[];
  line: number;
}

interface CallStmt {
  kind: "call_stmt";
  name: string;
  args: Expr[];
  line: number;
}

interface ReturnStmt {
  kind: "return";
  expr: Expr | null;
  line: number;
}

interface AppendStmt {
  kind: "append";
  value: Expr;
  listName: string;
  line: number;
}

interface StopStmt {
  kind: "stop";
  line: number;
}

interface SkipStmt {
  kind: "skip";
  line: number;
}

interface ExprStmt {
  kind: "expr_stmt";
  expr: Expr;
  line: number;
}

type Expr =
  | NumberLit
  | StringLit
  | BooleanLit
  | NothingLit
  | ListLit
  | IdentifierExpr
  | BinaryExpr
  | UnaryExpr
  | CallExpr
  | JoinedWithExpr
  | ContainsExpr
  | AsExpr
  | UppercaseOfExpr
  | LowercaseOfExpr
  | LengthOfExpr
  | FirstOfExpr
  | LastOfExpr
  | ItemOfExpr
  | SliceOfExpr
  | NegativeExpr
  | NotExpr
  | GroupExpr;

interface NumberLit {
  kind: "number";
  value: number;
  line: number;
}

interface StringLit {
  kind: "string";
  value: string;
  line: number;
}

interface BooleanLit {
  kind: "boolean";
  value: boolean;
  line: number;
}

interface NothingLit {
  kind: "nothing";
  line: number;
}

interface ListLit {
  kind: "list";
  elements: Expr[];
  line: number;
}

interface IdentifierExpr {
  kind: "identifier";
  name: string;
  line: number;
}

interface BinaryExpr {
  kind: "binary";
  op: string;
  left: Expr;
  right: Expr;
  line: number;
}

interface UnaryExpr {
  kind: "unary";
  op: string;
  operand: Expr;
  line: number;
}

interface CallExpr {
  kind: "call";
  name: string;
  args: Expr[];
  line: number;
}

interface JoinedWithExpr {
  kind: "joined_with";
  left: Expr;
  right: Expr;
  line: number;
}

interface ContainsExpr {
  kind: "contains";
  left: Expr;
  right: Expr;
  line: number;
}

interface AsExpr {
  kind: "as";
  expr: Expr;
  targetType: "number" | "string" | "boolean";
  line: number;
}

interface UppercaseOfExpr {
  kind: "uppercase_of";
  expr: Expr;
  line: number;
}

interface LowercaseOfExpr {
  kind: "lowercase_of";
  expr: Expr;
  line: number;
}

interface LengthOfExpr {
  kind: "length_of";
  expr: Expr;
  line: number;
}

interface FirstOfExpr {
  kind: "first_of";
  expr: Expr;
  line: number;
}

interface LastOfExpr {
  kind: "last_of";
  expr: Expr;
  line: number;
}

interface ItemOfExpr {
  kind: "item_of";
  index: Expr;
  list: Expr;
  line: number;
}

interface SliceOfExpr {
  kind: "slice_of";
  target: Expr;
  from: Expr;
  to: Expr;
  line: number;
}

interface NegativeExpr {
  kind: "negative";
  expr: Expr;
  line: number;
}

interface NotExpr {
  kind: "not";
  expr: Expr;
  line: number;
}

interface GroupExpr {
  kind: "group";
  expr: Expr;
  line: number;
}

// ============================================================
// Parser
// ============================================================

class Parser {
  private tokens: Token[];
  private pos: number = 0;

  constructor(tokens: Token[]) {
    this.tokens = tokens;
  }

  parse(): Stmt[] {
    const stmts: Stmt[] = [];
    this.skipNewlines();
    while (!this.isAtEnd()) {
      stmts.push(this.parseStatement());
      this.skipNewlines();
    }
    return stmts;
  }

  private parseStatement(): Stmt {
    const tok = this.peek();

    switch (tok.type) {
      case TokenType.PRINT:
        return this.parsePrint();
      case TokenType.SET:
        return this.parseSet();
      case TokenType.IF:
        return this.parseIf();
      case TokenType.WHILE:
        return this.parseWhile();
      case TokenType.FOR_EACH:
        return this.parseForEach();
      case TokenType.FOR:
        return this.parseForFrom();
      case TokenType.REPEAT:
        return this.parseRepeat();
      case TokenType.DEFINE:
        return this.parseDefine();
      case TokenType.CALL:
        return this.parseCallStatement();
      case TokenType.RETURN:
        return this.parseReturn();
      case TokenType.APPEND:
        return this.parseAppend();
      case TokenType.STOP:
        this.advance();
        this.expectNewline();
        return { kind: "stop", line: tok.line };
      case TokenType.SKIP:
        this.advance();
        this.expectNewline();
        return { kind: "skip", line: tok.line };
      default:
        // Try parsing as expression statement
        const expr = this.parseExpression();
        this.expectNewline();
        return { kind: "expr_stmt", expr, line: tok.line };
    }
  }

  private parsePrint(): PrintStmt {
    const tok = this.expect(TokenType.PRINT);
    const expr = this.parseExpression();
    this.expectNewline();
    return { kind: "print", expr, line: tok.line };
  }

  private parseSet(): SetStmt {
    const tok = this.expect(TokenType.SET);
    const name = this.expect(TokenType.IDENTIFIER).value;
    this.expect(TokenType.TO);
    const expr = this.parseExpression();
    this.expectNewline();
    return { kind: "set", name, expr, line: tok.line };
  }

  private parseIf(): IfStmt {
    const tok = this.expect(TokenType.IF);
    const condition = this.parseExpression();
    this.expect(TokenType.COLON);
    this.expectNewline();
    const body = this.parseBlock();

    const elseIfs: { condition: Expr; body: Stmt[] }[] = [];
    let elseBody: Stmt[] | null = null;

    while (this.check(TokenType.OTHERWISE_IF)) {
      this.advance();
      const elseIfCond = this.parseExpression();
      this.expect(TokenType.COLON);
      this.expectNewline();
      const elseIfBody = this.parseBlock();
      elseIfs.push({ condition: elseIfCond, body: elseIfBody });
    }

    if (this.check(TokenType.OTHERWISE)) {
      this.advance();
      this.expect(TokenType.COLON);
      this.expectNewline();
      elseBody = this.parseBlock();
    }

    return { kind: "if", condition, body, elseIfs, elseBody, line: tok.line };
  }

  private parseWhile(): WhileStmt {
    const tok = this.expect(TokenType.WHILE);
    const condition = this.parseExpression();
    this.expect(TokenType.COLON);
    this.expectNewline();
    const body = this.parseBlock();
    return { kind: "while", condition, body, line: tok.line };
  }

  private parseForEach(): ForEachStmt {
    const tok = this.expect(TokenType.FOR_EACH);
    const variable = this.expect(TokenType.IDENTIFIER).value;
    this.expect(TokenType.IN);
    const iterable = this.parseExpression();
    this.expect(TokenType.COLON);
    this.expectNewline();
    const body = this.parseBlock();
    return { kind: "for_each", variable, iterable, body, line: tok.line };
  }

  private parseForFrom(): ForFromStmt {
    const tok = this.expect(TokenType.FOR);
    const variable = this.expect(TokenType.IDENTIFIER).value;
    this.expect(TokenType.FROM);
    const from = this.parseExpression();
    this.expect(TokenType.TO);
    const to = this.parseExpression();
    this.expect(TokenType.COLON);
    this.expectNewline();
    const body = this.parseBlock();
    return { kind: "for_from", variable, from, to, body, line: tok.line };
  }

  private parseRepeat(): RepeatStmt {
    const tok = this.expect(TokenType.REPEAT);
    // Parse count as a primary expression only, to avoid consuming "times" as multiplication
    const count = this.parsePrimary();
    // "times" followed by colon — the lexer emits TIMES_OP for "times"
    this.expect(TokenType.TIMES_OP);
    this.expect(TokenType.COLON);
    this.expectNewline();
    const body = this.parseBlock();
    return { kind: "repeat", count, body, line: tok.line };
  }

  private parseDefine(): DefineStmt {
    const tok = this.expect(TokenType.DEFINE);
    const name = this.expect(TokenType.IDENTIFIER).value;
    const params: string[] = [];

    if (this.check(TokenType.WITH)) {
      this.advance();
      params.push(this.expect(TokenType.IDENTIFIER).value);
      while (this.check(TokenType.AND)) {
        this.advance();
        params.push(this.expect(TokenType.IDENTIFIER).value);
      }
    }

    this.expect(TokenType.COLON);
    this.expectNewline();
    const body = this.parseBlock();
    return { kind: "define", name, params, body, line: tok.line };
  }

  private parseCallStatement(): CallStmt {
    // "call" at statement level (not inside expression)
    const tok = this.peek();
    // Parse as expression, which will handle "call"
    const expr = this.parseExpression();
    this.expectNewline();

    if (expr.kind === "call") {
      return { kind: "call_stmt", name: expr.name, args: expr.args, line: tok.line };
    }
    // Should not happen, but fallback
    return { kind: "call_stmt", name: "", args: [], line: tok.line };
  }

  private parseReturn(): ReturnStmt {
    const tok = this.expect(TokenType.RETURN);
    let expr: Expr | null = null;
    if (!this.check(TokenType.NEWLINE) && !this.check(TokenType.EOF) && !this.check(TokenType.DEDENT)) {
      expr = this.parseExpression();
    }
    this.expectNewline();
    return { kind: "return", expr, line: tok.line };
  }

  private parseAppend(): AppendStmt {
    const tok = this.expect(TokenType.APPEND);
    const value = this.parseExpression();
    this.expect(TokenType.TO);
    const listName = this.expect(TokenType.IDENTIFIER).value;
    this.expectNewline();
    return { kind: "append", value, listName, line: tok.line };
  }

  private parseBlock(): Stmt[] {
    this.expect(TokenType.INDENT);
    const stmts: Stmt[] = [];
    this.skipNewlines();
    while (!this.check(TokenType.DEDENT) && !this.isAtEnd()) {
      stmts.push(this.parseStatement());
      this.skipNewlines();
    }
    if (this.check(TokenType.DEDENT)) {
      this.advance();
    }
    return stmts;
  }

  // ---- Expression Parsing (Pratt-style / recursive descent) ----

  private parseExpression(): Expr {
    return this.parseOr();
  }

  private parseOr(): Expr {
    let left = this.parseAnd();
    while (this.check(TokenType.OR)) {
      const tok = this.advance();
      const right = this.parseAnd();
      left = { kind: "binary", op: "or", left, right, line: tok.line };
    }
    return left;
  }

  private parseAnd(): Expr {
    let left = this.parseNot();
    while (this.check(TokenType.AND)) {
      const tok = this.advance();
      const right = this.parseNot();
      left = { kind: "binary", op: "and", left, right, line: tok.line };
    }
    return left;
  }

  private parseNot(): Expr {
    if (this.check(TokenType.NOT)) {
      const tok = this.advance();
      const operand = this.parseNot();
      return { kind: "not", expr: operand, line: tok.line };
    }
    return this.parseComparison();
  }

  private parseComparison(): Expr {
    let left = this.parseAddition();

    while (
      this.check(TokenType.IS_EQUAL_TO) ||
      this.check(TokenType.IS_NOT_EQUAL_TO) ||
      this.check(TokenType.IS_GREATER_THAN) ||
      this.check(TokenType.IS_LESS_THAN) ||
      this.check(TokenType.IS_AT_LEAST) ||
      this.check(TokenType.IS_AT_MOST)
    ) {
      const tok = this.advance();
      const right = this.parseAddition();
      left = { kind: "binary", op: tok.value, left, right, line: tok.line };
    }

    return left;
  }

  private parseAddition(): Expr {
    let left = this.parseMultiplication();

    while (this.check(TokenType.PLUS) || this.check(TokenType.MINUS)) {
      const tok = this.advance();
      const right = this.parseMultiplication();
      left = { kind: "binary", op: tok.value, left, right, line: tok.line };
    }

    return left;
  }

  private parseMultiplication(): Expr {
    let left = this.parseUnary();

    while (
      this.check(TokenType.TIMES_OP) ||
      this.check(TokenType.DIVIDED_BY) ||
      this.check(TokenType.MODULO)
    ) {
      const tok = this.advance();
      const right = this.parseUnary();
      left = { kind: "binary", op: tok.value, left, right, line: tok.line };
    }

    return left;
  }

  private parseUnary(): Expr {
    if (this.check(TokenType.NEGATIVE)) {
      const tok = this.advance();
      const operand = this.parsePostfix();
      return { kind: "negative", expr: operand, line: tok.line };
    }
    return this.parsePostfix();
  }

  private parsePostfix(): Expr {
    let left = this.parsePrimary();

    while (true) {
      if (this.check(TokenType.JOINED_WITH)) {
        const tok = this.advance();
        const right = this.parsePrimary();
        left = { kind: "joined_with", left, right, line: tok.line };
      } else if (this.check(TokenType.AS)) {
        const tok = this.advance();
        let targetType: "number" | "string" | "boolean";
        if (this.check(TokenType.NUMBER_TYPE)) {
          this.advance();
          targetType = "number";
        } else if (this.check(TokenType.STRING_TYPE)) {
          this.advance();
          targetType = "string";
        } else if (this.check(TokenType.BOOLEAN_TYPE)) {
          this.advance();
          targetType = "boolean";
        } else {
          throw new HumanlangError(tok.line, "Expected type name after 'as'");
        }
        left = { kind: "as", expr: left, targetType, line: tok.line };
      } else if (this.check(TokenType.CONTAINS)) {
        const tok = this.advance();
        const right = this.parsePrimary();
        left = { kind: "contains", left, right, line: tok.line };
      } else {
        break;
      }
    }

    return left;
  }

  private parsePrimary(): Expr {
    const tok = this.peek();

    // Number literal
    if (tok.type === TokenType.NUMBER) {
      this.advance();
      return { kind: "number", value: parseFloat(tok.value), line: tok.line };
    }

    // String literal
    if (tok.type === TokenType.STRING) {
      this.advance();
      return { kind: "string", value: tok.value, line: tok.line };
    }

    // Boolean literals
    if (tok.type === TokenType.TRUE) {
      this.advance();
      return { kind: "boolean", value: true, line: tok.line };
    }
    if (tok.type === TokenType.FALSE) {
      this.advance();
      return { kind: "boolean", value: false, line: tok.line };
    }

    // Nothing
    if (tok.type === TokenType.NOTHING) {
      this.advance();
      return { kind: "nothing", line: tok.line };
    }

    // List literal
    if (tok.type === TokenType.LBRACKET) {
      return this.parseListLiteral();
    }

    // Parenthesized expression
    if (tok.type === TokenType.LPAREN) {
      this.advance();
      const expr = this.parseExpression();
      this.expect(TokenType.RPAREN);
      return { kind: "group", expr, line: tok.line };
    }

    // Prefix operators
    if (tok.type === TokenType.UPPERCASE_OF) {
      this.advance();
      const expr = this.parsePrimary();
      return { kind: "uppercase_of", expr, line: tok.line };
    }
    if (tok.type === TokenType.LOWERCASE_OF) {
      this.advance();
      const expr = this.parsePrimary();
      return { kind: "lowercase_of", expr, line: tok.line };
    }
    if (tok.type === TokenType.LENGTH_OF) {
      this.advance();
      const expr = this.parsePrimary();
      return { kind: "length_of", expr, line: tok.line };
    }
    if (tok.type === TokenType.FIRST_OF) {
      this.advance();
      const expr = this.parsePrimary();
      return { kind: "first_of", expr, line: tok.line };
    }
    if (tok.type === TokenType.LAST_OF) {
      this.advance();
      const expr = this.parsePrimary();
      return { kind: "last_of", expr, line: tok.line };
    }

    // "item N of list" — "item" is lexed as IDENTIFIER
    // Only parse as item-of if next token can start an expression (lookahead for "item <expr> of")
    if (tok.type === TokenType.IDENTIFIER && tok.value === "item") {
      const next = this.tokens[this.pos + 1];
      if (next && (next.type === TokenType.NUMBER || next.type === TokenType.IDENTIFIER ||
          next.type === TokenType.LPAREN || next.type === TokenType.STRING ||
          next.type === TokenType.NEGATIVE || next.type === TokenType.LBRACKET ||
          next.type === TokenType.CALL)) {
        // Try parsing as "item <expr> of <primary>"
        const savedPos = this.pos;
        this.advance(); // consume "item"
        try {
          const index = this.parseExpression();
          if (this.check(TokenType.OF)) {
            this.advance(); // consume "of"
            const list = this.parsePrimary();
            return { kind: "item_of", index, list, line: tok.line };
          }
        } catch {
          // not an item-of expression
        }
        // Backtrack
        this.pos = savedPos;
      }
      // Fall through to treat "item" as a regular identifier
    }

    // "slice of X from A to B"
    if (tok.type === TokenType.SLICE_OF) {
      this.advance();
      const target = this.parsePrimary();
      this.expect(TokenType.FROM);
      const from = this.parseExpression();
      this.expect(TokenType.TO);
      const to = this.parseExpression();
      return { kind: "slice_of", target, from, to, line: tok.line };
    }

    // "call functionname with args"
    if (tok.type === TokenType.CALL) {
      return this.parseCallExpr();
    }

    // Identifier
    if (tok.type === TokenType.IDENTIFIER) {
      this.advance();
      return { kind: "identifier", name: tok.value, line: tok.line };
    }

    throw new HumanlangError(tok.line, `Unexpected token: ${tok.value} (${TokenType[tok.type]})`);
  }

  private parseCallExpr(): CallExpr {
    const tok = this.advance(); // consume CALL
    const name = this.expect(TokenType.IDENTIFIER).value;
    const args: Expr[] = [];
    if (this.check(TokenType.WITH)) {
      this.advance();
      // Parse each argument at the "not" level to avoid consuming "and" as logical operator
      args.push(this.parseNot());
      while (this.check(TokenType.AND)) {
        this.advance();
        args.push(this.parseNot());
      }
    }
    return { kind: "call", name, args, line: tok.line };
  }

  private parseListLiteral(): ListLit {
    const tok = this.expect(TokenType.LBRACKET);
    const elements: Expr[] = [];
    if (!this.check(TokenType.RBRACKET)) {
      elements.push(this.parseExpression());
      while (this.check(TokenType.COMMA)) {
        this.advance();
        elements.push(this.parseExpression());
      }
    }
    this.expect(TokenType.RBRACKET);
    return { kind: "list", elements, line: tok.line };
  }

  // ---- Helpers ----

  private peek(): Token {
    if (this.pos >= this.tokens.length) {
      return { type: TokenType.EOF, value: "", line: 0 };
    }
    return this.tokens[this.pos];
  }

  private advance(): Token {
    const tok = this.peek();
    this.pos++;
    return tok;
  }

  private check(type: TokenType): boolean {
    return this.peek().type === type;
  }

  private expect(type: TokenType): Token {
    const tok = this.peek();
    if (tok.type !== type) {
      throw new HumanlangError(
        tok.line,
        `Expected ${TokenType[type]} but got ${TokenType[tok.type]} ('${tok.value}')`
      );
    }
    return this.advance();
  }

  private expectNewline(): void {
    if (this.check(TokenType.NEWLINE)) {
      this.advance();
    } else if (this.check(TokenType.EOF)) {
      // OK
    } else if (this.check(TokenType.DEDENT)) {
      // OK — dedent can appear before newline
    } else {
      // Don't throw — some statements don't strictly end with newline
    }
  }

  private skipNewlines(): void {
    while (this.check(TokenType.NEWLINE)) {
      this.advance();
    }
  }

  private isAtEnd(): boolean {
    return this.peek().type === TokenType.EOF;
  }
}

// ============================================================
// Runtime Values
// ============================================================

type Value =
  | { type: "number"; value: number }
  | { type: "string"; value: string }
  | { type: "boolean"; value: boolean }
  | { type: "list"; value: Value[] }
  | { type: "nothing" }
  | { type: "function"; name: string; params: string[]; body: Stmt[]; closure: Environment };

function formatValue(val: Value): string {
  switch (val.type) {
    case "number": {
      if (Number.isInteger(val.value)) {
        return String(val.value);
      }
      // Up to 6 decimal places, no trailing zeros
      let s = val.value.toFixed(6);
      // Remove trailing zeros after decimal point
      if (s.includes(".")) {
        s = s.replace(/0+$/, "");
        s = s.replace(/\.$/, "");
      }
      return s;
    }
    case "string":
      return val.value;
    case "boolean":
      return val.value ? "true" : "false";
    case "list":
      return "[" + val.value.map(formatValue).join(", ") + "]";
    case "nothing":
      return "nothing";
    case "function":
      return `<function ${val.name}>`;
  }
}

// ============================================================
// Environment (Lexical Scoping)
// ============================================================

class Environment {
  private vars: Map<string, Value> = new Map();
  readonly parent: Environment | null;

  constructor(parent: Environment | null = null) {
    this.parent = parent;
  }

  get(name: string, line: number): Value {
    if (this.vars.has(name)) {
      return this.vars.get(name)!;
    }
    if (this.parent) {
      return this.parent.get(name, line);
    }
    throw new HumanlangError(line, `Undefined variable '${name}'`);
  }

  set(name: string, value: Value): void {
    this.vars.set(name, value);
  }

  has(name: string): boolean {
    if (this.vars.has(name)) return true;
    if (this.parent) return this.parent.has(name);
    return false;
  }

  // For getting the list reference for append (need to find where the var lives)
  getListRef(name: string, line: number): Value[] {
    const val = this.get(name, line);
    if (val.type !== "list") {
      throw new HumanlangError(line, `'${name}' is not a list`);
    }
    return val.value;
  }
}

// ============================================================
// Control Flow Signals
// ============================================================

class ReturnSignal {
  constructor(public value: Value) {}
}

class StopSignal {}
class SkipSignal {}

// ============================================================
// Error
// ============================================================

class HumanlangError extends Error {
  constructor(public line: number, public description: string) {
    super(`Error on line ${line}: ${description}`);
  }
}

// ============================================================
// Interpreter
// ============================================================

class Interpreter {
  private globals: Environment = new Environment();
  private output: string[] = [];
  private functions: Map<string, Value & { type: "function" }> = new Map();
  private inLoop: number = 0;

  run(program: Stmt[]): string {
    try {
      this.executeBlock(program, this.globals);
    } catch (e) {
      if (e instanceof HumanlangError) {
        process.stderr.write(e.message + "\n");
        process.exit(1);
      }
      if (e instanceof ReturnSignal) {
        throw new HumanlangError(0, "'return' used outside of function");
      }
      throw e;
    }
    return this.output.join("");
  }

  private executeBlock(stmts: Stmt[], env: Environment): void {
    for (const stmt of stmts) {
      this.executeStatement(stmt, env);
    }
  }

  private executeStatement(stmt: Stmt, env: Environment): void {
    switch (stmt.kind) {
      case "print":
        this.executePrint(stmt, env);
        break;
      case "set":
        this.executeSet(stmt, env);
        break;
      case "if":
        this.executeIf(stmt, env);
        break;
      case "while":
        this.executeWhile(stmt, env);
        break;
      case "for_each":
        this.executeForEach(stmt, env);
        break;
      case "for_from":
        this.executeForFrom(stmt, env);
        break;
      case "repeat":
        this.executeRepeat(stmt, env);
        break;
      case "define":
        this.executeDefine(stmt, env);
        break;
      case "call_stmt":
        this.executeCallStmt(stmt, env);
        break;
      case "return":
        this.executeReturn(stmt, env);
        break;
      case "append":
        this.executeAppend(stmt, env);
        break;
      case "stop":
        if (this.inLoop === 0) {
          throw new HumanlangError(stmt.line, "'stop' used outside of loop");
        }
        throw new StopSignal();
      case "skip":
        if (this.inLoop === 0) {
          throw new HumanlangError(stmt.line, "'skip' used outside of loop");
        }
        throw new SkipSignal();
      case "expr_stmt":
        this.evaluate(stmt.expr, env);
        break;
    }
  }

  private executePrint(stmt: PrintStmt, env: Environment): void {
    const val = this.evaluate(stmt.expr, env);
    this.output.push(formatValue(val) + "\n");
  }

  private executeSet(stmt: SetStmt, env: Environment): void {
    const val = this.evaluate(stmt.expr, env);
    env.set(stmt.name, val);
  }

  private executeIf(stmt: IfStmt, env: Environment): void {
    const condVal = this.evaluate(stmt.condition, env);
    if (condVal.type !== "boolean") {
      throw new HumanlangError(stmt.line, "Condition must be a boolean");
    }

    if (condVal.value) {
      this.executeBlock(stmt.body, env);
      return;
    }

    for (const elseIf of stmt.elseIfs) {
      const elseIfCond = this.evaluate(elseIf.condition, env);
      if (elseIfCond.type !== "boolean") {
        throw new HumanlangError(stmt.line, "Condition must be a boolean");
      }
      if (elseIfCond.value) {
        this.executeBlock(elseIf.body, env);
        return;
      }
    }

    if (stmt.elseBody) {
      this.executeBlock(stmt.elseBody, env);
    }
  }

  private executeWhile(stmt: WhileStmt, env: Environment): void {
    this.inLoop++;
    try {
      while (true) {
        const condVal = this.evaluate(stmt.condition, env);
        if (condVal.type !== "boolean") {
          throw new HumanlangError(stmt.line, "Condition must be a boolean");
        }
        if (!condVal.value) break;

        try {
          this.executeBlock(stmt.body, env);
        } catch (e) {
          if (e instanceof StopSignal) break;
          if (e instanceof SkipSignal) continue;
          throw e;
        }
      }
    } finally {
      this.inLoop--;
    }
  }

  private executeForEach(stmt: ForEachStmt, env: Environment): void {
    const iterableVal = this.evaluate(stmt.iterable, env);
    if (iterableVal.type !== "list") {
      throw new HumanlangError(stmt.line, "for each requires a list");
    }

    this.inLoop++;
    try {
      for (const item of iterableVal.value) {
        env.set(stmt.variable, item);
        try {
          this.executeBlock(stmt.body, env);
        } catch (e) {
          if (e instanceof StopSignal) break;
          if (e instanceof SkipSignal) continue;
          throw e;
        }
      }
    } finally {
      this.inLoop--;
    }
  }

  private executeForFrom(stmt: ForFromStmt, env: Environment): void {
    const fromVal = this.evaluate(stmt.from, env);
    const toVal = this.evaluate(stmt.to, env);

    if (fromVal.type !== "number" || toVal.type !== "number") {
      throw new HumanlangError(stmt.line, "for from/to requires numbers");
    }

    const from = fromVal.value;
    const to = toVal.value;

    this.inLoop++;
    try {
      for (let i = from; i <= to; i++) {
        env.set(stmt.variable, { type: "number", value: i });
        try {
          this.executeBlock(stmt.body, env);
        } catch (e) {
          if (e instanceof StopSignal) break;
          if (e instanceof SkipSignal) continue;
          throw e;
        }
      }
    } finally {
      this.inLoop--;
    }
  }

  private executeRepeat(stmt: RepeatStmt, env: Environment): void {
    const countVal = this.evaluate(stmt.count, env);
    if (countVal.type !== "number") {
      throw new HumanlangError(stmt.line, "repeat requires a number");
    }

    const count = countVal.value;
    this.inLoop++;
    try {
      for (let i = 0; i < count; i++) {
        try {
          this.executeBlock(stmt.body, env);
        } catch (e) {
          if (e instanceof StopSignal) break;
          if (e instanceof SkipSignal) continue;
          throw e;
        }
      }
    } finally {
      this.inLoop--;
    }
  }

  private executeDefine(stmt: DefineStmt, env: Environment): void {
    const func: Value & { type: "function" } = {
      type: "function",
      name: stmt.name,
      params: stmt.params,
      body: stmt.body,
      closure: env,
    };
    this.functions.set(stmt.name, func);
    env.set(stmt.name, func);
  }

  private executeCallStmt(stmt: CallStmt, env: Environment): void {
    this.callFunction(stmt.name, stmt.args, env, stmt.line);
  }

  private executeReturn(stmt: ReturnStmt, env: Environment): void {
    let val: Value = { type: "nothing" };
    if (stmt.expr) {
      val = this.evaluate(stmt.expr, env);
    }
    throw new ReturnSignal(val);
  }

  private executeAppend(stmt: AppendStmt, env: Environment): void {
    const val = this.evaluate(stmt.value, env);
    const listVal = env.get(stmt.listName, stmt.line);
    if (listVal.type !== "list") {
      throw new HumanlangError(stmt.line, `'${stmt.listName}' is not a list`);
    }
    listVal.value.push(val);
  }

  private callFunction(name: string, argExprs: Expr[], env: Environment, line: number): Value {
    const func = this.functions.get(name);
    if (!func) {
      throw new HumanlangError(line, `Undefined function '${name}'`);
    }

    if (argExprs.length !== func.params.length) {
      throw new HumanlangError(
        line,
        `Function '${name}' expects ${func.params.length} arguments, got ${argExprs.length}`
      );
    }

    // Evaluate arguments in the calling environment
    const args = argExprs.map((a) => this.evaluate(a, env));

    // Create new scope for the function body, parented to the closure
    const funcEnv = new Environment(func.closure);
    for (let i = 0; i < func.params.length; i++) {
      funcEnv.set(func.params[i], args[i]);
    }

    try {
      this.executeBlock(func.body, funcEnv);
    } catch (e) {
      if (e instanceof ReturnSignal) {
        return e.value;
      }
      throw e;
    }

    return { type: "nothing" };
  }

  // ---- Expression Evaluation ----

  private evaluate(expr: Expr, env: Environment): Value {
    switch (expr.kind) {
      case "number":
        return { type: "number", value: expr.value };
      case "string":
        return { type: "string", value: expr.value };
      case "boolean":
        return { type: "boolean", value: expr.value };
      case "nothing":
        return { type: "nothing" };
      case "list":
        return {
          type: "list",
          value: expr.elements.map((e) => this.evaluate(e, env)),
        };
      case "identifier":
        return env.get(expr.name, expr.line);
      case "group":
        return this.evaluate(expr.expr, env);
      case "binary":
        return this.evalBinary(expr, env);
      case "negative":
        return this.evalNegative(expr, env);
      case "not":
        return this.evalNot(expr, env);
      case "call":
        return this.callFunction(expr.name, expr.args, env, expr.line);
      case "joined_with":
        return this.evalJoinedWith(expr, env);
      case "contains":
        return this.evalContains(expr, env);
      case "as":
        return this.evalAs(expr, env);
      case "uppercase_of":
        return this.evalUppercaseOf(expr, env);
      case "lowercase_of":
        return this.evalLowercaseOf(expr, env);
      case "length_of":
        return this.evalLengthOf(expr, env);
      case "first_of":
        return this.evalFirstOf(expr, env);
      case "last_of":
        return this.evalLastOf(expr, env);
      case "item_of":
        return this.evalItemOf(expr, env);
      case "slice_of":
        return this.evalSliceOf(expr, env);
    }
  }

  private evalBinary(expr: BinaryExpr, env: Environment): Value {
    // Short-circuit for and/or
    if (expr.op === "and") {
      const left = this.evaluate(expr.left, env);
      if (left.type !== "boolean") {
        throw new HumanlangError(expr.line, "Operands to 'and' must be booleans");
      }
      if (!left.value) return { type: "boolean", value: false };
      const right = this.evaluate(expr.right, env);
      if (right.type !== "boolean") {
        throw new HumanlangError(expr.line, "Operands to 'and' must be booleans");
      }
      return { type: "boolean", value: right.value };
    }

    if (expr.op === "or") {
      const left = this.evaluate(expr.left, env);
      if (left.type !== "boolean") {
        throw new HumanlangError(expr.line, "Operands to 'or' must be booleans");
      }
      if (left.value) return { type: "boolean", value: true };
      const right = this.evaluate(expr.right, env);
      if (right.type !== "boolean") {
        throw new HumanlangError(expr.line, "Operands to 'or' must be booleans");
      }
      return { type: "boolean", value: right.value };
    }

    const left = this.evaluate(expr.left, env);
    const right = this.evaluate(expr.right, env);

    // Arithmetic
    if (expr.op === "plus" || expr.op === "minus" || expr.op === "times" || expr.op === "divided by" || expr.op === "modulo") {
      if (left.type !== "number" || right.type !== "number") {
        throw new HumanlangError(expr.line, `Arithmetic requires numbers, got ${left.type} and ${right.type}`);
      }
      switch (expr.op) {
        case "plus":
          return { type: "number", value: left.value + right.value };
        case "minus":
          return { type: "number", value: left.value - right.value };
        case "times":
          return { type: "number", value: left.value * right.value };
        case "divided by":
          if (right.value === 0) {
            throw new HumanlangError(expr.line, "Division by zero");
          }
          return { type: "number", value: left.value / right.value };
        case "modulo":
          if (right.value === 0) {
            throw new HumanlangError(expr.line, "Division by zero");
          }
          return { type: "number", value: left.value % right.value };
      }
    }

    // Comparisons
    if (expr.op === "is equal to") {
      return { type: "boolean", value: this.valuesEqual(left, right) };
    }
    if (expr.op === "is not equal to") {
      return { type: "boolean", value: !this.valuesEqual(left, right) };
    }

    if (expr.op === "is greater than" || expr.op === "is less than" || expr.op === "is at least" || expr.op === "is at most") {
      if (left.type !== right.type) {
        throw new HumanlangError(expr.line, `Cannot compare ${left.type} with ${right.type}`);
      }
      if (left.type === "number" && right.type === "number") {
        switch (expr.op) {
          case "is greater than":
            return { type: "boolean", value: left.value > right.value };
          case "is less than":
            return { type: "boolean", value: left.value < right.value };
          case "is at least":
            return { type: "boolean", value: left.value >= right.value };
          case "is at most":
            return { type: "boolean", value: left.value <= right.value };
        }
      }
      if (left.type === "string" && right.type === "string") {
        switch (expr.op) {
          case "is greater than":
            return { type: "boolean", value: left.value > right.value };
          case "is less than":
            return { type: "boolean", value: left.value < right.value };
          case "is at least":
            return { type: "boolean", value: left.value >= right.value };
          case "is at most":
            return { type: "boolean", value: left.value <= right.value };
        }
      }
      throw new HumanlangError(expr.line, `Cannot order ${left.type} values`);
    }

    throw new HumanlangError(expr.line, `Unknown operator: ${expr.op}`);
  }

  private valuesEqual(a: Value, b: Value): boolean {
    if (a.type !== b.type) return false;
    switch (a.type) {
      case "number":
        return a.value === (b as typeof a).value;
      case "string":
        return a.value === (b as typeof a).value;
      case "boolean":
        return a.value === (b as typeof a).value;
      case "nothing":
        return true;
      case "list": {
        const bl = b as typeof a;
        if (a.value.length !== bl.value.length) return false;
        for (let i = 0; i < a.value.length; i++) {
          if (!this.valuesEqual(a.value[i], bl.value[i])) return false;
        }
        return true;
      }
      default:
        return false;
    }
  }

  private evalNegative(expr: NegativeExpr, env: Environment): Value {
    const val = this.evaluate(expr.expr, env);
    if (val.type !== "number") {
      throw new HumanlangError(expr.line, "'negative' requires a number");
    }
    return { type: "number", value: -val.value };
  }

  private evalNot(expr: NotExpr, env: Environment): Value {
    const val = this.evaluate(expr.expr, env);
    if (val.type !== "boolean") {
      throw new HumanlangError(expr.line, "'not' requires a boolean");
    }
    return { type: "boolean", value: !val.value };
  }

  private evalJoinedWith(expr: JoinedWithExpr, env: Environment): Value {
    const left = this.evaluate(expr.left, env);
    const right = this.evaluate(expr.right, env);
    return {
      type: "string",
      value: formatValue(left) + formatValue(right),
    };
  }

  private evalContains(expr: ContainsExpr, env: Environment): Value {
    const left = this.evaluate(expr.left, env);
    const right = this.evaluate(expr.right, env);

    if (left.type === "string") {
      if (right.type !== "string") {
        throw new HumanlangError(expr.line, "String contains requires a string argument");
      }
      return { type: "boolean", value: left.value.includes(right.value) };
    }

    if (left.type === "list") {
      for (const item of left.value) {
        if (this.valuesEqual(item, right)) {
          return { type: "boolean", value: true };
        }
      }
      return { type: "boolean", value: false };
    }

    throw new HumanlangError(expr.line, "'contains' requires a string or list");
  }

  private evalAs(expr: AsExpr, env: Environment): Value {
    const val = this.evaluate(expr.expr, env);

    switch (expr.targetType) {
      case "number": {
        if (val.type === "number") return val;
        if (val.type === "string") {
          const n = Number(val.value);
          if (isNaN(n) || val.value.trim() === "") {
            throw new HumanlangError(expr.line, `Cannot convert "${val.value}" to number`);
          }
          return { type: "number", value: n };
        }
        if (val.type === "boolean") {
          return { type: "number", value: val.value ? 1 : 0 };
        }
        throw new HumanlangError(expr.line, `Cannot convert ${val.type} to number`);
      }
      case "string": {
        return { type: "string", value: formatValue(val) };
      }
      case "boolean": {
        switch (val.type) {
          case "number":
            return { type: "boolean", value: val.value !== 0 };
          case "string":
            return { type: "boolean", value: val.value !== "" };
          case "boolean":
            return val;
          case "list":
            return { type: "boolean", value: val.value.length > 0 };
          case "nothing":
            return { type: "boolean", value: false };
          default:
            throw new HumanlangError(expr.line, `Cannot convert ${val.type} to boolean`);
        }
      }
    }
  }

  private evalUppercaseOf(expr: UppercaseOfExpr, env: Environment): Value {
    const val = this.evaluate(expr.expr, env);
    if (val.type !== "string") {
      throw new HumanlangError(expr.line, "'uppercase of' requires a string");
    }
    return { type: "string", value: val.value.toUpperCase() };
  }

  private evalLowercaseOf(expr: LowercaseOfExpr, env: Environment): Value {
    const val = this.evaluate(expr.expr, env);
    if (val.type !== "string") {
      throw new HumanlangError(expr.line, "'lowercase of' requires a string");
    }
    return { type: "string", value: val.value.toLowerCase() };
  }

  private evalLengthOf(expr: LengthOfExpr, env: Environment): Value {
    const val = this.evaluate(expr.expr, env);
    if (val.type === "string") {
      return { type: "number", value: val.value.length };
    }
    if (val.type === "list") {
      return { type: "number", value: val.value.length };
    }
    throw new HumanlangError(expr.line, "'length of' requires a string or list");
  }

  private evalFirstOf(expr: FirstOfExpr, env: Environment): Value {
    const val = this.evaluate(expr.expr, env);
    if (val.type !== "list") {
      throw new HumanlangError(expr.line, "'first of' requires a list");
    }
    if (val.value.length === 0) {
      throw new HumanlangError(expr.line, "Cannot get first element of empty list");
    }
    return val.value[0];
  }

  private evalLastOf(expr: LastOfExpr, env: Environment): Value {
    const val = this.evaluate(expr.expr, env);
    if (val.type !== "list") {
      throw new HumanlangError(expr.line, "'last of' requires a list");
    }
    if (val.value.length === 0) {
      throw new HumanlangError(expr.line, "Cannot get last element of empty list");
    }
    return val.value[val.value.length - 1];
  }

  private evalItemOf(expr: ItemOfExpr, env: Environment): Value {
    const indexVal = this.evaluate(expr.index, env);
    const listVal = this.evaluate(expr.list, env);

    if (indexVal.type !== "number") {
      throw new HumanlangError(expr.line, "'item' index must be a number");
    }
    if (listVal.type !== "list") {
      throw new HumanlangError(expr.line, "'item of' requires a list");
    }

    const idx = indexVal.value;
    if (!Number.isInteger(idx) || idx < 0 || idx >= listVal.value.length) {
      throw new HumanlangError(expr.line, `Index ${idx} out of bounds for list of length ${listVal.value.length}`);
    }

    return listVal.value[idx];
  }

  private evalSliceOf(expr: SliceOfExpr, env: Environment): Value {
    const target = this.evaluate(expr.target, env);
    const fromVal = this.evaluate(expr.from, env);
    const toVal = this.evaluate(expr.to, env);

    if (fromVal.type !== "number" || toVal.type !== "number") {
      throw new HumanlangError(expr.line, "Slice indices must be numbers");
    }

    const from = fromVal.value;
    const to = toVal.value;

    if (target.type === "string") {
      return { type: "string", value: target.value.slice(from, to) };
    }
    if (target.type === "list") {
      return { type: "list", value: target.value.slice(from, to) };
    }

    throw new HumanlangError(expr.line, "'slice of' requires a string or list");
  }
}

// ============================================================
// Main
// ============================================================

function main(): void {
  const args = process.argv.slice(2);
  if (args.length < 1) {
    console.error("Usage: humanlang <file.hl>");
    process.exit(1);
  }

  const filePath = path.resolve(args[0]);
  let source: string;
  try {
    source = fs.readFileSync(filePath, "utf-8");
  } catch (e) {
    console.error(`Error: Cannot read file '${filePath}'`);
    process.exit(1);
  }

  const lexer = new Lexer(source);
  let tokens: Token[];
  try {
    tokens = lexer.tokenize();
  } catch (e) {
    if (e instanceof HumanlangError) {
      process.stderr.write(e.message + "\n");
      process.exit(1);
    }
    throw e;
  }

  const parser = new Parser(tokens);
  let ast: Stmt[];
  try {
    ast = parser.parse();
  } catch (e) {
    if (e instanceof HumanlangError) {
      process.stderr.write(e.message + "\n");
      process.exit(1);
    }
    throw e;
  }

  const interpreter = new Interpreter();
  const output = interpreter.run(ast);
  process.stdout.write(output);
}

main();
