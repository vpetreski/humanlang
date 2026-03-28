use crate::token::{LocToken, Token};

pub struct Lexer {
    source: Vec<char>,
    pos: usize,
    line: usize,
    tokens: Vec<LocToken>,
    indent_stack: Vec<usize>,
    at_line_start: bool,
}

impl Lexer {
    pub fn new(source: &str) -> Self {
        Lexer {
            source: source.chars().collect(),
            pos: 0,
            line: 1,
            tokens: Vec::new(),
            indent_stack: vec![0],
            at_line_start: true,
        }
    }

    pub fn tokenize(mut self) -> Result<Vec<LocToken>, String> {
        while self.pos < self.source.len() {
            if self.at_line_start {
                self.handle_line_start()?;
            } else {
                self.skip_spaces();
                if self.pos >= self.source.len() {
                    break;
                }
                let ch = self.current();
                if ch == '\n' {
                    self.emit(Token::Newline);
                    self.pos += 1;
                    self.line += 1;
                    self.at_line_start = true;
                } else if ch == '-' && self.peek_char(1) == Some('-') {
                    // Comment - skip to end of line
                    while self.pos < self.source.len() && self.current() != '\n' {
                        self.pos += 1;
                    }
                } else {
                    self.read_token()?;
                }
            }
        }

        // Emit final newline if needed
        if !self.tokens.is_empty() {
            if let Some(last) = self.tokens.last() {
                if last.token != Token::Newline {
                    self.emit(Token::Newline);
                }
            }
        }

        // Close all remaining indents
        while self.indent_stack.len() > 1 {
            self.indent_stack.pop();
            self.emit(Token::Dedent);
        }

        self.emit(Token::Eof);
        Ok(self.tokens)
    }

    fn handle_line_start(&mut self) -> Result<(), String> {
        self.at_line_start = false;

        // Count leading spaces
        let mut spaces = 0;
        while self.pos < self.source.len() && self.current() == ' ' {
            spaces += 1;
            self.pos += 1;
        }

        // Skip blank lines
        if self.pos >= self.source.len() || self.current() == '\n' {
            if self.pos < self.source.len() {
                self.pos += 1;
                self.line += 1;
                self.at_line_start = true;
            }
            return Ok(());
        }

        // Skip comment-only lines
        if self.current() == '-' && self.peek_char(1) == Some('-') {
            while self.pos < self.source.len() && self.current() != '\n' {
                self.pos += 1;
            }
            if self.pos < self.source.len() {
                self.pos += 1;
                self.line += 1;
                self.at_line_start = true;
            }
            return Ok(());
        }

        let current_indent = *self.indent_stack.last().unwrap();

        if spaces > current_indent {
            self.indent_stack.push(spaces);
            self.emit(Token::Indent);
        } else if spaces < current_indent {
            while *self.indent_stack.last().unwrap() > spaces {
                self.indent_stack.pop();
                self.emit(Token::Dedent);
            }
        }
        Ok(())
    }

    fn read_token(&mut self) -> Result<(), String> {
        let ch = self.current();

        match ch {
            '"' => self.read_string()?,
            '(' => {
                self.emit(Token::LeftParen);
                self.pos += 1;
            }
            ')' => {
                self.emit(Token::RightParen);
                self.pos += 1;
            }
            '[' => {
                self.emit(Token::LeftBracket);
                self.pos += 1;
            }
            ']' => {
                self.emit(Token::RightBracket);
                self.pos += 1;
            }
            ',' => {
                self.emit(Token::Comma);
                self.pos += 1;
            }
            ':' => {
                self.emit(Token::Colon);
                self.pos += 1;
            }
            _ if ch.is_ascii_digit() || (ch == '-' && self.peek_is_digit()) => {
                // Only parse negative number literal at the very start when it makes sense
                // Actually, humanlang uses "negative" keyword for negation, so '-' is not used
                // as a prefix. But number literals like -7 exist in the spec... let's handle
                // them only as digit sequences.
                self.read_number()?;
            }
            _ if ch.is_ascii_alphabetic() => {
                self.read_word()?;
            }
            _ => {
                return Err(format!("Error on line {}: unexpected character '{}'", self.line, ch));
            }
        }

        Ok(())
    }

