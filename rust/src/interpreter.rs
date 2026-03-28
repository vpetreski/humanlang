use std::collections::HashMap;
use std::fmt;
use std::cell::RefCell;
use std::rc::Rc;

use crate::ast::*;

/// Runtime values
#[derive(Debug, Clone)]
pub enum Value {
    Number(f64),
    Str(String),
    Bool(bool),
    List(Rc<RefCell<Vec<Value>>>),
    Nothing,
}

impl Value {
    pub fn type_name(&self) -> &'static str {
        match self {
            Value::Number(_) => "number",
            Value::Str(_) => "string",
            Value::Bool(_) => "boolean",
            Value::List(_) => "list",
            Value::Nothing => "nothing",
        }
    }
}

impl fmt::Display for Value {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Value::Number(n) => {
                if n.fract() == 0.0 && n.is_finite() {
                    write!(f, "{}", *n as i64)
                } else {
                    // Up to 6 decimal places, no trailing zeros
                    let s = format!("{:.6}", n);
                    let s = s.trim_end_matches('0');
                    let s = s.trim_end_matches('.');
                    write!(f, "{}", s)
                }
            }
            Value::Str(s) => write!(f, "{}", s),
            Value::Bool(b) => write!(f, "{}", b),
            Value::List(items) => {
                let items = items.borrow();
                write!(f, "[")?;
                for (i, item) in items.iter().enumerate() {
                    if i > 0 {
                        write!(f, ", ")?;
                    }
                    match item {
                        Value::Str(s) => write!(f, "\"{}\"", s)?, // strings in lists are quoted? No, spec says [1, 2, 3]. Let me check...
                        // Actually the spec output for lists shows [1, 2, 3], ["a", "b", "c"] would need quotes?
                        // But the test for list item access prints "a" without quotes.
                        // Let me check: the print format for lists... the spec says `[1, 2, 3]` bracket notation.
                        // Looking at tests: `print [1, 2, 3]` -> `[1, 2, 3]`. No string list test in print output.
                        // Actually there's "fibonacci first 10" which prints `[0, 1, 1, 2, 3, 5, 8, 13, 21, 34]`
                        // And "nested function calls with logic" which prints `[2, 4, 6, 8]`
                        // No test prints a list of strings. I'll use the display format for each item.
                        other => write!(f, "{}", other)?,
                    }
                }
                write!(f, "]")
            }
            Value::Nothing => write!(f, "nothing"),
        }
    }
}

impl PartialEq for Value {
    fn eq(&self, other: &Self) -> bool {
        match (self, other) {
            (Value::Number(a), Value::Number(b)) => a == b,
            (Value::Str(a), Value::Str(b)) => a == b,
            (Value::Bool(a), Value::Bool(b)) => a == b,
            (Value::Nothing, Value::Nothing) => true,
            _ => false,
        }
    }
}

/// Function definition stored at runtime
#[derive(Debug, Clone)]
struct FuncDef {
    params: Vec<String>,
    body: Vec<Stmt>,
}

/// Control flow signals
enum Signal {
    None,
    Return(Value),
    Stop,
    Skip,
}

/// Scope for variable lookup
struct Scope {
    vars: HashMap<String, Value>,
    parent: Option<Box<Scope>>,
}

impl Scope {
    fn new() -> Self {
        Scope {
            vars: HashMap::new(),
            parent: None,
        }
    }

    fn with_parent(parent: Scope) -> Self {
        Scope {
            vars: HashMap::new(),
            parent: Some(Box::new(parent)),
        }
    }

    fn get(&self, name: &str) -> Option<Value> {
        if let Some(val) = self.vars.get(name) {
            Some(val.clone())
        } else if let Some(ref parent) = self.parent {
            parent.get(name)
        } else {
            None
        }
    }

