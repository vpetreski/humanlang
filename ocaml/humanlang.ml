(* humanlang interpreter in OCaml
   A complete lexer, parser, and tree-walk interpreter for the humanlang language.
   Usage: humanlang <file.hl> *)

(* ========================================================================= *)
(* Tokens                                                                    *)
(* ========================================================================= *)

type token_kind =
  (* Literals *)
  | TNumber of float
  | TString of string
  | TTrue
  | TFalse
  | TNothing
  (* Identifiers *)
  | TIdent of string
  (* Keywords *)
  | TPrint
  | TSet
  | TTo
  | TIf
  | TOtherwise
  | TOtherwiseIf
  | TWhile
  | TForEach
  | TFor
  | TFrom
  | TRepeat
  | TTimes
  | TDefine
  | TWith
  | TCall
  | TReturn
  | TAppend
  | TStop
  | TSkip
  | TIn
  | TAnd
  | TOr
  | TNot
  (* Operators *)
  | TPlus
  | TMinus
  | TDividedBy
  | TModulo
  | TIsEqualTo
  | TIsNotEqualTo
  | TIsGreaterThan
  | TIsLessThan
  | TIsAtLeast
  | TIsAtMost
  | TJoinedWith
  | TContains
  | TAs
  | TNegative
  (* Prefix operators *)
  | TUppercaseOf
  | TLowercaseOf
  | TLengthOf
  | TFirstOf
  | TLastOf
  | TOf
  | TSliceOf
  (* Delimiters *)
  | TColon
  | TLParen
  | TRParen
  | TLBracket
  | TRBracket
  | TComma
  (* Indentation *)
  | TIndent
  | TDedent
  | TNewline
  | TEOF

type token = {
  kind : token_kind;
  line : int;
}

(* ========================================================================= *)
(* Lexer                                                                     *)
(* ========================================================================= *)

exception LexError of int * string

