#!/usr/bin/env python3
"""humanlang interpreter — lexer, parser, and tree-walk interpreter."""

import sys
import math
import re

# ---------------------------------------------------------------------------
# Token types
# ---------------------------------------------------------------------------

class TT:
    # Literals
    NUMBER   = 'NUMBER'
    STRING   = 'STRING'
    TRUE     = 'TRUE'
    FALSE    = 'FALSE'
    NOTHING  = 'NOTHING'
    IDENT    = 'IDENT'

    # Delimiters / structure
    LPAREN   = 'LPAREN'
    RPAREN   = 'RPAREN'
    LBRACKET = 'LBRACKET'
    RBRACKET = 'RBRACKET'
    COMMA    = 'COMMA'
    COLON    = 'COLON'
    NEWLINE  = 'NEWLINE'
    INDENT   = 'INDENT'
    DEDENT   = 'DEDENT'
    EOF      = 'EOF'

    # Keywords (single-word)
    PRINT    = 'PRINT'
    SET      = 'SET'
    TO       = 'TO'
    IF       = 'IF'
    OTHERWISE = 'OTHERWISE'
    WHILE    = 'WHILE'
    REPEAT   = 'REPEAT'
    TIMES    = 'TIMES'
    FOR      = 'FOR'
    FROM     = 'FROM'
    IN       = 'IN'
    DEFINE   = 'DEFINE'
    WITH     = 'WITH'
    CALL     = 'CALL'
    RETURN   = 'RETURN'
    AND      = 'AND'
    OR       = 'OR'
    NOT      = 'NOT'
    PLUS     = 'PLUS'
    MINUS    = 'MINUS'
    MODULO   = 'MODULO'
    APPEND   = 'APPEND'
    STOP     = 'STOP'
    SKIP     = 'SKIP'
    NEGATIVE = 'NEGATIVE'
    CONTAINS = 'CONTAINS'
    ITEM     = 'ITEM'
    OF       = 'OF'
    AS       = 'AS'

    # Multi-word keywords (lexed as single tokens)
    DIVIDED_BY       = 'DIVIDED_BY'
    IS_EQUAL_TO      = 'IS_EQUAL_TO'
    IS_NOT_EQUAL_TO  = 'IS_NOT_EQUAL_TO'
    IS_GREATER_THAN  = 'IS_GREATER_THAN'
    IS_LESS_THAN     = 'IS_LESS_THAN'
    IS_AT_LEAST      = 'IS_AT_LEAST'
    IS_AT_MOST       = 'IS_AT_MOST'
    FOR_EACH         = 'FOR_EACH'
    OTHERWISE_IF     = 'OTHERWISE_IF'
    JOINED_WITH      = 'JOINED_WITH'
    UPPERCASE_OF     = 'UPPERCASE_OF'
    LOWERCASE_OF     = 'LOWERCASE_OF'
    LENGTH_OF        = 'LENGTH_OF'
    FIRST_OF         = 'FIRST_OF'
    LAST_OF          = 'LAST_OF'
    SLICE_OF         = 'SLICE_OF'

    # Type names (used after 'as')
    T_NUMBER  = 'T_NUMBER'
    T_STRING  = 'T_STRING'
    T_BOOLEAN = 'T_BOOLEAN'


class Token:
    __slots__ = ('type', 'value', 'line')
    def __init__(self, type, value, line):
        self.type = type
        self.value = value
        self.line = line
    def __repr__(self):
        return f'Token({self.type}, {self.value!r}, L{self.line})'


# ---------------------------------------------------------------------------
# Lexer
# ---------------------------------------------------------------------------

# Multi-word keywords, ordered longest-first so greedy matching works.
MULTI_WORD = [
    (['is', 'not', 'equal', 'to'], TT.IS_NOT_EQUAL_TO),
    (['is', 'greater', 'than'],    TT.IS_GREATER_THAN),
    (['is', 'equal', 'to'],        TT.IS_EQUAL_TO),
    (['is', 'less', 'than'],       TT.IS_LESS_THAN),
    (['is', 'at', 'least'],        TT.IS_AT_LEAST),
    (['is', 'at', 'most'],         TT.IS_AT_MOST),
    (['divided', 'by'],            TT.DIVIDED_BY),
    (['joined', 'with'],           TT.JOINED_WITH),
    (['for', 'each'],              TT.FOR_EACH),
    (['otherwise', 'if'],          TT.OTHERWISE_IF),
    (['uppercase', 'of'],          TT.UPPERCASE_OF),
    (['lowercase', 'of'],          TT.LOWERCASE_OF),
    (['length', 'of'],             TT.LENGTH_OF),
    (['first', 'of'],              TT.FIRST_OF),
    (['last', 'of'],               TT.LAST_OF),
    (['slice', 'of'],              TT.SLICE_OF),
]

SINGLE_KEYWORDS = {
    'print':     TT.PRINT,
    'set':       TT.SET,
    'to':        TT.TO,
    'if':        TT.IF,
    'otherwise': TT.OTHERWISE,
    'while':     TT.WHILE,
    'repeat':    TT.REPEAT,
    'times':     TT.TIMES,
    'for':       TT.FOR,
    'from':      TT.FROM,
    'in':        TT.IN,
    'define':    TT.DEFINE,
    'with':      TT.WITH,
    'call':      TT.CALL,
    'return':    TT.RETURN,
    'and':       TT.AND,
    'or':        TT.OR,
    'not':       TT.NOT,
    'plus':      TT.PLUS,
    'minus':     TT.MINUS,
    'modulo':    TT.MODULO,
    'append':    TT.APPEND,
    'stop':      TT.STOP,
    'skip':      TT.SKIP,
    'negative':  TT.NEGATIVE,
    'true':      TT.TRUE,
    'false':     TT.FALSE,
    'nothing':   TT.NOTHING,
    'contains':  TT.CONTAINS,
    'item':      TT.ITEM,
    'of':        TT.OF,
    'as':        TT.AS,
}


