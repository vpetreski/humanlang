// humanlang interpreter - a programming language where the syntax is natural English
// Lexer, Parser, and Tree-Walk Interpreter in a single file

import kotlin.system.exitProcess

// ============================================================================
// TOKENS
// ============================================================================

enum class TokenType {
    // Literals
    NUMBER, STRING, TRUE, FALSE, NOTHING,

    // Identifiers
    IDENTIFIER,

    // Keywords
    PRINT, SET, TO, IF, OTHERWISE, OTHERWISE_IF, WHILE, FOR, FOR_EACH,
    FROM, IN, REPEAT, TIMES_KW, DEFINE, WITH, CALL, RETURN, APPEND, STOP, SKIP, AND, OR, NOT,

    // Operators
    PLUS, MINUS, TIMES_OP, DIVIDED_BY, MODULO,
    IS_EQUAL_TO, IS_NOT_EQUAL_TO, IS_GREATER_THAN, IS_LESS_THAN,
    IS_AT_LEAST, IS_AT_MOST,
    JOINED_WITH, CONTAINS, NEGATIVE,

    // Type conversion
    AS,

    // Prefix operators
    UPPERCASE_OF, LOWERCASE_OF, LENGTH_OF, FIRST_OF, LAST_OF,
    ITEM, SLICE_OF, OF,

    // Delimiters
    COLON, LPAREN, RPAREN, LBRACKET, RBRACKET, COMMA,

    // Indentation
    INDENT, DEDENT, NEWLINE,

    // Special
    EOF
}

data class Token(val type: TokenType, val value: Any?, val line: Int)

// ============================================================================
// LEXER
// ============================================================================

class Lexer(private val source: String) {
    private var pos = 0
    private var line = 1
    private val tokens = mutableListOf<Token>()
    private val indentStack = mutableListOf(0)
    private var atLineStart = true

    fun tokenize(): List<Token> {
        while (pos < source.length) {
            if (atLineStart) {
                processLineStart()
            } else {
                processToken()
            }
        }
        // Emit remaining newline and dedents
        if (tokens.isNotEmpty() && tokens.last().type != TokenType.NEWLINE) {
            tokens.add(Token(TokenType.NEWLINE, null, line))
        }
        while (indentStack.size > 1) {
            indentStack.removeAt(indentStack.size - 1)
            tokens.add(Token(TokenType.DEDENT, null, line))
        }
        tokens.add(Token(TokenType.EOF, null, line))
        return tokens
    }

    private fun processLineStart() {
        var spaces = 0
        while (pos < source.length && source[pos] == ' ') {
            spaces++
            pos++
        }
        if (pos >= source.length || source[pos] == '\n') {
            if (pos < source.length) { pos++; line++ }
            return
        }
        if (pos + 1 < source.length && source[pos] == '-' && source[pos + 1] == '-') {
            skipToEndOfLine()
            return
        }
        atLineStart = false
        val currentIndent = indentStack.last()
        if (spaces > currentIndent) {
            indentStack.add(spaces)
            tokens.add(Token(TokenType.INDENT, null, line))
        } else if (spaces < currentIndent) {
            while (indentStack.size > 1 && indentStack.last() > spaces) {
                indentStack.removeAt(indentStack.size - 1)
                tokens.add(Token(TokenType.DEDENT, null, line))
            }
            if (indentStack.last() != spaces) {
                error("Indentation error on line $line")
            }
        }
    }

    private fun processToken() {
        skipSpaces()
        if (pos >= source.length) return
        val c = source[pos]
        when {
            c == '\n' -> {
                pos++
                tokens.add(Token(TokenType.NEWLINE, null, line))
                line++
                atLineStart = true
            }
            c == '-' && pos + 1 < source.length && source[pos + 1] == '-' -> skipToEndOfLine()
            c == '"' -> lexString()
            c == '(' -> { tokens.add(Token(TokenType.LPAREN, null, line)); pos++ }
            c == ')' -> { tokens.add(Token(TokenType.RPAREN, null, line)); pos++ }
            c == '[' -> { tokens.add(Token(TokenType.LBRACKET, null, line)); pos++ }
            c == ']' -> { tokens.add(Token(TokenType.RBRACKET, null, line)); pos++ }
            c == ',' -> { tokens.add(Token(TokenType.COMMA, null, line)); pos++ }
            c == ':' -> { tokens.add(Token(TokenType.COLON, null, line)); pos++ }
            c.isDigit() -> lexNumber()
            c.isLetter() -> lexKeywordOrIdentifier()
            else -> error("Unexpected character '$c' on line $line")
        }
    }

    private fun skipSpaces() {
        while (pos < source.length && source[pos] == ' ') pos++
    }

    private fun skipToEndOfLine() {
        while (pos < source.length && source[pos] != '\n') pos++
        if (pos < source.length) { pos++; line++ }
        atLineStart = true
    }

    private fun lexString() {
        pos++ // skip opening quote
        val sb = StringBuilder()
        while (pos < source.length && source[pos] != '"') {
            if (source[pos] == '\\' && pos + 1 < source.length) {
                pos++
                when (source[pos]) {
                    'n' -> sb.append('\n')
                    't' -> sb.append('\t')
                    '\\' -> sb.append('\\')
                    '"' -> sb.append('"')
                    else -> { sb.append('\\'); sb.append(source[pos]) }
                }
            } else {
                sb.append(source[pos])
            }
            pos++
        }
        if (pos >= source.length) error("Unterminated string on line $line")
        pos++ // skip closing quote
        tokens.add(Token(TokenType.STRING, sb.toString(), line))
    }

    private fun lexNumber() {
        val start = pos
        while (pos < source.length && source[pos].isDigit()) pos++
        if (pos < source.length && source[pos] == '.' && pos + 1 < source.length && source[pos + 1].isDigit()) {
            pos++
            while (pos < source.length && source[pos].isDigit()) pos++
        }
        tokens.add(Token(TokenType.NUMBER, source.substring(start, pos).toDouble(), line))
    }

    private fun lexKeywordOrIdentifier() {
        val start = pos
        while (pos < source.length && (source[pos].isLetterOrDigit() || source[pos] == '_')) pos++
        val word = source.substring(start, pos)

        val multiWord = matchMultiWordKeyword(word)
        if (multiWord != null) {
            tokens.add(multiWord)
        } else {
            tokens.add(matchSingleKeyword(word))
        }
    }