    fn set_local_or_current(&mut self, name: &str, value: Value) {
        // If variable exists in current scope, update it there
        if self.vars.contains_key(name) {
            self.vars.insert(name.to_string(), value);
        } else {
            // Always set in current scope (not in parent)
            self.vars.insert(name.to_string(), value);
        }
    }
}

pub struct Interpreter {
    scope: Scope,
    functions: HashMap<String, FuncDef>,
    in_loop: usize, // nesting depth
}

impl Interpreter {
    pub fn new() -> Self {
        Interpreter {
            scope: Scope::new(),
            functions: HashMap::new(),
            in_loop: 0,
        }
    }

    pub fn run(&mut self, stmts: &[Stmt]) -> Result<(), String> {
        match self.exec_stmts(stmts)? {
            Signal::None => Ok(()),
            Signal::Return(_) => Ok(()),
            Signal::Stop => Err("Error: 'stop' used outside of a loop".to_string()),
            Signal::Skip => Err("Error: 'skip' used outside of a loop".to_string()),
        }
    }

    fn exec_stmts(&mut self, stmts: &[Stmt]) -> Result<Signal, String> {
        for stmt in stmts {
            let signal = self.exec_stmt(stmt)?;
            match signal {
                Signal::None => {}
                _ => return Ok(signal),
            }
        }
        Ok(Signal::None)
    }