def lex(source: str) -> list:
    """Tokenise humanlang source into a flat list of tokens."""
    tokens = []
    lines = source.split('\n')
    indent_stack = [0]

    for lineno_0, raw_line in enumerate(lines):
        lineno = lineno_0 + 1

        # Strip trailing whitespace
        line = raw_line.rstrip()

        # Skip blank lines
        if line == '':
            continue

        # Skip comment lines
        stripped = line.lstrip()
        if stripped.startswith('--'):
            continue

        # --- Indentation handling ---
        # Count leading spaces
        indent = len(line) - len(stripped)
        level = indent // 4  # each indent = 4 spaces

        if level > indent_stack[-1]:
            indent_stack.append(level)
            tokens.append(Token(TT.INDENT, None, lineno))
        else:
            while level < indent_stack[-1]:
                indent_stack.pop()
                tokens.append(Token(TT.DEDENT, None, lineno))

        # --- Tokenise the line content ---
        # We work with a list of "words" but also handle strings, numbers, symbols.
        pos = indent  # start past leading whitespace
        line_len = len(line)

        while pos < line_len:
            ch = line[pos]

            # Skip spaces between tokens
            if ch == ' ':
                pos += 1
                continue

            # String literal
            if ch == '"':
                pos += 1
                s = []
                while pos < line_len and line[pos] != '"':
                    if line[pos] == '\\' and pos + 1 < line_len:
                        nc = line[pos + 1]
                        if nc == 'n':
                            s.append('\n')
                            pos += 2
                        elif nc == 't':
                            s.append('\t')
                            pos += 2
                        elif nc == '\\':
                            s.append('\\')
                            pos += 2
                        elif nc == '"':
                            s.append('"')
                            pos += 2
                        else:
                            s.append(line[pos])
                            pos += 1
                    else:
                        s.append(line[pos])
                        pos += 1
                if pos < line_len:
                    pos += 1  # skip closing "
                tokens.append(Token(TT.STRING, ''.join(s), lineno))
                continue

            # Number literal
            if ch.isdigit() or (ch == '.' and pos + 1 < line_len and line[pos+1].isdigit()):
                start = pos
                while pos < line_len and (line[pos].isdigit() or line[pos] == '.'):
                    pos += 1
                numstr = line[start:pos]
                if '.' in numstr:
                    tokens.append(Token(TT.NUMBER, float(numstr), lineno))
                else:
                    tokens.append(Token(TT.NUMBER, float(numstr), lineno))
                continue

            # Single-char symbols
            if ch == '(':
                tokens.append(Token(TT.LPAREN, '(', lineno))
                pos += 1
                continue
            if ch == ')':
                tokens.append(Token(TT.RPAREN, ')', lineno))
                pos += 1
                continue
            if ch == '[':
                tokens.append(Token(TT.LBRACKET, '[', lineno))
                pos += 1
                continue
            if ch == ']':
                tokens.append(Token(TT.RBRACKET, ']', lineno))
                pos += 1
                continue
            if ch == ',':
                tokens.append(Token(TT.COMMA, ',', lineno))
                pos += 1
                continue
            if ch == ':':
                tokens.append(Token(TT.COLON, ':', lineno))
                pos += 1
                continue

            # Word (identifier / keyword)
            if ch.isalpha() or ch == '_':
                start = pos
                while pos < line_len and (line[pos].isalnum() or line[pos] == '_'):
                    pos += 1
                word = line[start:pos]

                # Try multi-word keywords: look ahead to see if this word starts one.
                matched_multi = False
                for mw_words, mw_tt in MULTI_WORD:
                    if mw_words[0] != word:
                        continue
                    # Try to match remaining words
                    saved_pos = pos
                    ok = True
                    for i in range(1, len(mw_words)):
                        # skip spaces
                        p = saved_pos
                        while p < line_len and line[p] == ' ':
                            p += 1
                        # read next word
                        if p >= line_len or not line[p].isalpha():
                            ok = False
                            break
                        ws = p
                        while p < line_len and (line[p].isalnum() or line[p] == '_'):
                            p += 1
                        nw = line[ws:p]
                        if nw != mw_words[i]:
                            ok = False
                            break
                        saved_pos = p
                    if ok:
                        tokens.append(Token(mw_tt, ' '.join(mw_words), lineno))
                        pos = saved_pos
                        matched_multi = True
                        break

                if not matched_multi:
                    if word in SINGLE_KEYWORDS:
                        tokens.append(Token(SINGLE_KEYWORDS[word], word, lineno))
                    else:
                        tokens.append(Token(TT.IDENT, word, lineno))
                continue

            # Unrecognised character -- skip
            pos += 1

        # End of non-blank line -> emit NEWLINE
        tokens.append(Token(TT.NEWLINE, None, lineno))

    # Emit remaining DEDENTs
    while indent_stack[-1] > 0:
        indent_stack.pop()
        tokens.append(Token(TT.DEDENT, None, lineno if lines else 0))

    tokens.append(Token(TT.EOF, None, lineno if lines else 0))
    return tokens


# ---------------------------------------------------------------------------
# AST node classes
# ---------------------------------------------------------------------------

class NumberLit:
    __slots__ = ('value', 'line')
    def __init__(self, value, line): self.value = value; self.line = line

class StringLit:
    __slots__ = ('value', 'line')
    def __init__(self, value, line): self.value = value; self.line = line

class BoolLit:
    __slots__ = ('value', 'line')
    def __init__(self, value, line): self.value = value; self.line = line