let lex (source : string) : token list =
  let lines = String.split_on_char '\n' source in
  let tokens = ref [] in
  let indent_stack = ref [0] in
  let line_num = ref 0 in

  let emit k = tokens := { kind = k; line = !line_num } :: !tokens in

  let parse_string_literal (s : string) (start : int) : string * int =
    (* start points to the char after the opening quote *)
    let buf = Buffer.create 64 in
    let i = ref start in
    let len = String.length s in
    while !i < len && s.[!i] <> '"' do
      if s.[!i] = '\\' && !i + 1 < len then begin
        (match s.[!i + 1] with
         | 'n' -> Buffer.add_char buf '\n'
         | 't' -> Buffer.add_char buf '\t'
         | '\\' -> Buffer.add_char buf '\\'
         | '"' -> Buffer.add_char buf '"'
         | c -> Buffer.add_char buf '\\'; Buffer.add_char buf c);
        i := !i + 2
      end else begin
        Buffer.add_char buf s.[!i];
        i := !i + 1
      end
    done;
    if !i >= len then raise (LexError (!line_num, "Unterminated string"));
    (Buffer.contents buf, !i + 1) (* skip closing quote *)
  in

  let is_alpha c = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') in
  let is_digit c = c >= '0' && c <= '9' in
  let is_alnum_under c = is_alpha c || is_digit c || c = '_' in

  let parse_word (s : string) (start : int) : string * int =
    let len = String.length s in
    let i = ref start in
    while !i < len && is_alnum_under s.[!i] do
      i := !i + 1
    done;
    (String.sub s start (!i - start), !i)
  in

  let parse_number (s : string) (start : int) : float * int =
    let len = String.length s in
    let i = ref start in
    while !i < len && is_digit s.[!i] do i := !i + 1 done;
    if !i < len && s.[!i] = '.' && !i + 1 < len && is_digit s.[!i + 1] then begin
      i := !i + 1;
      while !i < len && is_digit s.[!i] do i := !i + 1 done
    end;
    (float_of_string (String.sub s start (!i - start)), !i)
  in

  (* Check if string s starting at position i matches word w at a word boundary *)
  let match_word s i w =
    let wl = String.length w in
    let sl = String.length s in
    if i + wl > sl then false
    else
      String.sub s i wl = w &&
      (i + wl >= sl || not (is_alnum_under s.[i + wl]))
  in

  (* Try to match a multi-word keyword starting at position i.
     Returns Some (token_kind, new_position) or None. *)
  let try_multi_word (s : string) (i : int) : (token_kind * int) option =
    let sl = String.length s in
    (* Helper: skip exactly one space at position p *)
    let space_at p = p < sl && s.[p] = ' ' in
    (* "otherwise if" *)
    if match_word s i "otherwise" then begin
      let p = i + 9 in
      if space_at p && match_word s (p + 1) "if" then
        Some (TOtherwiseIf, p + 3)
      else
        None (* let it fall through to single-word *)
    end
    (* "divided by" *)
    else if match_word s i "divided" then begin
      let p = i + 7 in
      if space_at p && match_word s (p + 1) "by" then
        Some (TDividedBy, p + 3)
      else None
    end
    (* "is not equal to" / "is equal to" / "is greater than" / "is less than" / "is at least" / "is at most" *)
    else if match_word s i "is" then begin
      let p = i + 2 in
      if space_at p then begin
        let q = p + 1 in
        if match_word s q "not" then begin
          let r = q + 3 in
          if space_at r && match_word s (r+1) "equal" then begin
            let t = r + 6 in
            if space_at t && match_word s (t+1) "to" then
              Some (TIsNotEqualTo, t + 3)
            else None
          end else None
        end
        else if match_word s q "equal" then begin
          let r = q + 5 in
          if space_at r && match_word s (r+1) "to" then
            Some (TIsEqualTo, r + 3)
          else None
        end
        else if match_word s q "greater" then begin
          let r = q + 7 in
          if space_at r && match_word s (r+1) "than" then
            Some (TIsGreaterThan, r + 5)
          else None
        end
        else if match_word s q "less" then begin
          let r = q + 4 in
          if space_at r && match_word s (r+1) "than" then
            Some (TIsLessThan, r + 5)
          else None
        end
        else if match_word s q "at" then begin
          let r = q + 2 in
          if space_at r then begin
            if match_word s (r+1) "least" then
              Some (TIsAtLeast, r + 6)
            else if match_word s (r+1) "most" then
              Some (TIsAtMost, r + 6)
            else None
          end else None
        end
        else None
      end else None
    end
    (* "for each" *)
    else if match_word s i "for" then begin
      let p = i + 3 in
      if space_at p && match_word s (p+1) "each" then
        Some (TForEach, p + 5)
      else None
    end
    (* "joined with" *)
    else if match_word s i "joined" then begin
      let p = i + 6 in
      if space_at p && match_word s (p+1) "with" then
        Some (TJoinedWith, p + 5)
      else None
    end
    (* "uppercase of" *)
    else if match_word s i "uppercase" then begin
      let p = i + 9 in
      if space_at p && match_word s (p+1) "of" then
        Some (TUppercaseOf, p + 3)
      else None
    end
    (* "lowercase of" *)
    else if match_word s i "lowercase" then begin
      let p = i + 9 in
      if space_at p && match_word s (p+1) "of" then
        Some (TLowercaseOf, p + 3)
      else None
    end
    (* "length of" *)
    else if match_word s i "length" then begin
      let p = i + 6 in
      if space_at p && match_word s (p+1) "of" then
        Some (TLengthOf, p + 3)
      else None
    end
    (* "first of" *)
    else if match_word s i "first" then begin
      let p = i + 5 in
      if space_at p && match_word s (p+1) "of" then
        Some (TFirstOf, p + 3)
      else None
    end
    (* "last of" *)
    else if match_word s i "last" then begin
      let p = i + 4 in
      if space_at p && match_word s (p+1) "of" then
        Some (TLastOf, p + 3)
      else None
    end
    (* "slice of" *)
    else if match_word s i "slice" then begin
      let p = i + 5 in
      if space_at p && match_word s (p+1) "of" then
        Some (TSliceOf, p + 3)
      else None
    end
    else
      None
  in

  let keyword_of_word = function
    | "print" -> Some TPrint
    | "set" -> Some TSet
    | "to" -> Some TTo
    | "if" -> Some TIf
    | "otherwise" -> Some TOtherwise
    | "while" -> Some TWhile
    | "for" -> Some TFor
    | "from" -> Some TFrom
    | "repeat" -> Some TRepeat
    | "times" -> Some TTimes
    | "define" -> Some TDefine
    | "with" -> Some TWith
    | "call" -> Some TCall
    | "return" -> Some TReturn
    | "append" -> Some TAppend
    | "stop" -> Some TStop
    | "skip" -> Some TSkip
    | "in" -> Some TIn
    | "and" -> Some TAnd
    | "or" -> Some TOr
    | "not" -> Some TNot
    | "true" -> Some TTrue
    | "false" -> Some TFalse
    | "nothing" -> Some TNothing
    | "plus" -> Some TPlus
    | "minus" -> Some TMinus
    | "modulo" -> Some TModulo
    | "contains" -> Some TContains
    | "as" -> Some TAs
    | "negative" -> Some TNegative
    | "of" -> Some TOf
    | _ -> None
  in

  List.iter (fun raw_line ->
    line_num := !line_num + 1;
    (* Strip trailing whitespace *)
    let line =
      let len = String.length raw_line in
      let e = ref len in
      while !e > 0 && (raw_line.[!e - 1] = ' ' || raw_line.[!e - 1] = '\r' || raw_line.[!e - 1] = '\t') do
        e := !e - 1
      done;
      String.sub raw_line 0 !e
    in
    let len = String.length line in
    (* Skip blank lines *)
    if len = 0 then ()
    else begin
      (* Count leading spaces *)
      let spaces = ref 0 in
      while !spaces < len && line.[!spaces] = ' ' do
        spaces := !spaces + 1
      done;
      (* Check for comment *)
      if !spaces + 1 < len && line.[!spaces] = '-' && line.[!spaces + 1] = '-' then
        () (* comment line, skip *)
      else begin
        let indent = !spaces / 4 in
        let current_indent = List.hd !indent_stack in
        if indent > current_indent then begin
          indent_stack := indent :: !indent_stack;
          emit TIndent
        end else begin
          while indent < List.hd !indent_stack do
            indent_stack := List.tl !indent_stack;
            emit TDedent
          done
        end;
        (* Tokenize the rest of the line *)
        let i = ref !spaces in
        while !i < len do
          let c = line.[!i] in
          if c = ' ' then
            i := !i + 1
          else if c = '"' then begin
            let (s, next) = parse_string_literal line (!i + 1) in
            emit (TString s);
            i := next
          end
          else if is_digit c then begin
            let (n, next) = parse_number line !i in
            emit (TNumber n);
            i := next
          end
          else if c = '(' then (emit TLParen; i := !i + 1)
          else if c = ')' then (emit TRParen; i := !i + 1)
          else if c = '[' then (emit TLBracket; i := !i + 1)
          else if c = ']' then (emit TRBracket; i := !i + 1)
          else if c = ',' then (emit TComma; i := !i + 1)
          else if c = ':' then (emit TColon; i := !i + 1)
          else if is_alpha c then begin
            (* Try multi-word keywords first *)
            match try_multi_word line !i with
            | Some (tk, next) ->
              emit tk;
              i := next
            | None ->
              let (word, next) = parse_word line !i in
              (match keyword_of_word word with
               | Some tk -> emit tk
               | None -> emit (TIdent word));
              i := next
          end
          else
            raise (LexError (!line_num, Printf.sprintf "Unexpected character '%c'" c))
        done;
        emit TNewline
      end
    end
  ) lines;

  (* Emit remaining dedents *)
  while List.hd !indent_stack > 0 do
    indent_stack := List.tl !indent_stack;
    emit TDedent
  done;
  emit TEOF;

  List.rev !tokens