    private fun matchMultiWordKeyword(word: String): Token? {
        val savedPos = pos
        when (word) {
            "divided" -> {
                if (tryMatch(" by")) return Token(TokenType.DIVIDED_BY, null, line)
                pos = savedPos
            }
            "is" -> {
                if (tryMatch(" not equal to")) return Token(TokenType.IS_NOT_EQUAL_TO, null, line)
                if (tryMatch(" equal to")) return Token(TokenType.IS_EQUAL_TO, null, line)
                if (tryMatch(" greater than")) return Token(TokenType.IS_GREATER_THAN, null, line)
                if (tryMatch(" less than")) return Token(TokenType.IS_LESS_THAN, null, line)
                if (tryMatch(" at least")) return Token(TokenType.IS_AT_LEAST, null, line)
                if (tryMatch(" at most")) return Token(TokenType.IS_AT_MOST, null, line)
                pos = savedPos
            }
            "joined" -> {
                if (tryMatch(" with")) return Token(TokenType.JOINED_WITH, null, line)
                pos = savedPos
            }
            "otherwise" -> {
                val s = pos
                if (tryMatch(" if")) return Token(TokenType.OTHERWISE_IF, null, line)
                pos = s
                return Token(TokenType.OTHERWISE, null, line)
            }
            "for" -> {
                if (tryMatch(" each")) return Token(TokenType.FOR_EACH, null, line)
                return Token(TokenType.FOR, null, line)
            }
            "uppercase" -> {
                if (tryMatch(" of")) return Token(TokenType.UPPERCASE_OF, null, line)
                pos = savedPos
            }
            "lowercase" -> {
                if (tryMatch(" of")) return Token(TokenType.LOWERCASE_OF, null, line)
                pos = savedPos
            }
            "length" -> {
                if (tryMatch(" of")) return Token(TokenType.LENGTH_OF, null, line)
                pos = savedPos
            }
            "first" -> {
                if (tryMatch(" of")) return Token(TokenType.FIRST_OF, null, line)
                pos = savedPos
            }
            "last" -> {
                if (tryMatch(" of")) return Token(TokenType.LAST_OF, null, line)
                pos = savedPos
            }
            "slice" -> {
                if (tryMatch(" of")) return Token(TokenType.SLICE_OF, null, line)
                pos = savedPos
            }
        }
        return null
    }

    private fun tryMatch(expected: String): Boolean {
        val savedPos = pos
        if (pos + expected.length <= source.length &&
            source.substring(pos, pos + expected.length) == expected) {
            val endPos = pos + expected.length
            if (endPos >= source.length || (!source[endPos].isLetterOrDigit() && source[endPos] != '_')) {
                pos += expected.length
                return true
            }
        }
        pos = savedPos
        return false
    }

    private fun matchSingleKeyword(word: String): Token {
        return when (word) {
            "print" -> Token(TokenType.PRINT, null, line)
            "set" -> Token(TokenType.SET, null, line)
            "to" -> Token(TokenType.TO, null, line)
            "if" -> Token(TokenType.IF, null, line)
            "while" -> Token(TokenType.WHILE, null, line)
            "from" -> Token(TokenType.FROM, null, line)
            "in" -> Token(TokenType.IN, null, line)
            "repeat" -> Token(TokenType.REPEAT, null, line)
            "times" -> Token(TokenType.TIMES_OP, null, line)
            "define" -> Token(TokenType.DEFINE, null, line)
            "with" -> Token(TokenType.WITH, null, line)
            "call" -> Token(TokenType.CALL, null, line)
            "return" -> Token(TokenType.RETURN, null, line)
            "append" -> Token(TokenType.APPEND, null, line)
            "stop" -> Token(TokenType.STOP, null, line)
            "skip" -> Token(TokenType.SKIP, null, line)
            "and" -> Token(TokenType.AND, null, line)
            "or" -> Token(TokenType.OR, null, line)
            "not" -> Token(TokenType.NOT, null, line)
            "plus" -> Token(TokenType.PLUS, null, line)
            "minus" -> Token(TokenType.MINUS, null, line)
            "modulo" -> Token(TokenType.MODULO, null, line)
            "true" -> Token(TokenType.TRUE, null, line)
            "false" -> Token(TokenType.FALSE, null, line)
            "nothing" -> Token(TokenType.NOTHING, null, line)
            "contains" -> Token(TokenType.CONTAINS, null, line)
            "negative" -> Token(TokenType.NEGATIVE, null, line)
            "as" -> Token(TokenType.AS, null, line)
            "item" -> Token(TokenType.IDENTIFIER, "item", line)
            "of" -> Token(TokenType.IDENTIFIER, "of", line)
            "number" -> Token(TokenType.IDENTIFIER, "number", line)
            "string" -> Token(TokenType.IDENTIFIER, "string", line)
            "boolean" -> Token(TokenType.IDENTIFIER, "boolean", line)
            else -> Token(TokenType.IDENTIFIER, word, line)
        }
    }
}

// ============================================================================
// AST NODES
// ============================================================================

sealed class ASTNode

// Statements
data class PrintStmt(val expr: ASTNode, val line: Int) : ASTNode()
data class SetStmt(val name: String, val expr: ASTNode, val line: Int) : ASTNode()
data class AppendStmt(val expr: ASTNode, val listName: String, val line: Int) : ASTNode()
data class IfStmt(
    val condition: ASTNode,
    val body: List<ASTNode>,
    val elseIfClauses: List<Pair<ASTNode, List<ASTNode>>>,
    val elseBody: List<ASTNode>?,
    val line: Int
) : ASTNode()
data class WhileStmt(val condition: ASTNode, val body: List<ASTNode>, val line: Int) : ASTNode()
data class ForEachStmt(val varName: String, val listExpr: ASTNode, val body: List<ASTNode>, val line: Int) : ASTNode()
data class ForFromStmt(val varName: String, val fromExpr: ASTNode, val toExpr: ASTNode, val body: List<ASTNode>, val line: Int) : ASTNode()
data class RepeatStmt(val count: ASTNode, val body: List<ASTNode>, val line: Int) : ASTNode()
data class DefineStmt(val name: String, val params: List<String>, val body: List<ASTNode>, val line: Int) : ASTNode()
data class ReturnStmt(val expr: ASTNode?, val line: Int) : ASTNode()
data class StopStmt(val line: Int) : ASTNode()
data class SkipStmt(val line: Int) : ASTNode()
data class ExprStmt(val expr: ASTNode, val line: Int) : ASTNode()