class NothingLit:
    __slots__ = ('line',)
    def __init__(self, line): self.line = line

class ListLit:
    __slots__ = ('elements', 'line')
    def __init__(self, elements, line): self.elements = elements; self.line = line

class Identifier:
    __slots__ = ('name', 'line')
    def __init__(self, name, line): self.name = name; self.line = line

class BinOp:
    __slots__ = ('op', 'left', 'right', 'line')
    def __init__(self, op, left, right, line):
        self.op = op; self.left = left; self.right = right; self.line = line

class UnaryOp:
    __slots__ = ('op', 'operand', 'line')
    def __init__(self, op, operand, line): self.op = op; self.operand = operand; self.line = line

class PrefixOp:
    """For uppercase of, lowercase of, length of, first of, last of."""
    __slots__ = ('op', 'operand', 'line')
    def __init__(self, op, operand, line): self.op = op; self.operand = operand; self.line = line

class ItemAccess:
    __slots__ = ('index', 'target', 'line')
    def __init__(self, index, target, line): self.index = index; self.target = target; self.line = line

class SliceExpr:
    __slots__ = ('target', 'start', 'end', 'line')
    def __init__(self, target, start, end, line):
        self.target = target; self.start = start; self.end = end; self.line = line

class AsExpr:
    __slots__ = ('expr', 'target_type', 'line')
    def __init__(self, expr, target_type, line):
        self.expr = expr; self.target_type = target_type; self.line = line

class ContainsExpr:
    __slots__ = ('container', 'item', 'line')
    def __init__(self, container, item, line):
        self.container = container; self.item = item; self.line = line

class JoinedWithExpr:
    __slots__ = ('left', 'right', 'line')
    def __init__(self, left, right, line):
        self.left = left; self.right = right; self.line = line

class CallExpr:
    __slots__ = ('name', 'args', 'line')
    def __init__(self, name, args, line): self.name = name; self.args = args; self.line = line

# Statements
class PrintStmt:
    __slots__ = ('expr', 'line')
    def __init__(self, expr, line): self.expr = expr; self.line = line

class SetStmt:
    __slots__ = ('name', 'expr', 'line')
    def __init__(self, name, expr, line): self.name = name; self.expr = expr; self.line = line

class AppendStmt:
    __slots__ = ('value', 'target', 'line')
    def __init__(self, value, target, line):
        self.value = value; self.target = target; self.line = line

class IfStmt:
    __slots__ = ('condition', 'body', 'elifs', 'else_body', 'line')
    def __init__(self, condition, body, elifs, else_body, line):
        self.condition = condition; self.body = body
        self.elifs = elifs; self.else_body = else_body; self.line = line

class WhileStmt:
    __slots__ = ('condition', 'body', 'line')
    def __init__(self, condition, body, line):
        self.condition = condition; self.body = body; self.line = line

class RepeatStmt:
    __slots__ = ('count', 'body', 'line')
    def __init__(self, count, body, line):
        self.count = count; self.body = body; self.line = line

class ForEachStmt:
    __slots__ = ('var', 'iterable', 'body', 'line')
    def __init__(self, var, iterable, body, line):
        self.var = var; self.iterable = iterable; self.body = body; self.line = line

class ForFromStmt:
    __slots__ = ('var', 'start', 'end', 'body', 'line')
    def __init__(self, var, start, end, body, line):
        self.var = var; self.start = start; self.end = end; self.body = body; self.line = line

class DefineStmt:
    __slots__ = ('name', 'params', 'body', 'line')
    def __init__(self, name, params, body, line):
        self.name = name; self.params = params; self.body = body; self.line = line

class CallStmt:
    __slots__ = ('expr', 'line')
    def __init__(self, expr, line): self.expr = expr; self.line = line

class ReturnStmt:
    __slots__ = ('expr', 'line')
    def __init__(self, expr, line): self.expr = expr; self.line = line

class StopStmt:
    __slots__ = ('line',)
    def __init__(self, line): self.line = line

class SkipStmt:
    __slots__ = ('line',)
    def __init__(self, line): self.line = line


# ---------------------------------------------------------------------------
# Parser
# ---------------------------------------------------------------------------

class ParseError(Exception):
    def __init__(self, msg, line):
        super().__init__(msg)
        self.line = line


