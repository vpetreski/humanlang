const std = @import("std");
const Allocator = std.mem.Allocator;

// ============================================================================
// Token Types
// ============================================================================

const TokenType = enum {
    // Literals
    number_literal,
    string_literal,
    true_kw,
    false_kw,
    nothing,

    // Identifiers
    identifier,

    // Keywords
    print,
    set,
    to,
    if_kw,
    otherwise,
    otherwise_if,
    while_kw,
    for_kw,
    for_each,
    from,
    in_kw,
    repeat,
    times,
    times_colon,
    define,
    with,
    call,
    return_kw,
    append,
    stop,
    skip,
    and_kw,
    or_kw,
    not,
    of,

    // Operators
    plus,
    minus,
    divided_by,
    modulo,
    is_equal_to,
    is_not_equal_to,
    is_greater_than,
    is_less_than,
    is_at_least,
    is_at_most,
    joined_with,
    contains,
    as_number,
    as_string,
    as_boolean,
    negative,

    // Prefix operations
    uppercase_of,
    lowercase_of,
    length_of,
    first_of,
    last_of,
    item,
    slice_of,

    // Symbols
    lparen,
    rparen,
    lbracket,
    rbracket,
    comma,
    colon,

    // Indentation
    indent,
    dedent,
    newline,

    // Special
    eof,
};

const Token = struct {
    type: TokenType,
    value: []const u8,
    line: usize,
};

// ============================================================================
// Lexer
// ============================================================================