    fn read_string(&mut self) -> Result<(), String> {
        let line = self.line;
        self.pos += 1; // skip opening quote
        let mut s = String::new();

        while self.pos < self.source.len() {
            let ch = self.current();
            if ch == '"' {
                self.pos += 1;
                self.tokens.push(LocToken { token: Token::StringLit(s), line });
                return Ok(());
            } else if ch == '\\' {
                self.pos += 1;
                if self.pos >= self.source.len() {
                    return Err(format!("Error on line {}: unterminated string escape", line));
                }
                match self.current() {
                    'n' => s.push('\n'),
                    't' => s.push('\t'),
                    '\\' => s.push('\\'),
                    '"' => s.push('"'),
                    c => return Err(format!("Error on line {}: unknown escape sequence '\\{}'", line, c)),
                }
                self.pos += 1;
            } else if ch == '\n' {
                return Err(format!("Error on line {}: unterminated string", line));
            } else {
                s.push(ch);
                self.pos += 1;
            }
        }

        Err(format!("Error on line {}: unterminated string", line))
    }

    fn read_number(&mut self) -> Result<(), String> {
        let start = self.pos;
        let line = self.line;

        while self.pos < self.source.len() && self.current().is_ascii_digit() {
            self.pos += 1;
        }

        if self.pos < self.source.len() && self.current() == '.' && self.peek_char(1).map_or(false, |c| c.is_ascii_digit()) {
            self.pos += 1; // skip '.'
            while self.pos < self.source.len() && self.current().is_ascii_digit() {
                self.pos += 1;
            }
        }

        let num_str: String = self.source[start..self.pos].iter().collect();
        let val: f64 = num_str.parse().map_err(|_| format!("Error on line {}: invalid number '{}'", line, num_str))?;
        self.tokens.push(LocToken { token: Token::NumberLit(val), line });
        Ok(())
    }

    fn read_word(&mut self) -> Result<(), String> {
        let start = self.pos;
        let line = self.line;

        while self.pos < self.source.len() && (self.current().is_ascii_alphanumeric() || self.current() == '_') {
            self.pos += 1;
        }

        let word: String = self.source[start..self.pos].iter().collect();

        // Try to match multi-word keywords by looking ahead
        let token = self.match_keyword(&word, line);
        self.tokens.push(LocToken { token, line });
        Ok(())
    }

    fn match_keyword(&mut self, word: &str, line: usize) -> Token {
        match word {
            "print" => Token::Print,
            "set" => Token::Set,
            "to" => Token::To,
            "if" => Token::If,
            "otherwise" => {
                // Check for "otherwise if"
                if self.try_consume_word("if") {
                    Token::OtherwiseIf
                } else {
                    Token::Otherwise
                }
            }
            "while" => Token::While,
            "for" => {
                // Check for "for each"
                if self.try_consume_word("each") {
                    Token::ForEach
                } else {
                    Token::For
                }
            }
            "from" => Token::From,
            "in" => Token::In,
            "repeat" => Token::Repeat,
            "times" => {
                // Check if followed by ":" which means this is "times:" in "repeat N times:"
                // In expression context, "times" is a multiplication operator
                Token::TimesOp
            }
            "define" => Token::Define,
            "with" => Token::With,
            "call" => Token::Call,
            "return" => Token::Return,
            "append" => Token::Append,
            "stop" => Token::Stop,
            "skip" => Token::Skip,
            "plus" => Token::Plus,
            "minus" => Token::Minus,
            "divided" => {
                // "divided by"
                if self.try_consume_word("by") {
                    Token::DividedBy
                } else {
                    Token::Identifier("divided".to_string())
                }
            }
            "modulo" => Token::Modulo,
            "negative" => Token::Negative,
            "is" => {
                // Multi-word comparisons starting with "is"
                self.match_is_keyword(line)
            }
            "and" => Token::And,
            "or" => Token::Or,
            "not" => Token::Not,
            "joined" => {
                if self.try_consume_word("with") {
                    Token::JoinedWith
                } else {
                    Token::Identifier("joined".to_string())
                }
            }
            "contains" => Token::Contains,
            "uppercase" => {
                if self.try_consume_word("of") {
                    Token::UppercaseOf
                } else {
                    Token::Identifier("uppercase".to_string())
                }
            }
            "lowercase" => {
                if self.try_consume_word("of") {
                    Token::LowercaseOf
                } else {
                    Token::Identifier("lowercase".to_string())
                }
            }
            "length" => {
                if self.try_consume_word("of") {
                    Token::LengthOf
                } else {
                    Token::Identifier("length".to_string())
                }
            }
            "first" => {
                if self.try_consume_word("of") {
                    Token::FirstOf
                } else {
                    Token::Identifier("first".to_string())
                }
            }
            "last" => {
                if self.try_consume_word("of") {
                    Token::LastOf
                } else {
                    Token::Identifier("last".to_string())
                }
            }
            "item" => Token::Item,
            "of" => Token::Of,
            "slice" => {
                if self.try_consume_word("of") {
                    Token::SliceOf
                } else {
                    Token::Identifier("slice".to_string())
                }
            }
            "as" => Token::As,
            "number" => Token::NumberType,
            "string" => Token::StringType,
            "boolean" => Token::BooleanType,
            "true" => Token::True,
            "false" => Token::False,
            "nothing" => Token::Nothing,
            _ => Token::Identifier(word.to_string()),
        }
    }