(* ========================================================================= *)
(* AST                                                                       *)
(* ========================================================================= *)

type binop =
  | OpPlus | OpMinus | OpTimes | OpDividedBy | OpModulo
  | OpEq | OpNeq | OpGt | OpLt | OpGte | OpLte
  | OpAnd | OpOr
  | OpJoinedWith
  | OpContains

type unaryop =
  | OpNot | OpNegative

type prefix_op =
  | PrefUppercase | PrefLowercase | PrefLength | PrefFirst | PrefLast

type type_name =
  | TyNumber | TyString | TyBoolean

type expr =
  | ENumber of float
  | EString of string
  | EBool of bool
  | ENothing
  | EIdent of string
  | EList of expr list
  | EBinop of binop * expr * expr
  | EUnary of unaryop * expr
  | EPrefix of prefix_op * expr
  | ECall of string * expr list
  | EAsType of expr * type_name
  | EItem of expr * expr       (* item <index> of <expr> *)
  | ESlice of expr * expr * expr  (* slice of <expr> from <expr> to <expr> *)

type stmt =
  | SPrint of int * expr
  | SSet of int * string * expr
  | SAppend of int * expr * string
  | SIf of int * (expr * stmt list) list * stmt list option
  | SWhile of int * expr * stmt list
  | SForEach of int * string * expr * stmt list
  | SForFrom of int * string * expr * expr * stmt list
  | SRepeat of int * expr * stmt list
  | SDefine of int * string * string list * stmt list
  | SCallStmt of int * string * expr list
  | SReturn of int * expr option
  | SStop of int
  | SSkip of int

(* ========================================================================= *)
(* Parser                                                                    *)
(* ========================================================================= *)

exception ParseError of int * string

type parser_state = {
  mutable toks : token list;
  mutable current_line : int;
  mutable stop_at : token_kind list;  (* expression parser stops at these *)
}

let make_parser tokens = { toks = tokens; current_line = 1; stop_at = [] }

let is_stopped ps kind =
  List.mem kind ps.stop_at

let peek ps =
  match ps.toks with
  | t :: _ -> t
  | [] -> { kind = TEOF; line = ps.current_line }

let advance ps =
  match ps.toks with
  | t :: rest ->
    ps.current_line <- t.line;
    ps.toks <- rest;
    t
  | [] -> { kind = TEOF; line = ps.current_line }

let expect ps kind =
  let t = advance ps in
  if t.kind <> kind then
    raise (ParseError (t.line,
      Printf.sprintf "Expected %s" (match kind with
        | TTo -> "'to'" | TColon -> "':'" | TFrom -> "'from'"
        | TIn -> "'in'" | TOf -> "'of'"
        | _ -> "token")))
  else t

let skip_newlines ps =
  while (peek ps).kind = TNewline do ignore (advance ps) done

(* Parse a block: expect INDENT, statements, DEDENT *)
let rec parse_block ps =
  skip_newlines ps;
  let _ = expect ps TIndent in
  let stmts = ref [] in
  let running = ref true in
  while !running do
    skip_newlines ps;
    match (peek ps).kind with
    | TDedent -> ignore (advance ps); running := false
    | TEOF -> running := false
    | _ -> stmts := parse_statement ps :: !stmts
  done;
  List.rev !stmts

(* ---- Expression parsing (precedence climbing) ---- *)

and parse_expression ps =
  parse_or ps

and parse_or ps =
  let left = ref (parse_and ps) in
  while (peek ps).kind = TOr do
    ignore (advance ps);
    let right = parse_and ps in
    left := EBinop (OpOr, !left, right)
  done;
  !left

and parse_and ps =
  let left = ref (parse_not ps) in
  while (peek ps).kind = TAnd && not (is_stopped ps TAnd) do
    ignore (advance ps);
    let right = parse_not ps in
    left := EBinop (OpAnd, !left, right)
  done;
  !left

and parse_not ps =
  if (peek ps).kind = TNot then begin
    ignore (advance ps);
    let e = parse_not ps in
    EUnary (OpNot, e)
  end else
    parse_comparison ps

and parse_comparison ps =
  let left = ref (parse_addition ps) in
  let running = ref true in
  while !running do
    let op = match (peek ps).kind with
      | TIsEqualTo -> Some OpEq
      | TIsNotEqualTo -> Some OpNeq
      | TIsGreaterThan -> Some OpGt
      | TIsLessThan -> Some OpLt
      | TIsAtLeast -> Some OpGte
      | TIsAtMost -> Some OpLte
      | _ -> None
    in
    match op with
    | Some op ->
      ignore (advance ps);
      let right = parse_addition ps in
      left := EBinop (op, !left, right)
    | None -> running := false
  done;
  !left

and parse_addition ps =
  let left = ref (parse_multiplication ps) in
  let running = ref true in
  while !running do
    let op = match (peek ps).kind with
      | TPlus -> Some OpPlus
      | TMinus -> Some OpMinus
      | _ -> None
    in
    match op with
    | Some op ->
      ignore (advance ps);
      let right = parse_multiplication ps in
      left := EBinop (op, !left, right)
    | None -> running := false
  done;
  !left