const Lexer = struct {
    source: []const u8,
    pos: usize,
    line: usize,
    tokens: std.ArrayList(Token),
    indent_stack: std.ArrayList(usize),
    alloc: Allocator,
    string_arena: std.ArrayList([]u8),
    at_line_start: bool,

    fn init(alloc: Allocator, source: []const u8) Lexer {
        return .{
            .source = source,
            .pos = 0,
            .line = 1,
            .tokens = .empty,
            .indent_stack = .empty,
            .alloc = alloc,
            .string_arena = .empty,
            .at_line_start = true,
        };
    }

    fn deinit(self: *Lexer) void {
        self.tokens.deinit(self.alloc);
        self.indent_stack.deinit(self.alloc);
        for (self.string_arena.items) |s| {
            self.alloc.free(s);
        }
        self.string_arena.deinit(self.alloc);
    }

    fn allocString(self: *Lexer, s: []const u8) ![]const u8 {
        const copy = try self.alloc.dupe(u8, s);
        try self.string_arena.append(self.alloc, copy);
        return copy;
    }

    fn remaining(self: *Lexer) []const u8 {
        return self.source[self.pos..];
    }

    fn startsWith(self: *Lexer, prefix: []const u8) bool {
        return std.mem.startsWith(u8, self.remaining(), prefix);
    }

    fn startsWithWord(self: *Lexer, prefix: []const u8) bool {
        if (!std.mem.startsWith(u8, self.remaining(), prefix)) return false;
        const after = self.pos + prefix.len;
        if (after >= self.source.len) return true;
        const ch = self.source[after];
        return !isIdentChar(ch);
    }

    fn isIdentChar(ch: u8) bool {
        return std.ascii.isAlphanumeric(ch) or ch == '_';
    }

    fn addToken(self: *Lexer, tt: TokenType, val: []const u8) !void {
        try self.tokens.append(self.alloc, .{ .type = tt, .value = val, .line = self.line });
    }

    fn tokenize(self: *Lexer) !void {
        try self.indent_stack.append(self.alloc, 0);

        while (self.pos < self.source.len) {
            if (self.at_line_start) {
                self.at_line_start = false;

                var spaces: usize = 0;
                while (self.pos < self.source.len and self.source[self.pos] == ' ') {
                    spaces += 1;
                    self.pos += 1;
                }

                // Skip blank lines
                if (self.pos >= self.source.len or self.source[self.pos] == '\n') {
                    if (self.pos < self.source.len) {
                        self.pos += 1;
                        self.line += 1;
                        self.at_line_start = true;
                    }
                    continue;
                }

                // Skip comment lines
                if (self.startsWith("--")) {
                    while (self.pos < self.source.len and self.source[self.pos] != '\n') {
                        self.pos += 1;
                    }
                    if (self.pos < self.source.len) {
                        self.pos += 1;
                        self.line += 1;
                        self.at_line_start = true;
                    }
                    continue;
                }

                // Emit indent/dedent tokens
                const current_indent = self.indent_stack.items[self.indent_stack.items.len - 1];
                if (spaces > current_indent) {
                    try self.indent_stack.append(self.alloc, spaces);
                    try self.addToken(.indent, "INDENT");
                } else if (spaces < current_indent) {
                    while (self.indent_stack.items.len > 1 and self.indent_stack.items[self.indent_stack.items.len - 1] > spaces) {
                        _ = self.indent_stack.pop();
                        try self.addToken(.dedent, "DEDENT");
                    }
                }
                continue;
            }

            const ch = self.source[self.pos];

            // Skip spaces (not at line start)
            if (ch == ' ' or ch == '\r' or ch == '\t') {
                self.pos += 1;
                continue;
            }

            // Newline
            if (ch == '\n') {
                try self.addToken(.newline, "\\n");
                self.pos += 1;
                self.line += 1;
                self.at_line_start = true;
                continue;
            }

            // Inline comment
            if (self.startsWith("--")) {
                while (self.pos < self.source.len and self.source[self.pos] != '\n') {
                    self.pos += 1;
                }
                continue;
            }

            // String literal
            if (ch == '"') {
                try self.tokenizeString();
                continue;
            }

            // Number literal
            if (std.ascii.isDigit(ch)) {
                try self.tokenizeNumber();
                continue;
            }

            // Symbols
            if (ch == '(') { try self.addToken(.lparen, "("); self.pos += 1; continue; }
            if (ch == ')') { try self.addToken(.rparen, ")"); self.pos += 1; continue; }
            if (ch == '[') { try self.addToken(.lbracket, "["); self.pos += 1; continue; }
            if (ch == ']') { try self.addToken(.rbracket, "]"); self.pos += 1; continue; }
            if (ch == ',') { try self.addToken(.comma, ","); self.pos += 1; continue; }

            // Multi-word keywords (longest first)
            if (try self.tryMultiWordKeywords()) continue;

            // Single-word identifier/keyword
            if (std.ascii.isAlphabetic(ch)) {
                try self.tokenizeIdentifier();
                continue;
            }

            // Colon
            if (ch == ':') {
                try self.addToken(.colon, ":");
                self.pos += 1;
                continue;
            }

            self.pos += 1;
        }

        // Final newline
        if (self.tokens.items.len > 0 and self.tokens.items[self.tokens.items.len - 1].type != .newline) {
            try self.addToken(.newline, "\\n");
        }

        // Remaining dedents
        while (self.indent_stack.items.len > 1) {
            _ = self.indent_stack.pop();
            try self.addToken(.dedent, "DEDENT");
        }

        try self.addToken(.eof, "");
    }

    fn tokenizeString(self: *Lexer) !void {
        self.pos += 1; // skip opening quote
        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(self.alloc);

        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c == '"') {
                self.pos += 1;
                break;
            }
            if (c == '\\') {
                self.pos += 1;
                if (self.pos < self.source.len) {
                    const esc = self.source[self.pos];
                    switch (esc) {
                        'n' => try buf.append(self.alloc, '\n'),
                        't' => try buf.append(self.alloc, '\t'),
                        '\\' => try buf.append(self.alloc, '\\'),
                        '"' => try buf.append(self.alloc, '"'),
                        else => {
                            try buf.append(self.alloc, '\\');
                            try buf.append(self.alloc, esc);
                        },
                    }
                    self.pos += 1;
                }
            } else {
                try buf.append(self.alloc, c);
                self.pos += 1;
            }
        }

        const str = try self.allocString(buf.items);
        try self.addToken(.string_literal, str);
    }

    fn tokenizeNumber(self: *Lexer) !void {
        const start = self.pos;
        while (self.pos < self.source.len and std.ascii.isDigit(self.source[self.pos])) {
            self.pos += 1;
        }
        if (self.pos < self.source.len and self.source[self.pos] == '.') {
            self.pos += 1;
            while (self.pos < self.source.len and std.ascii.isDigit(self.source[self.pos])) {
                self.pos += 1;
            }
        }
        try self.addToken(.number_literal, self.source[start..self.pos]);
    }

    fn tryMultiWordKeywords(self: *Lexer) !bool {
        // 4 words
        if (self.startsWithWord("is not equal to")) {
            try self.addToken(.is_not_equal_to, "is not equal to");
            self.pos += "is not equal to".len;
            return true;
        }
        // 3 words
        if (self.startsWithWord("is greater than")) {
            try self.addToken(.is_greater_than, "is greater than");
            self.pos += "is greater than".len;
            return true;
        }
        if (self.startsWithWord("is less than")) {
            try self.addToken(.is_less_than, "is less than");
            self.pos += "is less than".len;
            return true;
        }
        if (self.startsWithWord("is equal to")) {
            try self.addToken(.is_equal_to, "is equal to");
            self.pos += "is equal to".len;
            return true;
        }
        if (self.startsWithWord("is at least")) {
            try self.addToken(.is_at_least, "is at least");
            self.pos += "is at least".len;
            return true;
        }
        if (self.startsWithWord("is at most")) {
            try self.addToken(.is_at_most, "is at most");
            self.pos += "is at most".len;
            return true;
        }
        // 2 words
        if (self.startsWithWord("otherwise if")) {
            try self.addToken(.otherwise_if, "otherwise if");
            self.pos += "otherwise if".len;
            return true;
        }
        if (self.startsWithWord("divided by")) {
            try self.addToken(.divided_by, "divided by");
            self.pos += "divided by".len;
            return true;
        }
        if (self.startsWithWord("joined with")) {
            try self.addToken(.joined_with, "joined with");
            self.pos += "joined with".len;
            return true;
        }
        if (self.startsWithWord("for each")) {
            try self.addToken(.for_each, "for each");
            self.pos += "for each".len;
            return true;
        }
        if (self.startsWithWord("uppercase of")) {
            try self.addToken(.uppercase_of, "uppercase of");
            self.pos += "uppercase of".len;
            return true;
        }
        if (self.startsWithWord("lowercase of")) {
            try self.addToken(.lowercase_of, "lowercase of");
            self.pos += "lowercase of".len;
            return true;
        }
        if (self.startsWithWord("length of")) {
            try self.addToken(.length_of, "length of");
            self.pos += "length of".len;
            return true;
        }
        if (self.startsWithWord("first of")) {
            try self.addToken(.first_of, "first of");
            self.pos += "first of".len;
            return true;
        }
        if (self.startsWithWord("last of")) {
            try self.addToken(.last_of, "last of");
            self.pos += "last of".len;
            return true;
        }
        if (self.startsWithWord("slice of")) {
            try self.addToken(.slice_of, "slice of");
            self.pos += "slice of".len;
            return true;
        }
        if (self.startsWithWord("as number")) {
            try self.addToken(.as_number, "as number");
            self.pos += "as number".len;
            return true;
        }
        if (self.startsWithWord("as string")) {
            try self.addToken(.as_string, "as string");
            self.pos += "as string".len;
            return true;
        }
        if (self.startsWithWord("as boolean")) {
            try self.addToken(.as_boolean, "as boolean");
            self.pos += "as boolean".len;
            return true;
        }

        return false;
    }

    fn tokenizeIdentifier(self: *Lexer) !void {
        const start = self.pos;
        while (self.pos < self.source.len and isIdentChar(self.source[self.pos])) {
            self.pos += 1;
        }
        const word = self.source[start..self.pos];

        // Check for "times:" pattern (for repeat N times:)
        if (std.mem.eql(u8, word, "times")) {
            var lookahead = self.pos;
            while (lookahead < self.source.len and self.source[lookahead] == ' ') {
                lookahead += 1;
            }
            if (lookahead < self.source.len and self.source[lookahead] == ':') {
                self.pos = lookahead + 1;
                try self.addToken(.times_colon, "times:");
                return;
            }
        }

        const tt: TokenType = mapKeyword(word);
        try self.addToken(tt, word);
    }

    fn mapKeyword(word: []const u8) TokenType {
        if (std.mem.eql(u8, word, "print")) return .print;
        if (std.mem.eql(u8, word, "set")) return .set;
        if (std.mem.eql(u8, word, "to")) return .to;
        if (std.mem.eql(u8, word, "if")) return .if_kw;
        if (std.mem.eql(u8, word, "otherwise")) return .otherwise;
        if (std.mem.eql(u8, word, "while")) return .while_kw;
        if (std.mem.eql(u8, word, "for")) return .for_kw;
        if (std.mem.eql(u8, word, "from")) return .from;
        if (std.mem.eql(u8, word, "in")) return .in_kw;
        if (std.mem.eql(u8, word, "repeat")) return .repeat;
        if (std.mem.eql(u8, word, "times")) return .times;
        if (std.mem.eql(u8, word, "define")) return .define;
        if (std.mem.eql(u8, word, "with")) return .with;
        if (std.mem.eql(u8, word, "call")) return .call;
        if (std.mem.eql(u8, word, "return")) return .return_kw;
        if (std.mem.eql(u8, word, "append")) return .append;
        if (std.mem.eql(u8, word, "stop")) return .stop;
        if (std.mem.eql(u8, word, "skip")) return .skip;
        if (std.mem.eql(u8, word, "and")) return .and_kw;
        if (std.mem.eql(u8, word, "or")) return .or_kw;
        if (std.mem.eql(u8, word, "not")) return .not;
        if (std.mem.eql(u8, word, "plus")) return .plus;
        if (std.mem.eql(u8, word, "minus")) return .minus;
        if (std.mem.eql(u8, word, "modulo")) return .modulo;
        if (std.mem.eql(u8, word, "contains")) return .contains;
        if (std.mem.eql(u8, word, "negative")) return .negative;
        if (std.mem.eql(u8, word, "true")) return .true_kw;
        if (std.mem.eql(u8, word, "false")) return .false_kw;
        if (std.mem.eql(u8, word, "nothing")) return .nothing;
        if (std.mem.eql(u8, word, "item")) return .item;
        if (std.mem.eql(u8, word, "of")) return .of;
        return .identifier;
    }
};

