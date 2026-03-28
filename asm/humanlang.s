// =============================================================================
// humanlang interpreter — ARM64 macOS assembly
// Compile: cc -o humanlang humanlang.s
// Usage:   ./humanlang program.hl
// =============================================================================

.global _main

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
.equ VAL_SIZE, 32
.equ VAL_TYPE, 0
.equ VAL_DATA, 8
.equ VAL_LEN, 16
.equ VAL_CAP, 24

.equ TYPE_NUMBER, 0
.equ TYPE_STRING, 1
.equ TYPE_BOOL, 2
.equ TYPE_LIST, 3
.equ TYPE_NOTHING, 4

// Token types
.equ TOK_EOF, 0
.equ TOK_NUMBER, 1
.equ TOK_STRING, 2
.equ TOK_IDENT, 3
.equ TOK_TRUE, 4
.equ TOK_FALSE, 5
.equ TOK_NOTHING, 6
.equ TOK_PRINT, 7
.equ TOK_SET, 8
.equ TOK_TO, 9
.equ TOK_IF, 10
.equ TOK_OTHERWISE, 11
.equ TOK_OTHERWISE_IF, 12
.equ TOK_WHILE, 13
.equ TOK_FOR, 14
.equ TOK_FOR_EACH, 15
.equ TOK_FROM, 16
.equ TOK_IN, 17
.equ TOK_REPEAT, 18
.equ TOK_TIMES, 19
.equ TOK_DEFINE, 20
.equ TOK_WITH, 21
.equ TOK_CALL, 22
.equ TOK_RETURN, 23
.equ TOK_AND, 24
.equ TOK_OR, 25
.equ TOK_NOT, 26
.equ TOK_PLUS, 27
.equ TOK_MINUS, 28
.equ TOK_DIVIDED_BY, 29
.equ TOK_MODULO, 30
.equ TOK_IS_EQUAL_TO, 31
.equ TOK_IS_NOT_EQUAL_TO, 32
.equ TOK_IS_GREATER_THAN, 33
.equ TOK_IS_LESS_THAN, 34
.equ TOK_IS_AT_LEAST, 35
.equ TOK_IS_AT_MOST, 36
.equ TOK_JOINED_WITH, 37
.equ TOK_CONTAINS, 38
.equ TOK_UPPERCASE_OF, 39
.equ TOK_LOWERCASE_OF, 40
.equ TOK_LENGTH_OF, 41
.equ TOK_FIRST_OF, 42
.equ TOK_LAST_OF, 43
.equ TOK_ITEM, 44
.equ TOK_OF, 45
.equ TOK_SLICE_OF, 46
.equ TOK_AS, 47
.equ TOK_APPEND, 48
.equ TOK_STOP, 49
.equ TOK_SKIP, 50
.equ TOK_NEGATIVE, 51
.equ TOK_INDENT, 52
.equ TOK_DEDENT, 53
.equ TOK_NEWLINE, 54
.equ TOK_COLON, 55
.equ TOK_LPAREN, 56
.equ TOK_RPAREN, 57
.equ TOK_LBRACKET, 58
.equ TOK_RBRACKET, 59
.equ TOK_COMMA, 60
.equ TOK_NUMBER_KW, 61
.equ TOK_STRING_KW, 62
.equ TOK_BOOLEAN_KW, 63

// AST Node types
.equ NODE_PROGRAM, 0
.equ NODE_PRINT, 1
.equ NODE_SET, 2
.equ NODE_IF, 3
.equ NODE_WHILE, 4
.equ NODE_FOR_EACH, 5
.equ NODE_FOR_FROM, 6
.equ NODE_REPEAT, 7
.equ NODE_DEFINE, 8
.equ NODE_CALL, 9
.equ NODE_RETURN, 10
.equ NODE_APPEND, 11
.equ NODE_STOP, 12
.equ NODE_SKIP, 13
.equ NODE_NUMBER_LIT, 14
.equ NODE_STRING_LIT, 15
.equ NODE_BOOL_LIT, 16
.equ NODE_NOTHING_LIT, 17
.equ NODE_IDENT, 18
.equ NODE_LIST_LIT, 19
.equ NODE_BINOP, 20
.equ NODE_UNARY, 21
.equ NODE_JOINED_WITH, 22
.equ NODE_CONTAINS, 23
.equ NODE_AS, 24
.equ NODE_PREFIX_OP, 25
.equ NODE_ITEM_OF, 26
.equ NODE_SLICE_OF, 27
.equ NODE_NEGATIVE, 28
.equ NODE_BLOCK, 29

// Binop types
.equ OP_PLUS, 0
.equ OP_MINUS, 1
.equ OP_TIMES, 2
.equ OP_DIVIDED_BY, 3
.equ OP_MODULO, 4
.equ OP_EQ, 5
.equ OP_NEQ, 6
.equ OP_GT, 7
.equ OP_LT, 8
.equ OP_GTE, 9
.equ OP_LTE, 10
.equ OP_AND, 11
.equ OP_OR, 12

// Prefix op types
.equ PRE_UPPERCASE, 0
.equ PRE_LOWERCASE, 1
.equ PRE_LENGTH, 2
.equ PRE_FIRST, 3
.equ PRE_LAST, 4
.equ PRE_NOT, 5

// Signal values
.equ SIG_NONE, 0
.equ SIG_STOP, 1
.equ SIG_SKIP, 2
.equ SIG_RETURN, 3

// Token struct (32 bytes)
.equ TOKEN_SIZE, 32
.equ TOKEN_TYPE, 0
.equ TOKEN_STR, 8
.equ TOKEN_NUM, 16
.equ TOKEN_LINE, 24

// AST node (56 bytes)
.equ AST_TYPE, 0
.equ AST_F1, 8
.equ AST_F2, 16
.equ AST_F3, 24
.equ AST_F4, 32
.equ AST_F5, 40
.equ AST_LINE, 48
.equ AST_SIZE, 56

// Env struct
.equ ENV_PARENT, 0
.equ ENV_VARS, 8
.equ ENV_COUNT, 16
.equ ENV_CAP, 24
.equ ENV_SIZE, 32
.equ ENVVAR_NAME, 0
.equ ENVVAR_VAL, 8
.equ ENVVAR_SIZE, 40

// Function entry
.equ FUNC_SIZE, 40
.equ FUNC_NAME, 0
.equ FUNC_PARAMS, 8
.equ FUNC_PARAMCNT, 16
.equ FUNC_BODY, 24
.equ FUNC_LINE, 32

// ---------------------------------------------------------------------------
// Data section
// ---------------------------------------------------------------------------
.section __DATA,__data
.p2align 3

str_rb:     .asciz "rb"

// Format strings
fmt_int:    .asciz "%lld"
fmt_float:  .asciz "%.6f"
fmt_true:   .asciz "true"
fmt_false:  .asciz "false"
fmt_nothing_s: .asciz "nothing"
fmt_lbracket: .asciz "["
fmt_rbracket: .asciz "]"
fmt_comma:  .asciz ", "
fmt_newline: .asciz "\n"
fmt_quote:  .asciz "\""
empty_str:  .asciz ""

// Error format strings
err_usage:      .asciz "Usage: humanlang <file.hl>\n"
err_open:       .asciz "Error: cannot open file '%s'\n"
err_divzero:    .asciz "Error on line %lld: Division by zero\n"
err_not_bool:   .asciz "Error on line %lld: Condition must be a boolean\n"
err_undef_var:  .asciz "Error on line %lld: Undefined variable '%s'\n"
err_undef_fn:   .asciz "Error on line %lld: Undefined function '%s'\n"
err_index_oob:  .asciz "Error on line %lld: Index out of bounds\n"
err_empty_list: .asciz "Error on line %lld: Cannot get element of empty list\n"
err_not_list:   .asciz "Error on line %lld: Expected a list\n"
err_conv:       .asciz "Error on line %lld: Invalid type conversion\n"
err_parse_s:    .asciz "Error on line %lld: Unexpected token\n"

// Keyword strings
kw_print:    .asciz "print"
kw_set:      .asciz "set"
kw_to:       .asciz "to"
kw_if:       .asciz "if"
kw_otherwise: .asciz "otherwise"
kw_while:    .asciz "while"
kw_for:      .asciz "for"
kw_each:     .asciz "each"
kw_from:     .asciz "from"
kw_in:       .asciz "in"
kw_repeat:   .asciz "repeat"
kw_times:    .asciz "times"
kw_define:   .asciz "define"
kw_with:     .asciz "with"
kw_call:     .asciz "call"
kw_return:   .asciz "return"
kw_and:      .asciz "and"
kw_or:       .asciz "or"
kw_not:      .asciz "not"
kw_plus:     .asciz "plus"
kw_minus:    .asciz "minus"
kw_divided:  .asciz "divided"
kw_by:       .asciz "by"
kw_modulo:   .asciz "modulo"
kw_is:       .asciz "is"
kw_equal:    .asciz "equal"
kw_greater:  .asciz "greater"
kw_less:     .asciz "less"
kw_than:     .asciz "than"
kw_at:       .asciz "at"
kw_least:    .asciz "least"
kw_most:     .asciz "most"
kw_joined:   .asciz "joined"
kw_contains: .asciz "contains"
kw_uppercase: .asciz "uppercase"
kw_lowercase: .asciz "lowercase"
kw_length:   .asciz "length"
kw_first:    .asciz "first"
kw_last:     .asciz "last"
kw_item:     .asciz "item"
kw_of:       .asciz "of"
kw_slice:    .asciz "slice"
kw_as:       .asciz "as"
kw_append:   .asciz "append"
kw_stop:     .asciz "stop"
kw_skip:     .asciz "skip"
kw_negative: .asciz "negative"
kw_true:     .asciz "true"
kw_false:    .asciz "false"
kw_nothing:  .asciz "nothing"
kw_number:   .asciz "number"
kw_string:   .asciz "string"
kw_boolean:  .asciz "boolean"

// Global state
.p2align 3
g_tokens:       .quad 0
g_token_count:  .quad 0
g_token_cap:    .quad 0
g_token_pos:    .quad 0
g_env:          .quad 0
g_funcs:        .quad 0
g_func_count:   .quad 0
g_func_cap:     .quad 0
g_signal:       .quad 0
g_return_val:   .space 32
g_src:          .quad 0    // source pointer (for lexer helpers)
g_src_end:      .quad 0    // source end pointer

dbg_entry:      .asciz "DBG: entry"
dbg_before_read: .asciz "DBG: before read"
dbg_read:       .asciz "DBG: file read OK"
dbg_lex:        .asciz "DBG: lex OK"
dbg_parse:      .asciz "DBG: parse OK"
dbg_env:        .asciz "DBG: env OK"
dbg_interp:     .asciz "DBG: interp OK"

// ---------------------------------------------------------------------------
// Text section
// ---------------------------------------------------------------------------
.section __TEXT,__text
.p2align 2

// =============================================================================
// Variadic call wrappers (Apple ARM64 ABI: varargs go on stack)
// =============================================================================

// _printf_int: printf(fmt, int_val) — x0=fmt, x1=val
_printf_int:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    sub     sp, sp, #16
    str     x1, [sp]
    bl      _printf
    add     sp, sp, #16
    ldp     x29, x30, [sp], #16
    ret

// _printf_str: printf(fmt, str) — x0=fmt, x1=str
_printf_str:
    b       _printf_int

// _snprintf_int: snprintf(buf, n, fmt, val) — x0=buf, x1=n, x2=fmt, x3=val
_snprintf_int:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    sub     sp, sp, #16
    str     x3, [sp]
    bl      _snprintf
    add     sp, sp, #16
    ldp     x29, x30, [sp], #16
    ret

// _snprintf_float: snprintf(buf, n, fmt, d0) — x0=buf, x1=n, x2=fmt, d0=val
_snprintf_float:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    sub     sp, sp, #16
    str     d0, [sp]
    bl      _snprintf
    add     sp, sp, #16
    ldp     x29, x30, [sp], #16
    ret

// _fprintf_int: fprintf(file, fmt, val) — x0=file, x1=fmt, x2=val
_fprintf_int:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    sub     sp, sp, #16
    str     x2, [sp]
    bl      _fprintf
    add     sp, sp, #16
    ldp     x29, x30, [sp], #16
    ret

