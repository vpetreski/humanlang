use crate::ast::*;
use crate::token::{LocToken, Token};

pub struct Parser {
    tokens: Vec<LocToken>,
    pos: usize,
}

impl Parser {
    pub fn new(tokens: Vec<LocToken>) -> Self {
        Parser { tokens, pos: 0 }
    }

    pub fn parse(&mut self) -> Result<Vec<Stmt>, String> {
        let mut stmts = Vec::new();
        self.skip_newlines();
        while !self.check(Token::Eof) {
            let stmt = self.parse_statement()?;
            stmts.push(stmt);
            self.skip_newlines();
        }
        Ok(stmts)
    }

    fn parse_statement(&mut self) -> Result<Stmt, String> {
        let line = self.current_line();
        match self.current_token() {
            Token::Print => self.parse_print(),
            Token::Set => self.parse_set(),
            Token::Append => self.parse_append(),
            Token::If => self.parse_if(),
            Token::While => self.parse_while(),
            Token::ForEach => self.parse_for_each(),
            Token::For => self.parse_for_from(),
            Token::Repeat => self.parse_repeat(),
            Token::Define => self.parse_define(),
            Token::Return => self.parse_return(),
            Token::Stop => {
                self.advance();
                self.expect_newline_or_eof()?;
                Ok(Stmt::Stop { line })
            }
            Token::Skip => {
                self.advance();
                self.expect_newline_or_eof()?;
                Ok(Stmt::Skip { line })
            }
            Token::Call => {
                let expr = self.parse_call_expr()?;
                self.expect_newline_or_eof()?;
                Ok(Stmt::ExprStmt { expr, line })
            }
            _ => {
                Err(format!("Error on line {}: unexpected token {:?}", line, self.current_token()))
            }
        }
    }

    fn parse_print(&mut self) -> Result<Stmt, String> {
        let line = self.current_line();
        self.advance(); // skip 'print'
        let expr = self.parse_expression()?;
        self.expect_newline_or_eof()?;
        Ok(Stmt::Print { expr, line })
    }

    fn parse_set(&mut self) -> Result<Stmt, String> {
        let line = self.current_line();
        self.advance(); // skip 'set'
        let name = self.expect_identifier()?;
        self.expect(Token::To)?;
        let expr = self.parse_expression()?;
        self.expect_newline_or_eof()?;
        Ok(Stmt::Set { name, expr, line })
    }

    fn parse_append(&mut self) -> Result<Stmt, String> {
        let line = self.current_line();
        self.advance(); // skip 'append'
        // Parse value as a call-arg level expression (stops at bare "to" since
        // "to" is not an operator). Actually "to" is consumed by expect(Token::To)
        // below, so full expression is fine unless it contains "to" as an operator.
        // "to" is only a keyword, not an operator, so parse_expression is safe.
        let value = self.parse_expression()?;
        self.expect(Token::To)?;
        let list_name = self.expect_identifier()?;
        self.expect_newline_or_eof()?;
        Ok(Stmt::Append { value, list_name, line })
    }

    fn parse_if(&mut self) -> Result<Stmt, String> {
        let line = self.current_line();
        self.advance(); // skip 'if'
        let condition = self.parse_expression()?;
        self.expect(Token::Colon)?;
        let body = self.parse_block()?;

        let mut otherwise_ifs = Vec::new();
        let mut otherwise = None;

        loop {
            self.skip_newlines();
            if self.check(Token::OtherwiseIf) {
                self.advance();
                let cond = self.parse_expression()?;
                self.expect(Token::Colon)?;
                let blk = self.parse_block()?;
                otherwise_ifs.push((cond, blk));
            } else if self.check(Token::Otherwise) {
                self.advance();
                self.expect(Token::Colon)?;
                otherwise = Some(self.parse_block()?);
                break;
            } else {
                break;
            }
        }

        Ok(Stmt::If { condition, body, otherwise_ifs, otherwise, line })
    }

    fn parse_while(&mut self) -> Result<Stmt, String> {
        let line = self.current_line();
        self.advance(); // skip 'while'
        let condition = self.parse_expression()?;
        self.expect(Token::Colon)?;
        let body = self.parse_block()?;
        Ok(Stmt::While { condition, body, line })
    }

    fn parse_for_each(&mut self) -> Result<Stmt, String> {
        let line = self.current_line();
        self.advance(); // skip 'for each'
        let var_name = self.expect_identifier()?;
        self.expect(Token::In)?;
        let iterable = self.parse_expression()?;
        self.expect(Token::Colon)?;
        let body = self.parse_block()?;
        Ok(Stmt::ForEach { var_name, iterable, body, line })
    }