and parse_multiplication ps =
  let left = ref (parse_unary ps) in
  let running = ref true in
  while !running do
    let op = match (peek ps).kind with
      | TTimes when not (is_stopped ps TTimes) -> Some OpTimes
      | TDividedBy -> Some OpDividedBy
      | TModulo -> Some OpModulo
      | _ -> None
    in
    match op with
    | Some op ->
      ignore (advance ps);
      let right = parse_unary ps in
      left := EBinop (op, !left, right)
    | None -> running := false
  done;
  !left

and parse_unary ps =
  if (peek ps).kind = TNegative then begin
    ignore (advance ps);
    let e = parse_postfix ps in
    EUnary (OpNegative, e)
  end else
    parse_postfix ps

and parse_postfix ps =
  let left = ref (parse_primary ps) in
  let running = ref true in
  while !running do
    match (peek ps).kind with
    | TJoinedWith ->
      ignore (advance ps);
      let right = parse_primary ps in
      left := EBinop (OpJoinedWith, !left, right)
    | TAs ->
      ignore (advance ps);
      let ty = parse_type_name ps in
      left := EAsType (!left, ty)
    | TContains ->
      ignore (advance ps);
      let right = parse_primary ps in
      left := EBinop (OpContains, !left, right)
    | _ -> running := false
  done;
  !left