// _fprintf_int_str: fprintf(file, fmt, int, str) — x0=file, x1=fmt, x2=int, x3=str
_fprintf_int_str:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    sub     sp, sp, #16
    str     x2, [sp]
    str     x3, [sp, #8]
    bl      _fprintf
    add     sp, sp, #16
    ldp     x29, x30, [sp], #16
    ret

// =============================================================================
// _main
// =============================================================================
_main:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!

    cmp     x0, #2
    b.lt    L_main_usage

    ldr     x19, [x1, #8]          // x19 = filename

    // Read file
    mov     x0, x19
    bl      _read_file
    cbz     x0, L_main_open_err
    mov     x20, x0                // source buffer
    mov     x21, x1                // source length

    // Lex
    mov     x0, x20
    mov     x1, x21
    bl      _lexer

    // Parse
    bl      _parser
    mov     x22, x0                // AST root

    // Init env
    bl      _env_new
    adrp    x8, g_env@PAGE
    str     x0, [x8, g_env@PAGEOFF]

    // Interpret
    mov     x0, x22
    bl      _interpret_block

    mov     x0, #0
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    bl      _exit

L_main_usage:
    adrp    x0, ___stderrp@GOTPAGE
    ldr     x0, [x0, ___stderrp@GOTPAGEOFF]
    ldr     x0, [x0]
    adrp    x1, err_usage@PAGE
    add     x1, x1, err_usage@PAGEOFF
    bl      _fputs
    mov     x0, #1
    bl      _exit

L_main_open_err:
    adrp    x0, ___stderrp@GOTPAGE
    ldr     x0, [x0, ___stderrp@GOTPAGEOFF]
    ldr     x0, [x0]
    adrp    x1, err_open@PAGE
    add     x1, x1, err_open@PAGEOFF
    mov     x2, x19
    bl      _fprintf_int
    mov     x0, #1
    bl      _exit

// =============================================================================
// _read_file: x0 = filename -> x0 = buffer, x1 = length
// Uses stat + open + read (not fopen, which has issues with Apple ABI)
// =============================================================================
_read_file:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!

    mov     x19, x0                // filename

    // Get file size via stat (st_size at offset 96 on macOS ARM64)
    sub     sp, sp, #256
    mov     x0, x19
    mov     x1, sp
    bl      _stat
    cmp     x0, #0
    b.ne    L_rf_fail
    ldr     x20, [sp, #96]         // file size
    add     sp, sp, #256

    // Open file
    mov     x0, x19
    mov     x1, #0                 // O_RDONLY
    mov     x2, #0
    bl      _open
    cmp     x0, #0
    b.lt    L_rf_fail2
    mov     x21, x0                // fd

    // Allocate buffer
    add     x0, x20, #1
    bl      _malloc
    mov     x22, x0                // buffer

    // Read entire file
    mov     x0, x21
    mov     x1, x22
    mov     x2, x20
    bl      _read

    // Null terminate
    strb    wzr, [x22, x20]

    // Close
    mov     x0, x21
    bl      _close

    mov     x0, x22
    mov     x1, x20
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

L_rf_fail:
    add     sp, sp, #256
L_rf_fail2:
    mov     x0, #0
    mov     x1, #0
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// =============================================================================
// _die_err: x0 = fmt, x1 = line_num, x2 = optional detail. Print to stderr, exit(1)
// =============================================================================
_die_err:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x3, x2                 // detail
    mov     x2, x1                 // line
    mov     x1, x0                 // fmt
    adrp    x0, ___stderrp@GOTPAGE
    ldr     x0, [x0, ___stderrp@GOTPAGEOFF]
    ldr     x0, [x0]
    bl      _fprintf_int_str
    mov     x0, #1
    bl      _exit

// =============================================================================
// Token array helpers
// =============================================================================
// _token_add: x0=type, x1=str, d0=num, x2=line
_token_add:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    // Save d0 on stack
    str     d0, [sp, #-16]!

    mov     x19, x0                // type
    mov     x20, x1                // str
    mov     x21, x2                // line

    // Check capacity
    adrp    x8, g_token_count@PAGE
    ldr     x9, [x8, g_token_count@PAGEOFF]
    adrp    x10, g_token_cap@PAGE
    ldr     x11, [x10, g_token_cap@PAGEOFF]
    cmp     x9, x11
    b.lt    L_ta_store

    // Grow
    cbz     x11, L_ta_init
    lsl     x11, x11, #1
    b       L_ta_grow
L_ta_init:
    mov     x11, #256
L_ta_grow:
    str     x11, [x10, g_token_cap@PAGEOFF]
    adrp    x12, g_tokens@PAGE
    ldr     x0, [x12, g_tokens@PAGEOFF]
    mov     x1, #TOKEN_SIZE
    mul     x1, x11, x1
    bl      _realloc
    adrp    x12, g_tokens@PAGE
    str     x0, [x12, g_tokens@PAGEOFF]

L_ta_store:
    adrp    x8, g_tokens@PAGE
    ldr     x9, [x8, g_tokens@PAGEOFF]
    adrp    x10, g_token_count@PAGE
    ldr     x11, [x10, g_token_count@PAGEOFF]
    mov     x12, #TOKEN_SIZE
    mul     x13, x11, x12
    add     x9, x9, x13

    str     x19, [x9, #TOKEN_TYPE]
    str     x20, [x9, #TOKEN_STR]
    ldr     d0, [sp]
    str     d0, [x9, #TOKEN_NUM]
    str     x21, [x9, #TOKEN_LINE]

    add     x11, x11, #1
    str     x11, [x10, g_token_count@PAGEOFF]

    ldr     d0, [sp], #16
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// =============================================================================
// LEXER: x0=source, x1=length
// =============================================================================
_lexer:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    stp     x23, x24, [sp, #-16]!
    stp     x25, x26, [sp, #-16]!
    stp     x27, x28, [sp, #-16]!

    mov     x19, x0                // src ptr
    add     x20, x0, x1            // end ptr
    mov     x21, #1                // line number

    // Store in globals for peek helpers
    adrp    x8, g_src@PAGE
    str     x19, [x8, g_src@PAGEOFF]
    adrp    x8, g_src_end@PAGE
    str     x20, [x8, g_src_end@PAGEOFF]

    // Indent stack on real stack
    sub     sp, sp, #256
    mov     x23, sp                // indent stack base
    str     xzr, [x23]             // stack[0] = 0
    mov     x22, #1                // stack size
    mov     x24, #1                // at_line_start

L_lex_loop:
    cmp     x19, x20
    b.ge    L_lex_end

    ldrb    w25, [x19]

    // At line start? Handle indentation
    cbz     x24, L_lex_char
    mov     x24, #0

    // Count leading spaces
    mov     x26, #0
L_lex_spaces:
    cmp     x19, x20
    b.ge    L_lex_emit_indent
    ldrb    w25, [x19]
    cmp     w25, #' '
    b.ne    L_lex_emit_indent
    add     x26, x26, #1
    add     x19, x19, #1
    b       L_lex_spaces

L_lex_emit_indent:
    // Check blank line or comment
    cmp     x19, x20
    b.ge    L_lex_do_indent
    ldrb    w25, [x19]
    cmp     w25, #'\n'
    b.eq    L_lex_blank
    cmp     w25, #'\r'
    b.eq    L_lex_blank

    // Comment check
    cmp     w25, #'-'
    b.ne    L_lex_do_indent
    add     x8, x19, #1
    cmp     x8, x20
    b.ge    L_lex_do_indent
    ldrb    w9, [x8]
    cmp     w9, #'-'
    b.eq    L_lex_skip_line

L_lex_do_indent:
    // Compare with top of indent stack
    sub     x8, x22, #1
    ldr     x9, [x23, x8, lsl #3]

    cmp     x26, x9
    b.eq    L_lex_indent_done
    b.gt    L_lex_push_indent

    // Dedents
L_lex_dedent:
    sub     x8, x22, #1
    ldr     x9, [x23, x8, lsl #3]
    cmp     x26, x9
    b.ge    L_lex_indent_done

    mov     x0, #TOK_DEDENT
    mov     x1, #0
    movi    d0, #0
    mov     x2, x21
    bl      _token_add
    sub     x22, x22, #1
    b       L_lex_dedent

L_lex_push_indent:
    str     x26, [x23, x22, lsl #3]
    add     x22, x22, #1
    mov     x0, #TOK_INDENT
    mov     x1, #0
    movi    d0, #0
    mov     x2, x21
    bl      _token_add

L_lex_indent_done:
    cmp     x19, x20
    b.ge    L_lex_end
    ldrb    w25, [x19]
    b       L_lex_char

L_lex_blank:
    add     x19, x19, #1
    // Handle \r\n
    cmp     w25, #'\r'
    b.ne    L_lex_blank2
    cmp     x19, x20
    b.ge    L_lex_blank2
    ldrb    w25, [x19]
    cmp     w25, #'\n'
    b.ne    L_lex_blank2
    add     x19, x19, #1
L_lex_blank2:
    add     x21, x21, #1
    mov     x24, #1
    b       L_lex_loop

L_lex_skip_line:
    cmp     x19, x20
    b.ge    L_lex_loop
    ldrb    w25, [x19]
    cmp     w25, #'\n'
    b.eq    L_lex_newline
    cmp     w25, #'\r'
    b.eq    L_lex_newline
    add     x19, x19, #1
    b       L_lex_skip_line

L_lex_char:
    // Skip spaces (not newlines)
    cmp     w25, #' '
    b.eq    L_lex_skipspace
    cmp     w25, #'\t'
    b.eq    L_lex_skipspace

    cmp     w25, #'\n'
    b.eq    L_lex_newline
    cmp     w25, #'\r'
    b.eq    L_lex_newline

    // Comment
    cmp     w25, #'-'
    b.ne    L_lex_not_comment
    add     x8, x19, #1
    cmp     x8, x20
    b.ge    L_lex_not_comment
    ldrb    w9, [x8]
    cmp     w9, #'-'
    b.eq    L_lex_skip_line
L_lex_not_comment:

    cmp     w25, #'"'
    b.eq    L_lex_string
    cmp     w25, #'('
    b.eq    L_lex_single_lparen
    cmp     w25, #')'
    b.eq    L_lex_single_rparen
    cmp     w25, #'['
    b.eq    L_lex_single_lbracket
    cmp     w25, #']'
    b.eq    L_lex_single_rbracket
    cmp     w25, #','
    b.eq    L_lex_single_comma
    cmp     w25, #':'
    b.eq    L_lex_single_colon

    // Digit
    cmp     w25, #'0'
    b.lt    L_lex_not_digit
    cmp     w25, #'9'
    b.le    L_lex_number
L_lex_not_digit:

    // Letter -> identifier/keyword
    cmp     w25, #'a'
    b.ge    L_lex_check_az
    b       L_lex_skip_unknown
L_lex_check_az:
    cmp     w25, #'z'
    b.le    L_lex_ident
    cmp     w25, #'A'
    b.lt    L_lex_skip_unknown
    cmp     w25, #'Z'
    b.le    L_lex_ident

L_lex_skip_unknown:
    add     x19, x19, #1
    b       L_lex_loop

L_lex_skipspace:
    add     x19, x19, #1
    cmp     x19, x20
    b.ge    L_lex_loop
    ldrb    w25, [x19]
    b       L_lex_char

L_lex_newline:
    mov     x0, #TOK_NEWLINE
    mov     x1, #0
    movi    d0, #0
    mov     x2, x21
    bl      _token_add
    add     x19, x19, #1
    cmp     w25, #'\r'
    b.ne    L_lex_nl_done
    cmp     x19, x20
    b.ge    L_lex_nl_done
    ldrb    w9, [x19]
    cmp     w9, #'\n'
    b.ne    L_lex_nl_done
    add     x19, x19, #1
L_lex_nl_done:
    add     x21, x21, #1
    mov     x24, #1
    b       L_lex_loop

// --- Single-char tokens ---
L_lex_single_lparen:
    mov     x0, #TOK_LPAREN
    b       L_lex_emit_single
L_lex_single_rparen:
    mov     x0, #TOK_RPAREN
    b       L_lex_emit_single
L_lex_single_lbracket:
    mov     x0, #TOK_LBRACKET
    b       L_lex_emit_single
L_lex_single_rbracket:
    mov     x0, #TOK_RBRACKET
    b       L_lex_emit_single
L_lex_single_comma:
    mov     x0, #TOK_COMMA
    b       L_lex_emit_single
L_lex_single_colon:
    mov     x0, #TOK_COLON
    b       L_lex_emit_single

L_lex_emit_single:
    mov     x1, #0
    movi    d0, #0
    mov     x2, x21
    bl      _token_add
    add     x19, x19, #1
    b       L_lex_loop

// --- String literal ---
L_lex_string:
    add     x19, x19, #1          // skip opening "
    mov     x0, #256
    bl      _malloc
    mov     x26, x0               // buffer
    mov     x27, #0               // length
    mov     x28, #256             // capacity

L_lex_str_loop:
    cmp     x19, x20
    b.ge    L_lex_str_done
    ldrb    w25, [x19]
    cmp     w25, #'"'
    b.eq    L_lex_str_done
    cmp     w25, #'\\'
    b.eq    L_lex_str_esc
    strb    w25, [x26, x27]
    add     x27, x27, #1
    add     x19, x19, #1
    cmp     x27, x28
    b.lt    L_lex_str_loop
    // Grow
    lsl     x28, x28, #1
    mov     x0, x26
    mov     x1, x28
    bl      _realloc
    mov     x26, x0
    b       L_lex_str_loop

L_lex_str_esc:
    add     x19, x19, #1
    cmp     x19, x20
    b.ge    L_lex_str_done
    ldrb    w25, [x19]
    cmp     w25, #'n'
    b.eq    L_lex_str_esc_n
    cmp     w25, #'t'
    b.eq    L_lex_str_esc_t
    cmp     w25, #'\\'
    b.eq    L_lex_str_esc_bs
    cmp     w25, #'"'
    b.eq    L_lex_str_esc_dq
    // Unknown escape - store as-is
    strb    w25, [x26, x27]
    add     x27, x27, #1
    add     x19, x19, #1
    b       L_lex_str_loop

L_lex_str_esc_n:
    mov     w25, #10
    b       L_lex_str_esc_store
L_lex_str_esc_t:
    mov     w25, #9
    b       L_lex_str_esc_store
L_lex_str_esc_bs:
    mov     w25, #'\\'
    b       L_lex_str_esc_store
L_lex_str_esc_dq:
    mov     w25, #'"'
L_lex_str_esc_store:
    strb    w25, [x26, x27]
    add     x27, x27, #1
    add     x19, x19, #1
    b       L_lex_str_loop

L_lex_str_done:
    strb    wzr, [x26, x27]
    cmp     x19, x20
    b.ge    L_lex_str_emit
    ldrb    w25, [x19]
    cmp     w25, #'"'
    b.ne    L_lex_str_emit
    add     x19, x19, #1
L_lex_str_emit:
    mov     x0, #TOK_STRING
    mov     x1, x26
    movi    d0, #0
    mov     x2, x21
    bl      _token_add
    b       L_lex_loop

// --- Number literal ---
L_lex_number:
    mov     x26, x19
L_lex_num_digits:
    add     x19, x19, #1
    cmp     x19, x20
    b.ge    L_lex_num_done
    ldrb    w25, [x19]
    cmp     w25, #'0'
    b.lt    L_lex_num_dot
    cmp     w25, #'9'
    b.le    L_lex_num_digits
L_lex_num_dot:
    cmp     w25, #'.'
    b.ne    L_lex_num_done
    add     x8, x19, #1
    cmp     x8, x20
    b.ge    L_lex_num_done
    ldrb    w9, [x8]
    cmp     w9, #'0'
    b.lt    L_lex_num_done
    cmp     w9, #'9'
    b.gt    L_lex_num_done
    add     x19, x19, #1
L_lex_num_frac:
    add     x19, x19, #1
    cmp     x19, x20
    b.ge    L_lex_num_done
    ldrb    w25, [x19]
    cmp     w25, #'0'
    b.lt    L_lex_num_done
    cmp     w25, #'9'
    b.le    L_lex_num_frac

L_lex_num_done:
    // Copy number string to temp buffer and convert
    sub     x27, x19, x26
    // Allocate temp
    add     x0, x27, #1
    bl      _malloc
    mov     x28, x0
    mov     x9, #0
L_lex_num_copy:
    cmp     x9, x27
    b.ge    L_lex_num_cvt
    ldrb    w10, [x26, x9]
    strb    w10, [x28, x9]
    add     x9, x9, #1
    b       L_lex_num_copy
L_lex_num_cvt:
    strb    wzr, [x28, x27]
    mov     x0, x28
    bl      _atof
    // d0 has the value
    mov     x0, #TOK_NUMBER
    mov     x1, #0
    mov     x2, x21
    bl      _token_add
    // Free temp
    mov     x0, x28
    bl      _free
    b       L_lex_loop

// --- Identifier/keyword ---
L_lex_ident:
    mov     x26, x19
L_lex_ident_scan:
    add     x19, x19, #1
    cmp     x19, x20
    b.ge    L_lex_ident_done
    ldrb    w25, [x19]
    cmp     w25, #'_'
    b.eq    L_lex_ident_scan
    cmp     w25, #'a'
    b.lt    L_lex_ident_check2
    cmp     w25, #'z'
    b.le    L_lex_ident_scan
L_lex_ident_check2:
    cmp     w25, #'A'
    b.lt    L_lex_ident_check3
    cmp     w25, #'Z'
    b.le    L_lex_ident_scan
L_lex_ident_check3:
    cmp     w25, #'0'
    b.lt    L_lex_ident_done
    cmp     w25, #'9'
    b.le    L_lex_ident_scan

L_lex_ident_done:
    // Copy word
    sub     x27, x19, x26
    add     x0, x27, #1
    bl      _malloc
    mov     x28, x0
    mov     x9, #0
L_lex_id_copy:
    cmp     x9, x27
    b.ge    L_lex_id_copied
    ldrb    w10, [x26, x9]
    strb    w10, [x28, x9]
    add     x9, x9, #1
    b       L_lex_id_copy
L_lex_id_copied:
    strb    wzr, [x28, x27]

    // --- Classify the word (multi-word keywords first) ---
    // Check multi-word keywords by calling classify_ident
    mov     x0, x28                // word string
    // x19 = current source position
    // x20 = source end
    bl      _classify_ident
    // Returns x0 = token type, x1 = new source position (if advanced)
    mov     x19, x1               // update source position
    mov     x9, x0                // token type

    mov     x0, x9
    mov     x1, x28
    movi    d0, #0
    mov     x2, x21
    bl      _token_add
    b       L_lex_loop

// --- End of file ---
L_lex_end:
    // Emit remaining DEDENTs
L_lex_end_dedent:
    cmp     x22, #1
    b.le    L_lex_end_eof
    mov     x0, #TOK_DEDENT
    mov     x1, #0
    movi    d0, #0
    mov     x2, x21
    bl      _token_add
    sub     x22, x22, #1
    b       L_lex_end_dedent

L_lex_end_eof:
    mov     x0, #TOK_EOF
    mov     x1, #0
    movi    d0, #0
    mov     x2, x21
    bl      _token_add

    add     sp, sp, #256           // free indent stack

    ldp     x27, x28, [sp], #16
    ldp     x25, x26, [sp], #16
    ldp     x23, x24, [sp], #16
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// =============================================================================
// _classify_ident: classify a word, possibly consuming extra words from source
// x0 = word (char*), x19 = cur src pos, x20 = src end (from lexer regs)
// Returns x0 = token type, x1 = updated src pos
// =============================================================================
_classify_ident:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!

    mov     x21, x0                // word
    mov     x22, x19               // current source pos (will be updated)
    // x20 already has src end from caller

    // --- Multi-word: "otherwise" -> check "if" ---
    adrp    x1, kw_otherwise@PAGE
    add     x1, x1, kw_otherwise@PAGEOFF
    bl      _strcmp
    cbnz    x0, L_ci_not_otherwise
    mov     x0, x22
    adrp    x1, kw_if@PAGE
    add     x1, x1, kw_if@PAGEOFF
    mov     x2, #2
    bl      _peek_word_lex
    cbz     x0, L_ci_otherwise_plain
    mov     x22, x0
    mov     x0, #TOK_OTHERWISE_IF
    b       L_ci_done
L_ci_otherwise_plain:
    mov     x0, #TOK_OTHERWISE
    b       L_ci_done

L_ci_not_otherwise:
    // "for" -> "each"?
    mov     x0, x21
    adrp    x1, kw_for@PAGE
    add     x1, x1, kw_for@PAGEOFF
    bl      _strcmp
    cbnz    x0, L_ci_not_for
    mov     x0, x22
    adrp    x1, kw_each@PAGE
    add     x1, x1, kw_each@PAGEOFF
    mov     x2, #4
    bl      _peek_word_lex
    cbz     x0, L_ci_for_plain
    mov     x22, x0
    mov     x0, #TOK_FOR_EACH
    b       L_ci_done
L_ci_for_plain:
    mov     x0, #TOK_FOR
    b       L_ci_done

L_ci_not_for:
    // "divided" -> "by"
    mov     x0, x21
    adrp    x1, kw_divided@PAGE
    add     x1, x1, kw_divided@PAGEOFF
    bl      _strcmp
    cbnz    x0, L_ci_not_divided
    mov     x0, x22
    adrp    x1, kw_by@PAGE
    add     x1, x1, kw_by@PAGEOFF
    mov     x2, #2
    bl      _peek_word_lex
    cbz     x0, L_ci_ident_result
    mov     x22, x0
    mov     x0, #TOK_DIVIDED_BY
    b       L_ci_done

L_ci_not_divided:
    // "joined" -> "with"
    mov     x0, x21
    adrp    x1, kw_joined@PAGE
    add     x1, x1, kw_joined@PAGEOFF
    bl      _strcmp
    cbnz    x0, L_ci_not_joined
    mov     x0, x22
    adrp    x1, kw_with@PAGE
    add     x1, x1, kw_with@PAGEOFF
    mov     x2, #4
    bl      _peek_word_lex
    cbz     x0, L_ci_ident_result
    mov     x22, x0
    mov     x0, #TOK_JOINED_WITH
    b       L_ci_done

L_ci_not_joined:
    // "is" -> multi-word comparisons
    mov     x0, x21
    adrp    x1, kw_is@PAGE
    add     x1, x1, kw_is@PAGEOFF
    bl      _strcmp
    cbnz    x0, L_ci_not_is
    // Try: "not equal to", "equal to", "greater than", "less than", "at least", "at most"
    mov     x0, x22
    bl      _lex_classify_is
    // Returns x0 = token type (or TOK_IDENT), x1 = new position
    mov     x22, x1
    b       L_ci_done

L_ci_not_is:
    // "uppercase" -> "of"
    mov     x0, x21
    adrp    x1, kw_uppercase@PAGE
    add     x1, x1, kw_uppercase@PAGEOFF
    bl      _strcmp
    cbnz    x0, L_ci_not_uppercase
    mov     x0, x22
    adrp    x1, kw_of@PAGE
    add     x1, x1, kw_of@PAGEOFF
    mov     x2, #2
    bl      _peek_word_lex
    cbz     x0, L_ci_ident_result
    mov     x22, x0
    mov     x0, #TOK_UPPERCASE_OF
    b       L_ci_done

L_ci_not_uppercase:
    // "lowercase" -> "of"
    mov     x0, x21
    adrp    x1, kw_lowercase@PAGE
    add     x1, x1, kw_lowercase@PAGEOFF
    bl      _strcmp
    cbnz    x0, L_ci_not_lowercase
    mov     x0, x22
    adrp    x1, kw_of@PAGE
    add     x1, x1, kw_of@PAGEOFF
    mov     x2, #2
    bl      _peek_word_lex
    cbz     x0, L_ci_ident_result
    mov     x22, x0
    mov     x0, #TOK_LOWERCASE_OF
    b       L_ci_done

L_ci_not_lowercase:
    // "length" -> "of"
    mov     x0, x21
    adrp    x1, kw_length@PAGE
    add     x1, x1, kw_length@PAGEOFF
    bl      _strcmp
    cbnz    x0, L_ci_not_length
    mov     x0, x22
    adrp    x1, kw_of@PAGE
    add     x1, x1, kw_of@PAGEOFF
    mov     x2, #2
    bl      _peek_word_lex
    cbz     x0, L_ci_ident_result
    mov     x22, x0
    mov     x0, #TOK_LENGTH_OF
    b       L_ci_done

L_ci_not_length:
    // "first" -> "of"
    mov     x0, x21
    adrp    x1, kw_first@PAGE
    add     x1, x1, kw_first@PAGEOFF
    bl      _strcmp
    cbnz    x0, L_ci_not_first
    mov     x0, x22
    adrp    x1, kw_of@PAGE
    add     x1, x1, kw_of@PAGEOFF
    mov     x2, #2
    bl      _peek_word_lex
    cbz     x0, L_ci_ident_result
    mov     x22, x0
    mov     x0, #TOK_FIRST_OF
    b       L_ci_done

L_ci_not_first:
    // "last" -> "of"
    mov     x0, x21
    adrp    x1, kw_last@PAGE
    add     x1, x1, kw_last@PAGEOFF
    bl      _strcmp
    cbnz    x0, L_ci_not_last
    mov     x0, x22
    adrp    x1, kw_of@PAGE
    add     x1, x1, kw_of@PAGEOFF
    mov     x2, #2
    bl      _peek_word_lex
    cbz     x0, L_ci_ident_result
    mov     x22, x0
    mov     x0, #TOK_LAST_OF
    b       L_ci_done

L_ci_not_last:
    // "slice" -> "of"
    mov     x0, x21
    adrp    x1, kw_slice@PAGE
    add     x1, x1, kw_slice@PAGEOFF
    bl      _strcmp
    cbnz    x0, L_ci_not_slice
    mov     x0, x22
    adrp    x1, kw_of@PAGE
    add     x1, x1, kw_of@PAGEOFF
    mov     x2, #2
    bl      _peek_word_lex
    cbz     x0, L_ci_ident_result
    mov     x22, x0
    mov     x0, #TOK_SLICE_OF
    b       L_ci_done

L_ci_not_slice:
    // --- Single-word keywords ---
    mov     x0, x21
    bl      _classify_single_kw
    b       L_ci_done

L_ci_ident_result:
    mov     x0, #TOK_IDENT

L_ci_done:
    mov     x1, x22               // updated source position
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// =============================================================================
// _peek_word_lex: Check if next word matches expected
// x0 = current pos, x1 = expected word, x2 = expected len
// x20 = src end (from lexer env)
// Returns x0 = position after word if match, 0 if not
// =============================================================================
_peek_word_lex:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!

    mov     x19, x0               // pos
    // x20 = src end (already set by caller chain)
    mov     x8, x1                // expected
    mov     x9, x2                // expected len

    // Skip spaces
L_pwl_skip:
    cmp     x19, x20
    b.ge    L_pwl_fail
    ldrb    w10, [x19]
    cmp     w10, #' '
    b.ne    L_pwl_cmp
    add     x19, x19, #1
    b       L_pwl_skip

L_pwl_cmp:
    mov     x10, #0
L_pwl_loop:
    cmp     x10, x9
    b.ge    L_pwl_check_end
    add     x11, x19, x10
    cmp     x11, x20
    b.ge    L_pwl_fail
    ldrb    w12, [x11]
    ldrb    w13, [x8, x10]
    cmp     w12, w13
    b.ne    L_pwl_fail
    add     x10, x10, #1
    b       L_pwl_loop

L_pwl_check_end:
    add     x11, x19, x9
    cmp     x11, x20
    b.ge    L_pwl_match
    ldrb    w12, [x11]
    // Not alphanumeric/underscore?
    cmp     w12, #'a'
    b.lt    L_pwl_ce2
    cmp     w12, #'z'
    b.le    L_pwl_fail
L_pwl_ce2:
    cmp     w12, #'A'
    b.lt    L_pwl_ce3
    cmp     w12, #'Z'
    b.le    L_pwl_fail
L_pwl_ce3:
    cmp     w12, #'0'
    b.lt    L_pwl_match
    cmp     w12, #'9'
    b.le    L_pwl_fail
    cmp     w12, #'_'
    b.eq    L_pwl_fail

L_pwl_match:
    add     x0, x19, x9
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

L_pwl_fail:
    mov     x0, #0
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// =============================================================================
// _lex_classify_is: handle "is ..." multi-word comparisons
// x0 = source position after "is", x20 = src end
// Returns x0 = token type, x1 = new source position
// =============================================================================
_lex_classify_is:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!

    mov     x19, x0               // pos after "is"
    // x20 = src end from caller

    // Read next word
    mov     x0, x19
    bl      _read_next_word_lex    // x0 = word, x1 = pos after word
    cbz     x0, L_lcis_ident
    mov     x21, x0               // next word
    mov     x22, x1               // pos after it

    // Check "not" -> "equal" -> "to"
    adrp    x1, kw_not@PAGE
    add     x1, x1, kw_not@PAGEOFF
    bl      _strcmp
    cbnz    x0, L_lcis_not_not

    // "is not" -> need "equal"
    mov     x0, x22
    adrp    x1, kw_equal@PAGE
    add     x1, x1, kw_equal@PAGEOFF
    mov     x2, #5
    bl      _peek_word_lex
    cbz     x0, L_lcis_ident_free
    mov     x22, x0
    // need "to"
    mov     x0, x22
    adrp    x1, kw_to@PAGE
    add     x1, x1, kw_to@PAGEOFF
    mov     x2, #2
    bl      _peek_word_lex
    cbz     x0, L_lcis_ident_free
    mov     x22, x0
    mov     x0, x21
    bl      _free
    mov     x0, #TOK_IS_NOT_EQUAL_TO
    mov     x1, x22
    b       L_lcis_done

L_lcis_not_not:
    // "equal" -> "to"
    mov     x0, x21
    adrp    x1, kw_equal@PAGE
    add     x1, x1, kw_equal@PAGEOFF
    bl      _strcmp
    cbnz    x0, L_lcis_not_equal

    mov     x0, x22
    adrp    x1, kw_to@PAGE
    add     x1, x1, kw_to@PAGEOFF
    mov     x2, #2
    bl      _peek_word_lex
    cbz     x0, L_lcis_ident_free
    mov     x22, x0
    mov     x0, x21
    bl      _free
    mov     x0, #TOK_IS_EQUAL_TO
    mov     x1, x22
    b       L_lcis_done

L_lcis_not_equal:
    // "greater" -> "than"
    mov     x0, x21
    adrp    x1, kw_greater@PAGE
    add     x1, x1, kw_greater@PAGEOFF
    bl      _strcmp
    cbnz    x0, L_lcis_not_greater

    mov     x0, x22
    adrp    x1, kw_than@PAGE
    add     x1, x1, kw_than@PAGEOFF
    mov     x2, #4
    bl      _peek_word_lex
    cbz     x0, L_lcis_ident_free
    mov     x22, x0
    mov     x0, x21
    bl      _free
    mov     x0, #TOK_IS_GREATER_THAN
    mov     x1, x22
    b       L_lcis_done

L_lcis_not_greater:
    // "less" -> "than"
    mov     x0, x21
    adrp    x1, kw_less@PAGE
    add     x1, x1, kw_less@PAGEOFF
    bl      _strcmp
    cbnz    x0, L_lcis_not_less

    mov     x0, x22
    adrp    x1, kw_than@PAGE
    add     x1, x1, kw_than@PAGEOFF
    mov     x2, #4
    bl      _peek_word_lex
    cbz     x0, L_lcis_ident_free
    mov     x22, x0
    mov     x0, x21
    bl      _free
    mov     x0, #TOK_IS_LESS_THAN
    mov     x1, x22
    b       L_lcis_done

L_lcis_not_less:
    // "at" -> "least" or "most"
    mov     x0, x21
    adrp    x1, kw_at@PAGE
    add     x1, x1, kw_at@PAGEOFF
    bl      _strcmp
    cbnz    x0, L_lcis_ident_free

    // Try "least"
    mov     x0, x22
    adrp    x1, kw_least@PAGE
    add     x1, x1, kw_least@PAGEOFF
    mov     x2, #5
    bl      _peek_word_lex
    cbz     x0, L_lcis_at_most
    mov     x22, x0
    mov     x0, x21
    bl      _free
    mov     x0, #TOK_IS_AT_LEAST
    mov     x1, x22
    b       L_lcis_done

L_lcis_at_most:
    mov     x0, x22
    adrp    x1, kw_most@PAGE
    add     x1, x1, kw_most@PAGEOFF
    mov     x2, #4
    bl      _peek_word_lex
    cbz     x0, L_lcis_ident_free
    mov     x22, x0
    mov     x0, x21
    bl      _free
    mov     x0, #TOK_IS_AT_MOST
    mov     x1, x22
    b       L_lcis_done

L_lcis_ident_free:
    mov     x0, x21
    bl      _free
L_lcis_ident:
    mov     x0, #TOK_IDENT
    mov     x1, x19
    b       L_lcis_done

L_lcis_done:
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// =============================================================================
// _read_next_word_lex: read next word from source (skip spaces)
// x0 = position, x20 = end
// Returns x0 = malloc'd word (or 0), x1 = position after word
// =============================================================================
_read_next_word_lex:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!

    mov     x19, x0

    // Skip spaces
L_rnwl_skip:
    cmp     x19, x20
    b.ge    L_rnwl_fail
    ldrb    w9, [x19]
    cmp     w9, #' '
    b.ne    L_rnwl_start
    add     x19, x19, #1
    b       L_rnwl_skip

L_rnwl_start:
    // Must start with letter
    cmp     w9, #'a'
    b.lt    L_rnwl_upper
    cmp     w9, #'z'
    b.le    L_rnwl_scan
L_rnwl_upper:
    cmp     w9, #'A'
    b.lt    L_rnwl_fail
    cmp     w9, #'Z'
    b.gt    L_rnwl_fail

L_rnwl_scan:
    mov     x8, x19               // word start
L_rnwl_scan_loop:
    add     x19, x19, #1
    cmp     x19, x20
    b.ge    L_rnwl_copy
    ldrb    w9, [x19]
    cmp     w9, #'_'
    b.eq    L_rnwl_scan_loop
    cmp     w9, #'a'
    b.lt    L_rnwl_sc2
    cmp     w9, #'z'
    b.le    L_rnwl_scan_loop
L_rnwl_sc2:
    cmp     w9, #'A'
    b.lt    L_rnwl_sc3
    cmp     w9, #'Z'
    b.le    L_rnwl_scan_loop
L_rnwl_sc3:
    cmp     w9, #'0'
    b.lt    L_rnwl_copy
    cmp     w9, #'9'
    b.le    L_rnwl_scan_loop

L_rnwl_copy:
    sub     x9, x19, x8           // word length
    add     x0, x9, #1
    // Save x8, x9
    stp     x8, x9, [sp, #-16]!
    bl      _malloc
    ldp     x8, x9, [sp], #16
    mov     x10, #0
L_rnwl_cc:
    cmp     x10, x9
    b.ge    L_rnwl_done
    ldrb    w11, [x8, x10]
    strb    w11, [x0, x10]
    add     x10, x10, #1
    b       L_rnwl_cc
L_rnwl_done:
    strb    wzr, [x0, x9]
    mov     x1, x19
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

L_rnwl_fail:
    mov     x0, #0
    mov     x1, x19
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// =============================================================================
// _classify_single_kw: check single-word keywords
// x0 = word -> returns x0 = token type
// =============================================================================
_classify_single_kw:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    str     x19, [sp, #-16]!

    mov     x19, x0

    // Macro-like pattern: try each keyword
.macro try_kw label, kwsym, tokval
    mov     x0, x19
    adrp    x1, \kwsym\()@PAGE
    add     x1, x1, \kwsym\()@PAGEOFF
    bl      _strcmp
    cbz     x0, \label
.endm

    try_kw L_sk_print,    kw_print,    TOK_PRINT
    try_kw L_sk_set,      kw_set,      TOK_SET
    try_kw L_sk_to,       kw_to,       TOK_TO
    try_kw L_sk_if,       kw_if,       TOK_IF
    try_kw L_sk_while,    kw_while,    TOK_WHILE
    try_kw L_sk_repeat,   kw_repeat,   TOK_REPEAT
    try_kw L_sk_times,    kw_times,    TOK_TIMES
    try_kw L_sk_define,   kw_define,   TOK_DEFINE
    try_kw L_sk_with,     kw_with,     TOK_WITH
    try_kw L_sk_call,     kw_call,     TOK_CALL
    try_kw L_sk_return,   kw_return,   TOK_RETURN
    try_kw L_sk_and,      kw_and,      TOK_AND
    try_kw L_sk_or,       kw_or,       TOK_OR
    try_kw L_sk_not,      kw_not,      TOK_NOT
    try_kw L_sk_plus,     kw_plus,     TOK_PLUS
    try_kw L_sk_minus,    kw_minus,    TOK_MINUS
    try_kw L_sk_modulo,   kw_modulo,   TOK_MODULO
    try_kw L_sk_contains, kw_contains, TOK_CONTAINS
    // "item" is NOT a keyword - handled as identifier to avoid conflict with var names
    // try_kw L_sk_item,     kw_item,     TOK_ITEM
    try_kw L_sk_of,       kw_of,       TOK_OF
    try_kw L_sk_as,       kw_as,       TOK_AS
    try_kw L_sk_append,   kw_append,   TOK_APPEND
    try_kw L_sk_stop,     kw_stop,     TOK_STOP
    try_kw L_sk_skip,     kw_skip,     TOK_SKIP
    try_kw L_sk_negative, kw_negative, TOK_NEGATIVE
    try_kw L_sk_true,     kw_true,     TOK_TRUE
    try_kw L_sk_false,    kw_false,    TOK_FALSE
    try_kw L_sk_nothing,  kw_nothing,  TOK_NOTHING
    try_kw L_sk_from,     kw_from,     TOK_FROM
    try_kw L_sk_in,       kw_in,       TOK_IN
    try_kw L_sk_number,   kw_number,   TOK_NUMBER_KW
    try_kw L_sk_string,   kw_string,   TOK_STRING_KW
    try_kw L_sk_boolean,  kw_boolean,  TOK_BOOLEAN_KW

    // Not a keyword
    mov     x0, #TOK_IDENT
    b       L_sk_done

.macro emit_kw_result tokval
    mov     x0, #\tokval
    b       L_sk_done
.endm

L_sk_print:    emit_kw_result TOK_PRINT
L_sk_set:      emit_kw_result TOK_SET
L_sk_to:       emit_kw_result TOK_TO
L_sk_if:       emit_kw_result TOK_IF
L_sk_while:    emit_kw_result TOK_WHILE
L_sk_repeat:   emit_kw_result TOK_REPEAT
L_sk_times:    emit_kw_result TOK_TIMES
L_sk_define:   emit_kw_result TOK_DEFINE
L_sk_with:     emit_kw_result TOK_WITH
L_sk_call:     emit_kw_result TOK_CALL
L_sk_return:   emit_kw_result TOK_RETURN
L_sk_and:      emit_kw_result TOK_AND
L_sk_or:       emit_kw_result TOK_OR
L_sk_not:      emit_kw_result TOK_NOT
L_sk_plus:     emit_kw_result TOK_PLUS
L_sk_minus:    emit_kw_result TOK_MINUS
L_sk_modulo:   emit_kw_result TOK_MODULO
L_sk_contains: emit_kw_result TOK_CONTAINS
L_sk_item:     emit_kw_result TOK_ITEM
L_sk_of:       emit_kw_result TOK_OF
L_sk_as:       emit_kw_result TOK_AS
L_sk_append:   emit_kw_result TOK_APPEND
L_sk_stop:     emit_kw_result TOK_STOP
L_sk_skip:     emit_kw_result TOK_SKIP
L_sk_negative: emit_kw_result TOK_NEGATIVE
L_sk_true:     emit_kw_result TOK_TRUE
L_sk_false:    emit_kw_result TOK_FALSE
L_sk_nothing:  emit_kw_result TOK_NOTHING
L_sk_from:     emit_kw_result TOK_FROM
L_sk_in:       emit_kw_result TOK_IN
L_sk_number:   emit_kw_result TOK_NUMBER_KW
L_sk_string:   emit_kw_result TOK_STRING_KW
L_sk_boolean:  emit_kw_result TOK_BOOLEAN_KW

L_sk_done:
    ldr     x19, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// =============================================================================
// PARSER
// =============================================================================

// Token access helpers
_cur_tok:
    adrp    x8, g_token_pos@PAGE
    ldr     x9, [x8, g_token_pos@PAGEOFF]
    adrp    x10, g_tokens@PAGE
    ldr     x10, [x10, g_tokens@PAGEOFF]
    adrp    x11, g_token_count@PAGE
    ldr     x11, [x11, g_token_count@PAGEOFF]
    cmp     x9, x11
    b.ge    L_ct_eof
    mov     x12, #TOKEN_SIZE
    madd    x10, x9, x12, x10
    ldr     x0, [x10, #TOKEN_TYPE]
    ret
L_ct_eof:
    mov     x0, #TOK_EOF
    ret

_cur_tok_ptr:
    adrp    x8, g_token_pos@PAGE
    ldr     x9, [x8, g_token_pos@PAGEOFF]
    adrp    x10, g_tokens@PAGE
    ldr     x10, [x10, g_tokens@PAGEOFF]
    mov     x12, #TOKEN_SIZE
    madd    x0, x9, x12, x10
    ret

_cur_line:
    adrp    x8, g_token_pos@PAGE
    ldr     x9, [x8, g_token_pos@PAGEOFF]
    adrp    x10, g_tokens@PAGE
    ldr     x10, [x10, g_tokens@PAGEOFF]
    adrp    x11, g_token_count@PAGE
    ldr     x11, [x11, g_token_count@PAGEOFF]
    cmp     x9, x11
    b.ge    L_cl_def
    mov     x12, #TOKEN_SIZE
    madd    x10, x9, x12, x10
    ldr     x0, [x10, #TOKEN_LINE]
    ret
L_cl_def:
    mov     x0, #1
    ret

_advance:
    adrp    x8, g_token_pos@PAGE
    ldr     x9, [x8, g_token_pos@PAGEOFF]
    add     x9, x9, #1
    str     x9, [x8, g_token_pos@PAGEOFF]
    ret

_expect:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    str     x19, [sp, #-16]!
    mov     x19, x0
    bl      _cur_tok
    cmp     x0, x19
    b.ne    L_expect_fail
    bl      _advance
    ldr     x19, [sp], #16
    ldp     x29, x30, [sp], #16
    ret
L_expect_fail:
    bl      _cur_line
    adrp    x1, err_parse_s@PAGE
    add     x1, x1, err_parse_s@PAGEOFF
    mov     x2, x0
    adrp    x0, ___stderrp@GOTPAGE
    ldr     x0, [x0, ___stderrp@GOTPAGEOFF]
    ldr     x0, [x0]
    bl      _fprintf_int
    mov     x0, #1
    bl      _exit

_skip_newlines:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
L_sn_loop:
    bl      _cur_tok
    cmp     x0, #TOK_NEWLINE
    b.ne    L_sn_done
    bl      _advance
    b       L_sn_loop
L_sn_done:
    ldp     x29, x30, [sp], #16
    ret

// =============================================================================
// _ast_new: allocate AST node. x0 = type. Returns x0 = node ptr.
// =============================================================================
_ast_new:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    mov     x19, x0
    mov     x0, #AST_SIZE
    bl      _malloc
    mov     x20, x0
    stp     xzr, xzr, [x20]
    stp     xzr, xzr, [x20, #16]
    stp     xzr, xzr, [x20, #32]
    str     xzr, [x20, #48]
    str     x19, [x20, #AST_TYPE]
    // Get line
    bl      _cur_line
    str     x0, [x20, #AST_LINE]
    mov     x0, x20
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// =============================================================================
// _parser: returns x0 = program node
// =============================================================================
_parser:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!

    adrp    x8, g_token_pos@PAGE
    str     xzr, [x8, g_token_pos@PAGEOFF]

    // stmts array
    mov     x0, #512
    bl      _malloc
    mov     x20, x0
    mov     x21, #0                // count
    mov     x22, #64               // cap

    bl      _skip_newlines

L_parse_stmts:
    bl      _cur_tok
    cmp     x0, #TOK_EOF
    b.eq    L_parse_done

    bl      _parse_statement
    cbz     x0, L_parse_skip
    // Store
    cmp     x21, x22
    b.lt    L_parse_store
    lsl     x22, x22, #1
    mov     x0, x20
    lsl     x1, x22, #3
    bl      _realloc
    mov     x20, x0
L_parse_store:
    str     x0, [x20, x21, lsl #3]
    add     x21, x21, #1
L_parse_skip:
    bl      _skip_newlines
    b       L_parse_stmts

L_parse_done:
    mov     x0, #NODE_PROGRAM
    bl      _ast_new
    mov     x19, x0
    str     x20, [x19, #AST_F1]
    str     x21, [x19, #AST_F2]
    mov     x0, x19

    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// =============================================================================
// _parse_statement
// =============================================================================
_parse_statement:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    bl      _skip_newlines
    bl      _cur_tok

    cmp     x0, #TOK_PRINT
    b.eq    L_ps_print
    cmp     x0, #TOK_SET
    b.eq    L_ps_set
    cmp     x0, #TOK_IF
    b.eq    L_ps_if
    cmp     x0, #TOK_WHILE
    b.eq    L_ps_while
    cmp     x0, #TOK_FOR_EACH
    b.eq    L_ps_for_each
    cmp     x0, #TOK_FOR
    b.eq    L_ps_for_from
    cmp     x0, #TOK_REPEAT
    b.eq    L_ps_repeat
    cmp     x0, #TOK_DEFINE
    b.eq    L_ps_define
    cmp     x0, #TOK_RETURN
    b.eq    L_ps_return
    cmp     x0, #TOK_APPEND
    b.eq    L_ps_append
    cmp     x0, #TOK_STOP
    b.eq    L_ps_stop
    cmp     x0, #TOK_SKIP
    b.eq    L_ps_skip
    cmp     x0, #TOK_CALL
    b.eq    L_ps_call

    // Unknown -> skip
    bl      _advance
    mov     x0, #0
    ldp     x29, x30, [sp], #16
    ret

L_ps_print:
    bl      _parse_print
    ldp     x29, x30, [sp], #16
    ret
L_ps_set:
    bl      _parse_set
    ldp     x29, x30, [sp], #16
    ret
L_ps_if:
    bl      _parse_if
    ldp     x29, x30, [sp], #16
    ret
L_ps_while:
    bl      _parse_while
    ldp     x29, x30, [sp], #16
    ret
L_ps_for_each:
    bl      _parse_for_each
    ldp     x29, x30, [sp], #16
    ret
L_ps_for_from:
    bl      _parse_for_from
    ldp     x29, x30, [sp], #16
    ret
L_ps_repeat:
    bl      _parse_repeat
    ldp     x29, x30, [sp], #16
    ret
L_ps_define:
    bl      _parse_define
    ldp     x29, x30, [sp], #16
    ret
L_ps_return:
    bl      _parse_return
    ldp     x29, x30, [sp], #16
    ret
L_ps_append:
    bl      _parse_append
    ldp     x29, x30, [sp], #16
    ret
L_ps_stop:
    bl      _advance
    mov     x0, #NODE_STOP
    bl      _ast_new
    ldp     x29, x30, [sp], #16
    ret
L_ps_skip:
    bl      _advance
    mov     x0, #NODE_SKIP
    bl      _ast_new
    ldp     x29, x30, [sp], #16
    ret
L_ps_call:
    bl      _parse_call_expr
    ldp     x29, x30, [sp], #16
    ret

// --- Individual statement parsers ---

_parse_print:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    str     x19, [sp, #-16]!
    bl      _advance
    bl      _parse_expr
    mov     x19, x0
    mov     x0, #NODE_PRINT
    bl      _ast_new
    str     x19, [x0, #AST_F1]
    ldr     x19, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

_parse_set:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    bl      _advance               // skip "set"
    bl      _cur_tok_ptr
    ldr     x19, [x0, #TOKEN_STR]
    bl      _advance               // skip ident
    mov     x0, #TOK_TO
    bl      _expect
    bl      _parse_expr
    mov     x20, x0
    mov     x0, #NODE_SET
    bl      _ast_new
    str     x19, [x0, #AST_F1]
    str     x20, [x0, #AST_F2]
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

_parse_if:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    str     x23, [sp, #-16]!

    bl      _advance               // skip "if"
    bl      _parse_expr
    mov     x19, x0               // condition
    mov     x0, #TOK_COLON
    bl      _expect
    bl      _parse_block
    mov     x20, x0               // then body
    mov     x21, #0               // ow_ifs array
    mov     x22, #0               // ow_if count
    mov     x23, #0               // else body

    bl      _skip_newlines

L_pi_check:
    bl      _cur_tok
    cmp     x0, #TOK_OTHERWISE_IF
    b.eq    L_pi_oi
    cmp     x0, #TOK_OTHERWISE
    b.eq    L_pi_ow
    b       L_pi_make

L_pi_oi:
    bl      _advance
    bl      _parse_expr
    str     x0, [sp, #-16]!       // save oi condition on stack
    mov     x0, #TOK_COLON
    bl      _expect
    bl      _parse_block
    mov     x10, x0               // oi body
    ldr     x9, [sp], #16         // restore oi condition

    // Allocate ow_ifs if needed
    cbz     x21, L_pi_oi_alloc
    b       L_pi_oi_store
L_pi_oi_alloc:
    // x9 and x10 are caller-saved; save them
    stp     x9, x10, [sp, #-16]!
    mov     x0, #256
    bl      _malloc
    mov     x21, x0
    ldp     x9, x10, [sp], #16
L_pi_oi_store:
    lsl     x8, x22, #4
    str     x9, [x21, x8]
    add     x8, x8, #8
    str     x10, [x21, x8]
    add     x22, x22, #1
    bl      _skip_newlines
    b       L_pi_check

L_pi_ow:
    bl      _advance
    mov     x0, #TOK_COLON
    bl      _expect
    bl      _parse_block
    mov     x23, x0

L_pi_make:
    mov     x0, #NODE_IF
    bl      _ast_new
    str     x19, [x0, #AST_F1]
    str     x20, [x0, #AST_F2]
    str     x21, [x0, #AST_F3]
    str     x22, [x0, #AST_F4]
    str     x23, [x0, #AST_F5]

    ldr     x23, [sp], #16
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

_parse_while:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    bl      _advance
    bl      _parse_expr
    mov     x19, x0
    mov     x0, #TOK_COLON
    bl      _expect
    bl      _parse_block
    mov     x20, x0
    mov     x0, #NODE_WHILE
    bl      _ast_new
    str     x19, [x0, #AST_F1]
    str     x20, [x0, #AST_F2]
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

_parse_for_each:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    str     x21, [sp, #-16]!
    bl      _advance               // skip "for each"
    bl      _cur_tok_ptr
    ldr     x19, [x0, #TOKEN_STR]
    bl      _advance
    mov     x0, #TOK_IN
    bl      _expect
    bl      _parse_expr
    mov     x20, x0
    mov     x0, #TOK_COLON
    bl      _expect
    bl      _parse_block
    mov     x21, x0
    mov     x0, #NODE_FOR_EACH
    bl      _ast_new
    str     x19, [x0, #AST_F1]
    str     x20, [x0, #AST_F2]
    str     x21, [x0, #AST_F3]
    ldr     x21, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

_parse_for_from:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    bl      _advance               // skip "for"
    bl      _cur_tok_ptr
    ldr     x19, [x0, #TOKEN_STR]
    bl      _advance
    mov     x0, #TOK_FROM
    bl      _expect
    bl      _parse_expr
    mov     x20, x0
    mov     x0, #TOK_TO
    bl      _expect
    bl      _parse_expr
    mov     x21, x0
    mov     x0, #TOK_COLON
    bl      _expect
    bl      _parse_block
    mov     x22, x0
    mov     x0, #NODE_FOR_FROM
    bl      _ast_new
    str     x19, [x0, #AST_F1]
    str     x20, [x0, #AST_F2]
    str     x21, [x0, #AST_F3]
    str     x22, [x0, #AST_F4]
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

_parse_repeat:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    bl      _advance
    bl      _parse_expr
    mov     x19, x0
    mov     x0, #TOK_TIMES
    bl      _expect
    mov     x0, #TOK_COLON
    bl      _expect
    bl      _parse_block
    mov     x20, x0
    mov     x0, #NODE_REPEAT
    bl      _ast_new
    str     x19, [x0, #AST_F1]
    str     x20, [x0, #AST_F2]
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

_parse_define:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    bl      _advance               // skip "define"
    bl      _cur_tok_ptr
    ldr     x19, [x0, #TOKEN_STR]
    bl      _advance
    mov     x20, #0
    mov     x21, #0

    bl      _cur_tok
    cmp     x0, #TOK_WITH
    b.ne    L_pd_no_params
    bl      _advance
    mov     x0, #64
    bl      _malloc
    mov     x20, x0
L_pd_param:
    bl      _cur_tok_ptr
    ldr     x9, [x0, #TOKEN_STR]
    str     x9, [x20, x21, lsl #3]
    add     x21, x21, #1
    bl      _advance
    bl      _cur_tok
    cmp     x0, #TOK_AND
    b.ne    L_pd_no_params
    bl      _advance
    b       L_pd_param
L_pd_no_params:
    mov     x0, #TOK_COLON
    bl      _expect
    bl      _parse_block
    mov     x22, x0
    mov     x0, #NODE_DEFINE
    bl      _ast_new
    str     x19, [x0, #AST_F1]
    str     x20, [x0, #AST_F2]
    str     x21, [x0, #AST_F3]
    str     x22, [x0, #AST_F4]
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

_parse_return:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    str     x19, [sp, #-16]!
    bl      _advance
    bl      _cur_tok
    cmp     x0, #TOK_NEWLINE
    b.eq    L_pr_none
    cmp     x0, #TOK_EOF
    b.eq    L_pr_none
    cmp     x0, #TOK_DEDENT
    b.eq    L_pr_none
    bl      _parse_expr
    mov     x19, x0
    b       L_pr_make
L_pr_none:
    mov     x19, #0
L_pr_make:
    mov     x0, #NODE_RETURN
    bl      _ast_new
    str     x19, [x0, #AST_F1]
    ldr     x19, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

_parse_append:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    bl      _advance
    bl      _parse_expr
    mov     x19, x0
    mov     x0, #TOK_TO
    bl      _expect
    bl      _cur_tok_ptr
    ldr     x20, [x0, #TOKEN_STR]
    bl      _advance
    mov     x0, #NODE_APPEND
    bl      _ast_new
    str     x19, [x0, #AST_F1]
    str     x20, [x0, #AST_F2]
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

_parse_block:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!

    bl      _skip_newlines
    bl      _cur_tok
    cmp     x0, #TOK_INDENT
    b.ne    L_pb_empty
    bl      _advance

    mov     x0, #256
    bl      _malloc
    mov     x19, x0
    mov     x20, #0
    mov     x21, #32

    bl      _skip_newlines
L_pb_loop:
    bl      _cur_tok
    cmp     x0, #TOK_DEDENT
    b.eq    L_pb_end
    cmp     x0, #TOK_EOF
    b.eq    L_pb_end
    bl      _parse_statement
    cbz     x0, L_pb_skip
    cmp     x20, x21
    b.lt    L_pb_store
    lsl     x21, x21, #1
    mov     x0, x19
    lsl     x1, x21, #3
    bl      _realloc
    mov     x19, x0
L_pb_store:
    str     x0, [x19, x20, lsl #3]
    add     x20, x20, #1
L_pb_skip:
    bl      _skip_newlines
    b       L_pb_loop

L_pb_end:
    bl      _cur_tok
    cmp     x0, #TOK_DEDENT
    b.ne    L_pb_make
    bl      _advance
L_pb_make:
    mov     x0, #NODE_BLOCK
    bl      _ast_new
    str     x19, [x0, #AST_F1]
    str     x20, [x0, #AST_F2]
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

L_pb_empty:
    mov     x0, #NODE_BLOCK
    bl      _ast_new
    str     xzr, [x0, #AST_F1]
    str     xzr, [x0, #AST_F2]
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// =============================================================================
// Expression parsing
// =============================================================================

_parse_expr:
    b       _parse_or

_parse_or:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    str     x19, [sp, #-16]!
    bl      _parse_and
    mov     x19, x0
L_por:
    bl      _cur_tok
    cmp     x0, #TOK_OR
    b.ne    L_por_done
    bl      _advance
    str     x19, [sp, #-16]!
    bl      _parse_and
    mov     x19, x0               // right node
    mov     x0, #NODE_BINOP
    bl      _ast_new
    str     x19, [x0, #AST_F2]   // right
    ldr     x1, [sp], #16
    str     x1, [x0, #AST_F1]    // left
    mov     x9, #OP_OR
    str     x9, [x0, #AST_F3]
    mov     x19, x0
    b       L_por
L_por_done:
    mov     x0, x19
    ldr     x19, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

_parse_and:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    str     x19, [sp, #-16]!
    bl      _parse_not
    mov     x19, x0
L_pand:
    bl      _cur_tok
    cmp     x0, #TOK_AND
    b.ne    L_pand_done
    bl      _advance
    str     x19, [sp, #-16]!
    bl      _parse_not
    mov     x19, x0               // right
    mov     x0, #NODE_BINOP
    bl      _ast_new
    str     x19, [x0, #AST_F2]   // right
    ldr     x1, [sp], #16
    str     x1, [x0, #AST_F1]    // left
    mov     x9, #OP_AND
    str     x9, [x0, #AST_F3]
    mov     x19, x0
    b       L_pand
L_pand_done:
    mov     x0, x19
    ldr     x19, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

_parse_not:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    str     x19, [sp, #-16]!
    bl      _cur_tok
    cmp     x0, #TOK_NOT
    b.ne    L_pnot_cmp
    bl      _advance
    bl      _parse_not
    mov     x19, x0
    mov     x0, #NODE_PREFIX_OP
    bl      _ast_new
    str     x19, [x0, #AST_F1]
    mov     x9, #PRE_NOT
    str     x9, [x0, #AST_F2]
    ldr     x19, [sp], #16
    ldp     x29, x30, [sp], #16
    ret
L_pnot_cmp:
    bl      _parse_comparison
    ldr     x19, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

_parse_comparison:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    str     x19, [sp, #-16]!
    bl      _parse_addition
    mov     x19, x0
L_pcmp:
    bl      _cur_tok
    mov     x9, #-1
    cmp     x0, #TOK_IS_EQUAL_TO
    b.ne    1f
    mov     x9, #OP_EQ
    b       L_pcmp_op
1:  cmp     x0, #TOK_IS_NOT_EQUAL_TO
    b.ne    2f
    mov     x9, #OP_NEQ
    b       L_pcmp_op
2:  cmp     x0, #TOK_IS_GREATER_THAN
    b.ne    3f
    mov     x9, #OP_GT
    b       L_pcmp_op
3:  cmp     x0, #TOK_IS_LESS_THAN
    b.ne    4f
    mov     x9, #OP_LT
    b       L_pcmp_op
4:  cmp     x0, #TOK_IS_AT_LEAST
    b.ne    5f
    mov     x9, #OP_GTE
    b       L_pcmp_op
5:  cmp     x0, #TOK_IS_AT_MOST
    b.ne    L_pcmp_done
    mov     x9, #OP_LTE

L_pcmp_op:
    stp     x19, x9, [sp, #-16]!
    bl      _advance
    bl      _parse_addition
    mov     x19, x0                // right node
    mov     x0, #NODE_BINOP
    bl      _ast_new
    str     x19, [x0, #AST_F2]    // right
    ldp     x1, x9, [sp], #16     // left, op
    str     x1, [x0, #AST_F1]     // left
    str     x9, [x0, #AST_F3]     // op
    mov     x19, x0
    b       L_pcmp

L_pcmp_done:
    mov     x0, x19
    ldr     x19, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

_parse_addition:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    str     x19, [sp, #-16]!
    bl      _parse_multiplication
    mov     x19, x0
L_padd:
    bl      _cur_tok
    cmp     x0, #TOK_PLUS
    b.eq    L_padd_plus
    cmp     x0, #TOK_MINUS
    b.eq    L_padd_minus
    b       L_padd_done
L_padd_plus:
    mov     x9, #OP_PLUS
    b       L_padd_op
L_padd_minus:
    mov     x9, #OP_MINUS
L_padd_op:
    stp     x19, x9, [sp, #-16]!
    bl      _advance
    bl      _parse_multiplication
    mov     x19, x0                // right node in x19 (will be saved by ast_new)
    mov     x0, #NODE_BINOP
    bl      _ast_new
    // x0 = new node, x19 = right node (restored by ast_new's save/restore)
    // Wait: ast_new saves/restores its own x19. We need left, right, op.
    // After ast_new: x0 = node. We need: left (on stack), right (x19), op (on stack)
    str     x19, [x0, #AST_F2]    // right
    ldp     x1, x9, [sp], #16     // left, op
    str     x1, [x0, #AST_F1]     // left
    str     x9, [x0, #AST_F3]     // op
    mov     x19, x0
    b       L_padd
L_padd_done:
    mov     x0, x19
    ldr     x19, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

_parse_multiplication:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    str     x19, [sp, #-16]!
    bl      _parse_unary
    mov     x19, x0
L_pmul:
    bl      _cur_tok
    cmp     x0, #TOK_TIMES
    b.eq    L_pmul_times
    cmp     x0, #TOK_DIVIDED_BY
    b.eq    L_pmul_div
    cmp     x0, #TOK_MODULO
    b.eq    L_pmul_mod
    b       L_pmul_done
L_pmul_times:
    // Check if "times" is followed by ":" (repeat N times: context)
    // If so, don't treat as multiplication
    adrp    x8, g_token_pos@PAGE
    ldr     x9, [x8, g_token_pos@PAGEOFF]
    add     x9, x9, #1
    adrp    x10, g_tokens@PAGE
    ldr     x10, [x10, g_tokens@PAGEOFF]
    adrp    x11, g_token_count@PAGE
    ldr     x11, [x11, g_token_count@PAGEOFF]
    cmp     x9, x11
    b.ge    L_pmul_times_ok
    mov     x12, #TOKEN_SIZE
    madd    x10, x9, x12, x10
    ldr     x13, [x10, #TOKEN_TYPE]
    cmp     x13, #TOK_COLON
    b.eq    L_pmul_done            // "times:" = repeat keyword, not multiply
L_pmul_times_ok:
    mov     x9, #OP_TIMES
    b       L_pmul_op
L_pmul_div:
    mov     x9, #OP_DIVIDED_BY
    b       L_pmul_op
L_pmul_mod:
    mov     x9, #OP_MODULO
L_pmul_op:
    stp     x19, x9, [sp, #-16]!
    bl      _advance
    bl      _parse_unary
    mov     x19, x0                // right node
    mov     x0, #NODE_BINOP
    bl      _ast_new
    str     x19, [x0, #AST_F2]    // right
    ldp     x1, x9, [sp], #16     // left, op
    str     x1, [x0, #AST_F1]     // left
    str     x9, [x0, #AST_F3]     // op
    mov     x19, x0
    b       L_pmul
L_pmul_done:
    mov     x0, x19
    ldr     x19, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

_parse_unary:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    bl      _cur_tok
    cmp     x0, #TOK_NEGATIVE
    b.ne    L_pu_post
    bl      _advance
    str     x19, [sp, #-16]!
    bl      _parse_unary
    mov     x19, x0
    mov     x0, #NODE_NEGATIVE
    bl      _ast_new
    str     x19, [x0, #AST_F1]
    ldr     x19, [sp], #16
    ldp     x29, x30, [sp], #16
    ret
L_pu_post:
    bl      _parse_postfix
    ldp     x29, x30, [sp], #16
    ret

_parse_postfix:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    str     x19, [sp, #-16]!
    bl      _parse_primary
    mov     x19, x0
L_ppf:
    bl      _cur_tok
    cmp     x0, #TOK_JOINED_WITH
    b.eq    L_ppf_joined
    cmp     x0, #TOK_AS
    b.eq    L_ppf_as
    cmp     x0, #TOK_CONTAINS
    b.eq    L_ppf_contains
    b       L_ppf_done

L_ppf_joined:
    bl      _advance
    str     x19, [sp, #-16]!
    bl      _parse_primary
    mov     x19, x0               // right
    mov     x0, #NODE_JOINED_WITH
    bl      _ast_new
    str     x19, [x0, #AST_F2]   // right
    ldr     x1, [sp], #16
    str     x1, [x0, #AST_F1]    // left
    mov     x19, x0
    b       L_ppf

L_ppf_as:
    bl      _advance
    bl      _cur_tok
    str     x0, [sp, #-16]!       // save token type
    bl      _advance
    // x19 = expr, stack top = type token
    mov     x0, #NODE_AS
    bl      _ast_new
    str     x19, [x0, #AST_F1]    // expr
    ldr     x9, [sp], #16
    str     x9, [x0, #AST_F2]     // type token
    mov     x19, x0
    b       L_ppf

L_ppf_contains:
    bl      _advance
    str     x19, [sp, #-16]!
    bl      _parse_primary
    mov     x19, x0               // right
    mov     x0, #NODE_CONTAINS
    bl      _ast_new
    str     x19, [x0, #AST_F2]   // right
    ldr     x1, [sp], #16
    str     x1, [x0, #AST_F1]    // left
    mov     x19, x0
    b       L_ppf

L_ppf_done:
    mov     x0, x19
    ldr     x19, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

_parse_primary:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    bl      _cur_tok

    cmp     x0, #TOK_NUMBER
    b.eq    L_pp_number
    cmp     x0, #TOK_STRING
    b.eq    L_pp_string
    cmp     x0, #TOK_TRUE
    b.eq    L_pp_true
    cmp     x0, #TOK_FALSE
    b.eq    L_pp_false
    cmp     x0, #TOK_NOTHING
    b.eq    L_pp_nothing
    cmp     x0, #TOK_LPAREN
    b.eq    L_pp_paren
    cmp     x0, #TOK_LBRACKET
    b.eq    L_pp_list
    cmp     x0, #TOK_CALL
    b.eq    L_pp_call
    cmp     x0, #TOK_UPPERCASE_OF
    b.eq    L_pp_upper
    cmp     x0, #TOK_LOWERCASE_OF
    b.eq    L_pp_lower
    cmp     x0, #TOK_LENGTH_OF
    b.eq    L_pp_length
    cmp     x0, #TOK_FIRST_OF
    b.eq    L_pp_first
    cmp     x0, #TOK_LAST_OF
    b.eq    L_pp_last
    cmp     x0, #TOK_ITEM
    b.eq    L_pp_item
    cmp     x0, #TOK_SLICE_OF
    b.eq    L_pp_slice
    cmp     x0, #TOK_IDENT
    b.eq    L_pp_ident

    // Unexpected - return nothing node
    mov     x0, #NODE_NOTHING_LIT
    bl      _ast_new
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

L_pp_number:
    bl      _cur_tok_ptr
    ldr     d0, [x0, #TOKEN_NUM]
    fmov    x19, d0                // save number bits in x19 (callee-saved)
    bl      _advance
    mov     x0, #NODE_NUMBER_LIT
    bl      _ast_new
    str     x19, [x0, #AST_F1]    // store bits directly (same as d0)
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

L_pp_string:
    bl      _cur_tok_ptr
    ldr     x19, [x0, #TOKEN_STR]
    bl      _advance
    mov     x0, #NODE_STRING_LIT
    bl      _ast_new
    str     x19, [x0, #AST_F1]
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

L_pp_true:
    bl      _advance
    mov     x0, #NODE_BOOL_LIT
    bl      _ast_new
    mov     x9, #1
    str     x9, [x0, #AST_F1]
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

L_pp_false:
    bl      _advance
    mov     x0, #NODE_BOOL_LIT
    bl      _ast_new
    str     xzr, [x0, #AST_F1]
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

L_pp_nothing:
    bl      _advance
    mov     x0, #NODE_NOTHING_LIT
    bl      _ast_new
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

L_pp_paren:
    bl      _advance
    bl      _parse_expr
    mov     x19, x0
    mov     x0, #TOK_RPAREN
    bl      _expect
    mov     x0, x19
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

L_pp_list:
    bl      _advance
    mov     x0, #128
    bl      _malloc
    mov     x19, x0
    mov     x20, #0
    bl      _cur_tok
    cmp     x0, #TOK_RBRACKET
    b.eq    L_pp_list_end
L_pp_list_loop:
    bl      _parse_expr
    str     x0, [x19, x20, lsl #3]
    add     x20, x20, #1
    bl      _cur_tok
    cmp     x0, #TOK_COMMA
    b.ne    L_pp_list_end
    bl      _advance
    b       L_pp_list_loop
L_pp_list_end:
    mov     x0, #TOK_RBRACKET
    bl      _expect
    mov     x0, #NODE_LIST_LIT
    bl      _ast_new
    str     x19, [x0, #AST_F1]
    str     x20, [x0, #AST_F2]
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

L_pp_call:
    bl      _parse_call_expr
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

L_pp_upper:
    bl      _advance
    bl      _parse_primary
    mov     x19, x0
    mov     x0, #NODE_PREFIX_OP
    bl      _ast_new
    str     x19, [x0, #AST_F1]
    mov     x9, #PRE_UPPERCASE
    str     x9, [x0, #AST_F2]
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

L_pp_lower:
    bl      _advance
    bl      _parse_primary
    mov     x19, x0
    mov     x0, #NODE_PREFIX_OP
    bl      _ast_new
    str     x19, [x0, #AST_F1]
    mov     x9, #PRE_LOWERCASE
    str     x9, [x0, #AST_F2]
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

L_pp_length:
    bl      _advance
    bl      _parse_primary
    mov     x19, x0
    mov     x0, #NODE_PREFIX_OP
    bl      _ast_new
    str     x19, [x0, #AST_F1]
    mov     x9, #PRE_LENGTH
    str     x9, [x0, #AST_F2]
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

L_pp_first:
    bl      _advance
    bl      _parse_primary
    mov     x19, x0
    mov     x0, #NODE_PREFIX_OP
    bl      _ast_new
    str     x19, [x0, #AST_F1]
    mov     x9, #PRE_FIRST
    str     x9, [x0, #AST_F2]
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

L_pp_last:
    bl      _advance
    bl      _parse_primary
    mov     x19, x0
    mov     x0, #NODE_PREFIX_OP
    bl      _ast_new
    str     x19, [x0, #AST_F1]
    mov     x9, #PRE_LAST
    str     x9, [x0, #AST_F2]
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

L_pp_item:
    bl      _advance
    bl      _parse_expr
    mov     x19, x0
    mov     x0, #TOK_OF
    bl      _expect
    bl      _parse_primary
    mov     x20, x0
    mov     x0, #NODE_ITEM_OF
    bl      _ast_new
    str     x19, [x0, #AST_F1]
    str     x20, [x0, #AST_F2]
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

L_pp_slice:
    bl      _advance
    bl      _parse_primary
    mov     x19, x0               // collection
    mov     x0, #TOK_FROM
    bl      _expect
    bl      _parse_expr
    mov     x20, x0               // from
    mov     x0, #TOK_TO
    bl      _expect
    stp     x19, x20, [sp, #-16]! // save collection, from
    bl      _parse_expr
    mov     x19, x0               // to_expr in x19 (callee-saved)
    mov     x0, #NODE_SLICE_OF
    bl      _ast_new
    str     x19, [x0, #AST_F3]   // to
    ldp     x19, x20, [sp], #16  // restore collection, from
    str     x19, [x0, #AST_F1]   // collection
    str     x20, [x0, #AST_F2]   // from
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

L_pp_ident:
    bl      _cur_tok_ptr
    ldr     x19, [x0, #TOKEN_STR]
    // Check if this is "item" (for "item N of list")
    mov     x0, x19
    adrp    x1, kw_item@PAGE
    add     x1, x1, kw_item@PAGEOFF
    bl      _strcmp
    cbz     x0, L_pp_item_from_ident
    // Regular identifier
    bl      _advance
    mov     x0, #NODE_IDENT
    bl      _ast_new
    str     x19, [x0, #AST_F1]
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret
L_pp_item_from_ident:
    // Check if next token is a number or expression start (for "item N of list")
    // If next token is NEWLINE, EOF, DEDENT, or a keyword that can't start an expression,
    // treat "item" as a regular identifier variable
    adrp    x8, g_token_pos@PAGE
    ldr     x9, [x8, g_token_pos@PAGEOFF]
    add     x9, x9, #1
    adrp    x10, g_tokens@PAGE
    ldr     x10, [x10, g_tokens@PAGEOFF]
    adrp    x11, g_token_count@PAGE
    ldr     x11, [x11, g_token_count@PAGEOFF]
    cmp     x9, x11
    b.ge    L_pp_item_as_var
    mov     x12, #TOKEN_SIZE
    madd    x10, x9, x12, x10
    ldr     x13, [x10, #TOKEN_TYPE]
    // If next token is a number, lparen, lbracket, call, ident, or negative -> it's "item N of"
    cmp     x13, #TOK_NUMBER
    b.eq    L_pp_item_real
    cmp     x13, #TOK_LPAREN
    b.eq    L_pp_item_real
    cmp     x13, #TOK_NEGATIVE
    b.eq    L_pp_item_real
    cmp     x13, #TOK_IDENT
    b.eq    L_pp_item_real
    cmp     x13, #TOK_CALL
    b.eq    L_pp_item_real
    // Otherwise treat as variable
    b       L_pp_item_as_var

L_pp_item_real:
    // "item" keyword usage: "item N of list"
    bl      _advance               // skip "item"
    bl      _parse_expr            // index
    mov     x19, x0
    mov     x0, #TOK_OF
    bl      _expect                // skip "of"
    bl      _parse_primary         // list
    mov     x20, x0
    mov     x0, #NODE_ITEM_OF
    bl      _ast_new
    str     x19, [x0, #AST_F1]
    str     x20, [x0, #AST_F2]
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

L_pp_item_as_var:
    // Treat "item" as a regular variable
    bl      _advance
    mov     x0, #NODE_IDENT
    bl      _ast_new
    str     x19, [x0, #AST_F1]
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

_parse_call_expr:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    str     x21, [sp, #-16]!
    bl      _advance               // skip "call"
    bl      _cur_tok_ptr
    ldr     x19, [x0, #TOKEN_STR]
    bl      _advance
    mov     x20, #0
    mov     x21, #0
    bl      _cur_tok
    cmp     x0, #TOK_WITH
    b.ne    L_pce_done
    bl      _advance
    mov     x0, #128
    bl      _malloc
    mov     x20, x0
L_pce_arg:
    bl      _parse_not             // parse at "not" level (below "and")
    str     x0, [x20, x21, lsl #3]
    add     x21, x21, #1
    bl      _cur_tok
    cmp     x0, #TOK_AND
    b.ne    L_pce_done
    bl      _advance
    b       L_pce_arg
L_pce_done:
    mov     x0, #NODE_CALL
    bl      _ast_new
    str     x19, [x0, #AST_F1]
    str     x20, [x0, #AST_F2]
    str     x21, [x0, #AST_F3]
    ldr     x21, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// =============================================================================
// INTERPRETER
// =============================================================================

// --- Environment ---
_env_new:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x0, #ENV_SIZE
    bl      _malloc
    stp     xzr, xzr, [x0]
    stp     xzr, xzr, [x0, #16]
    ldp     x29, x30, [sp], #16
    ret

_env_push:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    str     x19, [sp, #-16]!
    mov     x19, x0
    bl      _env_new
    str     x19, [x0, #ENV_PARENT]
    ldr     x19, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// _env_set: x0=env, x1=name, x2=val_ptr(32 bytes)
_env_set:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!

    mov     x19, x0
    mov     x20, x1
    mov     x21, x2

    // Search current scope
    ldr     x8, [x19, #ENV_VARS]
    ldr     x9, [x19, #ENV_COUNT]
    mov     x10, #0
L_es_search:
    cmp     x10, x9
    b.ge    L_es_add
    mov     x11, #ENVVAR_SIZE
    madd    x12, x10, x11, x8
    ldr     x13, [x12, #ENVVAR_NAME]
    mov     x0, x20
    mov     x1, x13
    bl      _strcmp
    cbz     x0, L_es_found
    add     x10, x10, #1
    b       L_es_search

L_es_found:
    ldr     x8, [x19, #ENV_VARS]
    mov     x11, #ENVVAR_SIZE
    madd    x12, x10, x11, x8
    add     x12, x12, #ENVVAR_VAL
    ldp     x13, x14, [x21]
    stp     x13, x14, [x12]
    ldp     x13, x14, [x21, #16]
    stp     x13, x14, [x12, #16]
    b       L_es_done

L_es_add:
    ldr     x9, [x19, #ENV_COUNT]
    ldr     x22, [x19, #ENV_CAP]
    cmp     x9, x22
    b.lt    L_es_room
    cbz     x22, L_es_init
    lsl     x22, x22, #1
    b       L_es_grow
L_es_init:
    mov     x22, #16
L_es_grow:
    str     x22, [x19, #ENV_CAP]
    ldr     x0, [x19, #ENV_VARS]
    mov     x1, #ENVVAR_SIZE
    mul     x1, x22, x1
    bl      _realloc
    str     x0, [x19, #ENV_VARS]

L_es_room:
    ldr     x8, [x19, #ENV_VARS]
    ldr     x9, [x19, #ENV_COUNT]
    mov     x11, #ENVVAR_SIZE
    madd    x12, x9, x11, x8
    str     x20, [x12, #ENVVAR_NAME]
    add     x12, x12, #ENVVAR_VAL
    ldp     x13, x14, [x21]
    stp     x13, x14, [x12]
    ldp     x13, x14, [x21, #16]
    stp     x13, x14, [x12, #16]
    add     x9, x9, #1
    str     x9, [x19, #ENV_COUNT]

L_es_done:
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// _env_get: x0=env, x1=name -> x0=val_ptr or 0
_env_get:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!

    mov     x19, x0
    mov     x20, x1
L_eg_scope:
    cbz     x19, L_eg_fail
    ldr     x8, [x19, #ENV_VARS]
    ldr     x9, [x19, #ENV_COUNT]
    mov     x10, #0
L_eg_search:
    cmp     x10, x9
    b.ge    L_eg_next
    mov     x11, #ENVVAR_SIZE
    madd    x12, x10, x11, x8
    ldr     x13, [x12, #ENVVAR_NAME]
    mov     x0, x20
    mov     x1, x13
    bl      _strcmp
    cbz     x0, L_eg_found
    add     x10, x10, #1
    b       L_eg_search
L_eg_found:
    ldr     x8, [x19, #ENV_VARS]
    mov     x11, #ENVVAR_SIZE
    madd    x0, x10, x11, x8
    add     x0, x0, #ENVVAR_VAL
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret
L_eg_next:
    ldr     x19, [x19, #ENV_PARENT]
    b       L_eg_scope
L_eg_fail:
    mov     x0, #0
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// _env_set_in_scope: x0=env, x1=name, x2=val_ptr
// Search all scopes; if found update there, else set in current
_env_set_in_scope:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    str     x21, [sp, #-16]!

    mov     x19, x0
    mov     x20, x1
    mov     x21, x2

    mov     x8, x19
L_esis_loop:
    cbz     x8, L_esis_new
    ldr     x9, [x8, #ENV_VARS]
    ldr     x10, [x8, #ENV_COUNT]
    mov     x11, #0
L_esis_search:
    cmp     x11, x10
    b.ge    L_esis_next
    mov     x12, #ENVVAR_SIZE
    madd    x13, x11, x12, x9
    ldr     x14, [x13, #ENVVAR_NAME]
    mov     x0, x20
    mov     x1, x14
    stp     x8, x9, [sp, #-16]!
    stp     x10, x11, [sp, #-16]!
    bl      _strcmp
    ldp     x10, x11, [sp], #16
    ldp     x8, x9, [sp], #16
    cbz     x0, L_esis_found
    add     x11, x11, #1
    b       L_esis_search
L_esis_found:
    mov     x0, x8
    mov     x1, x20
    mov     x2, x21
    bl      _env_set
    b       L_esis_done
L_esis_next:
    ldr     x8, [x8, #ENV_PARENT]
    b       L_esis_loop
L_esis_new:
    mov     x0, x19
    mov     x1, x20
    mov     x2, x21
    bl      _env_set
L_esis_done:
    ldr     x21, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// --- Value helpers ---
_val_number:   // x0=out, d0=num
    mov     x9, #TYPE_NUMBER
    str     x9, [x0, #VAL_TYPE]
    str     d0, [x0, #VAL_DATA]
    stp     xzr, xzr, [x0, #16]
    ret
_val_string:   // x0=out, x1=str
    mov     x9, #TYPE_STRING
    str     x9, [x0, #VAL_TYPE]
    str     x1, [x0, #VAL_DATA]
    stp     xzr, xzr, [x0, #16]
    ret
_val_bool:     // x0=out, x1=bool(0/1)
    mov     x9, #TYPE_BOOL
    str     x9, [x0, #VAL_TYPE]
    str     x1, [x0, #VAL_DATA]
    stp     xzr, xzr, [x0, #16]
    ret
_val_nothing:  // x0=out
    mov     x9, #TYPE_NOTHING
    str     x9, [x0, #VAL_TYPE]
    stp     xzr, xzr, [x0, #8]
    str     xzr, [x0, #24]
    ret
_val_list:     // x0=out, x1=data, x2=len, x3=cap
    mov     x9, #TYPE_LIST
    str     x9, [x0, #VAL_TYPE]
    str     x1, [x0, #VAL_DATA]
    str     x2, [x0, #VAL_LEN]
    str     x3, [x0, #VAL_CAP]
    ret

// =============================================================================
// _print_number: d0 = number
// =============================================================================
_print_number:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    str     d8, [sp, #-16]!

    fmov    d8, d0
    fcvtzs  x9, d8
    scvtf   d1, x9
    fcmp    d8, d1
    b.ne    L_pn_dec

    // Integer
    adrp    x0, fmt_int@PAGE
    add     x0, x0, fmt_int@PAGEOFF
    mov     x1, x9
    bl      _printf_int
    b       L_pn_done

L_pn_dec:
    sub     sp, sp, #64
    mov     x0, sp
    mov     x1, #63
    adrp    x2, fmt_float@PAGE
    add     x2, x2, fmt_float@PAGEOFF
    fmov    d0, d8
    bl      _snprintf_float
    // Strip trailing zeros
    mov     x0, sp
    bl      _strip_trailing_zeros
    mov     x0, sp
    bl      _fputs_stdout
    add     sp, sp, #64

L_pn_done:
    ldr     d8, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

_strip_trailing_zeros:
    // x0 = buffer string
    mov     x8, x0
    // Find end
    mov     x9, #0
L_stz_len:
    ldrb    w10, [x8, x9]
    cbz     w10, L_stz_find_dot
    add     x9, x9, #1
    b       L_stz_len
L_stz_find_dot:
    mov     x10, #0
L_stz_dot:
    cmp     x10, x9
    b.ge    L_stz_ret
    ldrb    w11, [x8, x10]
    cmp     w11, #'.'
    b.eq    L_stz_strip
    add     x10, x10, #1
    b       L_stz_dot
L_stz_strip:
    sub     x10, x9, #1
L_stz_loop:
    ldrb    w11, [x8, x10]
    cmp     w11, #'0'
    b.ne    L_stz_chk
    strb    wzr, [x8, x10]
    sub     x10, x10, #1
    b       L_stz_loop
L_stz_chk:
    cmp     w11, #'.'
    b.ne    L_stz_ret
    strb    wzr, [x8, x10]
L_stz_ret:
    ret

_fputs_stdout:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    mov     x1, x0
    adrp    x0, ___stdoutp@GOTPAGE
    ldr     x0, [x0, ___stdoutp@GOTPAGEOFF]
    ldr     x0, [x0]
    mov     x2, x0
    mov     x0, x1
    mov     x1, x2
    bl      _fputs
    ldp     x29, x30, [sp], #16
    ret

// =============================================================================
// _print_value: x0 = val_ptr
// =============================================================================
_print_value:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    str     x19, [sp, #-16]!
    mov     x19, x0
    ldr     x9, [x19, #VAL_TYPE]

    cmp     x9, #TYPE_NUMBER
    b.eq    L_pv_num
    cmp     x9, #TYPE_STRING
    b.eq    L_pv_str
    cmp     x9, #TYPE_BOOL
    b.eq    L_pv_bool
    cmp     x9, #TYPE_LIST
    b.eq    L_pv_list
    cmp     x9, #TYPE_NOTHING
    b.eq    L_pv_nothing
    b       L_pv_done

L_pv_num:
    ldr     d0, [x19, #VAL_DATA]
    bl      _print_number
    b       L_pv_done

L_pv_str:
    ldr     x0, [x19, #VAL_DATA]
    bl      _fputs_stdout
    b       L_pv_done

L_pv_bool:
    ldr     x9, [x19, #VAL_DATA]
    cbz     x9, L_pv_false
    adrp    x0, fmt_true@PAGE
    add     x0, x0, fmt_true@PAGEOFF
    b       L_pv_bprint
L_pv_false:
    adrp    x0, fmt_false@PAGE
    add     x0, x0, fmt_false@PAGEOFF
L_pv_bprint:
    bl      _fputs_stdout
    b       L_pv_done

L_pv_nothing:
    adrp    x0, fmt_nothing_s@PAGE
    add     x0, x0, fmt_nothing_s@PAGEOFF
    bl      _fputs_stdout
    b       L_pv_done

L_pv_list:
    adrp    x0, fmt_lbracket@PAGE
    add     x0, x0, fmt_lbracket@PAGEOFF
    bl      _fputs_stdout
    ldr     x8, [x19, #VAL_DATA]
    ldr     x9, [x19, #VAL_LEN]
    mov     x10, #0
L_pv_list_loop:
    cmp     x10, x9
    b.ge    L_pv_list_end
    cmp     x10, #0
    b.eq    L_pv_list_nocomma
    str     x10, [sp, #-16]!
    adrp    x0, fmt_comma@PAGE
    add     x0, x0, fmt_comma@PAGEOFF
    bl      _fputs_stdout
    ldr     x10, [sp], #16
    ldr     x8, [x19, #VAL_DATA]
    ldr     x9, [x19, #VAL_LEN]
L_pv_list_nocomma:
    mov     x11, #VAL_SIZE
    madd    x0, x10, x11, x8
    str     x10, [sp, #-16]!
    bl      _print_value_inline
    ldr     x10, [sp], #16
    ldr     x8, [x19, #VAL_DATA]
    ldr     x9, [x19, #VAL_LEN]
    add     x10, x10, #1
    b       L_pv_list_loop
L_pv_list_end:
    adrp    x0, fmt_rbracket@PAGE
    add     x0, x0, fmt_rbracket@PAGEOFF
    bl      _fputs_stdout

L_pv_done:
    ldr     x19, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// _print_value_inline: for list elements (strings get quoted)
_print_value_inline:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    str     x19, [sp, #-16]!
    mov     x19, x0
    ldr     x9, [x19, #VAL_TYPE]
    cmp     x9, #TYPE_STRING
    b.ne    L_pvi_other
    mov     w0, #'"'
    bl      _putchar
    ldr     x0, [x19, #VAL_DATA]
    bl      _fputs_stdout
    mov     w0, #'"'
    bl      _putchar
    b       L_pvi_done
L_pvi_other:
    mov     x0, x19
    bl      _print_value
L_pvi_done:
    ldr     x19, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// =============================================================================
// _value_to_string: x0 = val_ptr -> x0 = malloc'd string
// =============================================================================
_value_to_string:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    mov     x19, x0
    ldr     x20, [x19, #VAL_TYPE]

    cmp     x20, #TYPE_NUMBER
    b.eq    L_vts_num
    cmp     x20, #TYPE_STRING
    b.eq    L_vts_str
    cmp     x20, #TYPE_BOOL
    b.eq    L_vts_bool
    cmp     x20, #TYPE_NOTHING
    b.eq    L_vts_nothing
    cmp     x20, #TYPE_LIST
    b.eq    L_vts_list

    adrp    x0, empty_str@PAGE
    add     x0, x0, empty_str@PAGEOFF
    bl      _strdup
    b       L_vts_done

L_vts_num:
    ldr     d0, [x19, #VAL_DATA]
    fcvtzs  x9, d0
    scvtf   d1, x9
    fcmp    d0, d1
    b.ne    L_vts_num_dec
    sub     sp, sp, #64
    mov     x0, sp
    mov     x1, #63
    adrp    x2, fmt_int@PAGE
    add     x2, x2, fmt_int@PAGEOFF
    mov     x3, x9
    bl      _snprintf_int
    mov     x0, sp
    bl      _strdup
    add     sp, sp, #64
    b       L_vts_done

L_vts_num_dec:
    sub     sp, sp, #64
    mov     x0, sp
    mov     x1, #63
    adrp    x2, fmt_float@PAGE
    add     x2, x2, fmt_float@PAGEOFF
    ldr     d0, [x19, #VAL_DATA]
    bl      _snprintf_float
    mov     x0, sp
    bl      _strip_trailing_zeros
    mov     x0, sp
    bl      _strdup
    add     sp, sp, #64
    b       L_vts_done

L_vts_str:
    ldr     x0, [x19, #VAL_DATA]
    bl      _strdup
    b       L_vts_done

L_vts_bool:
    ldr     x9, [x19, #VAL_DATA]
    cbz     x9, L_vts_bfalse
    adrp    x0, fmt_true@PAGE
    add     x0, x0, fmt_true@PAGEOFF
    bl      _strdup
    b       L_vts_done
L_vts_bfalse:
    adrp    x0, fmt_false@PAGE
    add     x0, x0, fmt_false@PAGEOFF
    bl      _strdup
    b       L_vts_done

L_vts_nothing:
    adrp    x0, fmt_nothing_s@PAGE
    add     x0, x0, fmt_nothing_s@PAGEOFF
    bl      _strdup
    b       L_vts_done

L_vts_list:
    // Write list to a buffer
    mov     x0, #2048
    bl      _malloc
    mov     x20, x0
    mov     w9, #'['
    strb    w9, [x20]
    mov     x9, #1                 // pos

    ldr     x8, [x19, #VAL_DATA]
    ldr     x10, [x19, #VAL_LEN]
    mov     x11, #0

L_vts_ll:
    cmp     x11, x10
    b.ge    L_vts_ll_end
    cmp     x11, #0
    b.eq    L_vts_ll_nc
    mov     w12, #','
    strb    w12, [x20, x9]
    add     x9, x9, #1
    mov     w12, #' '
    strb    w12, [x20, x9]
    add     x9, x9, #1
L_vts_ll_nc:
    mov     x12, #VAL_SIZE
    madd    x0, x11, x12, x8

    ldr     x13, [x0, #VAL_TYPE]
    cmp     x13, #TYPE_STRING
    b.ne    L_vts_ll_nq

    // String with quotes
    mov     w12, #'"'
    strb    w12, [x20, x9]
    add     x9, x9, #1

    stp     x8, x9, [sp, #-16]!
    stp     x10, x11, [sp, #-16]!
    str     x20, [sp, #-16]!
    bl      _value_to_string
    mov     x14, x0
    ldr     x20, [sp], #16
    ldp     x10, x11, [sp], #16
    ldp     x8, x9, [sp], #16

    mov     x15, #0
L_vts_ll_sc:
    ldrb    w12, [x14, x15]
    cbz     w12, L_vts_ll_sd
    strb    w12, [x20, x9]
    add     x9, x9, #1
    add     x15, x15, #1
    b       L_vts_ll_sc
L_vts_ll_sd:
    mov     x0, x14
    stp     x8, x9, [sp, #-16]!
    stp     x10, x11, [sp, #-16]!
    str     x20, [sp, #-16]!
    bl      _free
    ldr     x20, [sp], #16
    ldp     x10, x11, [sp], #16
    ldp     x8, x9, [sp], #16

    mov     w12, #'"'
    strb    w12, [x20, x9]
    add     x9, x9, #1
    add     x11, x11, #1
    b       L_vts_ll

L_vts_ll_nq:
    stp     x8, x9, [sp, #-16]!
    stp     x10, x11, [sp, #-16]!
    str     x20, [sp, #-16]!
    bl      _value_to_string
    mov     x14, x0
    ldr     x20, [sp], #16
    ldp     x10, x11, [sp], #16
    ldp     x8, x9, [sp], #16

    mov     x15, #0
L_vts_ll_cc:
    ldrb    w12, [x14, x15]
    cbz     w12, L_vts_ll_cd
    strb    w12, [x20, x9]
    add     x9, x9, #1
    add     x15, x15, #1
    b       L_vts_ll_cc
L_vts_ll_cd:
    mov     x0, x14
    stp     x8, x9, [sp, #-16]!
    stp     x10, x11, [sp, #-16]!
    str     x20, [sp, #-16]!
    bl      _free
    ldr     x20, [sp], #16
    ldp     x10, x11, [sp], #16
    ldp     x8, x9, [sp], #16

    add     x11, x11, #1
    b       L_vts_ll

L_vts_ll_end:
    mov     w12, #']'
    strb    w12, [x20, x9]
    add     x9, x9, #1
    strb    wzr, [x20, x9]
    mov     x0, x20

L_vts_done:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// =============================================================================
// _interpret_block: x0 = block/program node
// =============================================================================
_interpret_block:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!

    mov     x19, x0
    ldr     x20, [x19, #AST_F1]
    ldr     x21, [x19, #AST_F2]
    mov     x22, #0
L_ib_loop:
    cmp     x22, x21
    b.ge    L_ib_done
    adrp    x8, g_signal@PAGE
    ldr     x9, [x8, g_signal@PAGEOFF]
    cbnz    x9, L_ib_done
    ldr     x0, [x20, x22, lsl #3]
    bl      _interpret_stmt
    add     x22, x22, #1
    b       L_ib_loop
L_ib_done:
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// =============================================================================
// _interpret_stmt: x0 = AST node
// =============================================================================
_interpret_stmt:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    str     x19, [sp, #-16]!
    mov     x19, x0
    cbz     x19, L_is_done
    ldr     x9, [x19, #AST_TYPE]

    cmp     x9, #NODE_PRINT
    b.eq    L_is_print
    cmp     x9, #NODE_SET
    b.eq    L_is_set
    cmp     x9, #NODE_IF
    b.eq    L_is_if
    cmp     x9, #NODE_WHILE
    b.eq    L_is_while
    cmp     x9, #NODE_FOR_EACH
    b.eq    L_is_for_each
    cmp     x9, #NODE_FOR_FROM
    b.eq    L_is_for_from
    cmp     x9, #NODE_REPEAT
    b.eq    L_is_repeat
    cmp     x9, #NODE_DEFINE
    b.eq    L_is_define
    cmp     x9, #NODE_RETURN
    b.eq    L_is_return
    cmp     x9, #NODE_APPEND
    b.eq    L_is_append
    cmp     x9, #NODE_STOP
    b.eq    L_is_stop
    cmp     x9, #NODE_SKIP
    b.eq    L_is_skip
    cmp     x9, #NODE_CALL
    b.eq    L_is_call
    b       L_is_done

L_is_print:
    ldr     x0, [x19, #AST_F1]
    sub     sp, sp, #32
    mov     x1, sp
    bl      _eval_expr
    mov     x0, sp
    bl      _print_value
    mov     w0, #'\n'
    bl      _putchar
    add     sp, sp, #32
    b       L_is_done

L_is_set:
    ldr     x0, [x19, #AST_F2]
    sub     sp, sp, #32
    mov     x1, sp
    bl      _eval_expr
    adrp    x8, g_env@PAGE
    ldr     x0, [x8, g_env@PAGEOFF]
    ldr     x1, [x19, #AST_F1]
    mov     x2, sp
    bl      _env_set_in_scope
    add     sp, sp, #32
    b       L_is_done

L_is_if:
    mov     x0, x19
    bl      _exec_if
    b       L_is_done

L_is_while:
    mov     x0, x19
    bl      _exec_while
    b       L_is_done

L_is_for_each:
    mov     x0, x19
    bl      _exec_for_each
    b       L_is_done

L_is_for_from:
    mov     x0, x19
    bl      _exec_for_from
    b       L_is_done

L_is_repeat:
    mov     x0, x19
    bl      _exec_repeat
    b       L_is_done

L_is_define:
    mov     x0, x19
    bl      _exec_define
    b       L_is_done

L_is_return:
    ldr     x9, [x19, #AST_F1]
    cbz     x9, L_is_ret_nothing
    sub     sp, sp, #32
    mov     x0, x9
    mov     x1, sp
    bl      _eval_expr
    adrp    x8, g_return_val@PAGE
    add     x8, x8, g_return_val@PAGEOFF
    ldp     x9, x10, [sp]
    stp     x9, x10, [x8]
    ldp     x9, x10, [sp, #16]
    stp     x9, x10, [x8, #16]
    add     sp, sp, #32
    b       L_is_ret_sig
L_is_ret_nothing:
    adrp    x8, g_return_val@PAGE
    add     x8, x8, g_return_val@PAGEOFF
    mov     x9, #TYPE_NOTHING
    str     x9, [x8]
    str     xzr, [x8, #8]
L_is_ret_sig:
    adrp    x8, g_signal@PAGE
    mov     x9, #SIG_RETURN
    str     x9, [x8, g_signal@PAGEOFF]
    b       L_is_done

L_is_append:
    mov     x0, x19
    bl      _exec_append
    b       L_is_done

L_is_stop:
    adrp    x8, g_signal@PAGE
    mov     x9, #SIG_STOP
    str     x9, [x8, g_signal@PAGEOFF]
    b       L_is_done

L_is_skip:
    adrp    x8, g_signal@PAGE
    mov     x9, #SIG_SKIP
    str     x9, [x8, g_signal@PAGEOFF]
    b       L_is_done

L_is_call:
    sub     sp, sp, #32
    mov     x0, x19
    mov     x1, sp
    bl      _eval_expr
    add     sp, sp, #32
    b       L_is_done

L_is_done:
    ldr     x19, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// =============================================================================
// Control flow executors
// =============================================================================

_exec_if:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    mov     x19, x0

    ldr     x0, [x19, #AST_F1]
    sub     sp, sp, #32
    mov     x1, sp
    bl      _eval_expr
    ldr     x9, [sp, #VAL_TYPE]
    cmp     x9, #TYPE_BOOL
    b.ne    L_eif_err
    ldr     x9, [sp, #VAL_DATA]
    add     sp, sp, #32
    cbnz    x9, L_eif_then

    // Otherwise ifs
    ldr     x20, [x19, #AST_F3]
    cbz     x20, L_eif_else
    ldr     x10, [x19, #AST_F4]
    mov     x11, #0
L_eif_oi:
    cmp     x11, x10
    b.ge    L_eif_else
    lsl     x12, x11, #4
    ldr     x13, [x20, x12]
    add     x12, x12, #8
    ldr     x14, [x20, x12]

    sub     sp, sp, #48
    str     x10, [sp, #32]
    str     x11, [sp, #40]
    mov     x0, x13
    mov     x1, sp
    bl      _eval_expr
    ldr     x9, [sp, #VAL_TYPE]
    cmp     x9, #TYPE_BOOL
    b.ne    L_eif_oi_err
    ldr     x9, [sp, #VAL_DATA]
    ldr     x10, [sp, #32]
    ldr     x11, [sp, #40]
    add     sp, sp, #48
    cbnz    x9, L_eif_oi_match

    add     x11, x11, #1
    b       L_eif_oi
L_eif_oi_match:
    mov     x0, x14
    bl      _interpret_block
    b       L_eif_done
L_eif_oi_err:
    add     sp, sp, #48
    b       L_eif_err2

L_eif_else:
    ldr     x9, [x19, #AST_F5]
    cbz     x9, L_eif_done
    mov     x0, x9
    bl      _interpret_block
    b       L_eif_done

L_eif_then:
    ldr     x0, [x19, #AST_F2]
    bl      _interpret_block
    b       L_eif_done

L_eif_err:
    add     sp, sp, #32
L_eif_err2:
    ldr     x0, [x19, #AST_LINE]
    adrp    x1, err_not_bool@PAGE
    add     x1, x1, err_not_bool@PAGEOFF
    mov     x2, x0
    bl      _die_err

L_eif_done:
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

_exec_while:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    str     x19, [sp, #-16]!
    mov     x19, x0
L_ew_loop:
    adrp    x8, g_signal@PAGE
    ldr     x9, [x8, g_signal@PAGEOFF]
    cbnz    x9, L_ew_done
    ldr     x0, [x19, #AST_F1]
    sub     sp, sp, #32
    mov     x1, sp
    bl      _eval_expr
    ldr     x9, [sp, #VAL_TYPE]
    cmp     x9, #TYPE_BOOL
    b.ne    L_ew_err
    ldr     x9, [sp, #VAL_DATA]
    add     sp, sp, #32
    cbz     x9, L_ew_done
    ldr     x0, [x19, #AST_F2]
    bl      _interpret_block
    adrp    x8, g_signal@PAGE
    ldr     x9, [x8, g_signal@PAGEOFF]
    cmp     x9, #SIG_STOP
    b.eq    L_ew_break
    cmp     x9, #SIG_SKIP
    b.eq    L_ew_cont
    b       L_ew_loop
L_ew_break:
    adrp    x8, g_signal@PAGE
    str     xzr, [x8, g_signal@PAGEOFF]
    b       L_ew_done
L_ew_cont:
    adrp    x8, g_signal@PAGE
    str     xzr, [x8, g_signal@PAGEOFF]
    b       L_ew_loop
L_ew_err:
    add     sp, sp, #32
    ldr     x0, [x19, #AST_LINE]
    adrp    x1, err_not_bool@PAGE
    add     x1, x1, err_not_bool@PAGEOFF
    mov     x2, x0
    bl      _die_err
L_ew_done:
    ldr     x19, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

_exec_for_each:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!

    mov     x19, x0
    ldr     x0, [x19, #AST_F2]
    sub     sp, sp, #32
    mov     x1, sp
    bl      _eval_expr
    ldr     x20, [sp, #VAL_DATA]
    ldr     x21, [sp, #VAL_LEN]
    add     sp, sp, #32
    mov     x22, #0

L_efe_loop:
    cmp     x22, x21
    b.ge    L_efe_done
    adrp    x8, g_signal@PAGE
    ldr     x9, [x8, g_signal@PAGEOFF]
    cmp     x9, #SIG_RETURN
    b.eq    L_efe_done

    mov     x9, #VAL_SIZE
    madd    x10, x22, x9, x20
    adrp    x8, g_env@PAGE
    ldr     x0, [x8, g_env@PAGEOFF]
    ldr     x1, [x19, #AST_F1]
    mov     x2, x10
    bl      _env_set_in_scope

    ldr     x0, [x19, #AST_F3]
    bl      _interpret_block

    adrp    x8, g_signal@PAGE
    ldr     x9, [x8, g_signal@PAGEOFF]
    cmp     x9, #SIG_STOP
    b.eq    L_efe_break
    cmp     x9, #SIG_SKIP
    b.eq    L_efe_cont
    add     x22, x22, #1
    b       L_efe_loop
L_efe_break:
    str     xzr, [x8, g_signal@PAGEOFF]
    b       L_efe_done
L_efe_cont:
    str     xzr, [x8, g_signal@PAGEOFF]
    add     x22, x22, #1
    b       L_efe_loop
L_efe_done:
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

_exec_for_from:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!

    mov     x19, x0
    ldr     x0, [x19, #AST_F2]
    sub     sp, sp, #32
    mov     x1, sp
    bl      _eval_expr
    ldr     d0, [sp, #VAL_DATA]
    fcvtzs  x20, d0
    add     sp, sp, #32

    ldr     x0, [x19, #AST_F3]
    sub     sp, sp, #32
    mov     x1, sp
    bl      _eval_expr
    ldr     d0, [sp, #VAL_DATA]
    fcvtzs  x21, d0
    add     sp, sp, #32

    mov     x22, x20
L_eff_loop:
    cmp     x22, x21
    b.gt    L_eff_done
    adrp    x8, g_signal@PAGE
    ldr     x9, [x8, g_signal@PAGEOFF]
    cmp     x9, #SIG_RETURN
    b.eq    L_eff_done

    sub     sp, sp, #32
    scvtf   d0, x22
    mov     x0, sp
    bl      _val_number
    adrp    x8, g_env@PAGE
    ldr     x0, [x8, g_env@PAGEOFF]
    ldr     x1, [x19, #AST_F1]
    mov     x2, sp
    bl      _env_set_in_scope
    add     sp, sp, #32

    ldr     x0, [x19, #AST_F4]
    bl      _interpret_block

    adrp    x8, g_signal@PAGE
    ldr     x9, [x8, g_signal@PAGEOFF]
    cmp     x9, #SIG_STOP
    b.eq    L_eff_break
    cmp     x9, #SIG_SKIP
    b.eq    L_eff_cont
    add     x22, x22, #1
    b       L_eff_loop
L_eff_break:
    str     xzr, [x8, g_signal@PAGEOFF]
    b       L_eff_done
L_eff_cont:
    str     xzr, [x8, g_signal@PAGEOFF]
    add     x22, x22, #1
    b       L_eff_loop
L_eff_done:
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

_exec_repeat:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    str     x21, [sp, #-16]!

    mov     x19, x0
    ldr     x0, [x19, #AST_F1]
    sub     sp, sp, #32
    mov     x1, sp
    bl      _eval_expr
    ldr     d0, [sp, #VAL_DATA]
    fcvtzs  x20, d0
    add     sp, sp, #32

    mov     x21, #0
L_er_loop:
    cmp     x21, x20
    b.ge    L_er_done
    adrp    x8, g_signal@PAGE
    ldr     x9, [x8, g_signal@PAGEOFF]
    cmp     x9, #SIG_RETURN
    b.eq    L_er_done
    ldr     x0, [x19, #AST_F2]
    bl      _interpret_block
    adrp    x8, g_signal@PAGE
    ldr     x9, [x8, g_signal@PAGEOFF]
    cmp     x9, #SIG_STOP
    b.eq    L_er_break
    cmp     x9, #SIG_SKIP
    b.eq    L_er_cont
    add     x21, x21, #1
    b       L_er_loop
L_er_break:
    str     xzr, [x8, g_signal@PAGEOFF]
    b       L_er_done
L_er_cont:
    str     xzr, [x8, g_signal@PAGEOFF]
    add     x21, x21, #1
    b       L_er_loop
L_er_done:
    ldr     x21, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

_exec_define:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    str     x19, [sp, #-16]!
    mov     x19, x0

    adrp    x8, g_func_count@PAGE
    ldr     x9, [x8, g_func_count@PAGEOFF]
    adrp    x10, g_func_cap@PAGE
    ldr     x11, [x10, g_func_cap@PAGEOFF]
    cmp     x9, x11
    b.lt    L_ed_room
    cbz     x11, L_ed_init
    lsl     x11, x11, #1
    b       L_ed_grow
L_ed_init:
    mov     x11, #32
L_ed_grow:
    str     x11, [x10, g_func_cap@PAGEOFF]
    adrp    x12, g_funcs@PAGE
    ldr     x0, [x12, g_funcs@PAGEOFF]
    mov     x1, #FUNC_SIZE
    mul     x1, x11, x1
    bl      _realloc
    adrp    x12, g_funcs@PAGE
    str     x0, [x12, g_funcs@PAGEOFF]

L_ed_room:
    adrp    x8, g_funcs@PAGE
    ldr     x8, [x8, g_funcs@PAGEOFF]
    adrp    x9, g_func_count@PAGE
    ldr     x10, [x9, g_func_count@PAGEOFF]
    mov     x11, #FUNC_SIZE
    madd    x12, x10, x11, x8

    ldr     x13, [x19, #AST_F1]
    str     x13, [x12, #FUNC_NAME]
    ldr     x13, [x19, #AST_F2]
    str     x13, [x12, #FUNC_PARAMS]
    ldr     x13, [x19, #AST_F3]
    str     x13, [x12, #FUNC_PARAMCNT]
    ldr     x13, [x19, #AST_F4]
    str     x13, [x12, #FUNC_BODY]
    ldr     x13, [x19, #AST_LINE]
    str     x13, [x12, #FUNC_LINE]

    add     x10, x10, #1
    str     x10, [x9, g_func_count@PAGEOFF]

    ldr     x19, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

_exec_append:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    mov     x19, x0

    ldr     x0, [x19, #AST_F1]
    sub     sp, sp, #32
    mov     x1, sp
    bl      _eval_expr

    adrp    x8, g_env@PAGE
    ldr     x0, [x8, g_env@PAGEOFF]
    ldr     x1, [x19, #AST_F2]
    bl      _env_get
    cbz     x0, L_ea_err
    mov     x20, x0

    ldr     x8, [x20, #VAL_DATA]
    ldr     x9, [x20, #VAL_LEN]
    ldr     x10, [x20, #VAL_CAP]

    cmp     x9, x10
    b.lt    L_ea_room
    cbz     x10, L_ea_init
    lsl     x10, x10, #1
    b       L_ea_grow
L_ea_init:
    mov     x10, #8
L_ea_grow:
    mov     x0, x8
    mov     x1, #VAL_SIZE
    mul     x1, x10, x1
    bl      _realloc
    mov     x8, x0
    str     x8, [x20, #VAL_DATA]
    str     x10, [x20, #VAL_CAP]

L_ea_room:
    ldr     x9, [x20, #VAL_LEN]
    mov     x11, #VAL_SIZE
    madd    x12, x9, x11, x8
    ldp     x13, x14, [sp]
    stp     x13, x14, [x12]
    ldp     x13, x14, [sp, #16]
    stp     x13, x14, [x12, #16]
    add     x9, x9, #1
    str     x9, [x20, #VAL_LEN]

    add     sp, sp, #32
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

L_ea_err:
    add     sp, sp, #32
    ldr     x0, [x19, #AST_LINE]
    adrp    x1, err_not_list@PAGE
    add     x1, x1, err_not_list@PAGEOFF
    mov     x2, x0
    bl      _die_err

// =============================================================================
// _eval_expr: x0=node, x1=out_val_ptr(32 bytes)
// =============================================================================
_eval_expr:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!

    mov     x19, x0
    mov     x20, x1
    cbz     x19, L_ee_nothing

    ldr     x9, [x19, #AST_TYPE]

    cmp     x9, #NODE_NUMBER_LIT
    b.eq    L_ee_num
    cmp     x9, #NODE_STRING_LIT
    b.eq    L_ee_str
    cmp     x9, #NODE_BOOL_LIT
    b.eq    L_ee_bool
    cmp     x9, #NODE_NOTHING_LIT
    b.eq    L_ee_nothing
    cmp     x9, #NODE_IDENT
    b.eq    L_ee_ident
    cmp     x9, #NODE_LIST_LIT
    b.eq    L_ee_list
    cmp     x9, #NODE_BINOP
    b.eq    L_ee_binop
    cmp     x9, #NODE_NEGATIVE
    b.eq    L_ee_neg
    cmp     x9, #NODE_PREFIX_OP
    b.eq    L_ee_prefix
    cmp     x9, #NODE_JOINED_WITH
    b.eq    L_ee_joined
    cmp     x9, #NODE_CONTAINS
    b.eq    L_ee_contains
    cmp     x9, #NODE_AS
    b.eq    L_ee_as
    cmp     x9, #NODE_ITEM_OF
    b.eq    L_ee_item
    cmp     x9, #NODE_SLICE_OF
    b.eq    L_ee_slice
    cmp     x9, #NODE_CALL
    b.eq    L_ee_call
    b       L_ee_nothing

L_ee_num:
    ldr     d0, [x19, #AST_F1]
    mov     x0, x20
    bl      _val_number
    b       L_ee_done

L_ee_str:
    ldr     x1, [x19, #AST_F1]
    mov     x0, x20
    bl      _val_string
    b       L_ee_done

L_ee_bool:
    ldr     x1, [x19, #AST_F1]
    mov     x0, x20
    bl      _val_bool
    b       L_ee_done

L_ee_nothing:
    mov     x0, x20
    bl      _val_nothing
    b       L_ee_done

L_ee_ident:
    ldr     x1, [x19, #AST_F1]
    adrp    x8, g_env@PAGE
    ldr     x0, [x8, g_env@PAGEOFF]
    bl      _env_get
    cbz     x0, L_ee_undef
    ldp     x9, x10, [x0]
    stp     x9, x10, [x20]
    ldp     x9, x10, [x0, #16]
    stp     x9, x10, [x20, #16]
    b       L_ee_done
L_ee_undef:
    ldr     x0, [x19, #AST_LINE]
    adrp    x1, err_undef_var@PAGE
    add     x1, x1, err_undef_var@PAGEOFF
    ldr     x2, [x19, #AST_F1]
    mov     x3, x2
    mov     x2, x0
    adrp    x0, ___stderrp@GOTPAGE
    ldr     x0, [x0, ___stderrp@GOTPAGEOFF]
    ldr     x0, [x0]
    bl      _fprintf_int_str
    mov     x0, #1
    bl      _exit

L_ee_list:
    ldr     x21, [x19, #AST_F1]
    ldr     x22, [x19, #AST_F2]
    cbz     x22, L_ee_list_empty
    mov     x0, #VAL_SIZE
    mul     x0, x22, x0
    bl      _malloc
    mov     x9, x0
    mov     x10, #0
L_ee_ll:
    cmp     x10, x22
    b.ge    L_ee_list_st
    ldr     x0, [x21, x10, lsl #3]
    mov     x11, #VAL_SIZE
    madd    x1, x10, x11, x9
    stp     x9, x10, [sp, #-16]!
    bl      _eval_expr
    ldp     x9, x10, [sp], #16
    add     x10, x10, #1
    b       L_ee_ll
L_ee_list_st:
    mov     x0, x20
    mov     x1, x9
    mov     x2, x22
    mov     x3, x22
    bl      _val_list
    b       L_ee_done
L_ee_list_empty:
    mov     x0, x20
    mov     x1, #0
    mov     x2, #0
    mov     x3, #0
    bl      _val_list
    b       L_ee_done

L_ee_neg:
    ldr     x0, [x19, #AST_F1]
    mov     x1, x20
    bl      _eval_expr
    ldr     d0, [x20, #VAL_DATA]
    fneg    d0, d0
    str     d0, [x20, #VAL_DATA]
    b       L_ee_done

L_ee_binop:
    ldr     x21, [x19, #AST_F3]   // op

    // Short-circuit for AND/OR
    cmp     x21, #OP_AND
    b.eq    L_ee_and
    cmp     x21, #OP_OR
    b.eq    L_ee_or

    // Eval both sides
    sub     sp, sp, #64
    ldr     x0, [x19, #AST_F1]
    mov     x1, sp
    bl      _eval_expr
    ldr     x0, [x19, #AST_F2]
    add     x1, sp, #32
    bl      _eval_expr

    ldr     x9, [sp, #VAL_TYPE]
    ldr     x10, [sp, #32]

    // Arithmetic
    cmp     x21, #OP_PLUS
    b.le    L_ee_arith
    cmp     x21, #OP_MODULO
    b.le    L_ee_arith
    b       L_ee_cmp

L_ee_arith:
    ldr     d0, [sp, #VAL_DATA]
    ldr     d1, [sp, #40]
    cmp     x21, #OP_PLUS
    b.eq    L_ee_a_add
    cmp     x21, #OP_MINUS
    b.eq    L_ee_a_sub
    cmp     x21, #OP_TIMES
    b.eq    L_ee_a_mul
    cmp     x21, #OP_DIVIDED_BY
    b.eq    L_ee_a_div
    cmp     x21, #OP_MODULO
    b.eq    L_ee_a_mod
    b       L_ee_a_done

L_ee_a_add:
    fadd    d0, d0, d1
    b       L_ee_a_done
L_ee_a_sub:
    fsub    d0, d0, d1
    b       L_ee_a_done
L_ee_a_mul:
    fmul    d0, d0, d1
    b       L_ee_a_done
L_ee_a_div:
    fcmp    d1, #0.0
    b.eq    L_ee_divzero
    fdiv    d0, d0, d1
    b       L_ee_a_done
L_ee_a_mod:
    fdiv    d2, d0, d1
    frintm  d2, d2
    fmul    d2, d2, d1
    fsub    d0, d0, d2

L_ee_a_done:
    add     sp, sp, #64
    mov     x0, x20
    bl      _val_number
    b       L_ee_done

L_ee_divzero:
    add     sp, sp, #64
    ldr     x0, [x19, #AST_LINE]
    adrp    x1, err_divzero@PAGE
    add     x1, x1, err_divzero@PAGEOFF
    mov     x2, x0
    bl      _die_err

L_ee_cmp:
    cmp     x21, #OP_EQ
    b.eq    L_ee_eq
    cmp     x21, #OP_NEQ
    b.eq    L_ee_neq

    // Ordering comparisons
    cmp     x9, #TYPE_NUMBER
    b.eq    L_ee_cmp_num
    cmp     x9, #TYPE_STRING
    b.eq    L_ee_cmp_str
    b       L_ee_cmp_false

L_ee_cmp_num:
    ldr     d0, [sp, #VAL_DATA]
    ldr     d1, [sp, #40]
    cmp     x21, #OP_GT
    b.eq    L_ee_gt
    cmp     x21, #OP_LT
    b.eq    L_ee_lt
    cmp     x21, #OP_GTE
    b.eq    L_ee_gte
    cmp     x21, #OP_LTE
    b.eq    L_ee_lte
    b       L_ee_cmp_false

L_ee_gt:
    fcmp    d0, d1
    b.gt    L_ee_cmp_true
    b       L_ee_cmp_false
L_ee_lt:
    fcmp    d0, d1
    b.lt    L_ee_cmp_true
    b       L_ee_cmp_false
L_ee_gte:
    fcmp    d0, d1
    b.ge    L_ee_cmp_true
    b       L_ee_cmp_false
L_ee_lte:
    fcmp    d0, d1
    b.le    L_ee_cmp_true
    b       L_ee_cmp_false

L_ee_cmp_str:
    ldr     x0, [sp, #VAL_DATA]
    ldr     x1, [sp, #40]
    bl      _strcmp
    cmp     x21, #OP_GT
    b.eq    L_ee_sgt
    cmp     x21, #OP_LT
    b.eq    L_ee_slt
    cmp     x21, #OP_GTE
    b.eq    L_ee_sgte
    b       L_ee_slte
L_ee_sgt:
    cmp     x0, #0
    b.gt    L_ee_cmp_true
    b       L_ee_cmp_false
L_ee_slt:
    cmp     x0, #0
    b.lt    L_ee_cmp_true
    b       L_ee_cmp_false
L_ee_sgte:
    cmp     x0, #0
    b.ge    L_ee_cmp_true
    b       L_ee_cmp_false
L_ee_slte:
    cmp     x0, #0
    b.le    L_ee_cmp_true
    b       L_ee_cmp_false

L_ee_eq:
    cmp     x9, x10
    b.ne    L_ee_cmp_false
    cmp     x9, #TYPE_NUMBER
    b.eq    L_ee_eq_num
    cmp     x9, #TYPE_STRING
    b.eq    L_ee_eq_str
    cmp     x9, #TYPE_BOOL
    b.eq    L_ee_eq_bool
    cmp     x9, #TYPE_NOTHING
    b.eq    L_ee_cmp_true
    b       L_ee_cmp_false
L_ee_eq_num:
    ldr     d0, [sp, #VAL_DATA]
    ldr     d1, [sp, #40]
    fcmp    d0, d1
    b.eq    L_ee_cmp_true
    b       L_ee_cmp_false
L_ee_eq_str:
    ldr     x0, [sp, #VAL_DATA]
    ldr     x1, [sp, #40]
    bl      _strcmp
    cbz     x0, L_ee_cmp_true
    b       L_ee_cmp_false
L_ee_eq_bool:
    ldr     x0, [sp, #VAL_DATA]
    ldr     x1, [sp, #40]
    cmp     x0, x1
    b.eq    L_ee_cmp_true
    b       L_ee_cmp_false

L_ee_neq:
    cmp     x9, x10
    b.ne    L_ee_cmp_true
    cmp     x9, #TYPE_NUMBER
    b.eq    L_ee_neq_num
    cmp     x9, #TYPE_STRING
    b.eq    L_ee_neq_str
    cmp     x9, #TYPE_BOOL
    b.eq    L_ee_neq_bool
    cmp     x9, #TYPE_NOTHING
    b.eq    L_ee_cmp_false
    b       L_ee_cmp_true
L_ee_neq_num:
    ldr     d0, [sp, #VAL_DATA]
    ldr     d1, [sp, #40]
    fcmp    d0, d1
    b.ne    L_ee_cmp_true
    b       L_ee_cmp_false
L_ee_neq_str:
    ldr     x0, [sp, #VAL_DATA]
    ldr     x1, [sp, #40]
    bl      _strcmp
    cbnz    x0, L_ee_cmp_true
    b       L_ee_cmp_false
L_ee_neq_bool:
    ldr     x0, [sp, #VAL_DATA]
    ldr     x1, [sp, #40]
    cmp     x0, x1
    b.ne    L_ee_cmp_true
    b       L_ee_cmp_false

L_ee_cmp_true:
    add     sp, sp, #64
    mov     x0, x20
    mov     x1, #1
    bl      _val_bool
    b       L_ee_done
L_ee_cmp_false:
    add     sp, sp, #64
    mov     x0, x20
    mov     x1, #0
    bl      _val_bool
    b       L_ee_done

L_ee_and:
    ldr     x0, [x19, #AST_F1]
    mov     x1, x20
    bl      _eval_expr
    ldr     x9, [x20, #VAL_DATA]
    cbz     x9, L_ee_done
    ldr     x0, [x19, #AST_F2]
    mov     x1, x20
    bl      _eval_expr
    b       L_ee_done

L_ee_or:
    ldr     x0, [x19, #AST_F1]
    mov     x1, x20
    bl      _eval_expr
    ldr     x9, [x20, #VAL_DATA]
    cbnz    x9, L_ee_done
    ldr     x0, [x19, #AST_F2]
    mov     x1, x20
    bl      _eval_expr
    b       L_ee_done

L_ee_prefix:
    ldr     x21, [x19, #AST_F2]
    ldr     x0, [x19, #AST_F1]
    mov     x1, x20
    bl      _eval_expr

    cmp     x21, #PRE_NOT
    b.eq    L_ee_p_not
    cmp     x21, #PRE_LENGTH
    b.eq    L_ee_p_len
    cmp     x21, #PRE_FIRST
    b.eq    L_ee_p_first
    cmp     x21, #PRE_LAST
    b.eq    L_ee_p_last
    cmp     x21, #PRE_UPPERCASE
    b.eq    L_ee_p_upper
    cmp     x21, #PRE_LOWERCASE
    b.eq    L_ee_p_lower
    b       L_ee_done

L_ee_p_not:
    ldr     x9, [x20, #VAL_DATA]
    eor     x9, x9, #1
    mov     x0, x20
    mov     x1, x9
    bl      _val_bool
    b       L_ee_done

L_ee_p_len:
    ldr     x9, [x20, #VAL_TYPE]
    cmp     x9, #TYPE_STRING
    b.eq    L_ee_pl_str
    cmp     x9, #TYPE_LIST
    b.eq    L_ee_pl_list
    b       L_ee_done
L_ee_pl_str:
    ldr     x0, [x20, #VAL_DATA]
    bl      _strlen
    scvtf   d0, x0
    mov     x0, x20
    bl      _val_number
    b       L_ee_done
L_ee_pl_list:
    ldr     x9, [x20, #VAL_LEN]
    scvtf   d0, x9
    mov     x0, x20
    bl      _val_number
    b       L_ee_done

L_ee_p_first:
    ldr     x9, [x20, #VAL_TYPE]
    cmp     x9, #TYPE_LIST
    b.ne    L_ee_done
    ldr     x9, [x20, #VAL_LEN]
    cbz     x9, L_ee_empty_err
    ldr     x8, [x20, #VAL_DATA]
    ldp     x9, x10, [x8]
    stp     x9, x10, [x20]
    ldp     x9, x10, [x8, #16]
    stp     x9, x10, [x20, #16]
    b       L_ee_done

L_ee_p_last:
    ldr     x9, [x20, #VAL_TYPE]
    cmp     x9, #TYPE_LIST
    b.ne    L_ee_done
    ldr     x9, [x20, #VAL_LEN]
    cbz     x9, L_ee_empty_err
    ldr     x8, [x20, #VAL_DATA]
    sub     x9, x9, #1
    mov     x10, #VAL_SIZE
    madd    x8, x9, x10, x8
    ldp     x9, x10, [x8]
    stp     x9, x10, [x20]
    ldp     x9, x10, [x8, #16]
    stp     x9, x10, [x20, #16]
    b       L_ee_done

L_ee_empty_err:
    ldr     x0, [x19, #AST_LINE]
    adrp    x1, err_empty_list@PAGE
    add     x1, x1, err_empty_list@PAGEOFF
    mov     x2, x0
    bl      _die_err

L_ee_p_upper:
    ldr     x0, [x20, #VAL_DATA]
    bl      _strdup
    mov     x21, x0
    mov     x9, #0
L_ee_ul:
    ldrb    w10, [x21, x9]
    cbz     w10, L_ee_ud
    cmp     w10, #'a'
    b.lt    L_ee_un
    cmp     w10, #'z'
    b.gt    L_ee_un
    sub     w10, w10, #32
    strb    w10, [x21, x9]
L_ee_un:
    add     x9, x9, #1
    b       L_ee_ul
L_ee_ud:
    mov     x0, x20
    mov     x1, x21
    bl      _val_string
    b       L_ee_done

L_ee_p_lower:
    ldr     x0, [x20, #VAL_DATA]
    bl      _strdup
    mov     x21, x0
    mov     x9, #0
L_ee_ll2:
    ldrb    w10, [x21, x9]
    cbz     w10, L_ee_ld
    cmp     w10, #'A'
    b.lt    L_ee_ln
    cmp     w10, #'Z'
    b.gt    L_ee_ln
    add     w10, w10, #32
    strb    w10, [x21, x9]
L_ee_ln:
    add     x9, x9, #1
    b       L_ee_ll2
L_ee_ld:
    mov     x0, x20
    mov     x1, x21
    bl      _val_string
    b       L_ee_done

L_ee_joined:
    sub     sp, sp, #32
    ldr     x0, [x19, #AST_F1]
    mov     x1, sp
    bl      _eval_expr
    mov     x0, sp
    bl      _value_to_string
    mov     x21, x0

    ldr     x0, [x19, #AST_F2]
    mov     x1, sp
    bl      _eval_expr
    mov     x0, sp
    bl      _value_to_string
    mov     x22, x0
    add     sp, sp, #32

    mov     x0, x21
    bl      _strlen
    mov     x9, x0
    mov     x0, x22
    bl      _strlen
    add     x10, x0, x9
    add     x10, x10, #1
    mov     x0, x10
    bl      _malloc
    mov     x9, x0
    mov     x0, x9
    mov     x1, x21
    bl      _strcpy
    mov     x0, x9
    mov     x1, x22
    bl      _strcat
    mov     x0, x21
    str     x9, [sp, #-16]!
    bl      _free
    mov     x0, x22
    bl      _free
    ldr     x9, [sp], #16
    mov     x0, x20
    mov     x1, x9
    bl      _val_string
    b       L_ee_done

L_ee_contains:
    sub     sp, sp, #64
    ldr     x0, [x19, #AST_F1]
    mov     x1, sp
    bl      _eval_expr
    ldr     x0, [x19, #AST_F2]
    add     x1, sp, #32
    bl      _eval_expr
    ldr     x9, [sp, #VAL_TYPE]
    cmp     x9, #TYPE_STRING
    b.eq    L_ee_cont_str
    cmp     x9, #TYPE_LIST
    b.eq    L_ee_cont_list
    b       L_ee_cont_false

L_ee_cont_str:
    ldr     x0, [sp, #VAL_DATA]
    ldr     x1, [sp, #40]
    bl      _strstr
    cmp     x0, #0
    b.ne    L_ee_cont_true
    b       L_ee_cont_false

L_ee_cont_list:
    ldr     x8, [sp, #VAL_DATA]
    ldr     x9, [sp, #VAL_LEN]
    mov     x10, #0
L_ee_cl_loop:
    cmp     x10, x9
    b.ge    L_ee_cont_false
    mov     x11, #VAL_SIZE
    madd    x12, x10, x11, x8
    ldr     x13, [x12, #VAL_TYPE]
    ldr     x14, [sp, #32]
    cmp     x13, x14
    b.ne    L_ee_cl_next

    cmp     x13, #TYPE_NUMBER
    b.ne    L_ee_cl_ns
    ldr     d0, [x12, #VAL_DATA]
    ldr     d1, [sp, #40]
    fcmp    d0, d1
    b.eq    L_ee_cont_true
    b       L_ee_cl_next
L_ee_cl_ns:
    cmp     x13, #TYPE_STRING
    b.ne    L_ee_cl_nb
    ldr     x0, [x12, #VAL_DATA]
    ldr     x1, [sp, #40]
    stp     x8, x9, [sp, #-16]!
    str     x10, [sp, #-16]!
    bl      _strcmp
    ldr     x10, [sp], #16
    ldp     x8, x9, [sp], #16
    cbz     x0, L_ee_cont_true
    b       L_ee_cl_next
L_ee_cl_nb:
    cmp     x13, #TYPE_BOOL
    b.ne    L_ee_cl_next
    ldr     x0, [x12, #VAL_DATA]
    ldr     x1, [sp, #40]
    cmp     x0, x1
    b.eq    L_ee_cont_true
L_ee_cl_next:
    add     x10, x10, #1
    b       L_ee_cl_loop

L_ee_cont_true:
    add     sp, sp, #64
    mov     x0, x20
    mov     x1, #1
    bl      _val_bool
    b       L_ee_done
L_ee_cont_false:
    add     sp, sp, #64
    mov     x0, x20
    mov     x1, #0
    bl      _val_bool
    b       L_ee_done

L_ee_as:
    ldr     x0, [x19, #AST_F1]
    mov     x1, x20
    bl      _eval_expr
    ldr     x21, [x19, #AST_F2]

    cmp     x21, #TOK_NUMBER_KW
    b.eq    L_ee_as_num
    cmp     x21, #TOK_STRING_KW
    b.eq    L_ee_as_str
    cmp     x21, #TOK_BOOLEAN_KW
    b.eq    L_ee_as_bool
    b       L_ee_done

L_ee_as_num:
    ldr     x9, [x20, #VAL_TYPE]
    cmp     x9, #TYPE_STRING
    b.eq    L_ee_as_num_str
    cmp     x9, #TYPE_NUMBER
    b.eq    L_ee_done
    b       L_ee_conv_err
L_ee_as_num_str:
    ldr     x0, [x20, #VAL_DATA]
    bl      _atof
    mov     x0, x20
    bl      _val_number
    b       L_ee_done

L_ee_as_str:
    mov     x0, x20
    bl      _value_to_string
    mov     x1, x0
    mov     x0, x20
    bl      _val_string
    b       L_ee_done

L_ee_as_bool:
    ldr     x9, [x20, #VAL_TYPE]
    cmp     x9, #TYPE_NUMBER
    b.eq    L_ee_asb_num
    cmp     x9, #TYPE_STRING
    b.eq    L_ee_asb_str
    cmp     x9, #TYPE_BOOL
    b.eq    L_ee_done
    cmp     x9, #TYPE_LIST
    b.eq    L_ee_asb_list
    b       L_ee_asb_false      // nothing -> false
L_ee_asb_num:
    ldr     d0, [x20, #VAL_DATA]
    fcmp    d0, #0.0
    b.eq    L_ee_asb_false
    b       L_ee_asb_true
L_ee_asb_str:
    ldr     x0, [x20, #VAL_DATA]
    ldrb    w9, [x0]
    cbz     w9, L_ee_asb_false
    b       L_ee_asb_true
L_ee_asb_list:
    ldr     x9, [x20, #VAL_LEN]
    cbz     x9, L_ee_asb_false
    b       L_ee_asb_true
L_ee_asb_true:
    mov     x0, x20
    mov     x1, #1
    bl      _val_bool
    b       L_ee_done
L_ee_asb_false:
    mov     x0, x20
    mov     x1, #0
    bl      _val_bool
    b       L_ee_done

L_ee_conv_err:
    ldr     x0, [x19, #AST_LINE]
    adrp    x1, err_conv@PAGE
    add     x1, x1, err_conv@PAGEOFF
    mov     x2, x0
    bl      _die_err

L_ee_item:
    sub     sp, sp, #64
    ldr     x0, [x19, #AST_F1]
    mov     x1, sp
    bl      _eval_expr
    ldr     d0, [sp, #VAL_DATA]
    fcvtzs  x21, d0

    ldr     x0, [x19, #AST_F2]
    add     x1, sp, #32
    bl      _eval_expr

    ldr     x8, [sp, #40]
    ldr     x9, [sp, #48]
    add     sp, sp, #64

    cmp     x21, #0
    b.lt    L_ee_item_oob
    cmp     x21, x9
    b.ge    L_ee_item_oob

    mov     x10, #VAL_SIZE
    madd    x11, x21, x10, x8
    ldp     x12, x13, [x11]
    stp     x12, x13, [x20]
    ldp     x12, x13, [x11, #16]
    stp     x12, x13, [x20, #16]
    b       L_ee_done

L_ee_item_oob:
    ldr     x0, [x19, #AST_LINE]
    adrp    x1, err_index_oob@PAGE
    add     x1, x1, err_index_oob@PAGEOFF
    mov     x2, x0
    bl      _die_err

L_ee_slice:
    sub     sp, sp, #96
    ldr     x0, [x19, #AST_F1]
    mov     x1, sp
    bl      _eval_expr
    ldr     x0, [x19, #AST_F2]
    add     x1, sp, #32
    bl      _eval_expr
    ldr     d0, [sp, #40]
    fcvtzs  x21, d0
    ldr     x0, [x19, #AST_F3]
    add     x1, sp, #64
    bl      _eval_expr
    ldr     d0, [sp, #72]
    fcvtzs  x22, d0

    ldr     x9, [sp, #VAL_TYPE]
    cmp     x9, #TYPE_STRING
    b.eq    L_ee_sl_str
    cmp     x9, #TYPE_LIST
    b.eq    L_ee_sl_list
    add     sp, sp, #96
    mov     x0, x20
    bl      _val_nothing
    b       L_ee_done

L_ee_sl_str:
    ldr     x8, [sp, #VAL_DATA]
    sub     x9, x22, x21
    cmp     x9, #0
    b.le    L_ee_sl_empty_s
    add     x0, x9, #1
    stp     x8, x9, [sp, #-16]!
    bl      _malloc
    ldp     x8, x9, [sp], #16
    mov     x10, x0
    mov     x11, #0
L_ee_sl_sc:
    cmp     x11, x9
    b.ge    L_ee_sl_sd
    add     x12, x21, x11
    ldrb    w13, [x8, x12]
    strb    w13, [x10, x11]
    add     x11, x11, #1
    b       L_ee_sl_sc
L_ee_sl_sd:
    strb    wzr, [x10, x9]
    add     sp, sp, #96
    mov     x0, x20
    mov     x1, x10
    bl      _val_string
    b       L_ee_done
L_ee_sl_empty_s:
    add     sp, sp, #96
    adrp    x1, empty_str@PAGE
    add     x1, x1, empty_str@PAGEOFF
    mov     x0, x20
    bl      _val_string
    b       L_ee_done

L_ee_sl_list:
    ldr     x8, [sp, #VAL_DATA]
    sub     x10, x22, x21
    cmp     x10, #0
    b.le    L_ee_sl_empty_l
    mov     x0, #VAL_SIZE
    mul     x0, x10, x0
    stp     x8, x10, [sp, #-16]!
    bl      _malloc
    ldp     x8, x10, [sp], #16
    mov     x11, x0
    mov     x12, #0
L_ee_sl_lc:
    cmp     x12, x10
    b.ge    L_ee_sl_ld
    add     x13, x21, x12
    mov     x14, #VAL_SIZE
    madd    x15, x13, x14, x8
    madd    x13, x12, x14, x11
    ldp     x0, x1, [x15]
    stp     x0, x1, [x13]
    ldp     x0, x1, [x15, #16]
    stp     x0, x1, [x13, #16]
    add     x12, x12, #1
    b       L_ee_sl_lc
L_ee_sl_ld:
    add     sp, sp, #96
    mov     x0, x20
    mov     x1, x11
    mov     x2, x10
    mov     x3, x10
    bl      _val_list
    b       L_ee_done
L_ee_sl_empty_l:
    add     sp, sp, #96
    mov     x0, x20
    mov     x1, #0
    mov     x2, #0
    mov     x3, #0
    bl      _val_list
    b       L_ee_done

L_ee_call:
    mov     x0, x19
    mov     x1, x20
    bl      _exec_call
    b       L_ee_done

L_ee_done:
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

// =============================================================================
// _exec_call: x0=CALL node, x1=output val ptr
// =============================================================================
_exec_call:
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    stp     x19, x20, [sp, #-16]!
    stp     x21, x22, [sp, #-16]!
    stp     x23, x24, [sp, #-16]!
    stp     x25, x26, [sp, #-16]!

    mov     x19, x0
    mov     x20, x1
    ldr     x21, [x19, #AST_F1]   // name
    ldr     x22, [x19, #AST_F2]   // args
    ldr     x23, [x19, #AST_F3]   // arg count

    // Find function
    adrp    x8, g_funcs@PAGE
    ldr     x8, [x8, g_funcs@PAGEOFF]
    adrp    x9, g_func_count@PAGE
    ldr     x9, [x9, g_func_count@PAGEOFF]
    mov     x10, #0
L_ec_find:
    cmp     x10, x9
    b.ge    L_ec_undef
    mov     x11, #FUNC_SIZE
    madd    x12, x10, x11, x8
    ldr     x13, [x12, #FUNC_NAME]
    mov     x0, x21
    mov     x1, x13
    stp     x8, x9, [sp, #-16]!
    stp     x10, x12, [sp, #-16]!
    bl      _strcmp
    ldp     x10, x12, [sp], #16
    ldp     x8, x9, [sp], #16
    cbz     x0, L_ec_found
    add     x10, x10, #1
    b       L_ec_find

L_ec_found:
    ldr     x24, [x12, #FUNC_PARAMS]
    ldr     x25, [x12, #FUNC_PARAMCNT]
    ldr     x26, [x12, #FUNC_BODY]

    // Create new scope
    adrp    x8, g_env@PAGE
    ldr     x0, [x8, g_env@PAGEOFF]
    bl      _env_push
    // Save old env on stack
    adrp    x8, g_env@PAGE
    ldr     x9, [x8, g_env@PAGEOFF]
    str     x9, [sp, #-16]!
    str     x0, [x8, g_env@PAGEOFF]

    // Bind args to params
    mov     x10, #0
L_ec_bind:
    cmp     x10, x25
    b.ge    L_ec_exec
    cmp     x10, x23
    b.ge    L_ec_exec

    ldr     x0, [x22, x10, lsl #3]
    sub     sp, sp, #32
    mov     x1, sp
    str     x10, [sp, #-16]!
    bl      _eval_expr
    ldr     x10, [sp], #16

    adrp    x8, g_env@PAGE
    ldr     x0, [x8, g_env@PAGEOFF]
    ldr     x1, [x24, x10, lsl #3]
    mov     x2, sp
    str     x10, [sp, #-16]!
    bl      _env_set
    ldr     x10, [sp], #16
    add     sp, sp, #32

    add     x10, x10, #1
    b       L_ec_bind

L_ec_exec:
    adrp    x8, g_signal@PAGE
    str     xzr, [x8, g_signal@PAGEOFF]

    mov     x0, x26
    bl      _interpret_block

    adrp    x8, g_signal@PAGE
    ldr     x9, [x8, g_signal@PAGEOFF]
    cmp     x9, #SIG_RETURN
    b.ne    L_ec_no_ret

    adrp    x8, g_return_val@PAGE
    add     x8, x8, g_return_val@PAGEOFF
    ldp     x9, x10, [x8]
    stp     x9, x10, [x20]
    ldp     x9, x10, [x8, #16]
    stp     x9, x10, [x20, #16]
    b       L_ec_cleanup

L_ec_no_ret:
    mov     x0, x20
    bl      _val_nothing

L_ec_cleanup:
    adrp    x8, g_signal@PAGE
    str     xzr, [x8, g_signal@PAGEOFF]

    // Restore env
    ldr     x9, [sp], #16
    adrp    x8, g_env@PAGE
    str     x9, [x8, g_env@PAGEOFF]

    ldp     x25, x26, [sp], #16
    ldp     x23, x24, [sp], #16
    ldp     x21, x22, [sp], #16
    ldp     x19, x20, [sp], #16
    ldp     x29, x30, [sp], #16
    ret

L_ec_undef:
    ldr     x0, [x19, #AST_LINE]
    adrp    x1, err_undef_fn@PAGE
    add     x1, x1, err_undef_fn@PAGEOFF
    ldr     x2, [x19, #AST_F1]
    mov     x3, x2
    mov     x2, x0
    adrp    x0, ___stderrp@GOTPAGE
    ldr     x0, [x0, ___stderrp@GOTPAGEOFF]
    ldr     x0, [x0]
    bl      _fprintf_int_str
    mov     x0, #1
    bl      _exit