// Expressions
data class NumberLit(val value: Double, val line: Int) : ASTNode()
data class StringLit(val value: String, val line: Int) : ASTNode()
data class BoolLit(val value: Boolean, val line: Int) : ASTNode()
data class NothingLit(val line: Int) : ASTNode()
data class ListLit(val elements: List<ASTNode>, val line: Int) : ASTNode()
data class IdentifierExpr(val name: String, val line: Int) : ASTNode()
data class BinaryOp(val op: String, val left: ASTNode, val right: ASTNode, val line: Int) : ASTNode()
data class UnaryOp(val op: String, val operand: ASTNode, val line: Int) : ASTNode()
data class CallExpr(val name: String, val args: List<ASTNode>, val line: Int) : ASTNode()
data class PrefixOp(val op: String, val operand: ASTNode, val line: Int) : ASTNode()
data class ItemAccess(val index: ASTNode, val list: ASTNode, val line: Int) : ASTNode()
data class SliceExpr(val target: ASTNode, val fromExpr: ASTNode, val toExpr: ASTNode, val line: Int) : ASTNode()
data class TypeConversion(val expr: ASTNode, val targetType: String, val line: Int) : ASTNode()
data class ContainsExpr(val left: ASTNode, val right: ASTNode, val line: Int) : ASTNode()
data class JoinedWithExpr(val left: ASTNode, val right: ASTNode, val line: Int) : ASTNode()
data class NegativeExpr(val operand: ASTNode, val line: Int) : ASTNode()

// ============================================================================
// PARSER
// ============================================================================

class Parser(private val tokens: List<Token>) {
    private var pos = 0

    // Context flag: when true, AND is treated as argument separator, not logical operator
    private var inCallArgs = false

    fun parse(): List<ASTNode> {
        val stmts = mutableListOf<ASTNode>()
        skipNewlines()
        while (!isAtEnd()) {
            stmts.add(parseStatement())
            skipNewlines()
        }
        return stmts
    }

    private fun isAtEnd(): Boolean = peek().type == TokenType.EOF
    private fun peek(): Token = tokens[pos]
    private fun peekType(): TokenType = tokens[pos].type
    private fun peekAhead(offset: Int): Token = if (pos + offset < tokens.size) tokens[pos + offset] else tokens[tokens.size - 1]

    private fun advance(): Token {
        val t = tokens[pos]
        pos++
        return t
    }

    private fun expect(type: TokenType): Token {
        if (peekType() != type) {
            error("Expected $type but got ${peekType()} on line ${peek().line}")
        }
        return advance()
    }

    // Accept either an IDENTIFIER token or context-sensitive keywords that can be identifiers
    private fun expectIdentifier(): Token {
        val tok = peek()
        // These token types can serve as identifiers in certain positions
        return when (tok.type) {
            TokenType.IDENTIFIER -> advance()
            // ITEM and OF are now always lexed as IDENTIFIER
            TokenType.TIMES_OP -> { advance(); Token(TokenType.IDENTIFIER, "times", tok.line) }
            TokenType.FROM -> { advance(); Token(TokenType.IDENTIFIER, "from", tok.line) }
            TokenType.TO -> { advance(); Token(TokenType.IDENTIFIER, "to", tok.line) }
            TokenType.IN -> { advance(); Token(TokenType.IDENTIFIER, "in", tok.line) }
            TokenType.WITH -> { advance(); Token(TokenType.IDENTIFIER, "with", tok.line) }
            else -> error("Expected identifier but got ${tok.type} on line ${tok.line}")
        }
    }

    private fun skipNewlines() {
        while (pos < tokens.size && peekType() == TokenType.NEWLINE) advance()
    }

    private fun expectNewline() {
        if (peekType() == TokenType.NEWLINE || peekType() == TokenType.EOF) {
            if (peekType() == TokenType.NEWLINE) advance()
        } else {
            error("Expected newline but got ${peekType()} on line ${peek().line}")
        }
    }

    private fun parseBlock(): List<ASTNode> {
        expect(TokenType.COLON)
        expectNewline()
        expect(TokenType.INDENT)
        val stmts = mutableListOf<ASTNode>()
        skipNewlines()
        while (peekType() != TokenType.DEDENT && peekType() != TokenType.EOF) {
            stmts.add(parseStatement())
            skipNewlines()
        }
        if (peekType() == TokenType.DEDENT) advance()
        return stmts
    }

    private fun parseStatement(): ASTNode {
        return when (peekType()) {
            TokenType.PRINT -> parsePrint()
            TokenType.SET -> parseSet()
            TokenType.IF -> parseIf()
            TokenType.WHILE -> parseWhile()
            TokenType.FOR_EACH -> parseForEach()
            TokenType.FOR -> parseFor()
            TokenType.REPEAT -> parseRepeat()
            TokenType.DEFINE -> parseDefine()
            TokenType.CALL -> {
                val line = peek().line
                val expr = parseCallExpr()
                expectNewline()
                ExprStmt(expr, line)
            }
            TokenType.RETURN -> parseReturn()
            TokenType.APPEND -> parseAppend()
            TokenType.STOP -> { val l = advance().line; expectNewline(); StopStmt(l) }
            TokenType.SKIP -> { val l = advance().line; expectNewline(); SkipStmt(l) }
            else -> error("Unexpected token ${peekType()} on line ${peek().line}")
        }
    }

    private fun parsePrint(): ASTNode {
        val line = expect(TokenType.PRINT).line
        val expr = parseExpression()
        expectNewline()
        return PrintStmt(expr, line)
    }

    private fun parseSet(): ASTNode {
        val line = expect(TokenType.SET).line
        val name = expectIdentifier().value as String
        expect(TokenType.TO)
        val expr = parseExpression()
        expectNewline()
        return SetStmt(name, expr, line)
    }

