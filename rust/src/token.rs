/// Token types for humanlang.

#[derive(Debug, Clone, PartialEq)]
pub enum Token {
    // Literals
    NumberLit(f64),
    StringLit(String),
    True,
    False,
    Nothing,

    // Identifiers
    Identifier(String),

    // Keywords - statements
    Print,
    Set,
    To,
    If,
    Otherwise,
    OtherwiseIf,
    While,
    ForEach,
    For,
    From,
    In,
    Repeat,
    Define,
    With,
    Call,
    Return,
    Append,
    Stop,
    Skip,

    // Arithmetic operators
    Plus,
    Minus,
    TimesOp, // "times" in expression context
    DividedBy,
    Modulo,
    Negative,

    // Comparison operators (multi-word)
    IsEqualTo,
    IsNotEqualTo,
    IsGreaterThan,
    IsLessThan,
    IsAtLeast,
    IsAtMost,

    // Logical operators
    And,
    Or,
    Not,

    // String/list operations
    JoinedWith,
    Contains,
    UppercaseOf,
    LowercaseOf,
    LengthOf,
    FirstOf,
    LastOf,
    Item,
    Of,
    SliceOf,

    // Type conversion
    As,
    NumberType,
    StringType,
    BooleanType,

    // Delimiters
    LeftParen,
    RightParen,
    LeftBracket,
    RightBracket,
    Comma,
    Colon,

    // Indentation
    Indent,
    Dedent,
    Newline,

    // End of file
    Eof,
}

#[derive(Debug, Clone)]
pub struct LocToken {
    pub token: Token,
    pub line: usize,
}