    fn parse_for_from(&mut self) -> Result<Stmt, String> {
        let line = self.current_line();
        self.advance(); // skip 'for'
        let var_name = self.expect_identifier()?;
        self.expect(Token::From)?;
        let from = self.parse_expression()?;
        self.expect(Token::To)?;
        let to = self.parse_expression()?;
        self.expect(Token::Colon)?;
        let body = self.parse_block()?;
        Ok(Stmt::ForFrom { var_name, from, to, body, line })
    }

    fn parse_repeat(&mut self) -> Result<Stmt, String> {
        let line = self.current_line();
        self.advance(); // skip 'repeat'
        // Parse count expression, but stop before "times" keyword.
        // Use parse_unary to avoid consuming "times" as multiplication.
        let count = self.parse_unary()?;
        // Expect "times" then ":"
        self.expect(Token::TimesOp)?;
        self.expect(Token::Colon)?;
        let body = self.parse_block()?;
        Ok(Stmt::Repeat { count, body, line })
    }

    fn parse_define(&mut self) -> Result<Stmt, String> {
        let line = self.current_line();
        self.advance(); // skip 'define'
        let name = self.expect_identifier()?;

        let mut params = Vec::new();
        if self.check(Token::With) {
            self.advance();
            params.push(self.expect_identifier()?);
            while self.check(Token::And) {
                self.advance();
                params.push(self.expect_identifier()?);
            }
        }

        self.expect(Token::Colon)?;
        let body = self.parse_block()?;
        Ok(Stmt::Define { name, params, body, line })
    }

    fn parse_return(&mut self) -> Result<Stmt, String> {
        let line = self.current_line();
        self.advance(); // skip 'return'

        // Check if there's an expression to return
        if self.check(Token::Newline) || self.check(Token::Eof) || self.check(Token::Dedent) {
            self.expect_newline_or_eof()?;
            return Ok(Stmt::Return { value: None, line });
        }

        let value = Some(self.parse_expression()?);
        self.expect_newline_or_eof()?;
        Ok(Stmt::Return { value, line })
    }

    fn parse_block(&mut self) -> Result<Vec<Stmt>, String> {
        self.expect(Token::Newline)?;
        self.expect(Token::Indent)?;

        let mut stmts = Vec::new();
        self.skip_newlines();
        while !self.check(Token::Dedent) && !self.check(Token::Eof) {
            let stmt = self.parse_statement()?;
            stmts.push(stmt);
            self.skip_newlines();
        }

        if self.check(Token::Dedent) {
            self.advance();
        }

        Ok(stmts)
    }

    // Expression parsing with precedence climbing

    fn parse_expression(&mut self) -> Result<Expr, String> {
        self.parse_or()
    }

    /// Parse an expression that stops at `and` tokens (used for call arguments
    /// and define parameter lists where `and` is an argument separator).
    fn parse_call_arg(&mut self) -> Result<Expr, String> {
        self.parse_not()
    }

    fn parse_or(&mut self) -> Result<Expr, String> {
        let mut left = self.parse_and()?;
        while self.check(Token::Or) {
            self.advance();
            let right = self.parse_and()?;
            left = Expr::LogicalOr(Box::new(left), Box::new(right));
        }
        Ok(left)
    }

    fn parse_and(&mut self) -> Result<Expr, String> {
        let mut left = self.parse_not()?;
        while self.check(Token::And) {
            self.advance();
            let right = self.parse_not()?;
            left = Expr::LogicalAnd(Box::new(left), Box::new(right));
        }
        Ok(left)
    }

    fn parse_not(&mut self) -> Result<Expr, String> {
        if self.check(Token::Not) {
            self.advance();
            let expr = self.parse_not()?;
            return Ok(Expr::LogicalNot(Box::new(expr)));
        }
        self.parse_comparison()
    }

    fn parse_comparison(&mut self) -> Result<Expr, String> {
        let mut left = self.parse_addition()?;

        loop {
            let op = match self.current_token() {
                Token::IsEqualTo => CmpOp::Equal,
                Token::IsNotEqualTo => CmpOp::NotEqual,
                Token::IsGreaterThan => CmpOp::GreaterThan,
                Token::IsLessThan => CmpOp::LessThan,
                Token::IsAtLeast => CmpOp::AtLeast,
                Token::IsAtMost => CmpOp::AtMost,
                _ => break,
            };
            self.advance();
            let right = self.parse_addition()?;
            left = Expr::Compare {
                left: Box::new(left),
                op,
                right: Box::new(right),
            };
        }

        Ok(left)
    }

    fn parse_addition(&mut self) -> Result<Expr, String> {
        let mut left = self.parse_multiplication()?;

        loop {
            match self.current_token() {
                Token::Plus => {
                    self.advance();
                    let right = self.parse_multiplication()?;
                    left = Expr::BinOp {
                        left: Box::new(left),
                        op: BinOpKind::Plus,
                        right: Box::new(right),
                    };
                }
                Token::Minus => {
                    self.advance();
                    let right = self.parse_multiplication()?;
                    left = Expr::BinOp {
                        left: Box::new(left),
                        op: BinOpKind::Minus,
                        right: Box::new(right),
                    };
                }
                _ => break,
            }
        }

        Ok(left)
    }