    fn match_is_keyword(&mut self, _line: usize) -> Token {
        // Save position in case we need to backtrack
        let saved_pos = self.pos;

        // Try "is not equal to"
        if self.try_consume_word("not") {
            if self.try_consume_word("equal") {
                if self.try_consume_word("to") {
                    return Token::IsNotEqualTo;
                }
            }
            // Backtrack
            self.pos = saved_pos;
        }

        // Try "is equal to"
        if self.try_consume_word("equal") {
            if self.try_consume_word("to") {
                return Token::IsEqualTo;
            }
            self.pos = saved_pos;
        }

        // Try "is greater than"
        if self.try_consume_word("greater") {
            if self.try_consume_word("than") {
                return Token::IsGreaterThan;
            }
            self.pos = saved_pos;
        }

        // Try "is less than"
        if self.try_consume_word("less") {
            if self.try_consume_word("than") {
                return Token::IsLessThan;
            }
            self.pos = saved_pos;
        }

        // Try "is at least" / "is at most"
        if self.try_consume_word("at") {
            if self.try_consume_word("least") {
                return Token::IsAtLeast;
            }
            self.pos = saved_pos;
            if self.try_consume_word("at") {
                if self.try_consume_word("most") {
                    return Token::IsAtMost;
                }
            }
            self.pos = saved_pos;
        }

        Token::Identifier("is".to_string())
    }

    fn try_consume_word(&mut self, expected: &str) -> bool {
        let saved = self.pos;

        // Skip spaces
        let mut p = self.pos;
        while p < self.source.len() && self.source[p] == ' ' {
            p += 1;
        }

        // Check if the next word matches
        let start = p;
        while p < self.source.len() && (self.source[p].is_ascii_alphanumeric() || self.source[p] == '_') {
            p += 1;
        }

        let word: String = self.source[start..p].iter().collect();
        if word == expected {
            self.pos = p;
            true
        } else {
            self.pos = saved;
            false
        }
    }

    fn current(&self) -> char {
        self.source[self.pos]
    }

    fn peek_char(&self, offset: usize) -> Option<char> {
        self.source.get(self.pos + offset).copied()
    }

    fn peek_is_digit(&self) -> bool {
        self.peek_char(1).map_or(false, |c| c.is_ascii_digit())
    }

    fn skip_spaces(&mut self) {
        while self.pos < self.source.len() && self.current() == ' ' {
            self.pos += 1;
        }
    }

    fn emit(&mut self, token: Token) {
        self.tokens.push(LocToken { token, line: self.line });
    }
}