// ============================================================================
// AST Nodes
// ============================================================================

const BinaryOp = enum {
    add, sub, mul, div, mod_op,
    eq, neq, gt, lt, gte, lte,
    and_op, or_op,
    join, contains_op,
};

const UnaryOp = enum { not_op, neg };

const PrefixOp = enum { upper, lower, length, first, last };

const ConvType = enum { to_number, to_string, to_boolean };

const Expr = union(enum) {
    number: f64,
    string: []const u8,
    boolean: bool,
    nothing_val: void,
    ident: []const u8,
    list_lit: []const *Expr,
    binary: struct { op: BinaryOp, left: *Expr, right: *Expr },
    unary: struct { op: UnaryOp, operand: *Expr },
    prefix: struct { op: PrefixOp, operand: *Expr },
    call_expr: struct { name: []const u8, args: []const *Expr },
    item_access: struct { index: *Expr, list_expr: *Expr },
    slice_expr: struct { target: *Expr, from: *Expr, to: *Expr },
    type_conv: struct { operand: *Expr, target: ConvType },
};

const ElseIfBranch = struct {
    condition: *Expr,
    body: []const *Stmt,
};

const Stmt = union(enum) {
    print_stmt: *Expr,
    set_stmt: struct { name: []const u8, value: *Expr },
    append_stmt: struct { value: *Expr, target: []const u8 },
    if_stmt: struct {
        condition: *Expr,
        body: []const *Stmt,
        elseif_branches: []const ElseIfBranch,
        else_body: ?[]const *Stmt,
    },
    while_stmt: struct { condition: *Expr, body: []const *Stmt },
    for_each_stmt: struct { var_name: []const u8, iterable: *Expr, body: []const *Stmt },
    for_from_stmt: struct { var_name: []const u8, from: *Expr, to: *Expr, body: []const *Stmt },
    repeat_stmt: struct { count: *Expr, body: []const *Stmt },
    define_stmt: struct { name: []const u8, params: []const []const u8, body: []const *Stmt },
    call_stmt: struct { name: []const u8, args: []const *Expr },
    return_stmt: ?*Expr,
    stop_stmt: void,
    skip_stmt: void,
    expr_stmt: *Expr,
};

// ============================================================================
// Parser
// ============================================================================

const ParseError = error{ UnexpectedToken, OutOfMemory };