class Parser:
    def __init__(self, tokens):
        self.tokens = tokens
        self.pos = 0

    def peek(self):
        return self.tokens[self.pos]

    def advance(self):
        t = self.tokens[self.pos]
        self.pos += 1
        return t

    def expect(self, tt):
        t = self.peek()
        if t.type != tt:
            raise ParseError(f"Expected {tt}, got {t.type} ({t.value!r})", t.line)
        return self.advance()

    # Keywords that can also serve as identifiers in variable-name positions.
    IDENT_KEYWORDS = {
        TT.ITEM, TT.TIMES, TT.MODULO, TT.CONTAINS, TT.OF, TT.AS,
        TT.FROM, TT.IN, TT.TO, TT.WITH,
    }

    def expect_ident(self):
        """Expect an identifier. Also accepts certain keywords used as variable names."""
        t = self.peek()
        if t.type == TT.IDENT:
            return self.advance()
        if t.type in self.IDENT_KEYWORDS:
            tok = self.advance()
            return Token(TT.IDENT, tok.value, tok.line)
        raise ParseError(f"Expected identifier, got {t.type} ({t.value!r})", t.line)

    def match(self, *tts):
        if self.peek().type in tts:
            return self.advance()
        return None

    def skip_newlines(self):
        while self.peek().type == TT.NEWLINE:
            self.advance()

    # --- Program / blocks ---

    def parse_program(self):
        stmts = []
        self.skip_newlines()
        while self.peek().type != TT.EOF:
            stmts.append(self.parse_statement())
            self.skip_newlines()
        return stmts

    def parse_block(self):
        self.expect(TT.COLON)
        self.expect(TT.NEWLINE)
        self.expect(TT.INDENT)
        stmts = []
        while self.peek().type != TT.DEDENT and self.peek().type != TT.EOF:
            stmts.append(self.parse_statement())
            self.skip_newlines()
        if self.peek().type == TT.DEDENT:
            self.advance()
        return stmts

    # --- Statements ---

    def parse_statement(self):
        t = self.peek()

        if t.type == TT.PRINT:
            return self.parse_print()
        if t.type == TT.SET:
            return self.parse_set()
        if t.type == TT.IF:
            return self.parse_if()
        if t.type == TT.OTHERWISE_IF:
            raise ParseError("Unexpected 'otherwise if' without matching 'if'", t.line)
        if t.type == TT.OTHERWISE:
            raise ParseError("Unexpected 'otherwise' without matching 'if'", t.line)
        if t.type == TT.WHILE:
            return self.parse_while()
        if t.type == TT.REPEAT:
            return self.parse_repeat()
        if t.type == TT.FOR_EACH:
            return self.parse_for_each()
        if t.type == TT.FOR:
            return self.parse_for_from()
        if t.type == TT.DEFINE:
            return self.parse_define()
        if t.type == TT.CALL:
            expr = self.parse_call_expr()
            self.expect(TT.NEWLINE)
            return CallStmt(expr, t.line)
        if t.type == TT.RETURN:
            return self.parse_return()
        if t.type == TT.APPEND:
            return self.parse_append()
        if t.type == TT.STOP:
            self.advance()
            self.expect(TT.NEWLINE)
            return StopStmt(t.line)
        if t.type == TT.SKIP:
            self.advance()
            self.expect(TT.NEWLINE)
            return SkipStmt(t.line)

        raise ParseError(f"Unexpected token {t.type} ({t.value!r})", t.line)

    def parse_print(self):
        t = self.advance()  # consume 'print'
        expr = self.parse_expression()
        self.expect(TT.NEWLINE)
        return PrintStmt(expr, t.line)

    def parse_set(self):
        t = self.advance()  # consume 'set'
        name_tok = self.expect_ident()
        self.expect(TT.TO)
        expr = self.parse_expression()
        self.expect(TT.NEWLINE)
        return SetStmt(name_tok.value, expr, t.line)

    def parse_if(self):
        t = self.advance()  # consume 'if'
        cond = self.parse_expression()
        body = self.parse_block()

        elifs = []
        else_body = None

        self.skip_newlines()
        while self.peek().type == TT.OTHERWISE_IF:
            self.advance()
            elif_cond = self.parse_expression()
            elif_body = self.parse_block()
            elifs.append((elif_cond, elif_body))
            self.skip_newlines()

        if self.peek().type == TT.OTHERWISE:
            self.advance()
            else_body = self.parse_block()

        return IfStmt(cond, body, elifs, else_body, t.line)

    def parse_while(self):
        t = self.advance()
        cond = self.parse_expression()
        body = self.parse_block()
        return WhileStmt(cond, body, t.line)

    def parse_repeat(self):
        t = self.advance()
        # Parse count at unary level so 'times' is not consumed as an arithmetic operator
        count = self.parse_unary()
        self.expect(TT.TIMES)
        body = self.parse_block()
        return RepeatStmt(count, body, t.line)

    def parse_for_each(self):
        t = self.advance()  # consume 'for each'
        var = self.expect_ident()
        self.expect(TT.IN)
        iterable = self.parse_expression()
        body = self.parse_block()
        return ForEachStmt(var.value, iterable, body, t.line)

    def parse_for_from(self):
        t = self.advance()  # consume 'for'
        var = self.expect_ident()
        self.expect(TT.FROM)
        start = self.parse_expression()
        self.expect(TT.TO)
        end = self.parse_expression()
        body = self.parse_block()
        return ForFromStmt(var.value, start, end, body, t.line)

    def parse_define(self):
        t = self.advance()  # consume 'define'
        name = self.expect_ident()
        params = []
        if self.peek().type == TT.WITH:
            self.advance()
            params.append(self.expect_ident().value)
            while self.peek().type == TT.AND:
                self.advance()
                params.append(self.expect_ident().value)
        body = self.parse_block()
        return DefineStmt(name.value, params, body, t.line)

    def parse_return(self):
        t = self.advance()
        if self.peek().type == TT.NEWLINE:
            self.advance()
            return ReturnStmt(None, t.line)
        expr = self.parse_expression()
        self.expect(TT.NEWLINE)
        return ReturnStmt(expr, t.line)

    def parse_append(self):
        t = self.advance()  # consume 'append'
        value = self.parse_expression()
        self.expect(TT.TO)
        target = self.expect_ident()
        self.expect(TT.NEWLINE)
        return AppendStmt(value, target.value, t.line)

    # --- Expressions (precedence climbing) ---

    def parse_expression(self):
        return self.parse_or()

    def parse_or(self):
        left = self.parse_and()
        while self.peek().type == TT.OR:
            op = self.advance()
            right = self.parse_and()
            left = BinOp('or', left, right, op.line)
        return left

    def parse_and(self):
        left = self.parse_not()
        while self.peek().type == TT.AND:
            op = self.advance()
            right = self.parse_not()
            left = BinOp('and', left, right, op.line)
        return left

    def parse_not(self):
        if self.peek().type == TT.NOT:
            op = self.advance()
            operand = self.parse_not()
            return UnaryOp('not', operand, op.line)
        return self.parse_comparison()

    def parse_comparison(self):
        left = self.parse_addition()
        comp_tokens = {
            TT.IS_EQUAL_TO, TT.IS_NOT_EQUAL_TO,
            TT.IS_GREATER_THAN, TT.IS_LESS_THAN,
            TT.IS_AT_LEAST, TT.IS_AT_MOST,
        }
        while self.peek().type in comp_tokens:
            op = self.advance()
            right = self.parse_addition()
            left = BinOp(op.type, left, right, op.line)
        return left

    def parse_addition(self):
        left = self.parse_multiplication()
        while self.peek().type in (TT.PLUS, TT.MINUS):
            op = self.advance()
            right = self.parse_multiplication()
            left = BinOp(op.type, left, right, op.line)
        return left

    def parse_multiplication(self):
        left = self.parse_unary()
        while self.peek().type in (TT.TIMES, TT.DIVIDED_BY, TT.MODULO):
            op = self.advance()
            right = self.parse_unary()
            left = BinOp(op.type, left, right, op.line)
        return left

    def parse_unary(self):
        if self.peek().type == TT.NEGATIVE:
            op = self.advance()
            operand = self.parse_postfix()
            return UnaryOp('negative', operand, op.line)
        return self.parse_postfix()

    def parse_postfix(self):
        left = self.parse_primary()
        while True:
            if self.peek().type == TT.JOINED_WITH:
                op = self.advance()
                right = self.parse_primary()
                left = JoinedWithExpr(left, right, op.line)
            elif self.peek().type == TT.AS:
                op = self.advance()
                # Next token must be a type keyword: number, string, boolean
                # These are lexed as keywords, so check:
                tt = self.peek()
                if tt.type == TT.IDENT and tt.value in ('number', 'string', 'boolean'):
                    self.advance()
                    left = AsExpr(left, tt.value, op.line)
                elif tt.value in ('number', 'string', 'boolean'):
                    # could be TT.NOTHING etc? No. number/string/boolean might lex as ident
                    self.advance()
                    left = AsExpr(left, tt.value, op.line)
                else:
                    raise ParseError(f"Expected type name after 'as', got {tt.value!r}", tt.line)
            elif self.peek().type == TT.CONTAINS:
                op = self.advance()
                right = self.parse_primary()
                left = ContainsExpr(left, right, op.line)
            else:
                break
        return left

    def parse_primary(self):
        t = self.peek()

        # Number
        if t.type == TT.NUMBER:
            self.advance()
            return NumberLit(t.value, t.line)

        # String
        if t.type == TT.STRING:
            self.advance()
            return StringLit(t.value, t.line)

        # Boolean
        if t.type == TT.TRUE:
            self.advance()
            return BoolLit(True, t.line)
        if t.type == TT.FALSE:
            self.advance()
            return BoolLit(False, t.line)

        # Nothing
        if t.type == TT.NOTHING:
            self.advance()
            return NothingLit(t.line)

        # List literal
        if t.type == TT.LBRACKET:
            return self.parse_list_literal()

        # Parenthesised expression
        if t.type == TT.LPAREN:
            self.advance()
            expr = self.parse_expression()
            self.expect(TT.RPAREN)
            return expr

        # Call expression
        if t.type == TT.CALL:
            return self.parse_call_expr()

        # Prefix operators: uppercase of, lowercase of, length of, first of, last of
        if t.type in (TT.UPPERCASE_OF, TT.LOWERCASE_OF, TT.LENGTH_OF, TT.FIRST_OF, TT.LAST_OF):
            self.advance()
            operand = self.parse_primary()
            return PrefixOp(t.type, operand, t.line)

        # slice of X from A to B
        if t.type == TT.SLICE_OF:
            self.advance()
            target = self.parse_primary()
            self.expect(TT.FROM)
            start = self.parse_expression()
            self.expect(TT.TO)
            end = self.parse_expression()
            return SliceExpr(target, start, end, t.line)

        # item N of X  --  or  --  item used as a variable name
        if t.type == TT.ITEM:
            # Try parsing as "item <expr> of <primary>". If it fails, treat as ident.
            saved = self.pos
            self.advance()  # consume 'item'
            try:
                index = self.parse_expression()
                self.expect(TT.OF)
                target = self.parse_primary()
                return ItemAccess(index, target, t.line)
            except ParseError:
                self.pos = saved
                self.advance()
                return Identifier(t.value, t.line)

        # Identifier (including keywords that can serve as variable names)
        if t.type == TT.IDENT:
            self.advance()
            return Identifier(t.value, t.line)

        # Allow certain keywords to be used as identifiers in expression context
        if t.type in self.IDENT_KEYWORDS:
            self.advance()
            return Identifier(t.value, t.line)

        raise ParseError(f"Unexpected token in expression: {t.type} ({t.value!r})", t.line)

    def parse_list_literal(self):
        t = self.advance()  # consume '['
        elements = []
        if self.peek().type != TT.RBRACKET:
            elements.append(self.parse_expression())
            while self.peek().type == TT.COMMA:
                self.advance()
                elements.append(self.parse_expression())
        self.expect(TT.RBRACKET)
        return ListLit(elements, t.line)

    def parse_call_expr(self):
        t = self.advance()  # consume 'call'
        name = self.expect_ident()
        args = []
        if self.peek().type == TT.WITH:
            self.advance()
            # Parse each argument at 'not' level so 'and' serves as arg separator
            args.append(self.parse_not())
            while self.peek().type == TT.AND:
                self.advance()
                args.append(self.parse_not())
        return CallExpr(name.value, args, t.line)