    private fun parseAppend(): ASTNode {
        val line = expect(TokenType.APPEND).line
        // Parse expression up to "to" keyword -- use the standard expression parser
        // "append EXPR to IDENT"
        val expr = parseExpression()
        expect(TokenType.TO)
        val listName = expectIdentifier().value as String
        expectNewline()
        return AppendStmt(expr, listName, line)
    }

    private fun parseIf(): ASTNode {
        val line = expect(TokenType.IF).line
        val condition = parseExpression()
        val body = parseBlock()
        val elseIfClauses = mutableListOf<Pair<ASTNode, List<ASTNode>>>()
        var elseBody: List<ASTNode>? = null

        skipNewlines()
        while (peekType() == TokenType.OTHERWISE_IF) {
            advance()
            val elseIfCond = parseExpression()
            val elseIfBody = parseBlock()
            elseIfClauses.add(Pair(elseIfCond, elseIfBody))
            skipNewlines()
        }
        if (peekType() == TokenType.OTHERWISE) {
            advance()
            elseBody = parseBlock()
        }
        return IfStmt(condition, body, elseIfClauses, elseBody, line)
    }

    private fun parseWhile(): ASTNode {
        val line = expect(TokenType.WHILE).line
        val condition = parseExpression()
        val body = parseBlock()
        return WhileStmt(condition, body, line)
    }

    private fun parseForEach(): ASTNode {
        val line = expect(TokenType.FOR_EACH).line
        val varName = expectIdentifier().value as String
        expect(TokenType.IN)
        val listExpr = parseExpression()
        val body = parseBlock()
        return ForEachStmt(varName, listExpr, body, line)
    }

    private fun parseFor(): ASTNode {
        val line = expect(TokenType.FOR).line
        val varName = expectIdentifier().value as String
        expect(TokenType.FROM)
        val fromExpr = parseExpression()
        expect(TokenType.TO)
        val toExpr = parseExpression()
        val body = parseBlock()
        return ForFromStmt(varName, fromExpr, toExpr, body, line)
    }

    private fun parseRepeat(): ASTNode {
        val line = expect(TokenType.REPEAT).line
        // Parse count expression: everything up to "times:"
        // We parse a limited expression (primary only covers simple values) but
        // we need to handle things like "repeat (x plus 1) times:"
        // The trick: parse the expression, and the parser for multiplication
        // will consume "times" as an operator. We need to handle "times" followed
        // by ":" specially.
        val count = parseRepeatCount()
        // Now expect colon (times was consumed by parseRepeatCount)
        val body = parseBlock()
        return RepeatStmt(count, body, line)
    }

    // Parse the count expression for "repeat N times:" statement.
    // This is tricky because "times" is also the multiplication operator.
    // Strategy: parse a primary expression. If "times" follows and then ":", it's the keyword.
    // If "times" follows and something else follows, it's multiplication.
    private fun parseRepeatCount(): ASTNode {
        // Parse using standard expression parsing, but stop at TIMES_OP when followed by COLON
        return parseRepeatOr()
    }

    private fun parseRepeatOr(): ASTNode {
        var left = parseRepeatAnd()
        while (peekType() == TokenType.OR) {
            val line = advance().line
            val right = parseRepeatAnd()
            left = BinaryOp("or", left, right, line)
        }
        return left
    }

    private fun parseRepeatAnd(): ASTNode {
        var left = parseRepeatNot()
        while (peekType() == TokenType.AND) {
            val line = advance().line
            val right = parseRepeatNot()
            left = BinaryOp("and", left, right, line)
        }
        return left
    }

    private fun parseRepeatNot(): ASTNode {
        if (peekType() == TokenType.NOT) {
            val line = advance().line
            return UnaryOp("not", parseRepeatNot(), line)
        }
        return parseRepeatComparison()
    }

    private fun parseRepeatComparison(): ASTNode {
        var left = parseRepeatAddition()
        while (peekType() in listOf(
                TokenType.IS_EQUAL_TO, TokenType.IS_NOT_EQUAL_TO,
                TokenType.IS_GREATER_THAN, TokenType.IS_LESS_THAN,
                TokenType.IS_AT_LEAST, TokenType.IS_AT_MOST)) {
            val op = advance()
            val opStr = compOpStr(op.type)
            val right = parseRepeatAddition()
            left = BinaryOp(opStr, left, right, op.line)
        }
        return left
    }

    private fun parseRepeatAddition(): ASTNode {
        var left = parseRepeatMultiplication()
        while (peekType() == TokenType.PLUS || peekType() == TokenType.MINUS) {
            val op = advance()
            val opStr = if (op.type == TokenType.PLUS) "plus" else "minus"
            val right = parseRepeatMultiplication()
            left = BinaryOp(opStr, left, right, op.line)
        }
        return left
    }

    private fun parseRepeatMultiplication(): ASTNode {
        var left = parseUnary()
        while (true) {
            if (peekType() == TokenType.TIMES_OP) {
                // Check if this "times" is followed by ":" -- if so, it's the repeat keyword
                if (peekAhead(1).type == TokenType.COLON) {
                    advance() // consume "times"
                    break
                }
                // Otherwise it's the multiplication operator
                val op = advance()
                val right = parseUnary()
                left = BinaryOp("times", left, right, op.line)
            } else if (peekType() == TokenType.DIVIDED_BY || peekType() == TokenType.MODULO) {
                val op = advance()
                val opStr = if (op.type == TokenType.DIVIDED_BY) "divided_by" else "modulo"
                val right = parseUnary()
                left = BinaryOp(opStr, left, right, op.line)
            } else {
                break
            }
        }
        return left
    }

    private fun parseDefine(): ASTNode {
        val line = expect(TokenType.DEFINE).line
        val name = expectIdentifier().value as String
        val params = mutableListOf<String>()
        if (peekType() == TokenType.WITH) {
            advance()
            params.add(expectIdentifier().value as String)
            while (peekType() == TokenType.AND) {
                advance()
                params.add(expectIdentifier().value as String)
            }
        }
        val body = parseBlock()
        return DefineStmt(name, params, body, line)
    }