const Parser = struct {
    tokens: []const Token,
    pos: usize,
    alloc: Allocator,
    in_call_args: bool,

    fn init(alloc: Allocator, tokens: []const Token) Parser {
        return .{ .tokens = tokens, .pos = 0, .alloc = alloc, .in_call_args = false };
    }

    fn cur(self: *Parser) Token {
        if (self.pos >= self.tokens.len) return .{ .type = .eof, .value = "", .line = 0 };
        return self.tokens[self.pos];
    }

    fn peek(self: *Parser) TokenType {
        return self.cur().type;
    }

    fn advance(self: *Parser) Token {
        const t = self.cur();
        if (self.pos < self.tokens.len) self.pos += 1;
        return t;
    }

    fn expect(self: *Parser, tt: TokenType) !Token {
        if (self.peek() != tt) return error.UnexpectedToken;
        return self.advance();
    }

    fn skipNl(self: *Parser) void {
        while (self.peek() == .newline) self.pos += 1;
    }

    fn expectIdent(self: *Parser) !Token {
        // Accept identifiers and contextual keywords that can be used as variable names.
        // Words like "item", "of", "from", "to" etc. are keywords but can be valid var names.
        const t = self.cur();
        switch (t.type) {
            .identifier, .item, .of, .from, .to, .times => {
                self.pos += 1;
                return t;
            },
            else => return error.UnexpectedToken,
        }
    }

    fn mkExpr(self: *Parser, e: Expr) !*Expr {
        const p = try self.alloc.create(Expr);
        p.* = e;
        return p;
    }

    fn mkStmt(self: *Parser, s: Stmt) !*Stmt {
        const p = try self.alloc.create(Stmt);
        p.* = s;
        return p;
    }

    fn parse(self: *Parser) ParseError![]*Stmt {
        var stmts: std.ArrayList(*Stmt) = .empty;
        self.skipNl();
        while (self.peek() != .eof) {
            const s = try self.parseStmt();
            try stmts.append(self.alloc, s);
            self.skipNl();
        }
        return stmts.toOwnedSlice(self.alloc);
    }

    fn parseBlock(self: *Parser) ParseError![]*Stmt {
        _ = try self.expect(.indent);
        var stmts: std.ArrayList(*Stmt) = .empty;
        self.skipNl();
        while (self.peek() != .dedent and self.peek() != .eof) {
            const s = try self.parseStmt();
            try stmts.append(self.alloc, s);
            self.skipNl();
        }
        if (self.peek() == .dedent) self.pos += 1;
        return stmts.toOwnedSlice(self.alloc);
    }

    fn eatNl(self: *Parser) void {
        if (self.peek() == .newline) self.pos += 1;
    }

    fn parseStmt(self: *Parser) ParseError!*Stmt {
        return switch (self.peek()) {
            .print => self.parsePrint(),
            .set => self.parseSet(),
            .append => self.parseAppend(),
            .if_kw => self.parseIf(),
            .while_kw => self.parseWhile(),
            .for_each => self.parseForEach(),
            .for_kw => self.parseForFrom(),
            .repeat => self.parseRepeat(),
            .define => self.parseDefine(),
            .call => self.parseCallStmt(),
            .return_kw => self.parseReturn(),
            .stop => {
                self.pos += 1;
                self.eatNl();
                return self.mkStmt(.{ .stop_stmt = {} });
            },
            .skip => {
                self.pos += 1;
                self.eatNl();
                return self.mkStmt(.{ .skip_stmt = {} });
            },
            else => {
                const e = try self.parseExpr();
                self.eatNl();
                return self.mkStmt(.{ .expr_stmt = e });
            },
        };
    }

    fn parsePrint(self: *Parser) ParseError!*Stmt {
        self.pos += 1;
        const e = try self.parseExpr();
        self.eatNl();
        return self.mkStmt(.{ .print_stmt = e });
    }

    fn parseSet(self: *Parser) ParseError!*Stmt {
        self.pos += 1;
        const name = (try self.expectIdent()).value;
        _ = try self.expect(.to);
        const val = try self.parseExpr();
        self.eatNl();
        return self.mkStmt(.{ .set_stmt = .{ .name = name, .value = val } });
    }

    fn parseAppend(self: *Parser) ParseError!*Stmt {
        self.pos += 1;
        const val = try self.parseExpr();
        _ = try self.expect(.to);
        const target = (try self.expectIdent()).value;
        self.eatNl();
        return self.mkStmt(.{ .append_stmt = .{ .value = val, .target = target } });
    }

    fn parseIf(self: *Parser) ParseError!*Stmt {
        self.pos += 1;
        const cond = try self.parseExpr();
        _ = try self.expect(.colon);
        self.eatNl();
        const body = try self.parseBlock();

        var elseifs: std.ArrayList(ElseIfBranch) = .empty;
        var else_body: ?[]const *Stmt = null;

        self.skipNl();
        while (self.peek() == .otherwise_if) {
            self.pos += 1;
            const ec = try self.parseExpr();
            _ = try self.expect(.colon);
            self.eatNl();
            const eb = try self.parseBlock();
            try elseifs.append(self.alloc, .{ .condition = ec, .body = eb });
            self.skipNl();
        }

        if (self.peek() == .otherwise) {
            self.pos += 1;
            _ = try self.expect(.colon);
            self.eatNl();
            else_body = try self.parseBlock();
        }

        return self.mkStmt(.{ .if_stmt = .{
            .condition = cond,
            .body = body,
            .elseif_branches = try elseifs.toOwnedSlice(self.alloc),
            .else_body = else_body,
        } });
    }

    fn parseWhile(self: *Parser) ParseError!*Stmt {
        self.pos += 1;
        const cond = try self.parseExpr();
        _ = try self.expect(.colon);
        self.eatNl();
        const body = try self.parseBlock();
        return self.mkStmt(.{ .while_stmt = .{ .condition = cond, .body = body } });
    }

    fn parseForEach(self: *Parser) ParseError!*Stmt {
        self.pos += 1;
        const vn = (try self.expectIdent()).value;
        _ = try self.expect(.in_kw);
        const it = try self.parseExpr();
        _ = try self.expect(.colon);
        self.eatNl();
        const body = try self.parseBlock();
        return self.mkStmt(.{ .for_each_stmt = .{ .var_name = vn, .iterable = it, .body = body } });
    }

    fn parseForFrom(self: *Parser) ParseError!*Stmt {
        self.pos += 1;
        const vn = (try self.expectIdent()).value;
        _ = try self.expect(.from);
        const fr = try self.parseExpr();
        _ = try self.expect(.to);
        const t = try self.parseExpr();
        _ = try self.expect(.colon);
        self.eatNl();
        const body = try self.parseBlock();
        return self.mkStmt(.{ .for_from_stmt = .{ .var_name = vn, .from = fr, .to = t, .body = body } });
    }

    fn parseRepeat(self: *Parser) ParseError!*Stmt {
        self.pos += 1;
        const count = try self.parseExpr();
        _ = try self.expect(.times_colon);
        self.eatNl();
        const body = try self.parseBlock();
        return self.mkStmt(.{ .repeat_stmt = .{ .count = count, .body = body } });
    }

    fn parseDefine(self: *Parser) ParseError!*Stmt {
        self.pos += 1;
        const name = (try self.expectIdent()).value;
        var params: std.ArrayList([]const u8) = .empty;

        if (self.peek() == .with) {
            self.pos += 1;
            try params.append(self.alloc, (try self.expectIdent()).value);
            while (self.peek() == .and_kw) {
                self.pos += 1;
                try params.append(self.alloc, (try self.expectIdent()).value);
            }
        }
        _ = try self.expect(.colon);
        self.eatNl();
        const body = try self.parseBlock();
        return self.mkStmt(.{ .define_stmt = .{
            .name = name,
            .params = try params.toOwnedSlice(self.alloc),
            .body = body,
        } });
    }

    fn parseCallStmt(self: *Parser) ParseError!*Stmt {
        self.pos += 1;
        const name = (try self.expect(.identifier)).value;
        var args: std.ArrayList(*Expr) = .empty;

        if (self.peek() == .with) {
            self.pos += 1;
            const old = self.in_call_args;
            self.in_call_args = true;
            try args.append(self.alloc, try self.parseExpr());
            while (self.peek() == .and_kw) {
                self.pos += 1;
                try args.append(self.alloc, try self.parseExpr());
            }
            self.in_call_args = old;
        }
        self.eatNl();
        return self.mkStmt(.{ .call_stmt = .{
            .name = name,
            .args = try args.toOwnedSlice(self.alloc),
        } });
    }

    fn parseReturn(self: *Parser) ParseError!*Stmt {
        self.pos += 1;
        if (self.peek() == .newline or self.peek() == .eof or self.peek() == .dedent) {
            self.eatNl();
            return self.mkStmt(.{ .return_stmt = null });
        }
        const e = try self.parseExpr();
        self.eatNl();
        return self.mkStmt(.{ .return_stmt = e });
    }

    // ---- Expression parsing (precedence climbing) ----

    fn parseExpr(self: *Parser) ParseError!*Expr {
        return self.parseOr();
    }

    fn parseOr(self: *Parser) ParseError!*Expr {
        var left = try self.parseAnd();
        while (self.peek() == .or_kw) {
            self.pos += 1;
            const right = try self.parseAnd();
            left = try self.mkExpr(.{ .binary = .{ .op = .or_op, .left = left, .right = right } });
        }
        return left;
    }

    fn parseAnd(self: *Parser) ParseError!*Expr {
        var left = try self.parseNot();
        while (self.peek() == .and_kw and !self.in_call_args) {
            self.pos += 1;
            const right = try self.parseNot();
            left = try self.mkExpr(.{ .binary = .{ .op = .and_op, .left = left, .right = right } });
        }
        return left;
    }

    fn parseNot(self: *Parser) ParseError!*Expr {
        if (self.peek() == .not) {
            self.pos += 1;
            const operand = try self.parseNot();
            return self.mkExpr(.{ .unary = .{ .op = .not_op, .operand = operand } });
        }
        return self.parseComparison();
    }

    fn parseComparison(self: *Parser) ParseError!*Expr {
        var left = try self.parseAddition();
        while (true) {
            const op: BinaryOp = switch (self.peek()) {
                .is_equal_to => .eq,
                .is_not_equal_to => .neq,
                .is_greater_than => .gt,
                .is_less_than => .lt,
                .is_at_least => .gte,
                .is_at_most => .lte,
                else => break,
            };
            self.pos += 1;
            const right = try self.parseAddition();
            left = try self.mkExpr(.{ .binary = .{ .op = op, .left = left, .right = right } });
        }
        return left;
    }

    fn parseAddition(self: *Parser) ParseError!*Expr {
        var left = try self.parseMultiplication();
        while (self.peek() == .plus or self.peek() == .minus) {
            const op: BinaryOp = if (self.peek() == .plus) .add else .sub;
            self.pos += 1;
            const right = try self.parseMultiplication();
            left = try self.mkExpr(.{ .binary = .{ .op = op, .left = left, .right = right } });
        }
        return left;
    }

    fn parseMultiplication(self: *Parser) ParseError!*Expr {
        var left = try self.parseUnary();
        while (self.peek() == .times or self.peek() == .divided_by or self.peek() == .modulo) {
            const op: BinaryOp = switch (self.peek()) {
                .times => .mul,
                .divided_by => .div,
                .modulo => .mod_op,
                else => unreachable,
            };
            self.pos += 1;
            const right = try self.parseUnary();
            left = try self.mkExpr(.{ .binary = .{ .op = op, .left = left, .right = right } });
        }
        return left;
    }

    fn parseUnary(self: *Parser) ParseError!*Expr {
        if (self.peek() == .negative) {
            self.pos += 1;
            const operand = try self.parsePostfix();
            return self.mkExpr(.{ .unary = .{ .op = .neg, .operand = operand } });
        }
        return self.parsePostfix();
    }

    fn parsePostfix(self: *Parser) ParseError!*Expr {
        var left = try self.parsePrimary();
        while (true) {
            switch (self.peek()) {
                .joined_with => {
                    self.pos += 1;
                    const right = try self.parsePrimary();
                    left = try self.mkExpr(.{ .binary = .{ .op = .join, .left = left, .right = right } });
                },
                .as_number => {
                    self.pos += 1;
                    left = try self.mkExpr(.{ .type_conv = .{ .operand = left, .target = .to_number } });
                },
                .as_string => {
                    self.pos += 1;
                    left = try self.mkExpr(.{ .type_conv = .{ .operand = left, .target = .to_string } });
                },
                .as_boolean => {
                    self.pos += 1;
                    left = try self.mkExpr(.{ .type_conv = .{ .operand = left, .target = .to_boolean } });
                },
                .contains => {
                    self.pos += 1;
                    const right = try self.parsePrimary();
                    left = try self.mkExpr(.{ .binary = .{ .op = .contains_op, .left = left, .right = right } });
                },
                else => break,
            }
        }
        return left;
    }

    fn parsePrimary(self: *Parser) ParseError!*Expr {
        switch (self.peek()) {
            .number_literal => {
                const tok = self.advance();
                const val = std.fmt.parseFloat(f64, tok.value) catch 0.0;
                return self.mkExpr(.{ .number = val });
            },
            .string_literal => {
                const tok = self.advance();
                return self.mkExpr(.{ .string = tok.value });
            },
            .true_kw => {
                self.pos += 1;
                return self.mkExpr(.{ .boolean = true });
            },
            .false_kw => {
                self.pos += 1;
                return self.mkExpr(.{ .boolean = false });
            },
            .nothing => {
                self.pos += 1;
                return self.mkExpr(.{ .nothing_val = {} });
            },
            .identifier => {
                const tok = self.advance();
                return self.mkExpr(.{ .ident = tok.value });
            },
            .lbracket => return self.parseListLit(),
            .lparen => {
                self.pos += 1;
                const e = try self.parseExpr();
                _ = try self.expect(.rparen);
                return e;
            },
            .call => return self.parseCallExpr(),
            .uppercase_of => {
                self.pos += 1;
                return self.mkExpr(.{ .prefix = .{ .op = .upper, .operand = try self.parsePrimary() } });
            },
            .lowercase_of => {
                self.pos += 1;
                return self.mkExpr(.{ .prefix = .{ .op = .lower, .operand = try self.parsePrimary() } });
            },
            .length_of => {
                self.pos += 1;
                return self.mkExpr(.{ .prefix = .{ .op = .length, .operand = try self.parsePrimary() } });
            },
            .first_of => {
                self.pos += 1;
                return self.mkExpr(.{ .prefix = .{ .op = .first, .operand = try self.parsePrimary() } });
            },
            .last_of => {
                self.pos += 1;
                return self.mkExpr(.{ .prefix = .{ .op = .last, .operand = try self.parsePrimary() } });
            },
            .item => {
                // "item N of list" is item access; plain "item" as variable
                // Peek ahead: if next token can start an expression, try item access
                const saved = self.pos;
                self.pos += 1;
                if (self.peek() == .number_literal or self.peek() == .identifier or
                    self.peek() == .lparen or self.peek() == .call or self.peek() == .negative)
                {
                    const idx = try self.parseExpr();
                    if (self.peek() == .of) {
                        self.pos += 1;
                        const list_e = try self.parsePrimary();
                        return self.mkExpr(.{ .item_access = .{ .index = idx, .list_expr = list_e } });
                    }
                    // Not item access, backtrack
                    self.pos = saved;
                } else {
                    self.pos = saved;
                }
                // Treat as identifier
                const tok = self.advance();
                return self.mkExpr(.{ .ident = tok.value });
            },
            .slice_of => {
                self.pos += 1;
                const target = try self.parsePrimary();
                _ = try self.expect(.from);
                const fr = try self.parseExpr();
                _ = try self.expect(.to);
                const t = try self.parseExpr();
                return self.mkExpr(.{ .slice_expr = .{ .target = target, .from = fr, .to = t } });
            },
            // Contextual keywords used as variable names
            .of, .from, .times => {
                const tok = self.advance();
                return self.mkExpr(.{ .ident = tok.value });
            },
            else => return error.UnexpectedToken,
        }
    }

    fn parseListLit(self: *Parser) ParseError!*Expr {
        self.pos += 1;
        var items: std.ArrayList(*Expr) = .empty;
        if (self.peek() != .rbracket) {
            try items.append(self.alloc, try self.parseExpr());
            while (self.peek() == .comma) {
                self.pos += 1;
                try items.append(self.alloc, try self.parseExpr());
            }
        }
        _ = try self.expect(.rbracket);
        return self.mkExpr(.{ .list_lit = try items.toOwnedSlice(self.alloc) });
    }

    fn parseCallExpr(self: *Parser) ParseError!*Expr {
        self.pos += 1;
        const name = (try self.expect(.identifier)).value;
        var args: std.ArrayList(*Expr) = .empty;

        if (self.peek() == .with) {
            self.pos += 1;
            const old = self.in_call_args;
            self.in_call_args = true;
            try args.append(self.alloc, try self.parseExpr());
            while (self.peek() == .and_kw) {
                self.pos += 1;
                try args.append(self.alloc, try self.parseExpr());
            }
            self.in_call_args = old;
        }
        return self.mkExpr(.{ .call_expr = .{
            .name = name,
            .args = try args.toOwnedSlice(self.alloc),
        } });
    }
};