# ---------------------------------------------------------------------------
# Runtime values
# ---------------------------------------------------------------------------

class HLNothing:
    """Singleton for the nothing type."""
    _instance = None
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance
    def __repr__(self):
        return 'nothing'

NOTHING = HLNothing()


def format_value(val):
    """Format a humanlang value for print output."""
    if val is NOTHING:
        return 'nothing'
    if isinstance(val, bool):
        return 'true' if val else 'false'
    if isinstance(val, float):
        if val == float('inf') or val == float('-inf') or val != val:
            return str(val)
        if val == int(val) and not (val == 0.0 and math.copysign(1, val) < 0):
            return str(int(val))
        # Up to 6 decimal places, no trailing zeros
        formatted = f'{val:.6f}'.rstrip('0').rstrip('.')
        return formatted
    if isinstance(val, str):
        return val
    if isinstance(val, list):
        parts = [format_value(v) for v in val]
        return '[' + ', '.join(parts) + ']'
    return str(val)


# ---------------------------------------------------------------------------
# Interpreter
# ---------------------------------------------------------------------------

class RuntimeError_(Exception):
    def __init__(self, msg, line):
        super().__init__(msg)
        self.line = line

class ReturnSignal(Exception):
    def __init__(self, value):
        self.value = value

class StopSignal(Exception):
    pass