    private fun parseReturn(): ASTNode {
        val line = expect(TokenType.RETURN).line
        val expr = if (peekType() == TokenType.NEWLINE || peekType() == TokenType.EOF) {
            null
        } else {
            parseExpression()
        }
        expectNewline()
        return ReturnStmt(expr, line)
    }

    private fun parseCallExpr(): ASTNode {
        val line = expect(TokenType.CALL).line
        val name = expectIdentifier().value as String
        val args = mutableListOf<ASTNode>()
        if (peekType() == TokenType.WITH) {
            advance()
            // Parse arguments separated by AND.
            // Each argument is parsed without consuming AND as logical operator.
            val oldInCallArgs = inCallArgs
            inCallArgs = true
            args.add(parseExpression())
            while (peekType() == TokenType.AND) {
                advance()
                args.add(parseExpression())
            }
            inCallArgs = oldInCallArgs
        }
        return CallExpr(name, args, line)
    }

    // ---- Expression parsing with precedence ----

    private fun parseExpression(): ASTNode {
        return parseOr()
    }

    private fun parseOr(): ASTNode {
        var left = parseAnd()
        while (peekType() == TokenType.OR) {
            val line = advance().line
            val right = parseAnd()
            left = BinaryOp("or", left, right, line)
        }
        return left
    }

    private fun parseAnd(): ASTNode {
        var left = parseNot()
        // In call args context, AND is an argument separator, not a logical operator
        while (peekType() == TokenType.AND && !inCallArgs) {
            val line = advance().line
            val right = parseNot()
            left = BinaryOp("and", left, right, line)
        }
        return left
    }

    private fun parseNot(): ASTNode {
        if (peekType() == TokenType.NOT) {
            val line = advance().line
            return UnaryOp("not", parseNot(), line)
        }
        return parseComparison()
    }

    private fun compOpStr(type: TokenType): String = when (type) {
        TokenType.IS_EQUAL_TO -> "is_equal_to"
        TokenType.IS_NOT_EQUAL_TO -> "is_not_equal_to"
        TokenType.IS_GREATER_THAN -> "is_greater_than"
        TokenType.IS_LESS_THAN -> "is_less_than"
        TokenType.IS_AT_LEAST -> "is_at_least"
        TokenType.IS_AT_MOST -> "is_at_most"
        else -> error("Unexpected operator")
    }

    private fun parseComparison(): ASTNode {
        var left = parseAddition()
        while (peekType() in listOf(
                TokenType.IS_EQUAL_TO, TokenType.IS_NOT_EQUAL_TO,
                TokenType.IS_GREATER_THAN, TokenType.IS_LESS_THAN,
                TokenType.IS_AT_LEAST, TokenType.IS_AT_MOST)) {
            val op = advance()
            val right = parseAddition()
            left = BinaryOp(compOpStr(op.type), left, right, op.line)
        }
        return left
    }

    private fun parseAddition(): ASTNode {
        var left = parseMultiplication()
        while (peekType() == TokenType.PLUS || peekType() == TokenType.MINUS) {
            val op = advance()
            val opStr = if (op.type == TokenType.PLUS) "plus" else "minus"
            val right = parseMultiplication()
            left = BinaryOp(opStr, left, right, op.line)
        }
        return left
    }

    private fun parseMultiplication(): ASTNode {
        var left = parseUnary()
        while (peekType() in listOf(TokenType.TIMES_OP, TokenType.DIVIDED_BY, TokenType.MODULO)) {
            val op = advance()
            val opStr = when (op.type) {
                TokenType.TIMES_OP -> "times"
                TokenType.DIVIDED_BY -> "divided_by"
                TokenType.MODULO -> "modulo"
                else -> error("Unexpected")
            }
            val right = parseUnary()
            left = BinaryOp(opStr, left, right, op.line)
        }
        return left
    }

    private fun parseUnary(): ASTNode {
        if (peekType() == TokenType.NEGATIVE) {
            val line = advance().line
            val operand = parsePostfix()
            return NegativeExpr(operand, line)
        }
        return parsePostfix()
    }

    private fun parsePostfix(): ASTNode {
        var left = parsePrimary()
        while (true) {
            when (peekType()) {
                TokenType.JOINED_WITH -> {
                    val line = advance().line
                    val right = parsePrimary()
                    left = JoinedWithExpr(left, right, line)
                }
                TokenType.AS -> {
                    val asLine = advance().line
                    // Next token should be an identifier with value "number", "string", or "boolean"
                    val typeTok = peek()
                    if (typeTok.type == TokenType.IDENTIFIER) {
                        val typeName = typeTok.value as String
                        if (typeName in listOf("number", "string", "boolean")) {
                            advance()
                            left = TypeConversion(left, typeName, asLine)
                        } else {
                            error("Expected type name after 'as' on line $asLine")
                        }
                    } else {
                        error("Expected type name after 'as' on line $asLine")
                    }
                }
                TokenType.CONTAINS -> {
                    val line = advance().line
                    val right = parsePrimary()
                    left = ContainsExpr(left, right, line)
                }
                else -> break
            }
        }
        return left
    }

    private fun parsePrimary(): ASTNode {
        val tok = peek()
        return when (tok.type) {
            TokenType.NUMBER -> { advance(); NumberLit(tok.value as Double, tok.line) }
            TokenType.STRING -> { advance(); StringLit(tok.value as String, tok.line) }
            TokenType.TRUE -> { advance(); BoolLit(true, tok.line) }
            TokenType.FALSE -> { advance(); BoolLit(false, tok.line) }
            TokenType.NOTHING -> { advance(); NothingLit(tok.line) }
            TokenType.IDENTIFIER -> {
                if (tok.value == "item" && isItemAccessStart()) {
                    val line = advance().line
                    val index = parseItemIndex()
                    // expect identifier "of"
                    val ofTok = peek()
                    if (ofTok.type != TokenType.IDENTIFIER || ofTok.value != "of") {
                        error("Expected 'of' in 'item ... of ...' on line $line")
                    }
                    advance()
                    val list = parsePrimary()
                    ItemAccess(index, list, line)
                } else {
                    advance(); IdentifierExpr(tok.value as String, tok.line)
                }
            }
            TokenType.LPAREN -> {
                advance()
                val expr = parseExpression()
                expect(TokenType.RPAREN)
                expr
            }
            TokenType.LBRACKET -> parseListLiteral()
            TokenType.CALL -> parseCallExpr()
            TokenType.UPPERCASE_OF -> { advance(); PrefixOp("uppercase_of", parsePrimary(), tok.line) }
            TokenType.LOWERCASE_OF -> { advance(); PrefixOp("lowercase_of", parsePrimary(), tok.line) }
            TokenType.LENGTH_OF -> { advance(); PrefixOp("length_of", parsePrimary(), tok.line) }
            TokenType.FIRST_OF -> { advance(); PrefixOp("first_of", parsePrimary(), tok.line) }
            TokenType.LAST_OF -> { advance(); PrefixOp("last_of", parsePrimary(), tok.line) }
            TokenType.SLICE_OF -> {
                val line = advance().line
                val target = parsePrimary()
                expect(TokenType.FROM)
                val from = parseExpression()
                expect(TokenType.TO)
                val to = parseExpression()
                SliceExpr(target, from, to, line)
            }
            else -> error("Unexpected token ${tok.type} (value: ${tok.value}) on line ${tok.line}")
        }
    }

