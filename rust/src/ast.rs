/// AST nodes for humanlang.

#[derive(Debug, Clone)]
#[allow(dead_code)]
pub enum Stmt {
    Print {
        expr: Expr,
        line: usize,
    },
    Set {
        name: String,
        expr: Expr,
        line: usize,
    },
    Append {
        value: Expr,
        list_name: String,
        line: usize,
    },
    If {
        condition: Expr,
        body: Vec<Stmt>,
        otherwise_ifs: Vec<(Expr, Vec<Stmt>)>,
        otherwise: Option<Vec<Stmt>>,
        line: usize,
    },
    While {
        condition: Expr,
        body: Vec<Stmt>,
        line: usize,
    },
    ForEach {
        var_name: String,
        iterable: Expr,
        body: Vec<Stmt>,
        line: usize,
    },
    ForFrom {
        var_name: String,
        from: Expr,
        to: Expr,
        body: Vec<Stmt>,
        line: usize,
    },
    Repeat {
        count: Expr,
        body: Vec<Stmt>,
        line: usize,
    },
    Define {
        name: String,
        params: Vec<String>,
        body: Vec<Stmt>,
        line: usize,
    },
    Return {
        value: Option<Expr>,
        line: usize,
    },
    Stop {
        line: usize,
    },
    Skip {
        line: usize,
    },
    ExprStmt {
        expr: Expr,
        line: usize,
    },
}

#[derive(Debug, Clone)]
pub enum Expr {
    NumberLit(f64),
    StringLit(String),
    BoolLit(bool),
    NothingLit,
    ListLit(Vec<Expr>),
    Identifier(String, usize), // name, line

    // Arithmetic
    BinOp {
        left: Box<Expr>,
        op: BinOpKind,
        right: Box<Expr>,
    },
    Negative(Box<Expr>),

    // Comparison
    Compare {
        left: Box<Expr>,
        op: CmpOp,
        right: Box<Expr>,
    },

    // Logical
    LogicalAnd(Box<Expr>, Box<Expr>),
    LogicalOr(Box<Expr>, Box<Expr>),
    LogicalNot(Box<Expr>),

    // String/list operations
    JoinedWith(Box<Expr>, Box<Expr>),
    Contains(Box<Expr>, Box<Expr>),
    UppercaseOf(Box<Expr>),
    LowercaseOf(Box<Expr>),
    LengthOf(Box<Expr>),
    FirstOf(Box<Expr>),
    LastOf(Box<Expr>),
    ItemOf {
        index: Box<Expr>,
        list: Box<Expr>,
    },
    SliceOf {
        value: Box<Expr>,
        from: Box<Expr>,
        to: Box<Expr>,
    },

    // Type conversion
    AsType(Box<Expr>, TypeName),

    // Function call
    Call {
        name: String,
        args: Vec<Expr>,
        line: usize,
    },
}

#[derive(Debug, Clone, Copy)]
pub enum BinOpKind {
    Plus,
    Minus,
    Times,
    DividedBy,
    Modulo,
}

#[derive(Debug, Clone, Copy)]
pub enum CmpOp {
    Equal,
    NotEqual,
    GreaterThan,
    LessThan,
    AtLeast,
    AtMost,
}

#[derive(Debug, Clone, Copy)]
pub enum TypeName {
    Number,
    StringT,
    Boolean,
}