    fn parse_multiplication(&mut self) -> Result<Expr, String> {
        let mut left = self.parse_unary()?;

        loop {
            match self.current_token() {
                Token::TimesOp => {
                    // Check if this is "times:" (part of repeat statement) rather than multiplication.
                    // If the next token after "times" is ":", this is the repeat keyword, not multiplication.
                    if self.peek_token(1) == Token::Colon {
                        break;
                    }
                    self.advance();
                    let right = self.parse_unary()?;
                    left = Expr::BinOp {
                        left: Box::new(left),
                        op: BinOpKind::Times,
                        right: Box::new(right),
                    };
                }
                Token::DividedBy => {
                    self.advance();
                    let right = self.parse_unary()?;
                    left = Expr::BinOp {
                        left: Box::new(left),
                        op: BinOpKind::DividedBy,
                        right: Box::new(right),
                    };
                }
                Token::Modulo => {
                    self.advance();
                    let right = self.parse_unary()?;
                    left = Expr::BinOp {
                        left: Box::new(left),
                        op: BinOpKind::Modulo,
                        right: Box::new(right),
                    };
                }
                _ => break,
            }
        }

        Ok(left)
    }

    fn parse_unary(&mut self) -> Result<Expr, String> {
        if self.check(Token::Negative) {
            self.advance();
            let expr = self.parse_postfix()?;
            return Ok(Expr::Negative(Box::new(expr)));
        }
        self.parse_postfix()
    }

    fn parse_postfix(&mut self) -> Result<Expr, String> {
        let mut left = self.parse_primary()?;

        loop {
            match self.current_token() {
                Token::JoinedWith => {
                    self.advance();
                    let right = self.parse_primary()?;
                    left = Expr::JoinedWith(Box::new(left), Box::new(right));
                }
                Token::As => {
                    self.advance();
                    let type_name = match self.current_token() {
                        Token::NumberType => TypeName::Number,
                        Token::StringType => TypeName::StringT,
                        Token::BooleanType => TypeName::Boolean,
                        _ => return Err(format!("Error on line {}: expected type name after 'as'", self.current_line())),
                    };
                    self.advance();
                    left = Expr::AsType(Box::new(left), type_name);
                }
                Token::Contains => {
                    self.advance();
                    let right = self.parse_primary()?;
                    left = Expr::Contains(Box::new(left), Box::new(right));
                }
                _ => break,
            }
        }

        Ok(left)
    }

    fn parse_primary(&mut self) -> Result<Expr, String> {
        let line = self.current_line();
        match self.current_token() {
            Token::NumberLit(n) => {
                let val = n;
                self.advance();
                Ok(Expr::NumberLit(val))
            }
            Token::StringLit(s) => {
                let val = s;
                self.advance();
                Ok(Expr::StringLit(val))
            }
            Token::True => {
                self.advance();
                Ok(Expr::BoolLit(true))
            }
            Token::False => {
                self.advance();
                Ok(Expr::BoolLit(false))
            }
            Token::Nothing => {
                self.advance();
                Ok(Expr::NothingLit)
            }
            Token::LeftParen => {
                self.advance();
                let expr = self.parse_expression()?;
                self.expect(Token::RightParen)?;
                Ok(expr)
            }
            Token::LeftBracket => {
                self.parse_list_literal()
            }
            Token::Call => {
                self.parse_call_expr()
            }
            Token::UppercaseOf => {
                self.advance();
                let expr = self.parse_primary()?;
                Ok(Expr::UppercaseOf(Box::new(expr)))
            }
            Token::LowercaseOf => {
                self.advance();
                let expr = self.parse_primary()?;
                Ok(Expr::LowercaseOf(Box::new(expr)))
            }
            Token::LengthOf => {
                self.advance();
                let expr = self.parse_primary()?;
                Ok(Expr::LengthOf(Box::new(expr)))
            }
            Token::FirstOf => {
                self.advance();
                let expr = self.parse_primary()?;
                Ok(Expr::FirstOf(Box::new(expr)))
            }
            Token::LastOf => {
                self.advance();
                let expr = self.parse_primary()?;
                Ok(Expr::LastOf(Box::new(expr)))
            }
            Token::Item => {
                // "item" can be either the "item N of list" operator or a variable name.
                // Use lookahead: check if this is followed by an expression and then "of".
                // Simple heuristic: if the next token can start an expression (number, string,
                // identifier, paren, etc.), try parsing as "item N of". Otherwise treat as identifier.
                let next = self.peek_token(1);
                let is_item_access = matches!(next,
                    Token::NumberLit(_) | Token::Identifier(_) | Token::LeftParen |
                    Token::Call | Token::Negative | Token::StringLit(_) |
                    Token::True | Token::False | Token::Nothing
                );
                if is_item_access {
                    self.advance();
                    let index = self.parse_expression()?;
                    self.expect(Token::Of)?;
                    let list = self.parse_primary()?;
                    Ok(Expr::ItemOf {
                        index: Box::new(index),
                        list: Box::new(list),
                    })
                } else {
                    // Treat as identifier
                    self.advance();
                    Ok(Expr::Identifier("item".to_string(), line))
                }
            }
            Token::SliceOf => {
                self.advance();
                let value = self.parse_primary()?;
                self.expect(Token::From)?;
                let from = self.parse_expression()?;
                self.expect(Token::To)?;
                let to = self.parse_expression()?;
                Ok(Expr::SliceOf {
                    value: Box::new(value),
                    from: Box::new(from),
                    to: Box::new(to),
                })
            }
            Token::Identifier(name) => {
                let name = name;
                self.advance();
                Ok(Expr::Identifier(name, line))
            }
            _ => {
                Err(format!("Error on line {}: unexpected token {:?} in expression", line, self.current_token()))
            }
        }
    }