    // Check if "item" starts an item-access expression (item N of list)
    // by looking ahead: after "item", there should be an expression followed by identifier "of"
    private fun isItemAccessStart(): Boolean {
        // Look at what follows "item" - if the next token starts an expression, it's likely "item N of ..."
        val nextType = peekAhead(1).type
        return nextType == TokenType.NUMBER ||
               nextType == TokenType.LPAREN ||
               nextType == TokenType.CALL ||
               nextType == TokenType.NEGATIVE ||
               (nextType == TokenType.IDENTIFIER && peekAhead(1).value != "of")
    }

    // Parse the index expression in "item INDEX of LIST"
    // We need to be careful not to consume "of" as part of the expression
    private fun parseItemIndex(): ASTNode {
        return parseExpression()
    }

    private fun parseListLiteral(): ASTNode {
        val line = expect(TokenType.LBRACKET).line
        val elements = mutableListOf<ASTNode>()
        if (peekType() != TokenType.RBRACKET) {
            elements.add(parseExpression())
            while (peekType() == TokenType.COMMA) {
                advance()
                elements.add(parseExpression())
            }
        }
        expect(TokenType.RBRACKET)
        return ListLit(elements, line)
    }
}

// ============================================================================
// INTERPRETER
// ============================================================================

class RuntimeError(message: String) : Exception(message)
class ReturnSignal(val value: Any?) : Exception()
class StopSignal : Exception()
class SkipSignal : Exception()

class Environment(private val parent: Environment? = null) {
    private val vars = mutableMapOf<String, Any?>()

    fun get(name: String, line: Int): Any? {
        if (name in vars) return vars[name]
        if (parent != null) return parent.get(name, line)
        throw RuntimeError("Error on line $line: undefined variable '$name'")
    }

    fun set(name: String, value: Any?) {
        vars[name] = value
    }

    fun has(name: String): Boolean = name in vars || (parent != null && parent.has(name))

    fun assign(name: String, value: Any?) {
        vars[name] = value
    }
}

data class HLFunction(val name: String, val params: List<String>, val body: List<ASTNode>, val closure: Environment)

class Interpreter {
    private val globals = Environment()
    private val functions = mutableMapOf<String, HLFunction>()
    private var inLoop = 0

    fun run(program: List<ASTNode>) {
        executeBlock(program, globals)
    }

    private fun executeBlock(stmts: List<ASTNode>, env: Environment) {
        for (stmt in stmts) {
            executeStatement(stmt, env)
        }
    }

    private fun executeStatement(stmt: ASTNode, env: Environment) {
        when (stmt) {
            is PrintStmt -> {
                val value = evaluate(stmt.expr, env)
                println(formatValue(value))
            }
            is SetStmt -> {
                val value = evaluate(stmt.expr, env)
                env.assign(stmt.name, value)
            }
            is AppendStmt -> {
                val value = evaluate(stmt.expr, env)
                val list = env.get(stmt.listName, stmt.line)
                if (list !is MutableList<*>) {
                    throw RuntimeError("Error on line ${stmt.line}: '${stmt.listName}' is not a list")
                }
                @Suppress("UNCHECKED_CAST")
                (list as MutableList<Any?>).add(value)
            }
            is IfStmt -> {
                val condVal = evaluate(stmt.condition, env)
                if (condVal !is Boolean) {
                    throw RuntimeError("Error on line ${stmt.line}: condition must be a boolean")
                }
                if (condVal) {
                    executeBlock(stmt.body, env)
                } else {
                    var handled = false
                    for ((elseIfCond, elseIfBody) in stmt.elseIfClauses) {
                        val elseIfVal = evaluate(elseIfCond, env)
                        if (elseIfVal !is Boolean) {
                            throw RuntimeError("Error on line ${stmt.line}: condition must be a boolean")
                        }
                        if (elseIfVal) {
                            executeBlock(elseIfBody, env)
                            handled = true
                            break
                        }
                    }
                    if (!handled && stmt.elseBody != null) {
                        executeBlock(stmt.elseBody, env)
                    }
                }
            }
            is WhileStmt -> {
                inLoop++
                try {
                    while (true) {
                        val condVal = evaluate(stmt.condition, env)
                        if (condVal !is Boolean) {
                            throw RuntimeError("Error on line ${stmt.line}: condition must be a boolean")
                        }
                        if (!condVal) break
                        try {
                            executeBlock(stmt.body, env)
                        } catch (_: SkipSignal) { continue }
                        catch (_: StopSignal) { break }
                    }
                } finally { inLoop-- }
            }
            is ForEachStmt -> {
                val listVal = evaluate(stmt.listExpr, env)
                if (listVal !is List<*>) {
                    throw RuntimeError("Error on line ${stmt.line}: 'for each' requires a list")
                }
                inLoop++
                try {
                    for (item in listVal) {
                        env.assign(stmt.varName, item)
                        try {
                            executeBlock(stmt.body, env)
                        } catch (_: SkipSignal) { continue }
                        catch (_: StopSignal) { break }
                    }
                } finally { inLoop-- }
            }
            is ForFromStmt -> {
                val fromVal = evaluate(stmt.fromExpr, env)
                val toVal = evaluate(stmt.toExpr, env)
                if (fromVal !is Double || toVal !is Double) {
                    throw RuntimeError("Error on line ${stmt.line}: 'for from' requires numbers")
                }
                val from = fromVal.toInt()
                val to = toVal.toInt()
                inLoop++
                try {
                    for (i in from..to) {
                        env.assign(stmt.varName, i.toDouble())
                        try {
                            executeBlock(stmt.body, env)
                        } catch (_: SkipSignal) { continue }
                        catch (_: StopSignal) { break }
                    }
                } finally { inLoop-- }
            }
            is RepeatStmt -> {
                val countVal = evaluate(stmt.count, env)
                if (countVal !is Double) {
                    throw RuntimeError("Error on line ${stmt.line}: 'repeat' requires a number")
                }
                val count = countVal.toInt()
                inLoop++
                try {
                    for (i in 0 until count) {
                        try {
                            executeBlock(stmt.body, env)
                        } catch (_: SkipSignal) { continue }
                        catch (_: StopSignal) { break }
                    }
                } finally { inLoop-- }
            }
            is DefineStmt -> {
                functions[stmt.name] = HLFunction(stmt.name, stmt.params, stmt.body, env)
            }
            is ReturnStmt -> {
                val value = if (stmt.expr != null) evaluate(stmt.expr, env) else null
                throw ReturnSignal(value)
            }
            is StopStmt -> {
                if (inLoop == 0) throw RuntimeError("Error on line ${stmt.line}: 'stop' used outside of a loop")
                throw StopSignal()
            }
            is SkipStmt -> {
                if (inLoop == 0) throw RuntimeError("Error on line ${stmt.line}: 'skip' used outside of a loop")
                throw SkipSignal()
            }
            is ExprStmt -> evaluate(stmt.expr, env)
            else -> error("Unknown statement type: ${stmt::class.simpleName}")
        }
    }

