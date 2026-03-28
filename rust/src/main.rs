mod token;
mod lexer;
mod ast;
mod parser;
mod interpreter;

use std::env;
use std::fs;
use std::process;

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() != 2 {
        eprintln!("Usage: humanlang <file.hl>");
        process::exit(1);
    }

    let filename = &args[1];
    let source = match fs::read_to_string(filename) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("Error: could not read file '{}': {}", filename, e);
            process::exit(1);
        }
    };

    if let Err(e) = run(&source) {
        eprintln!("{}", e);
        process::exit(1);
    }
}

fn run(source: &str) -> Result<(), String> {
    let lexer = lexer::Lexer::new(source);
    let tokens = lexer.tokenize()?;

    let mut parser = parser::Parser::new(tokens);
    let program = parser.parse()?;

    let mut interp = interpreter::Interpreter::new();
    interp.run(&program)?;

    Ok(())
}