    fn exec_stmt(&mut self, stmt: &Stmt) -> Result<Signal, String> {
        match stmt {
            Stmt::Print { expr, line: _ } => {
                let val = self.eval_expr(expr)?;
                println!("{}", val);
                Ok(Signal::None)
            }

            Stmt::Set { name, expr, line: _ } => {
                let val = self.eval_expr(expr)?;
                self.scope.set_local_or_current(name, val);
                Ok(Signal::None)
            }

            Stmt::Append { value, list_name, line } => {
                let val = self.eval_expr(value)?;
                let list_val = self.scope.get(list_name)
                    .ok_or_else(|| format!("Error on line {}: undefined variable '{}'", line, list_name))?;
                match list_val {
                    Value::List(items) => {
                        items.borrow_mut().push(val);
                        Ok(Signal::None)
                    }
                    _ => Err(format!("Error on line {}: '{}' is not a list", line, list_name)),
                }
            }

            Stmt::If { condition, body, otherwise_ifs, otherwise, line } => {
                let cond_val = self.eval_expr(condition)?;
                let cond_bool = self.expect_bool(&cond_val, *line)?;

                if cond_bool {
                    return self.exec_stmts(body);
                }

                for (oi_cond, oi_body) in otherwise_ifs {
                    let oi_val = self.eval_expr(oi_cond)?;
                    let oi_bool = self.expect_bool(&oi_val, *line)?;
                    if oi_bool {
                        return self.exec_stmts(oi_body);
                    }
                }

                if let Some(else_body) = otherwise {
                    return self.exec_stmts(else_body);
                }

                Ok(Signal::None)
            }

            Stmt::While { condition, body, line } => {
                self.in_loop += 1;
                loop {
                    let cond_val = self.eval_expr(condition)?;
                    let cond_bool = self.expect_bool(&cond_val, *line)?;
                    if !cond_bool {
                        break;
                    }
                    match self.exec_stmts(body)? {
                        Signal::None => {}
                        Signal::Stop => break,
                        Signal::Skip => continue,
                        Signal::Return(v) => {
                            self.in_loop -= 1;
                            return Ok(Signal::Return(v));
                        }
                    }
                }
                self.in_loop -= 1;
                Ok(Signal::None)
            }

            Stmt::ForEach { var_name, iterable, body, line } => {
                let iter_val = self.eval_expr(iterable)?;
                match iter_val {
                    Value::List(items) => {
                        let items_snapshot: Vec<Value> = items.borrow().clone();
                        self.in_loop += 1;
                        for item in items_snapshot {
                            self.scope.set_local_or_current(var_name, item);
                            match self.exec_stmts(body)? {
                                Signal::None => {}
                                Signal::Stop => break,
                                Signal::Skip => continue,
                                Signal::Return(v) => {
                                    self.in_loop -= 1;
                                    return Ok(Signal::Return(v));
                                }
                            }
                        }
                        self.in_loop -= 1;
                        Ok(Signal::None)
                    }
                    _ => Err(format!("Error on line {}: 'for each' requires a list", line)),
                }
            }

            Stmt::ForFrom { var_name, from, to, body, line } => {
                let from_val = self.eval_expr(from)?;
                let to_val = self.eval_expr(to)?;

                let from_num = match from_val {
                    Value::Number(n) => n as i64,
                    _ => return Err(format!("Error on line {}: 'for' range must be numbers", line)),
                };
                let to_num = match to_val {
                    Value::Number(n) => n as i64,
                    _ => return Err(format!("Error on line {}: 'for' range must be numbers", line)),
                };

                self.in_loop += 1;
                for i in from_num..=to_num {
                    self.scope.set_local_or_current(var_name, Value::Number(i as f64));
                    match self.exec_stmts(body)? {
                        Signal::None => {}
                        Signal::Stop => break,
                        Signal::Skip => continue,
                        Signal::Return(v) => {
                            self.in_loop -= 1;
                            return Ok(Signal::Return(v));
                        }
                    }
                }
                self.in_loop -= 1;
                Ok(Signal::None)
            }

            Stmt::Repeat { count, body, line } => {
                let count_val = self.eval_expr(count)?;
                let n = match count_val {
                    Value::Number(n) => n as i64,
                    _ => return Err(format!("Error on line {}: 'repeat' count must be a number", line)),
                };

                self.in_loop += 1;
                for _ in 0..n {
                    match self.exec_stmts(body)? {
                        Signal::None => {}
                        Signal::Stop => break,
                        Signal::Skip => continue,
                        Signal::Return(v) => {
                            self.in_loop -= 1;
                            return Ok(Signal::Return(v));
                        }
                    }
                }
                self.in_loop -= 1;
                Ok(Signal::None)
            }

            Stmt::Define { name, params, body, line: _ } => {
                self.functions.insert(name.clone(), FuncDef {
                    params: params.clone(),
                    body: body.clone(),
                });
                Ok(Signal::None)
            }

            Stmt::Return { value, line: _ } => {
                let val = match value {
                    Some(expr) => self.eval_expr(expr)?,
                    None => Value::Nothing,
                };
                Ok(Signal::Return(val))
            }

            Stmt::Stop { line } => {
                if self.in_loop == 0 {
                    return Err(format!("Error on line {}: 'stop' used outside of a loop", line));
                }
                Ok(Signal::Stop)
            }

            Stmt::Skip { line } => {
                if self.in_loop == 0 {
                    return Err(format!("Error on line {}: 'skip' used outside of a loop", line));
                }
                Ok(Signal::Skip)
            }

            Stmt::ExprStmt { expr, line: _ } => {
                self.eval_expr(expr)?;
                Ok(Signal::None)
            }
        }
    }