    private fun evaluate(node: ASTNode, env: Environment): Any? {
        return when (node) {
            is NumberLit -> node.value
            is StringLit -> node.value
            is BoolLit -> node.value
            is NothingLit -> null
            is ListLit -> node.elements.map { evaluate(it, env) }.toMutableList()
            is IdentifierExpr -> env.get(node.name, node.line)
            is BinaryOp -> evaluateBinaryOp(node, env)
            is UnaryOp -> evaluateUnaryOp(node, env)
            is NegativeExpr -> {
                val operand = evaluate(node.operand, env)
                if (operand !is Double) throw RuntimeError("Error on line ${node.line}: 'negative' requires a number")
                -operand
            }
            is CallExpr -> evaluateCall(node, env)
            is PrefixOp -> evaluatePrefixOp(node, env)
            is ItemAccess -> {
                val index = evaluate(node.index, env)
                val list = evaluate(node.list, env)
                if (index !is Double) throw RuntimeError("Error on line ${node.line}: index must be a number")
                val i = index.toInt()
                when (list) {
                    is List<*> -> {
                        if (i < 0 || i >= list.size) throw RuntimeError("Error on line ${node.line}: index $i out of bounds")
                        list[i]
                    }
                    else -> throw RuntimeError("Error on line ${node.line}: 'item' requires a list")
                }
            }
            is SliceExpr -> {
                val target = evaluate(node.target, env)
                val from = evaluate(node.fromExpr, env)
                val to = evaluate(node.toExpr, env)
                if (from !is Double || to !is Double) throw RuntimeError("Error on line ${node.line}: slice indices must be numbers")
                val f = from.toInt()
                val t = to.toInt()
                when (target) {
                    is String -> target.substring(f, t)
                    is List<*> -> target.subList(f, t).toMutableList()
                    else -> throw RuntimeError("Error on line ${node.line}: 'slice' requires a string or list")
                }
            }
            is TypeConversion -> {
                val value = evaluate(node.expr, env)
                convertType(value, node.targetType, node.line)
            }
            is ContainsExpr -> {
                val left = evaluate(node.left, env)
                val right = evaluate(node.right, env)
                when (left) {
                    is String -> {
                        if (right !is String) throw RuntimeError("Error on line ${node.line}: 'contains' on string requires string")
                        left.contains(right)
                    }
                    is List<*> -> left.any { valuesEqual(it, right) }
                    else -> throw RuntimeError("Error on line ${node.line}: 'contains' requires string or list")
                }
            }
            is JoinedWithExpr -> {
                val left = evaluate(node.left, env)
                val right = evaluate(node.right, env)
                formatValue(left) + formatValue(right)
            }
            else -> error("Unknown expression: ${node::class.simpleName}")
        }
    }

    private fun evaluateBinaryOp(node: BinaryOp, env: Environment): Any? {
        if (node.op == "and") {
            val left = evaluate(node.left, env)
            if (left !is Boolean) throw RuntimeError("Error on line ${node.line}: 'and' requires booleans")
            if (!left) return false
            val right = evaluate(node.right, env)
            if (right !is Boolean) throw RuntimeError("Error on line ${node.line}: 'and' requires booleans")
            return right
        }
        if (node.op == "or") {
            val left = evaluate(node.left, env)
            if (left !is Boolean) throw RuntimeError("Error on line ${node.line}: 'or' requires booleans")
            if (left) return true
            val right = evaluate(node.right, env)
            if (right !is Boolean) throw RuntimeError("Error on line ${node.line}: 'or' requires booleans")
            return right
        }
        val left = evaluate(node.left, env)
        val right = evaluate(node.right, env)
        return when (node.op) {
            "plus" -> { requireNumbers(left, right, node.line); (left as Double) + (right as Double) }
            "minus" -> { requireNumbers(left, right, node.line); (left as Double) - (right as Double) }
            "times" -> { requireNumbers(left, right, node.line); (left as Double) * (right as Double) }
            "divided_by" -> {
                requireNumbers(left, right, node.line)
                if ((right as Double) == 0.0) throw RuntimeError("Error on line ${node.line}: division by zero")
                (left as Double) / right
            }
            "modulo" -> {
                requireNumbers(left, right, node.line)
                if ((right as Double) == 0.0) throw RuntimeError("Error on line ${node.line}: division by zero")
                (left as Double) % right
            }
            "is_equal_to" -> valuesEqual(left, right)
            "is_not_equal_to" -> !valuesEqual(left, right)
            "is_greater_than" -> compareValues(left, right, node.line) > 0
            "is_less_than" -> compareValues(left, right, node.line) < 0
            "is_at_least" -> compareValues(left, right, node.line) >= 0
            "is_at_most" -> compareValues(left, right, node.line) <= 0
            else -> error("Unknown op: ${node.op}")
        }
    }