and parse_type_name ps =
  let t = advance ps in
  match t.kind with
  | TIdent "number" -> TyNumber
  | TIdent "string" -> TyString
  | TIdent "boolean" -> TyBoolean
  (* "number", "string", "boolean" could also appear as these tokens
     since they're not reserved keywords in the keyword table *)
  | _ -> raise (ParseError (t.line, "Expected type name (number, string, boolean)"))

and parse_primary ps =
  let t = peek ps in
  match t.kind with
  | TNumber n -> ignore (advance ps); ENumber n
  | TString s -> ignore (advance ps); EString s
  | TTrue -> ignore (advance ps); EBool true
  | TFalse -> ignore (advance ps); EBool false
  | TNothing -> ignore (advance ps); ENothing
  | TIdent "item" ->
    (* Could be "item N of list" or just the variable "item" *)
    (* Save state and try parsing as "item N of list" *)
    let saved = ps.toks in
    let saved_line = ps.current_line in
    ignore (advance ps); (* consume 'item' *)
    (try
       let old_stop = ps.stop_at in
       ps.stop_at <- TOf :: ps.stop_at;
       let idx = parse_expression ps in
       ps.stop_at <- old_stop;
       ignore (expect ps TOf);
       let lst = parse_primary ps in
       EItem (idx, lst)
     with ParseError _ ->
       ps.toks <- saved;
       ps.current_line <- saved_line;
       ignore (advance ps);
       EIdent "item")
  | TIdent name -> ignore (advance ps); EIdent name
  | TLParen ->
    ignore (advance ps);
    let e = parse_expression ps in
    ignore (expect ps TRParen);
    e
  | TLBracket ->
    ignore (advance ps);
    let elems = ref [] in
    if (peek ps).kind <> TRBracket then begin
      elems := [parse_expression ps];
      while (peek ps).kind = TComma do
        ignore (advance ps);
        elems := parse_expression ps :: !elems
      done
    end;
    ignore (expect ps TRBracket);
    EList (List.rev !elems)
  | TCall ->
    ignore (advance ps);
    let name_tok = advance ps in
    let name = (match name_tok.kind with
      | TIdent n -> n
      | _ -> raise (ParseError (name_tok.line, "Expected function name after 'call'"))) in
    let args =
      if (peek ps).kind = TWith then begin
        ignore (advance ps);
        let old_stop = ps.stop_at in
        ps.stop_at <- TAnd :: ps.stop_at;
        let args = ref [parse_expression ps] in
        while (peek ps).kind = TAnd do
          ignore (advance ps);
          args := parse_expression ps :: !args
        done;
        ps.stop_at <- old_stop;
        List.rev !args
      end else []
    in
    ECall (name, args)
  | TUppercaseOf ->
    ignore (advance ps);
    let e = parse_primary ps in
    EPrefix (PrefUppercase, e)
  | TLowercaseOf ->
    ignore (advance ps);
    let e = parse_primary ps in
    EPrefix (PrefLowercase, e)
  | TLengthOf ->
    ignore (advance ps);
    let e = parse_primary ps in
    EPrefix (PrefLength, e)
  | TFirstOf ->
    ignore (advance ps);
    let e = parse_primary ps in
    EPrefix (PrefFirst, e)
  | TLastOf ->
    ignore (advance ps);
    let e = parse_primary ps in
    EPrefix (PrefLast, e)
  | TSliceOf ->
    ignore (advance ps);
    let target = parse_primary ps in
    ignore (expect ps TFrom);
    let from_e = parse_expression ps in
    ignore (expect ps TTo);
    let to_e = parse_expression ps in
    ESlice (target, from_e, to_e)
  | _ ->
    raise (ParseError (t.line, Printf.sprintf "Unexpected token in expression"))

(* ---- Statement parsing ---- *)

and parse_statement ps : stmt =
  skip_newlines ps;
  let t = peek ps in
  let ln = t.line in
  match t.kind with
  | TPrint ->
    ignore (advance ps);
    let e = parse_expression ps in
    skip_newlines ps;
    SPrint (ln, e)
  | TSet ->
    ignore (advance ps);
    let name_tok = advance ps in
    let name = (match name_tok.kind with
      | TIdent n -> n
      | _ -> raise (ParseError (name_tok.line, "Expected variable name after 'set'"))) in
    ignore (expect ps TTo);
    let e = parse_expression ps in
    skip_newlines ps;
    SSet (ln, name, e)
  | TAppend ->
    ignore (advance ps);
    let e = parse_expression ps in
    ignore (expect ps TTo);
    let name_tok = advance ps in
    let name = (match name_tok.kind with
      | TIdent n -> n
      | _ -> raise (ParseError (name_tok.line, "Expected variable name after 'to'"))) in
    skip_newlines ps;
    SAppend (ln, e, name)
  | TIf ->
    parse_if ps
  | TWhile ->
    ignore (advance ps);
    let cond = parse_expression ps in
    ignore (expect ps TColon);
    let body = parse_block ps in
    SWhile (ln, cond, body)
  | TForEach ->
    ignore (advance ps);
    let var_tok = advance ps in
    let var_name = (match var_tok.kind with
      | TIdent n -> n
      | _ -> raise (ParseError (var_tok.line, "Expected variable name after 'for each'"))) in
    ignore (expect ps TIn);
    let e = parse_expression ps in
    ignore (expect ps TColon);
    let body = parse_block ps in
    SForEach (ln, var_name, e, body)
  | TFor ->
    ignore (advance ps);
    let var_tok = advance ps in
    let var_name = (match var_tok.kind with
      | TIdent n -> n
      | _ -> raise (ParseError (var_tok.line, "Expected variable name after 'for'"))) in
    ignore (expect ps TFrom);
    let from_e = parse_expression ps in
    ignore (expect ps TTo);
    let to_e = parse_expression ps in
    (* Handle "times:" at end for "repeat N times:" *)
    ignore (expect ps TColon);
    let body = parse_block ps in
    SForFrom (ln, var_name, from_e, to_e, body)
  | TRepeat ->
    ignore (advance ps);
    let old_stop = ps.stop_at in
    ps.stop_at <- TTimes :: ps.stop_at;
    let count = parse_expression ps in
    ps.stop_at <- old_stop;
    (* expect "times:" -- times followed by colon *)
    ignore (expect ps TTimes);
    ignore (expect ps TColon);
    let body = parse_block ps in
    SRepeat (ln, count, body)
  | TDefine ->
    ignore (advance ps);
    let name_tok = advance ps in
    let name = (match name_tok.kind with
      | TIdent n -> n
      | _ -> raise (ParseError (name_tok.line, "Expected function name after 'define'"))) in
    let params =
      if (peek ps).kind = TWith then begin
        ignore (advance ps);
        let params = ref [] in
        let p_tok = advance ps in
        (match p_tok.kind with
         | TIdent n -> params := [n]
         | _ -> raise (ParseError (p_tok.line, "Expected parameter name")));
        while (peek ps).kind = TAnd do
          ignore (advance ps);
          let p2_tok = advance ps in
          (match p2_tok.kind with
           | TIdent n -> params := n :: !params
           | _ -> raise (ParseError (p2_tok.line, "Expected parameter name")))
        done;
        List.rev !params
      end else []
    in
    ignore (expect ps TColon);
    let body = parse_block ps in
    SDefine (ln, name, params, body)
  | TCall ->
    ignore (advance ps);
    let name_tok = advance ps in
    let name = (match name_tok.kind with
      | TIdent n -> n
      | _ -> raise (ParseError (name_tok.line, "Expected function name after 'call'"))) in
    let args =
      if (peek ps).kind = TWith then begin
        ignore (advance ps);
        let old_stop = ps.stop_at in
        ps.stop_at <- TAnd :: ps.stop_at;
        let args = ref [parse_expression ps] in
        while (peek ps).kind = TAnd do
          ignore (advance ps);
          args := parse_expression ps :: !args
        done;
        ps.stop_at <- old_stop;
        List.rev !args
      end else []
    in
    skip_newlines ps;
    SCallStmt (ln, name, args)
  | TReturn ->
    ignore (advance ps);
    let e =
      match (peek ps).kind with
      | TNewline | TEOF | TDedent -> None
      | _ -> Some (parse_expression ps)
    in
    skip_newlines ps;
    SReturn (ln, e)
  | TStop ->
    ignore (advance ps);
    skip_newlines ps;
    SStop ln
  | TSkip ->
    ignore (advance ps);
    skip_newlines ps;
    SSkip ln
  | _ ->
    raise (ParseError (ln, "Unexpected token at start of statement"))

and parse_if ps : stmt =
  let ln = (peek ps).line in
  ignore (advance ps); (* consume 'if' *)
  let cond = parse_expression ps in
  ignore (expect ps TColon);
  let body = parse_block ps in
  let branches = ref [(cond, body)] in
  let else_body = ref None in
  let running = ref true in
  while !running do
    skip_newlines ps;
    match (peek ps).kind with
    | TOtherwiseIf ->
      ignore (advance ps);
      let c = parse_expression ps in
      ignore (expect ps TColon);
      let b = parse_block ps in
      branches := (c, b) :: !branches
    | TOtherwise ->
      ignore (advance ps);
      ignore (expect ps TColon);
      let b = parse_block ps in
      else_body := Some b;
      running := false
    | _ -> running := false
  done;
  SIf (ln, List.rev !branches, !else_body)

let parse_program ps =
  let stmts = ref [] in
  let running = ref true in
  while !running do
    skip_newlines ps;
    match (peek ps).kind with
    | TEOF -> running := false
    | _ -> stmts := parse_statement ps :: !stmts
  done;
  List.rev !stmts

(* ========================================================================= *)
(* Runtime Values                                                            *)
(* ========================================================================= *)

type value =
  | VNumber of float
  | VString of string
  | VBool of bool
  | VList of value list ref
  | VNothing

exception RuntimeError of int * string
exception ReturnExn of value
exception StopExn
exception SkipExn

(* ========================================================================= *)
(* Environment                                                               *)
(* ========================================================================= *)

type env = {
  vars : (string, value) Hashtbl.t;
  parent : env option;
}

let new_env parent = { vars = Hashtbl.create 16; parent }

let rec env_get env name =
  match Hashtbl.find_opt env.vars name with
  | Some v -> Some v
  | None ->
    match env.parent with
    | Some p -> env_get p name
    | None -> None

let env_set env name value =
  Hashtbl.replace env.vars name value

(* For lexical scoping: set in the scope where the var is defined,
   or in current scope if not found *)
let rec env_set_scoped env name value =
  if Hashtbl.mem env.vars name then
    Hashtbl.replace env.vars name value
  else
    match env.parent with
    | Some p ->
      (* Check if parent has it -- but spec says outer vars not writable from inner *)
      (* So we always set in current scope *)
      ignore p;
      Hashtbl.replace env.vars name value
    | None ->
      Hashtbl.replace env.vars name value

(* ========================================================================= *)
(* String contains (no Str dependency)                                       *)
(* ========================================================================= *)

let string_contains haystack needle =
  let hl = String.length haystack in
  let nl = String.length needle in
  if nl = 0 then true
  else if nl > hl then false
  else begin
    let found = ref false in
    for i = 0 to hl - nl do
      if not !found && String.sub haystack i nl = needle then
        found := true
    done;
    !found
  end

(* ========================================================================= *)
(* Interpreter                                                               *)
(* ========================================================================= *)

type func_def = {
  params : string list;
  body : stmt list;
  closure_env : env;
}

type interp_state = {
  funcs : (string, func_def) Hashtbl.t;
  mutable in_loop : int;  (* nesting depth *)
}

let format_value v =
  let rec fmt v =
    match v with
    | VNumber n ->
      if Float.is_integer n && Float.is_finite n then
        string_of_int (int_of_float n)
      else begin
        (* Up to 6 decimal places, no trailing zeros *)
        let s = Printf.sprintf "%.6f" n in
        (* Remove trailing zeros after decimal point *)
        let len = String.length s in
        let i = ref (len - 1) in
        while !i > 0 && s.[!i] = '0' do i := !i - 1 done;
        if s.[!i] = '.' then i := !i - 1;
        String.sub s 0 (!i + 1)
      end
    | VString s -> s
    | VBool b -> if b then "true" else "false"
    | VNothing -> "nothing"
    | VList items ->
      let inner = List.map (fun v ->
        match v with
        | VString s -> "\"" ^ s ^ "\""
        | _ -> fmt v
      ) !items in
      "[" ^ String.concat ", " inner ^ "]"
  in
  fmt v

(* For joined with: convert any value to string representation *)
let value_to_string v =
  match v with
  | VString s -> s
  | _ -> format_value v

let rec eval_expr (state : interp_state) (env : env) (line : int) (e : expr) : value =
  let err msg = raise (RuntimeError (line, msg)) in
  match e with
  | ENumber n -> VNumber n
  | EString s -> VString s
  | EBool b -> VBool b
  | ENothing -> VNothing
  | EIdent name ->
    (match env_get env name with
     | Some v -> v
     | None -> err (Printf.sprintf "Undefined variable '%s'" name))
  | EList elems ->
    let vals = List.map (eval_expr state env line) elems in
    VList (ref vals)
  | EBinop (op, left, right) ->
    eval_binop state env line op left right
  | EUnary (op, inner) ->
    let v = eval_expr state env line inner in
    (match op with
     | OpNot ->
       (match v with
        | VBool b -> VBool (not b)
        | _ -> err "Operand of 'not' must be a boolean")
     | OpNegative ->
       (match v with
        | VNumber n -> VNumber (-.n)
        | _ -> err "Operand of 'negative' must be a number"))
  | EPrefix (op, inner) ->
    let v = eval_expr state env line inner in
    (match op with
     | PrefUppercase ->
       (match v with
        | VString s -> VString (String.uppercase_ascii s)
        | _ -> err "uppercase requires a string")
     | PrefLowercase ->
       (match v with
        | VString s -> VString (String.lowercase_ascii s)
        | _ -> err "lowercase requires a string")
     | PrefLength ->
       (match v with
        | VString s -> VNumber (float_of_int (String.length s))
        | VList items -> VNumber (float_of_int (List.length !items))
        | _ -> err "length requires a string or list")
     | PrefFirst ->
       (match v with
        | VList items ->
          (match !items with
           | [] -> err "Cannot get first of empty list"
           | x :: _ -> x)
        | _ -> err "first requires a list")
     | PrefLast ->
       (match v with
        | VList items ->
          (match !items with
           | [] -> err "Cannot get last of empty list"
           | _ -> List.nth !items (List.length !items - 1))
        | _ -> err "last requires a list"))
  | ECall (name, arg_exprs) ->
    eval_call state env line name arg_exprs
  | EAsType (inner, ty) ->
    let v = eval_expr state env line inner in
    eval_type_conv line v ty
  | EItem (idx_expr, list_expr) ->
    let idx_v = eval_expr state env line idx_expr in
    let list_v = eval_expr state env line list_expr in
    (match idx_v, list_v with
     | VNumber n, VList items ->
       let i = int_of_float n in
       let len = List.length !items in
       if i < 0 || i >= len then
         err (Printf.sprintf "Index %d out of bounds (length %d)" i len)
       else
         List.nth !items i
     | _ -> err "item requires a number index and a list")
  | ESlice (target_expr, from_expr, to_expr) ->
    let target = eval_expr state env line target_expr in
    let from_v = eval_expr state env line from_expr in
    let to_v = eval_expr state env line to_expr in
    (match from_v, to_v with
     | VNumber f, VNumber t ->
       let fi = int_of_float f in
       let ti = int_of_float t in
       (match target with
        | VString s ->
          let len = String.length s in
          let fi = max 0 fi in
          let ti = min len ti in
          if fi >= ti then VString ""
          else VString (String.sub s fi (ti - fi))
        | VList items ->
          let len = List.length !items in
          let fi = max 0 fi in
          let ti = min len ti in
          let result = ref [] in
          for i = fi to ti - 1 do
            result := List.nth !items i :: !result
          done;
          VList (ref (List.rev !result))
        | _ -> err "slice requires a string or list")
     | _ -> err "slice bounds must be numbers")

and eval_binop state env line op left_expr right_expr =
  let err msg = raise (RuntimeError (line, msg)) in
  (* Short-circuit for and/or *)
  match op with
  | OpAnd ->
    let lv = eval_expr state env line left_expr in
    (match lv with
     | VBool false -> VBool false
     | VBool true ->
       let rv = eval_expr state env line right_expr in
       (match rv with
        | VBool _ -> rv
        | _ -> err "Operand of 'and' must be a boolean")
     | _ -> err "Operand of 'and' must be a boolean")
  | OpOr ->
    let lv = eval_expr state env line left_expr in
    (match lv with
     | VBool true -> VBool true
     | VBool false ->
       let rv = eval_expr state env line right_expr in
       (match rv with
        | VBool _ -> rv
        | _ -> err "Operand of 'or' must be a boolean")
     | _ -> err "Operand of 'or' must be a boolean")
  | _ ->
    let lv = eval_expr state env line left_expr in
    let rv = eval_expr state env line right_expr in
    match op with
    | OpPlus ->
      (match lv, rv with
       | VNumber a, VNumber b -> VNumber (a +. b)
       | _ -> err "Operands of 'plus' must be numbers")
    | OpMinus ->
      (match lv, rv with
       | VNumber a, VNumber b -> VNumber (a -. b)
       | _ -> err "Operands of 'minus' must be numbers")
    | OpTimes ->
      (match lv, rv with
       | VNumber a, VNumber b -> VNumber (a *. b)
       | _ -> err "Operands of 'times' must be numbers")
    | OpDividedBy ->
      (match lv, rv with
       | VNumber _, VNumber 0.0 -> err "Division by zero"
       | VNumber a, VNumber b ->
         if b = 0.0 then err "Division by zero"
         else VNumber (a /. b)
       | _ -> err "Operands of 'divided by' must be numbers")
    | OpModulo ->
      (match lv, rv with
       | VNumber a, VNumber b ->
         if b = 0.0 then err "Division by zero"
         else VNumber (Float.rem a b)
       | _ -> err "Operands of 'modulo' must be numbers")
    | OpEq ->
      VBool (values_equal lv rv)
    | OpNeq ->
      VBool (not (values_equal lv rv))
    | OpGt ->
      (match lv, rv with
       | VNumber a, VNumber b -> VBool (a > b)
       | VString a, VString b -> VBool (a > b)
       | _ -> err "Cannot compare these types with 'is greater than'")
    | OpLt ->
      (match lv, rv with
       | VNumber a, VNumber b -> VBool (a < b)
       | VString a, VString b -> VBool (a < b)
       | _ -> err "Cannot compare these types with 'is less than'")
    | OpGte ->
      (match lv, rv with
       | VNumber a, VNumber b -> VBool (a >= b)
       | VString a, VString b -> VBool (a >= b)
       | _ -> err "Cannot compare these types with 'is at least'")
    | OpLte ->
      (match lv, rv with
       | VNumber a, VNumber b -> VBool (a <= b)
       | VString a, VString b -> VBool (a <= b)
       | _ -> err "Cannot compare these types with 'is at most'")
    | OpJoinedWith ->
      let ls = value_to_string lv in
      let rs = value_to_string rv in
      VString (ls ^ rs)
    | OpContains ->
      (match lv with
       | VString s ->
         (match rv with
          | VString sub -> VBool (string_contains s sub)
          | _ -> err "String contains requires a string argument")
       | VList items ->
         VBool (List.exists (fun item -> values_equal item rv) !items)
       | _ -> err "contains requires a string or list")
    | OpAnd | OpOr -> assert false (* handled above *)

and values_equal a b =
  match a, b with
  | VNumber x, VNumber y -> x = y
  | VString x, VString y -> x = y
  | VBool x, VBool y -> x = y
  | VNothing, VNothing -> true
  | VList la, VList lb ->
    let la = !la and lb = !lb in
    List.length la = List.length lb &&
    List.for_all2 values_equal la lb
  | _ -> false

and eval_type_conv line v ty =
  let err msg = raise (RuntimeError (line, msg)) in
  match ty with
  | TyNumber ->
    (match v with
     | VNumber _ -> v
     | VString s ->
       (try VNumber (float_of_string s)
        with Failure _ -> err (Printf.sprintf "Cannot convert \"%s\" to number" s))
     | VBool b -> VNumber (if b then 1.0 else 0.0)
     | _ -> err "Cannot convert to number")
  | TyString ->
    VString (value_to_string v)
  | TyBoolean ->
    let b = match v with
      | VNumber n -> n <> 0.0
      | VString s -> String.length s > 0
      | VBool b -> b
      | VList items -> List.length !items > 0
      | VNothing -> false
    in
    VBool b

and eval_call state env line name arg_exprs =
  let err msg = raise (RuntimeError (line, msg)) in
  match Hashtbl.find_opt state.funcs name with
  | None -> err (Printf.sprintf "Undefined function '%s'" name)
  | Some func ->
    let args = List.map (eval_expr state env line) arg_exprs in
    if List.length args <> List.length func.params then
      err (Printf.sprintf "Function '%s' expects %d arguments, got %d"
             name (List.length func.params) (List.length args));
    let func_env = new_env (Some func.closure_env) in
    List.iter2 (fun p a -> env_set func_env p a) func.params args;
    try
      exec_stmts state func_env func.body;
      VNothing
    with
    | ReturnExn v -> v

and exec_stmt (state : interp_state) (env : env) (s : stmt) : unit =
  match s with
  | SPrint (line, e) ->
    let v = eval_expr state env line e in
    print_string (format_value v);
    print_char '\n'
  | SSet (line, name, e) ->
    let v = eval_expr state env line e in
    env_set_scoped env name v
  | SAppend (line, e, name) ->
    let v = eval_expr state env line e in
    (match env_get env name with
     | Some (VList items) -> items := !items @ [v]
     | Some _ -> raise (RuntimeError (line, Printf.sprintf "'%s' is not a list" name))
     | None -> raise (RuntimeError (line, Printf.sprintf "Undefined variable '%s'" name)))
  | SIf (line, branches, else_body) ->
    let rec try_branches = function
      | [] ->
        (match else_body with
         | Some body -> exec_stmts state env body
         | None -> ())
      | (cond, body) :: rest ->
        let cv = eval_expr state env line cond in
        (match cv with
         | VBool true -> exec_stmts state env body
         | VBool false -> try_branches rest
         | _ -> raise (RuntimeError (line, "Condition in 'if' must be a boolean")))
    in
    try_branches branches
  | SWhile (line, cond, body) ->
    state.in_loop <- state.in_loop + 1;
    (try
       let running = ref true in
       while !running do
         let cv = eval_expr state env line cond in
         match cv with
         | VBool true ->
           (try exec_stmts state env body
            with SkipExn -> ())
         | VBool false -> running := false
         | _ -> raise (RuntimeError (line, "Condition in 'while' must be a boolean"))
       done
     with StopExn -> ());
    state.in_loop <- state.in_loop - 1
  | SForEach (line, var_name, list_expr, body) ->
    let lv = eval_expr state env line list_expr in
    (match lv with
     | VList items ->
       state.in_loop <- state.in_loop + 1;
       (try
          List.iter (fun item ->
            env_set env var_name item;
            try exec_stmts state env body
            with SkipExn -> ()
          ) !items
        with StopExn -> ());
       state.in_loop <- state.in_loop - 1
     | _ -> raise (RuntimeError (line, "for each requires a list")))
  | SForFrom (line, var_name, from_expr, to_expr, body) ->
    let fv = eval_expr state env line from_expr in
    let tv = eval_expr state env line to_expr in
    (match fv, tv with
     | VNumber f, VNumber t ->
       let fi = int_of_float f in
       let ti = int_of_float t in
       state.in_loop <- state.in_loop + 1;
       (try
          for i = fi to ti do
            env_set env var_name (VNumber (float_of_int i));
            try exec_stmts state env body
            with SkipExn -> ()
          done
        with StopExn -> ());
       state.in_loop <- state.in_loop - 1
     | _ -> raise (RuntimeError (line, "for..from..to requires numbers")))
  | SRepeat (line, count_expr, body) ->
    let cv = eval_expr state env line count_expr in
    (match cv with
     | VNumber n ->
       let count = int_of_float n in
       state.in_loop <- state.in_loop + 1;
       (try
          for _ = 1 to count do
            try exec_stmts state env body
            with SkipExn -> ()
          done
        with StopExn -> ());
       state.in_loop <- state.in_loop - 1
     | _ -> raise (RuntimeError (line, "repeat requires a number")))
  | SDefine (_, name, params, body) ->
    Hashtbl.replace state.funcs name { params; body; closure_env = env }
  | SCallStmt (line, name, arg_exprs) ->
    ignore (eval_call state env line name arg_exprs)
  | SReturn (_, e) ->
    let v = match e with
      | Some expr -> eval_expr state env 0 expr
      | None -> VNothing
    in
    raise (ReturnExn v)
  | SStop line ->
    if state.in_loop = 0 then
      raise (RuntimeError (line, "'stop' used outside of a loop"));
    raise StopExn
  | SSkip line ->
    if state.in_loop = 0 then
      raise (RuntimeError (line, "'skip' used outside of a loop"));
    raise SkipExn

and exec_stmts state env stmts =
  List.iter (exec_stmt state env) stmts

(* ========================================================================= *)
(* Main                                                                      *)
(* ========================================================================= *)

let () =
  if Array.length Sys.argv < 2 then begin
    Printf.eprintf "Usage: humanlang <file.hl>\n";
    exit 1
  end;
  let filename = Sys.argv.(1) in
  let ic = open_in filename in
  let n = in_channel_length ic in
  let source = Bytes.create n in
  really_input ic source 0 n;
  close_in ic;
  let source = Bytes.to_string source in
  try
    let tokens = lex source in
    let ps = make_parser tokens in
    let program = parse_program ps in
    let state = { funcs = Hashtbl.create 16; in_loop = 0 } in
    let global_env = new_env None in
    exec_stmts state global_env program
  with
  | LexError (line, msg) ->
    Printf.eprintf "Error on line %d: %s\n" line msg;
    exit 1
  | ParseError (line, msg) ->
    Printf.eprintf "Error on line %d: %s\n" line msg;
    exit 1
  | RuntimeError (line, msg) ->
    Printf.eprintf "Error on line %d: %s\n" line msg;
    exit 1