// ============================================================================
// Runtime Values
// ============================================================================

const Value = union(enum) {
    number: f64,
    string: []const u8,
    boolean: bool,
    list: *std.ArrayList(Value),
    nothing_val: void,
};

// ============================================================================
// Environment (Lexical Scoping)
// ============================================================================

const Env = struct {
    vars: std.StringHashMap(Value),
    parent: ?*Env,

    fn init(alloc: Allocator, parent: ?*Env) Env {
        return .{ .vars = std.StringHashMap(Value).init(alloc), .parent = parent };
    }

    fn deinit(self: *Env) void {
        self.vars.deinit();
    }

    fn get(self: *const Env, name: []const u8) ?Value {
        if (self.vars.get(name)) |v| return v;
        if (self.parent) |p| return p.get(name);
        return null;
    }

    fn put(self: *Env, name: []const u8, val: Value) !void {
        try self.vars.put(name, val);
    }
};

// ============================================================================
// Control Flow Signals
// ============================================================================

const Signal = enum { none, stop, skip };

const FuncDef = struct {
    params: []const []const u8,
    body: []const *Stmt,
};

// ============================================================================
// Interpreter
// ============================================================================

const Interpreter = struct {
    alloc: Allocator,
    funcs: std.StringHashMap(FuncDef),
    global: Env,
    list_arena: std.ArrayList(*std.ArrayList(Value)),
    str_arena: std.ArrayList([]u8),

    fn init(alloc: Allocator) Interpreter {
        return .{
            .alloc = alloc,
            .funcs = std.StringHashMap(FuncDef).init(alloc),
            .global = Env.init(alloc, null),
            .list_arena = .empty,
            .str_arena = .empty,
        };
    }

    fn deinit(self: *Interpreter) void {
        self.funcs.deinit();
        self.global.deinit();
        for (self.list_arena.items) |lst| {
            lst.deinit(self.alloc);
            self.alloc.destroy(lst);
        }
        self.list_arena.deinit(self.alloc);
        for (self.str_arena.items) |s| {
            self.alloc.free(s);
        }
        self.str_arena.deinit(self.alloc);
    }

    fn makeList(self: *Interpreter) !*std.ArrayList(Value) {
        const lst = try self.alloc.create(std.ArrayList(Value));
        lst.* = .empty;
        try self.list_arena.append(self.alloc, lst);
        return lst;
    }

    fn dupeStr(self: *Interpreter, s: []const u8) ![]const u8 {
        const c = try self.alloc.dupe(u8, s);
        try self.str_arena.append(self.alloc, c);
        return c;
    }

    fn writeOut(s: []const u8) void {
        std.fs.File.stdout().writeAll(s) catch {};
    }

    fn die(_: *Interpreter, comptime fmt: []const u8, args: anytype) noreturn {
        std.debug.print("Error: " ++ fmt ++ "\n", args);
        std.process.exit(1);
    }

    fn run(self: *Interpreter, stmts: []const *Stmt) void {
        var sig = Signal.none;
        _ = self.execBlock(stmts, &self.global, &sig, false);
    }

    fn execBlock(self: *Interpreter, stmts: []const *Stmt, env: *Env, sig: *Signal, in_loop: bool) ?Value {
        for (stmts) |s| {
            const ret = self.execStmt(s, env, sig, in_loop);
            if (ret != null) return ret;
            if (sig.* != .none) return null;
        }
        return null;
    }

    fn execStmt(self: *Interpreter, stmt: *const Stmt, env: *Env, sig: *Signal, in_loop: bool) ?Value {
        switch (stmt.*) {
            .print_stmt => |expr| {
                const val = self.eval(expr, env);
                const s = self.valToStr(val);
                writeOut(s);
                writeOut("\n");
            },
            .set_stmt => |st| {
                const val = self.eval(st.value, env);
                env.put(st.name, val) catch self.die("Out of memory", .{});
            },
            .append_stmt => |st| {
                const val = self.eval(st.value, env);
                const lv = env.get(st.target) orelse self.die("Undefined variable: {s}", .{st.target});
                switch (lv) {
                    .list => |lst| lst.append(self.alloc, val) catch self.die("Out of memory", .{}),
                    else => self.die("Cannot append to non-list", .{}),
                }
            },
            .if_stmt => |st| {
                const cv = self.eval(st.condition, env);
                const b = switch (cv) {
                    .boolean => |bv| bv,
                    else => self.die("Non-boolean condition in if", .{}),
                };
                if (b) {
                    return self.execBlock(st.body, env, sig, in_loop);
                }
                for (st.elseif_branches) |br| {
                    const ecv = self.eval(br.condition, env);
                    const eb = switch (ecv) {
                        .boolean => |bv| bv,
                        else => self.die("Non-boolean condition in otherwise if", .{}),
                    };
                    if (eb) {
                        return self.execBlock(br.body, env, sig, in_loop);
                    }
                }
                if (st.else_body) |eb| {
                    return self.execBlock(eb, env, sig, in_loop);
                }
            },
            .while_stmt => |st| {
                while (true) {
                    const cv = self.eval(st.condition, env);
                    const b = switch (cv) {
                        .boolean => |bv| bv,
                        else => self.die("Non-boolean condition in while", .{}),
                    };
                    if (!b) break;
                    const ret = self.execBlock(st.body, env, sig, true);
                    if (ret != null) return ret;
                    if (sig.* == .stop) { sig.* = .none; break; }
                    if (sig.* == .skip) { sig.* = .none; continue; }
                }
            },
            .for_each_stmt => |st| {
                const iv = self.eval(st.iterable, env);
                const lst = switch (iv) {
                    .list => |l| l,
                    else => self.die("Cannot iterate over non-list", .{}),
                };
                for (lst.items) |item| {
                    env.put(st.var_name, item) catch self.die("Out of memory", .{});
                    const ret = self.execBlock(st.body, env, sig, true);
                    if (ret != null) return ret;
                    if (sig.* == .stop) { sig.* = .none; break; }
                    if (sig.* == .skip) { sig.* = .none; continue; }
                }
            },
            .for_from_stmt => |st| {
                const fv = self.asNum(self.eval(st.from, env));
                const tv = self.asNum(self.eval(st.to, env));
                const fi: i64 = @intFromFloat(fv);
                const ti: i64 = @intFromFloat(tv);
                var i = fi;
                while (i <= ti) : (i += 1) {
                    env.put(st.var_name, .{ .number = @floatFromInt(i) }) catch self.die("Out of memory", .{});
                    const ret = self.execBlock(st.body, env, sig, true);
                    if (ret != null) return ret;
                    if (sig.* == .stop) { sig.* = .none; break; }
                    if (sig.* == .skip) { sig.* = .none; continue; }
                }
            },
            .repeat_stmt => |st| {
                const cv = self.asNum(self.eval(st.count, env));
                const ci: i64 = @intFromFloat(cv);
                var i: i64 = 0;
                while (i < ci) : (i += 1) {
                    const ret = self.execBlock(st.body, env, sig, true);
                    if (ret != null) return ret;
                    if (sig.* == .stop) { sig.* = .none; break; }
                    if (sig.* == .skip) { sig.* = .none; continue; }
                }
            },
            .define_stmt => |st| {
                self.funcs.put(st.name, .{ .params = st.params, .body = st.body }) catch
                    self.die("Out of memory", .{});
            },
            .call_stmt => |st| {
                _ = self.callFn(st.name, st.args, env);
            },
            .return_stmt => |maybe_expr| {
                if (maybe_expr) |expr| {
                    return self.eval(expr, env);
                }
                return Value{ .nothing_val = {} };
            },
            .stop_stmt => {
                if (!in_loop) self.die("stop used outside loop", .{});
                sig.* = .stop;
            },
            .skip_stmt => {
                if (!in_loop) self.die("skip used outside loop", .{});
                sig.* = .skip;
            },
            .expr_stmt => |expr| {
                _ = self.eval(expr, env);
            },
        }
        return null;
    }

    fn callFn(self: *Interpreter, name: []const u8, arg_exprs: []const *Expr, caller_env: *Env) Value {
        const func = self.funcs.get(name) orelse self.die("Undefined function: {s}", .{name});
        if (arg_exprs.len != func.params.len)
            self.die("Wrong number of arguments for {s}", .{name});

        var fenv = Env.init(self.alloc, &self.global);
        defer fenv.deinit();

        for (func.params, 0..) |param, i| {
            const val = self.eval(arg_exprs[i], caller_env);
            fenv.put(param, val) catch self.die("Out of memory", .{});
        }

        var sig = Signal.none;
        const ret = self.execBlock(func.body, &fenv, &sig, false);
        return ret orelse Value{ .nothing_val = {} };
    }

    fn eval(self: *Interpreter, expr: *const Expr, env: *Env) Value {
        switch (expr.*) {
            .number => |n| return .{ .number = n },
            .string => |s| return .{ .string = s },
            .boolean => |b| return .{ .boolean = b },
            .nothing_val => return .{ .nothing_val = {} },
            .ident => |name| return env.get(name) orelse self.die("Undefined variable: {s}", .{name}),
            .list_lit => |items| {
                const lst = self.makeList() catch self.die("Out of memory", .{});
                for (items) |ie| {
                    const v = self.eval(ie, env);
                    lst.append(self.alloc, v) catch self.die("Out of memory", .{});
                }
                return .{ .list = lst };
            },
            .binary => |b| return self.evalBinary(b.op, b.left, b.right, env),
            .unary => |u| return self.evalUnary(u.op, u.operand, env),
            .prefix => |p| return self.evalPrefix(p.op, p.operand, env),
            .call_expr => |c| return self.callFn(c.name, c.args, env),
            .item_access => |ia| {
                const idx_v = self.eval(ia.index, env);
                const list_v = self.eval(ia.list_expr, env);
                const idx = switch (idx_v) {
                    .number => |n| @as(i64, @intFromFloat(n)),
                    else => self.die("Index must be a number", .{}),
                };
                return switch (list_v) {
                    .list => |lst| blk: {
                        if (idx < 0 or idx >= @as(i64, @intCast(lst.items.len)))
                            self.die("Index out of bounds", .{});
                        break :blk lst.items[@intCast(idx)];
                    },
                    else => self.die("Cannot index non-list", .{}),
                };
            },
            .slice_expr => |s| {
                const tgt = self.eval(s.target, env);
                const fi: i64 = @intFromFloat(self.asNum(self.eval(s.from, env)));
                const ti: i64 = @intFromFloat(self.asNum(self.eval(s.to, env)));
                return switch (tgt) {
                    .string => |str| blk: {
                        const from_u: usize = @intCast(@max(0, fi));
                        const to_u: usize = @intCast(@min(@as(i64, @intCast(str.len)), ti));
                        if (from_u >= to_u) break :blk .{ .string = "" };
                        break :blk .{ .string = self.dupeStr(str[from_u..to_u]) catch self.die("Out of memory", .{}) };
                    },
                    .list => |lst| blk: {
                        const from_u: usize = @intCast(@max(0, fi));
                        const to_u: usize = @intCast(@min(@as(i64, @intCast(lst.items.len)), ti));
                        const nl = self.makeList() catch self.die("Out of memory", .{});
                        if (from_u < to_u) {
                            for (lst.items[from_u..to_u]) |item| {
                                nl.append(self.alloc, item) catch self.die("Out of memory", .{});
                            }
                        }
                        break :blk .{ .list = nl };
                    },
                    else => self.die("Cannot slice this type", .{}),
                };
            },
            .type_conv => |tc| return self.convertType(self.eval(tc.operand, env), tc.target),
        }
    }

    fn evalBinary(self: *Interpreter, op: BinaryOp, le: *const Expr, re: *const Expr, env: *Env) Value {
        // Short-circuit for and/or
        if (op == .and_op) {
            const lv = self.eval(le, env);
            const lb = switch (lv) {
                .boolean => |b| b,
                else => self.die("Logical and requires boolean operands", .{}),
            };
            if (!lb) return .{ .boolean = false };
            return self.eval(re, env);
        }
        if (op == .or_op) {
            const lv = self.eval(le, env);
            const lb = switch (lv) {
                .boolean => |b| b,
                else => self.die("Logical or requires boolean operands", .{}),
            };
            if (lb) return .{ .boolean = true };
            return self.eval(re, env);
        }

        const lv = self.eval(le, env);
        const rv = self.eval(re, env);

        return switch (op) {
            .add => .{ .number = self.numBin(lv) + self.numBin(rv) },
            .sub => .{ .number = self.numBin(lv) - self.numBin(rv) },
            .mul => .{ .number = self.numBin(lv) * self.numBin(rv) },
            .div => blk: {
                const l = self.numBin(lv);
                const r = self.numBin(rv);
                if (r == 0) self.die("Division by zero", .{});
                break :blk .{ .number = l / r };
            },
            .mod_op => .{ .number = @mod(self.numBin(lv), self.numBin(rv)) },
            .eq => .{ .boolean = self.valsEq(lv, rv) },
            .neq => .{ .boolean = !self.valsEq(lv, rv) },
            .gt => .{ .boolean = self.valsCmp(lv, rv, .gt) },
            .lt => .{ .boolean = self.valsCmp(lv, rv, .lt) },
            .gte => .{ .boolean = self.valsCmp(lv, rv, .gte) },
            .lte => .{ .boolean = self.valsCmp(lv, rv, .lte) },
            .join => blk: {
                const ls = self.valToStr(lv);
                const rs = self.valToStr(rv);
                const cat = std.fmt.allocPrint(self.alloc, "{s}{s}", .{ ls, rs }) catch
                    self.die("Out of memory", .{});
                self.str_arena.append(self.alloc, @constCast(cat)) catch self.die("Out of memory", .{});
                break :blk .{ .string = cat };
            },
            .contains_op => switch (lv) {
                .string => |s| blk: {
                    const sub = switch (rv) {
                        .string => |rs| rs,
                        else => self.die("Contains requires string operand", .{}),
                    };
                    break :blk .{ .boolean = std.mem.indexOf(u8, s, sub) != null };
                },
                .list => |lst| blk: {
                    for (lst.items) |item| {
                        if (self.valsEq(item, rv)) break :blk .{ .boolean = true };
                    }
                    break :blk .{ .boolean = false };
                },
                else => self.die("Contains requires string or list", .{}),
            },
            .and_op, .or_op => unreachable,
        };
    }

    fn evalUnary(self: *Interpreter, op: UnaryOp, operand: *const Expr, env: *Env) Value {
        const v = self.eval(operand, env);
        return switch (op) {
            .not_op => switch (v) {
                .boolean => |b| .{ .boolean = !b },
                else => self.die("Not requires boolean operand", .{}),
            },
            .neg => switch (v) {
                .number => |n| .{ .number = -n },
                else => self.die("Negative requires number operand", .{}),
            },
        };
    }

    fn evalPrefix(self: *Interpreter, op: PrefixOp, operand: *const Expr, env: *Env) Value {
        const v = self.eval(operand, env);
        return switch (op) {
            .upper => switch (v) {
                .string => |s| blk: {
                    const u = self.alloc.alloc(u8, s.len) catch self.die("Out of memory", .{});
                    for (s, 0..) |c, i| u[i] = std.ascii.toUpper(c);
                    self.str_arena.append(self.alloc, u) catch self.die("Out of memory", .{});
                    break :blk .{ .string = u };
                },
                else => self.die("uppercase of requires string", .{}),
            },
            .lower => switch (v) {
                .string => |s| blk: {
                    const u = self.alloc.alloc(u8, s.len) catch self.die("Out of memory", .{});
                    for (s, 0..) |c, i| u[i] = std.ascii.toLower(c);
                    self.str_arena.append(self.alloc, u) catch self.die("Out of memory", .{});
                    break :blk .{ .string = u };
                },
                else => self.die("lowercase of requires string", .{}),
            },
            .length => switch (v) {
                .string => |s| .{ .number = @floatFromInt(s.len) },
                .list => |lst| .{ .number = @floatFromInt(lst.items.len) },
                else => self.die("length of requires string or list", .{}),
            },
            .first => switch (v) {
                .list => |lst| blk: {
                    if (lst.items.len == 0) self.die("first of empty list", .{});
                    break :blk lst.items[0];
                },
                else => self.die("first of requires list", .{}),
            },
            .last => switch (v) {
                .list => |lst| blk: {
                    if (lst.items.len == 0) self.die("last of empty list", .{});
                    break :blk lst.items[lst.items.len - 1];
                },
                else => self.die("last of requires list", .{}),
            },
        };
    }

    fn convertType(self: *Interpreter, val: Value, target: ConvType) Value {
        return switch (target) {
            .to_number => switch (val) {
                .number => val,
                .string => |s| .{
                    .number = std.fmt.parseFloat(f64, s) catch self.die("Cannot convert string to number", .{}),
                },
                .boolean => |b| .{ .number = if (b) 1.0 else 0.0 },
                else => self.die("Cannot convert to number", .{}),
            },
            .to_string => .{ .string = self.valToStr(val) },
            .to_boolean => switch (val) {
                .number => |n| .{ .boolean = n != 0.0 },
                .string => |s| .{ .boolean = s.len > 0 },
                .boolean => val,
                .list => |lst| .{ .boolean = lst.items.len > 0 },
                .nothing_val => .{ .boolean = false },
            },
        };
    }

    // -- Helpers --

    fn numBin(self: *Interpreter, v: Value) f64 {
        return switch (v) {
            .number => |n| n,
            else => self.die("Arithmetic requires numbers", .{}),
        };
    }

    fn asNum(self: *Interpreter, v: Value) f64 {
        return switch (v) {
            .number => |n| n,
            else => self.die("Expected a number", .{}),
        };
    }

    fn valsEq(self: *Interpreter, a: Value, b: Value) bool {
        _ = self;
        return switch (a) {
            .number => |an| switch (b) {
                .number => |bn| an == bn,
                else => false,
            },
            .string => |as_str| switch (b) {
                .string => |bs| std.mem.eql(u8, as_str, bs),
                else => false,
            },
            .boolean => |ab| switch (b) {
                .boolean => |bb| ab == bb,
                else => false,
            },
            .nothing_val => switch (b) {
                .nothing_val => true,
                else => false,
            },
            .list => false,
        };
    }

    const CmpOp = enum { gt, lt, gte, lte };

    fn valsCmp(self: *Interpreter, a: Value, b: Value, op: CmpOp) bool {
        switch (a) {
            .number => |an| switch (b) {
                .number => |bn| return switch (op) {
                    .gt => an > bn,
                    .lt => an < bn,
                    .gte => an >= bn,
                    .lte => an <= bn,
                },
                else => self.die("Cannot compare different types", .{}),
            },
            .string => |as_str| switch (b) {
                .string => |bs| {
                    const ord = std.mem.order(u8, as_str, bs);
                    return switch (op) {
                        .gt => ord == .gt,
                        .lt => ord == .lt,
                        .gte => ord != .lt,
                        .lte => ord != .gt,
                    };
                },
                else => self.die("Cannot compare different types", .{}),
            },
            else => self.die("Cannot compare these types", .{}),
        }
    }

    fn valToStr(self: *Interpreter, v: Value) []const u8 {
        return switch (v) {
            .number => |n| self.fmtNum(n),
            .string => |s| s,
            .boolean => |b| if (b) "true" else "false",
            .nothing_val => "nothing",
            .list => |lst| self.fmtList(lst),
        };
    }

    fn fmtNum(self: *Interpreter, n: f64) []const u8 {
        // Integer check
        if (@rem(n, 1.0) == 0.0 and @abs(n) < 1e15) {
            const i: i64 = @intFromFloat(n);
            const s = std.fmt.allocPrint(self.alloc, "{d}", .{i}) catch self.die("Out of memory", .{});
            self.str_arena.append(self.alloc, @constCast(s)) catch self.die("Out of memory", .{});
            return s;
        }
        // Decimal with up to 6 places, strip trailing zeros
        const s = std.fmt.allocPrint(self.alloc, "{d:.6}", .{n}) catch self.die("Out of memory", .{});
        self.str_arena.append(self.alloc, @constCast(s)) catch self.die("Out of memory", .{});
        var len = s.len;
        if (std.mem.indexOf(u8, s, ".")) |_| {
            while (len > 0 and s[len - 1] == '0') len -= 1;
            if (len > 0 and s[len - 1] == '.') len -= 1;
        }
        return s[0..len];
    }

    fn fmtList(self: *Interpreter, lst: *std.ArrayList(Value)) []const u8 {
        var buf: std.ArrayList(u8) = .empty;
        buf.append(self.alloc, '[') catch self.die("Out of memory", .{});
        for (lst.items, 0..) |item, i| {
            if (i > 0) buf.appendSlice(self.alloc, ", ") catch self.die("Out of memory", .{});
            buf.appendSlice(self.alloc, self.fmtVal(item)) catch self.die("Out of memory", .{});
        }
        buf.append(self.alloc, ']') catch self.die("Out of memory", .{});
        const r = buf.toOwnedSlice(self.alloc) catch self.die("Out of memory", .{});
        self.str_arena.append(self.alloc, @constCast(r)) catch self.die("Out of memory", .{});
        return r;
    }

    fn fmtVal(self: *Interpreter, v: Value) []const u8 {
        return switch (v) {
            .number => |n| self.fmtNum(n),
            .string => |s| blk: {
                const q = std.fmt.allocPrint(self.alloc, "\"{s}\"", .{s}) catch
                    self.die("Out of memory", .{});
                self.str_arena.append(self.alloc, @constCast(q)) catch self.die("Out of memory", .{});
                break :blk q;
            },
            .boolean => |b| if (b) "true" else "false",
            .nothing_val => "nothing",
            .list => |lst| self.fmtList(lst),
        };
    }
};

// ============================================================================
// Main Entry Point
// ============================================================================

pub fn main() !void {
    // Arena over page_allocator: everything freed at process exit, no leak noise.
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const args = try std.process.argsAlloc(alloc);

    if (args.len < 2) {
        std.debug.print("Usage: humanlang <file.hl>\n", .{});
        std.process.exit(1);
    }

    const source = std.fs.cwd().readFileAlloc(alloc, args[1], 10 * 1024 * 1024) catch |err| {
        std.debug.print("Error reading file: {s}: {}\n", .{ args[1], err });
        std.process.exit(1);
    };

    // Lex
    var lexer = Lexer.init(alloc, source);
    lexer.tokenize() catch {
        std.debug.print("Lexer error\n", .{});
        std.process.exit(1);
    };

    // Parse
    var parser = Parser.init(alloc, lexer.tokens.items);
    const stmts = parser.parse() catch {
        std.debug.print("Parse error\n", .{});
        std.process.exit(1);
    };

    // Run
    var interp = Interpreter.init(alloc);
    interp.run(stmts);
}