    private fun requireNumbers(a: Any?, b: Any?, line: Int) {
        if (a !is Double || b !is Double) throw RuntimeError("Error on line $line: arithmetic requires numbers")
    }

    private fun evaluateUnaryOp(node: UnaryOp, env: Environment): Any? {
        val operand = evaluate(node.operand, env)
        return when (node.op) {
            "not" -> {
                if (operand !is Boolean) throw RuntimeError("Error on line ${node.line}: 'not' requires a boolean")
                !operand
            }
            else -> error("Unknown unary op: ${node.op}")
        }
    }

    private fun evaluateCall(node: CallExpr, env: Environment): Any? {
        val func = functions[node.name]
            ?: throw RuntimeError("Error on line ${node.line}: undefined function '${node.name}'")
        if (node.args.size != func.params.size) {
            throw RuntimeError("Error on line ${node.line}: function '${node.name}' expects ${func.params.size} arguments but got ${node.args.size}")
        }
        val funcEnv = Environment(func.closure)
        for (i in func.params.indices) {
            funcEnv.set(func.params[i], evaluate(node.args[i], env))
        }
        return try {
            executeBlock(func.body, funcEnv)
            null
        } catch (e: ReturnSignal) {
            e.value
        }
    }

    private fun evaluatePrefixOp(node: PrefixOp, env: Environment): Any? {
        val operand = evaluate(node.operand, env)
        return when (node.op) {
            "uppercase_of" -> {
                if (operand !is String) throw RuntimeError("Error on line ${node.line}: 'uppercase of' requires a string")
                operand.uppercase()
            }
            "lowercase_of" -> {
                if (operand !is String) throw RuntimeError("Error on line ${node.line}: 'lowercase of' requires a string")
                operand.lowercase()
            }
            "length_of" -> when (operand) {
                is String -> operand.length.toDouble()
                is List<*> -> operand.size.toDouble()
                else -> throw RuntimeError("Error on line ${node.line}: 'length of' requires a string or list")
            }
            "first_of" -> {
                if (operand !is List<*>) throw RuntimeError("Error on line ${node.line}: 'first of' requires a list")
                if (operand.isEmpty()) throw RuntimeError("Error on line ${node.line}: 'first of' on empty list")
                operand.first()
            }
            "last_of" -> {
                if (operand !is List<*>) throw RuntimeError("Error on line ${node.line}: 'last of' requires a list")
                if (operand.isEmpty()) throw RuntimeError("Error on line ${node.line}: 'last of' on empty list")
                operand.last()
            }
            else -> error("Unknown prefix op: ${node.op}")
        }
    }

    private fun valuesEqual(a: Any?, b: Any?): Boolean {
        if (a == null && b == null) return true
        if (a == null || b == null) return false
        if (a is Double && b is Double) return a == b
        if (a is String && b is String) return a == b
        if (a is Boolean && b is Boolean) return a == b
        if (a is List<*> && b is List<*>) {
            if (a.size != b.size) return false
            return a.zip(b).all { (x, y) -> valuesEqual(x, y) }
        }
        return false
    }

    private fun compareValues(a: Any?, b: Any?, line: Int): Int {
        if (a is Double && b is Double) return a.compareTo(b)
        if (a is String && b is String) return a.compareTo(b)
        throw RuntimeError("Error on line $line: cannot compare ${typeName(a)} and ${typeName(b)}")
    }

    private fun convertType(value: Any?, targetType: String, line: Int): Any? {
        return when (targetType) {
            "number" -> when (value) {
                is Double -> value
                is String -> value.toDoubleOrNull()
                    ?: throw RuntimeError("Error on line $line: cannot convert '$value' to number")
                is Boolean -> if (value) 1.0 else 0.0
                else -> throw RuntimeError("Error on line $line: cannot convert ${typeName(value)} to number")
            }
            "string" -> formatValue(value)
            "boolean" -> when (value) {
                is Double -> value != 0.0
                is String -> value.isNotEmpty()
                is Boolean -> value
                is List<*> -> value.isNotEmpty()
                null -> false
                else -> throw RuntimeError("Error on line $line: cannot convert to boolean")
            }
            else -> throw RuntimeError("Error on line $line: unknown type '$targetType'")
        }
    }

    private fun typeName(value: Any?): String = when (value) {
        null -> "nothing"
        is Double -> "number"
        is String -> "string"
        is Boolean -> "boolean"
        is List<*> -> "list"
        else -> "unknown"
    }

    companion object {
        fun formatValue(value: Any?): String = when (value) {
            null -> "nothing"
            is Double -> {
                if (value == value.toLong().toDouble() && !value.isInfinite() && !value.isNaN()) {
                    value.toLong().toString()
                } else {
                    val formatted = "%.6f".format(value)
                    formatted.trimEnd('0').trimEnd('.')
                }
            }
            is Boolean -> value.toString()
            is String -> value
            is List<*> -> "[${value.joinToString(", ") { formatValue(it) }}]"
            else -> value.toString()
        }
    }
}

// ============================================================================
// MAIN
// ============================================================================

fun main(args: Array<String>) {
    if (args.isEmpty()) {
        System.err.println("Usage: humanlang <file.hl>")
        exitProcess(1)
    }
    val source = try {
        java.io.File(args[0]).readText()
    } catch (e: Exception) {
        System.err.println("Error: cannot read file '${args[0]}'")
        exitProcess(1)
    }
    try {
        val tokens = Lexer(source).tokenize()
        val ast = Parser(tokens).parse()
        Interpreter().run(ast)
    } catch (e: RuntimeError) {
        System.err.println(e.message)
        exitProcess(1)
    } catch (e: Exception) {
        System.err.println("Error: ${e.message}")
        exitProcess(1)
    }
}