    fn eval_expr(&mut self, expr: &Expr) -> Result<Value, String> {
        match expr {
            Expr::NumberLit(n) => Ok(Value::Number(*n)),
            Expr::StringLit(s) => Ok(Value::Str(s.clone())),
            Expr::BoolLit(b) => Ok(Value::Bool(*b)),
            Expr::NothingLit => Ok(Value::Nothing),

            Expr::ListLit(elements) => {
                let mut items = Vec::new();
                for elem in elements {
                    items.push(self.eval_expr(elem)?);
                }
                Ok(Value::List(Rc::new(RefCell::new(items))))
            }

            Expr::Identifier(name, line) => {
                self.scope.get(name)
                    .ok_or_else(|| format!("Error on line {}: undefined variable '{}'", line, name))
            }

            Expr::BinOp { left, op, right } => {
                let lv = self.eval_expr(left)?;
                let rv = self.eval_expr(right)?;
                self.eval_binop(&lv, *op, &rv)
            }

            Expr::Negative(expr) => {
                let val = self.eval_expr(expr)?;
                match val {
                    Value::Number(n) => Ok(Value::Number(-n)),
                    _ => Err("Error: 'negative' requires a number".to_string()),
                }
            }

            Expr::Compare { left, op, right } => {
                let lv = self.eval_expr(left)?;
                let rv = self.eval_expr(right)?;
                self.eval_compare(&lv, *op, &rv)
            }

            Expr::LogicalAnd(left, right) => {
                let lv = self.eval_expr(left)?;
                match lv {
                    Value::Bool(false) => Ok(Value::Bool(false)),
                    Value::Bool(true) => {
                        let rv = self.eval_expr(right)?;
                        match rv {
                            Value::Bool(_) => Ok(rv),
                            _ => Err("Error: 'and' requires boolean operands".to_string()),
                        }
                    }
                    _ => Err("Error: 'and' requires boolean operands".to_string()),
                }
            }

            Expr::LogicalOr(left, right) => {
                let lv = self.eval_expr(left)?;
                match lv {
                    Value::Bool(true) => Ok(Value::Bool(true)),
                    Value::Bool(false) => {
                        let rv = self.eval_expr(right)?;
                        match rv {
                            Value::Bool(_) => Ok(rv),
                            _ => Err("Error: 'or' requires boolean operands".to_string()),
                        }
                    }
                    _ => Err("Error: 'or' requires boolean operands".to_string()),
                }
            }

            Expr::LogicalNot(expr) => {
                let val = self.eval_expr(expr)?;
                match val {
                    Value::Bool(b) => Ok(Value::Bool(!b)),
                    _ => Err("Error: 'not' requires a boolean operand".to_string()),
                }
            }

            Expr::JoinedWith(left, right) => {
                let lv = self.eval_expr(left)?;
                let rv = self.eval_expr(right)?;
                let ls = format!("{}", lv);
                let rs = format!("{}", rv);
                Ok(Value::Str(ls + &rs))
            }

            Expr::Contains(left, right) => {
                let lv = self.eval_expr(left)?;
                let rv = self.eval_expr(right)?;
                match (&lv, &rv) {
                    (Value::Str(s), Value::Str(sub)) => Ok(Value::Bool(s.contains(sub.as_str()))),
                    (Value::List(items), _) => {
                        let items = items.borrow();
                        let found = items.iter().any(|item| *item == rv);
                        Ok(Value::Bool(found))
                    }
                    _ => Err("Error: 'contains' requires a string or list".to_string()),
                }
            }

            Expr::UppercaseOf(expr) => {
                let val = self.eval_expr(expr)?;
                match val {
                    Value::Str(s) => Ok(Value::Str(s.to_uppercase())),
                    _ => Err("Error: 'uppercase of' requires a string".to_string()),
                }
            }

            Expr::LowercaseOf(expr) => {
                let val = self.eval_expr(expr)?;
                match val {
                    Value::Str(s) => Ok(Value::Str(s.to_lowercase())),
                    _ => Err("Error: 'lowercase of' requires a string".to_string()),
                }
            }

            Expr::LengthOf(expr) => {
                let val = self.eval_expr(expr)?;
                match val {
                    Value::Str(s) => Ok(Value::Number(s.len() as f64)),
                    Value::List(items) => Ok(Value::Number(items.borrow().len() as f64)),
                    _ => Err("Error: 'length of' requires a string or list".to_string()),
                }
            }

            Expr::FirstOf(expr) => {
                let val = self.eval_expr(expr)?;
                match val {
                    Value::List(items) => {
                        let items = items.borrow();
                        items.first().cloned()
                            .ok_or_else(|| "Error: 'first of' on empty list".to_string())
                    }
                    _ => Err("Error: 'first of' requires a list".to_string()),
                }
            }

            Expr::LastOf(expr) => {
                let val = self.eval_expr(expr)?;
                match val {
                    Value::List(items) => {
                        let items = items.borrow();
                        items.last().cloned()
                            .ok_or_else(|| "Error: 'last of' on empty list".to_string())
                    }
                    _ => Err("Error: 'last of' requires a list".to_string()),
                }
            }

            Expr::ItemOf { index, list } => {
                let idx_val = self.eval_expr(index)?;
                let list_val = self.eval_expr(list)?;
                let idx = match idx_val {
                    Value::Number(n) => n as i64,
                    _ => return Err("Error: item index must be a number".to_string()),
                };
                match list_val {
                    Value::List(items) => {
                        let items = items.borrow();
                        if idx < 0 || idx as usize >= items.len() {
                            Err(format!("Error: index {} out of bounds for list of length {}", idx, items.len()))
                        } else {
                            Ok(items[idx as usize].clone())
                        }
                    }
                    _ => Err("Error: 'item ... of' requires a list".to_string()),
                }
            }

            Expr::SliceOf { value, from, to } => {
                let val = self.eval_expr(value)?;
                let from_val = self.eval_expr(from)?;
                let to_val = self.eval_expr(to)?;

                let from_idx = match from_val {
                    Value::Number(n) => n as usize,
                    _ => return Err("Error: slice indices must be numbers".to_string()),
                };
                let to_idx = match to_val {
                    Value::Number(n) => n as usize,
                    _ => return Err("Error: slice indices must be numbers".to_string()),
                };

                match val {
                    Value::Str(s) => {
                        let chars: Vec<char> = s.chars().collect();
                        let end = to_idx.min(chars.len());
                        let start = from_idx.min(end);
                        let sliced: String = chars[start..end].iter().collect();
                        Ok(Value::Str(sliced))
                    }
                    Value::List(items) => {
                        let items = items.borrow();
                        let end = to_idx.min(items.len());
                        let start = from_idx.min(end);
                        let sliced: Vec<Value> = items[start..end].to_vec();
                        Ok(Value::List(Rc::new(RefCell::new(sliced))))
                    }
                    _ => Err("Error: 'slice of' requires a string or list".to_string()),
                }
            }

            Expr::AsType(expr, type_name) => {
                let val = self.eval_expr(expr)?;
                self.convert_type(val, *type_name)
            }

            Expr::Call { name, args, line } => {
                self.eval_call(name, args, *line)
            }
        }
    }