    fn parse_list_literal(&mut self) -> Result<Expr, String> {
        self.advance(); // skip '['
        let mut elements = Vec::new();

        if !self.check(Token::RightBracket) {
            elements.push(self.parse_expression()?);
            while self.check(Token::Comma) {
                self.advance();
                elements.push(self.parse_expression()?);
            }
        }

        self.expect(Token::RightBracket)?;
        Ok(Expr::ListLit(elements))
    }

    fn parse_call_expr(&mut self) -> Result<Expr, String> {
        let line = self.current_line();
        self.advance(); // skip 'call'
        let name = self.expect_identifier()?;

        let mut args = Vec::new();
        if self.check(Token::With) {
            self.advance();
            // Parse arguments separated by 'and'.
            // Each argument is parsed at the 'not' precedence level
            // so that 'and' acts as separator, not logical operator.
            args.push(self.parse_call_arg()?);
            while self.check(Token::And) {
                self.advance();
                args.push(self.parse_call_arg()?);
            }
        }

        Ok(Expr::Call { name, args, line })
    }

    // Helper methods

    fn current_token(&self) -> Token {
        self.tokens.get(self.pos).map(|t| t.token.clone()).unwrap_or(Token::Eof)
    }

    fn peek_token(&self, offset: usize) -> Token {
        self.tokens.get(self.pos + offset).map(|t| t.token.clone()).unwrap_or(Token::Eof)
    }

    fn current_line(&self) -> usize {
        self.tokens.get(self.pos).map(|t| t.line).unwrap_or(0)
    }

    fn advance(&mut self) {
        self.pos += 1;
    }

    fn check(&self, token: Token) -> bool {
        std::mem::discriminant(&self.current_token()) == std::mem::discriminant(&token)
    }

    fn expect(&mut self, expected: Token) -> Result<(), String> {
        if self.check(expected.clone()) {
            self.advance();
            Ok(())
        } else {
            Err(format!(
                "Error on line {}: expected {:?}, got {:?}",
                self.current_line(),
                expected,
                self.current_token()
            ))
        }
    }

    fn expect_identifier(&mut self) -> Result<String, String> {
        match self.current_token() {
            Token::Identifier(name) => {
                self.advance();
                Ok(name)
            }
            // Many keywords can be used as identifiers in certain positions
            // (variable names, function names, parameter names).
            // Allow common keywords that might appear as variable names.
            Token::Item => { self.advance(); Ok("item".to_string()) }
            Token::NumberType => { self.advance(); Ok("number".to_string()) }
            Token::StringType => { self.advance(); Ok("string".to_string()) }
            Token::BooleanType => { self.advance(); Ok("boolean".to_string()) }
            Token::TimesOp => { self.advance(); Ok("times".to_string()) }
            other => Err(format!(
                "Error on line {}: expected identifier, got {:?}",
                self.current_line(),
                other
            )),
        }
    }

    fn expect_newline_or_eof(&mut self) -> Result<(), String> {
        match self.current_token() {
            Token::Newline => {
                self.advance();
                Ok(())
            }
            Token::Eof => Ok(()),
            Token::Dedent => Ok(()), // Dedent implies end of line
            _ => Err(format!(
                "Error on line {}: expected end of line, got {:?}",
                self.current_line(),
                self.current_token()
            )),
        }
    }

    fn skip_newlines(&mut self) {
        while self.check(Token::Newline) {
            self.advance();
        }
    }
}