class SkipSignal(Exception):
    pass


class Environment:
    def __init__(self, parent=None):
        self.vars = {}
        self.parent = parent

    def get(self, name, line):
        if name in self.vars:
            return self.vars[name]
        if self.parent is not None:
            return self.parent.get(name, line)
        raise RuntimeError_(f"Undefined variable '{name}'", line)

    def set(self, name, value):
        self.vars[name] = value

    def has(self, name):
        if name in self.vars:
            return True
        if self.parent is not None:
            return self.parent.has(name)
        return False


class Interpreter:
    def __init__(self):
        self.globals = Environment()
        self.functions = {}
        self.output_parts = []

    def run(self, stmts):
        self.exec_stmts(stmts, self.globals)

    def exec_stmts(self, stmts, env):
        for stmt in stmts:
            self.exec_stmt(stmt, env)

    def exec_stmt(self, stmt, env):
        if isinstance(stmt, PrintStmt):
            val = self.eval_expr(stmt.expr, env)
            print(format_value(val))

        elif isinstance(stmt, SetStmt):
            val = self.eval_expr(stmt.expr, env)
            env.set(stmt.name, val)

        elif isinstance(stmt, AppendStmt):
            val = self.eval_expr(stmt.value, env)
            lst = env.get(stmt.target, stmt.line)
            if not isinstance(lst, list):
                raise RuntimeError_(f"Cannot append to non-list", stmt.line)
            lst.append(val)

        elif isinstance(stmt, IfStmt):
            cond = self.eval_expr(stmt.condition, env)
            if not isinstance(cond, bool):
                raise RuntimeError_("Condition must be a boolean", stmt.line)
            if cond:
                self.exec_stmts(stmt.body, env)
            else:
                executed = False
                for elif_cond, elif_body in stmt.elifs:
                    c = self.eval_expr(elif_cond, env)
                    if not isinstance(c, bool):
                        raise RuntimeError_("Condition must be a boolean", elif_cond.line if hasattr(elif_cond, 'line') else stmt.line)
                    if c:
                        self.exec_stmts(elif_body, env)
                        executed = True
                        break
                if not executed and stmt.else_body is not None:
                    self.exec_stmts(stmt.else_body, env)

        elif isinstance(stmt, WhileStmt):
            while True:
                cond = self.eval_expr(stmt.condition, env)
                if not isinstance(cond, bool):
                    raise RuntimeError_("Condition must be a boolean", stmt.line)
                if not cond:
                    break
                try:
                    self.exec_stmts(stmt.body, env)
                except StopSignal:
                    break
                except SkipSignal:
                    continue

        elif isinstance(stmt, RepeatStmt):
            count = self.eval_expr(stmt.count, env)
            if not isinstance(count, float):
                raise RuntimeError_("Repeat count must be a number", stmt.line)
            n = int(count)
            for _ in range(n):
                try:
                    self.exec_stmts(stmt.body, env)
                except StopSignal:
                    break
                except SkipSignal:
                    continue

        elif isinstance(stmt, ForEachStmt):
            iterable = self.eval_expr(stmt.iterable, env)
            if not isinstance(iterable, list):
                raise RuntimeError_("for each requires a list", stmt.line)
            for item in iterable:
                env.set(stmt.var, item)
                try:
                    self.exec_stmts(stmt.body, env)
                except StopSignal:
                    break
                except SkipSignal:
                    continue

        elif isinstance(stmt, ForFromStmt):
            start = self.eval_expr(stmt.start, env)
            end = self.eval_expr(stmt.end, env)
            if not isinstance(start, float) or not isinstance(end, float):
                raise RuntimeError_("for range bounds must be numbers", stmt.line)
            i = int(start)
            e = int(end)
            for val in range(i, e + 1):
                env.set(stmt.var, float(val))
                try:
                    self.exec_stmts(stmt.body, env)
                except StopSignal:
                    break
                except SkipSignal:
                    continue

        elif isinstance(stmt, DefineStmt):
            self.functions[stmt.name] = stmt

        elif isinstance(stmt, CallStmt):
            self.eval_expr(stmt.expr, env)

        elif isinstance(stmt, ReturnStmt):
            val = NOTHING
            if stmt.expr is not None:
                val = self.eval_expr(stmt.expr, env)
            raise ReturnSignal(val)

        elif isinstance(stmt, StopStmt):
            raise StopSignal()

        elif isinstance(stmt, SkipStmt):
            raise SkipSignal()

        else:
            raise RuntimeError_(f"Unknown statement type: {type(stmt).__name__}", getattr(stmt, 'line', 0))

    def eval_expr(self, expr, env):
        if isinstance(expr, NumberLit):
            return expr.value

        if isinstance(expr, StringLit):
            return expr.value

        if isinstance(expr, BoolLit):
            return expr.value

        if isinstance(expr, NothingLit):
            return NOTHING

        if isinstance(expr, ListLit):
            return [self.eval_expr(e, env) for e in expr.elements]

        if isinstance(expr, Identifier):
            return env.get(expr.name, expr.line)

        if isinstance(expr, BinOp):
            return self.eval_binop(expr, env)

        if isinstance(expr, UnaryOp):
            return self.eval_unary(expr, env)

        if isinstance(expr, PrefixOp):
            return self.eval_prefix(expr, env)

        if isinstance(expr, ItemAccess):
            return self.eval_item_access(expr, env)

        if isinstance(expr, SliceExpr):
            return self.eval_slice(expr, env)

        if isinstance(expr, AsExpr):
            return self.eval_as(expr, env)

        if isinstance(expr, ContainsExpr):
            return self.eval_contains(expr, env)

        if isinstance(expr, JoinedWithExpr):
            return self.eval_joined_with(expr, env)

        if isinstance(expr, CallExpr):
            return self.eval_call(expr, env)

        raise RuntimeError_(f"Unknown expression type: {type(expr).__name__}", getattr(expr, 'line', 0))

    def eval_binop(self, expr, env):
        # Short-circuit for and/or
        if expr.op == 'and':
            left = self.eval_expr(expr.left, env)
            if not isinstance(left, bool):
                raise RuntimeError_("Operand of 'and' must be a boolean", expr.line)
            if not left:
                return False
            right = self.eval_expr(expr.right, env)
            if not isinstance(right, bool):
                raise RuntimeError_("Operand of 'and' must be a boolean", expr.line)
            return right

        if expr.op == 'or':
            left = self.eval_expr(expr.left, env)
            if not isinstance(left, bool):
                raise RuntimeError_("Operand of 'or' must be a boolean", expr.line)
            if left:
                return True
            right = self.eval_expr(expr.right, env)
            if not isinstance(right, bool):
                raise RuntimeError_("Operand of 'or' must be a boolean", expr.line)
            return right

        left = self.eval_expr(expr.left, env)
        right = self.eval_expr(expr.right, env)

        # Arithmetic
        if expr.op == TT.PLUS:
            if not isinstance(left, float) or not isinstance(right, float):
                raise RuntimeError_("Arithmetic requires numbers", expr.line)
            return left + right

        if expr.op == TT.MINUS:
            if not isinstance(left, float) or not isinstance(right, float):
                raise RuntimeError_("Arithmetic requires numbers", expr.line)
            return left - right

        if expr.op == TT.TIMES:
            if not isinstance(left, float) or not isinstance(right, float):
                raise RuntimeError_("Arithmetic requires numbers", expr.line)
            return left * right

        if expr.op == TT.DIVIDED_BY:
            if not isinstance(left, float) or not isinstance(right, float):
                raise RuntimeError_("Arithmetic requires numbers", expr.line)
            if right == 0:
                raise RuntimeError_("Division by zero", expr.line)
            return left / right

        if expr.op == TT.MODULO:
            if not isinstance(left, float) or not isinstance(right, float):
                raise RuntimeError_("Arithmetic requires numbers", expr.line)
            if right == 0:
                raise RuntimeError_("Division by zero", expr.line)
            # Use fmod-style that matches Python % for positive numbers
            return left % right

        # Comparisons
        if expr.op == TT.IS_EQUAL_TO:
            return self._equals(left, right)

        if expr.op == TT.IS_NOT_EQUAL_TO:
            return not self._equals(left, right)

        if expr.op == TT.IS_GREATER_THAN:
            return self._compare(left, right, expr.line) > 0

        if expr.op == TT.IS_LESS_THAN:
            return self._compare(left, right, expr.line) < 0

        if expr.op == TT.IS_AT_LEAST:
            return self._compare(left, right, expr.line) >= 0

        if expr.op == TT.IS_AT_MOST:
            return self._compare(left, right, expr.line) <= 0

        raise RuntimeError_(f"Unknown binary op: {expr.op}", expr.line)

    def _equals(self, left, right):
        """Equality comparison. Incompatible types return false."""
        if type(left) != type(right):
            # Special cases: both are nothing
            if left is NOTHING and right is NOTHING:
                return True
            return False
        if isinstance(left, float):
            return left == right
        if isinstance(left, str):
            return left == right
        if isinstance(left, bool):
            return left == right
        if isinstance(left, list):
            if len(left) != len(right):
                return False
            return all(self._equals(a, b) for a, b in zip(left, right))
        if left is NOTHING:
            return True
        return False

    def _compare(self, left, right, line):
        """Ordering comparison. Returns <0, 0, >0. Runtime error on incompatible types."""
        if isinstance(left, float) and isinstance(right, float):
            if left < right:
                return -1
            if left > right:
                return 1
            return 0
        if isinstance(left, str) and isinstance(right, str):
            if left < right:
                return -1
            if left > right:
                return 1
            return 0
        raise RuntimeError_(f"Cannot compare {self._type_name(left)} with {self._type_name(right)}", line)

    def _type_name(self, val):
        if val is NOTHING:
            return 'nothing'
        if isinstance(val, bool):
            return 'boolean'
        if isinstance(val, float):
            return 'number'
        if isinstance(val, str):
            return 'string'
        if isinstance(val, list):
            return 'list'
        return type(val).__name__

    def eval_unary(self, expr, env):
        if expr.op == 'not':
            val = self.eval_expr(expr.operand, env)
            if not isinstance(val, bool):
                raise RuntimeError_("Operand of 'not' must be a boolean", expr.line)
            return not val
        if expr.op == 'negative':
            val = self.eval_expr(expr.operand, env)
            if not isinstance(val, float):
                raise RuntimeError_("Operand of 'negative' must be a number", expr.line)
            return -val
        raise RuntimeError_(f"Unknown unary op: {expr.op}", expr.line)

    def eval_prefix(self, expr, env):
        val = self.eval_expr(expr.operand, env)

        if expr.op == TT.UPPERCASE_OF:
            if not isinstance(val, str):
                raise RuntimeError_("uppercase of requires a string", expr.line)
            return val.upper()

        if expr.op == TT.LOWERCASE_OF:
            if not isinstance(val, str):
                raise RuntimeError_("lowercase of requires a string", expr.line)
            return val.lower()

        if expr.op == TT.LENGTH_OF:
            if isinstance(val, str):
                return float(len(val))
            if isinstance(val, list):
                return float(len(val))
            raise RuntimeError_("length of requires a string or list", expr.line)

        if expr.op == TT.FIRST_OF:
            if not isinstance(val, list):
                raise RuntimeError_("first of requires a list", expr.line)
            if len(val) == 0:
                raise RuntimeError_("Cannot get first of empty list", expr.line)
            return val[0]

        if expr.op == TT.LAST_OF:
            if not isinstance(val, list):
                raise RuntimeError_("last of requires a list", expr.line)
            if len(val) == 0:
                raise RuntimeError_("Cannot get last of empty list", expr.line)
            return val[-1]

        raise RuntimeError_(f"Unknown prefix op: {expr.op}", expr.line)

    def eval_item_access(self, expr, env):
        idx = self.eval_expr(expr.index, env)
        target = self.eval_expr(expr.target, env)
        if not isinstance(idx, float):
            raise RuntimeError_("Index must be a number", expr.line)
        i = int(idx)
        if isinstance(target, list):
            if i < 0 or i >= len(target):
                raise RuntimeError_("Index out of bounds", expr.line)
            return target[i]
        raise RuntimeError_("item access requires a list", expr.line)

    def eval_slice(self, expr, env):
        target = self.eval_expr(expr.target, env)
        start = self.eval_expr(expr.start, env)
        end = self.eval_expr(expr.end, env)
        if not isinstance(start, float) or not isinstance(end, float):
            raise RuntimeError_("Slice indices must be numbers", expr.line)
        s = int(start)
        e = int(end)
        if isinstance(target, str):
            return target[s:e]
        if isinstance(target, list):
            return target[s:e]
        raise RuntimeError_("slice requires a string or list", expr.line)

    def eval_as(self, expr, env):
        val = self.eval_expr(expr.expr, env)

        if expr.target_type == 'number':
            if isinstance(val, float):
                return val
            if isinstance(val, str):
                try:
                    return float(val)
                except ValueError:
                    raise RuntimeError_(f"Cannot convert '{val}' to number", expr.line)
            if isinstance(val, bool):
                return 1.0 if val else 0.0
            raise RuntimeError_(f"Cannot convert {self._type_name(val)} to number", expr.line)

        if expr.target_type == 'string':
            return format_value(val)

        if expr.target_type == 'boolean':
            if isinstance(val, bool):
                return val
            if isinstance(val, float):
                return val != 0.0
            if isinstance(val, str):
                return val != ''
            if isinstance(val, list):
                return len(val) > 0
            if val is NOTHING:
                return False
            raise RuntimeError_(f"Cannot convert {self._type_name(val)} to boolean", expr.line)

        raise RuntimeError_(f"Unknown type: {expr.target_type}", expr.line)

    def eval_contains(self, expr, env):
        container = self.eval_expr(expr.container, env)
        item = self.eval_expr(expr.item, env)
        if isinstance(container, str):
            if not isinstance(item, str):
                raise RuntimeError_("String contains requires a string argument", expr.line)
            return item in container
        if isinstance(container, list):
            for elem in container:
                if self._equals(elem, item):
                    return True
            return False
        raise RuntimeError_("contains requires a string or list", expr.line)

    def eval_joined_with(self, expr, env):
        left = self.eval_expr(expr.left, env)
        right = self.eval_expr(expr.right, env)
        return format_value(left) + format_value(right)

    def eval_call(self, expr, env):
        name = expr.name
        if name not in self.functions:
            raise RuntimeError_(f"Undefined function '{name}'", expr.line)
        func = self.functions[name]
        if len(expr.args) != len(func.params):
            raise RuntimeError_(
                f"Function '{name}' expects {len(func.params)} arguments, got {len(expr.args)}",
                expr.line
            )
        # Evaluate arguments in calling scope
        arg_vals = [self.eval_expr(a, env) for a in expr.args]
        # Create new scope with access to the defining scope (globals for top-level)
        func_env = Environment(parent=self.globals)
        for pname, pval in zip(func.params, arg_vals):
            func_env.set(pname, pval)
        # Execute function body
        try:
            self.exec_stmts(func.body, func_env)
        except ReturnSignal as r:
            return r.value
        return NOTHING

    def _type_name(self, val):
        if val is NOTHING:
            return 'nothing'
        if isinstance(val, bool):
            return 'boolean'
        if isinstance(val, float):
            return 'number'
        if isinstance(val, str):
            return 'string'
        if isinstance(val, list):
            return 'list'
        return type(val).__name__


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 humanlang.py <file.hl>", file=sys.stderr)
        sys.exit(1)

    filename = sys.argv[1]
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            source = f.read()
    except FileNotFoundError:
        print(f"Error: File not found: {filename}", file=sys.stderr)
        sys.exit(1)

    try:
        tokens = lex(source)
        parser = Parser(tokens)
        ast = parser.parse_program()
        interp = Interpreter()
        interp.run(ast)
    except ParseError as e:
        print(f"Error on line {e.line}: {e}", file=sys.stderr)
        sys.exit(1)
    except RuntimeError_ as e:
        print(f"Error on line {e.line}: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