    fn eval_binop(&self, left: &Value, op: BinOpKind, right: &Value) -> Result<Value, String> {
        match (left, right) {
            (Value::Number(a), Value::Number(b)) => {
                match op {
                    BinOpKind::Plus => Ok(Value::Number(a + b)),
                    BinOpKind::Minus => Ok(Value::Number(a - b)),
                    BinOpKind::Times => Ok(Value::Number(a * b)),
                    BinOpKind::DividedBy => {
                        if *b == 0.0 {
                            Err("Error: division by zero".to_string())
                        } else {
                            Ok(Value::Number(a / b))
                        }
                    }
                    BinOpKind::Modulo => {
                        if *b == 0.0 {
                            Err("Error: division by zero".to_string())
                        } else {
                            Ok(Value::Number(a % b))
                        }
                    }
                }
            }
            _ => Err(format!("Error: arithmetic requires numbers, got {} and {}", left.type_name(), right.type_name())),
        }
    }

    fn eval_compare(&self, left: &Value, op: CmpOp, right: &Value) -> Result<Value, String> {
        match op {
            CmpOp::Equal => Ok(Value::Bool(*left == *right)),
            CmpOp::NotEqual => Ok(Value::Bool(*left != *right)),
            CmpOp::GreaterThan | CmpOp::LessThan | CmpOp::AtLeast | CmpOp::AtMost => {
                match (left, right) {
                    (Value::Number(a), Value::Number(b)) => {
                        let result = match op {
                            CmpOp::GreaterThan => a > b,
                            CmpOp::LessThan => a < b,
                            CmpOp::AtLeast => a >= b,
                            CmpOp::AtMost => a <= b,
                            _ => unreachable!(),
                        };
                        Ok(Value::Bool(result))
                    }
                    (Value::Str(a), Value::Str(b)) => {
                        let result = match op {
                            CmpOp::GreaterThan => a > b,
                            CmpOp::LessThan => a < b,
                            CmpOp::AtLeast => a >= b,
                            CmpOp::AtMost => a <= b,
                            _ => unreachable!(),
                        };
                        Ok(Value::Bool(result))
                    }
                    _ => Err(format!("Error: cannot compare {} with {}", left.type_name(), right.type_name())),
                }
            }
        }
    }

    fn convert_type(&self, val: Value, target: TypeName) -> Result<Value, String> {
        match target {
            TypeName::Number => {
                match val {
                    Value::Number(_) => Ok(val),
                    Value::Str(s) => {
                        let n: f64 = s.parse()
                            .map_err(|_| format!("Error: cannot convert '{}' to number", s))?;
                        Ok(Value::Number(n))
                    }
                    Value::Bool(b) => Ok(Value::Number(if b { 1.0 } else { 0.0 })),
                    _ => Err(format!("Error: cannot convert {} to number", val.type_name())),
                }
            }
            TypeName::StringT => {
                Ok(Value::Str(format!("{}", val)))
            }
            TypeName::Boolean => {
                let b = match val {
                    Value::Number(n) => n != 0.0,
                    Value::Str(s) => !s.is_empty(),
                    Value::Bool(b) => b,
                    Value::List(items) => !items.borrow().is_empty(),
                    Value::Nothing => false,
                };
                Ok(Value::Bool(b))
            }
        }
    }

    fn eval_call(&mut self, name: &str, arg_exprs: &[Expr], line: usize) -> Result<Value, String> {
        let func = self.functions.get(name)
            .ok_or_else(|| format!("Error on line {}: undefined function '{}'", line, name))?
            .clone();

        if arg_exprs.len() != func.params.len() {
            return Err(format!(
                "Error on line {}: function '{}' expects {} arguments, got {}",
                line, name, func.params.len(), arg_exprs.len()
            ));
        }

        // Evaluate arguments in current scope
        let mut arg_vals = Vec::new();
        for arg in arg_exprs {
            arg_vals.push(self.eval_expr(arg)?);
        }

        // Save current scope and create new function scope
        let old_scope = std::mem::replace(&mut self.scope, Scope::new());
        self.scope = Scope::with_parent(old_scope);

        // Bind parameters
        for (param, val) in func.params.iter().zip(arg_vals) {
            self.scope.vars.insert(param.clone(), val);
        }

        // Save and reset loop counter
        let old_in_loop = self.in_loop;
        self.in_loop = 0;

        // Execute function body
        let result = self.exec_stmts(&func.body);

        // Restore loop counter
        self.in_loop = old_in_loop;

        // Restore scope
        let inner = std::mem::replace(&mut self.scope, Scope::new());
        self.scope = *inner.parent.unwrap();

        match result? {
            Signal::Return(val) => Ok(val),
            Signal::None => Ok(Value::Nothing),
            Signal::Stop => Err(format!("Error on line {}: 'stop' used outside of a loop", line)),
            Signal::Skip => Err(format!("Error on line {}: 'skip' used outside of a loop", line)),
        }
    }

    fn expect_bool(&self, val: &Value, line: usize) -> Result<bool, String> {
        match val {
            Value::Bool(b) => Ok(*b),
            _ => Err(format!("Error on line {}: condition must be a boolean, got {}", line, val.type_name())),
        }
    }
}
