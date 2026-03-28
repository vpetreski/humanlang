module Main where

import Control.Monad (when)
import Data.Char (isAlpha, isAlphaNum, isDigit, toLower, toUpper)
import Data.IORef
import Data.List (intercalate, isInfixOf, isPrefixOf)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr, hFlush, stdout)

-- ============================================================================
-- Token types
-- ============================================================================

data Token
  = TokPrint | TokSet | TokTo | TokIf | TokOtherwise | TokOtherwiseIf
  | TokWhile | TokForEach | TokFor | TokFrom | TokRepeat | TokTimes
  | TokDefine | TokWith | TokCall | TokReturn | TokAppend | TokIn
  | TokStop | TokSkip | TokAnd | TokOr | TokNot
  | TokPlus | TokMinus | TokTimesOp | TokDividedBy | TokModulo
  | TokIsEqualTo | TokIsNotEqualTo | TokIsGreaterThan | TokIsLessThan
  | TokIsAtLeast | TokIsAtMost
  | TokJoinedWith | TokContains
  | TokUppercaseOf | TokLowercaseOf | TokLengthOf | TokFirstOf | TokLastOf
  | TokSliceOf  -- "slice of" ... "from" ... "to"
  | TokAs | TokNegative
  | TokTrue | TokFalse | TokNothing
  | TokNumber Double | TokString String | TokIdent String
  | TokLParen | TokRParen | TokLBracket | TokRBracket | TokComma | TokColon
  | TokNewline | TokIndent | TokDedent
  | TokEOF
  | TokOf    -- bare "of" keyword
  deriving (Show, Eq)

data Located = Located { locLine :: !Int, locTok :: !Token }
  deriving (Show)

-- ============================================================================
-- Lexer
-- ============================================================================

lexAll :: String -> [Located]
lexAll input = postProcess $ lexLines (lines input) 1 [0]

lexLines :: [String] -> Int -> [Int] -> [Located]
lexLines [] lineNum indentStack =
  -- Emit dedents at EOF
  map (\_ -> Located lineNum TokDedent) (drop 1 indentStack)
  ++ [Located lineNum TokEOF]
lexLines (ln : rest) lineNum indentStack
  -- Skip blank lines and comment lines
  | all (\c -> c == ' ' || c == '\t') stripped = lexLines rest (lineNum + 1) indentStack
  | "--" `isPrefixOf` stripped = lexLines rest (lineNum + 1) indentStack
  | otherwise =
      let indent = countIndent ln
          curIndent = case indentStack of { (x:_) -> x; [] -> 0 }
      in if indent > curIndent then
           Located lineNum TokIndent
           : lexLine (dropWhile (== ' ') ln) lineNum
           ++ [Located lineNum TokNewline]
           ++ lexLines rest (lineNum + 1) (indent : indentStack)
         else if indent < curIndent then
           let (dedents, newStack) = popIndents indent indentStack lineNum
           in dedents
              ++ lexLine (dropWhile (== ' ') ln) lineNum
              ++ [Located lineNum TokNewline]
              ++ lexLines rest (lineNum + 1) newStack
         else
           lexLine (dropWhile (== ' ') ln) lineNum
           ++ [Located lineNum TokNewline]
           ++ lexLines rest (lineNum + 1) indentStack
  where
    stripped = dropWhile (== ' ') ln

countIndent :: String -> Int
countIndent = length . takeWhile (== ' ')

popIndents :: Int -> [Int] -> Int -> ([Located], [Int])
popIndents target (s : ss) lineNum
  | s == target = ([], s : ss)
  | s > target  = let (more, stack') = popIndents target ss lineNum
                  in (Located lineNum TokDedent : more, stack')
  | otherwise   = ([], s : ss)  -- Error: bad dedent
popIndents _ [] _ = ([], [0])

-- Lex a single line (stripped of leading indent) into tokens
lexLine :: String -> Int -> [Located]
lexLine [] _ = []
lexLine (' ' : cs) lineNum = lexLine cs lineNum
lexLine ('-' : '-' : _) _ = []  -- rest is comment
lexLine ('"' : cs) lineNum =
  let (s, rest) = lexString cs lineNum
  in Located lineNum (TokString s) : lexLine rest lineNum
lexLine ('[' : cs) lineNum = Located lineNum TokLBracket : lexLine cs lineNum
lexLine (']' : cs) lineNum = Located lineNum TokRBracket : lexLine cs lineNum
lexLine ('(' : cs) lineNum = Located lineNum TokLParen : lexLine cs lineNum
lexLine (')' : cs) lineNum = Located lineNum TokRParen : lexLine cs lineNum
lexLine (',' : cs) lineNum = Located lineNum TokComma : lexLine cs lineNum
lexLine (':' : cs) lineNum = Located lineNum TokColon : lexLine cs lineNum
lexLine input@(c : _) lineNum
  | isDigit c =
      let (numStr, rest) = lexNumber input
      in Located lineNum (TokNumber (read numStr)) : lexLine rest lineNum
  | isAlpha c =
      let (word, rest) = span (\ch -> isAlphaNum ch || ch == '_') input
      in matchKeyword word rest lineNum
  | otherwise = lexLine (drop 1 input) lineNum  -- skip unknown chars

lexNumber :: String -> (String, String)
lexNumber s =
  let (intPart, r1) = span isDigit s
  in case r1 of
       ('.' : r2@(d:_))
         | isDigit d ->
             let (decPart, r3) = span isDigit r2
             in (intPart ++ "." ++ decPart, r3)
       _ -> (intPart, r1)

lexString :: String -> Int -> (String, String)
lexString [] _ = ("", "")
lexString ('"' : rest) _ = ("", rest)
lexString ('\\' : 'n' : rest) ln = let (s, r) = lexString rest ln in ('\n' : s, r)
lexString ('\\' : 't' : rest) ln = let (s, r) = lexString rest ln in ('\t' : s, r)
lexString ('\\' : '\\' : rest) ln = let (s, r) = lexString rest ln in ('\\' : s, r)
lexString ('\\' : '"' : rest) ln = let (s, r) = lexString rest ln in ('"' : s, r)
lexString (c : rest) ln = let (s, r) = lexString rest ln in (c : s, r)

-- Multi-word keyword matching
matchKeyword :: String -> String -> Int -> [Located]
matchKeyword word rest lineNum = case word of
  -- Multi-word keywords: try to match longer sequences first
  "divided"     -> tryMulti "divided" [("by", TokDividedBy)] rest lineNum
  "is"          -> tryMultiIs rest lineNum
  "otherwise"   -> tryMulti "otherwise" [("if", TokOtherwiseIf)] rest lineNum
  "for"         -> tryMulti "for" [("each", TokForEach)] rest lineNum
  "joined"      -> tryMulti "joined" [("with", TokJoinedWith)] rest lineNum
  "uppercase"   -> tryMulti "uppercase" [("of", TokUppercaseOf)] rest lineNum
  "lowercase"   -> tryMulti "lowercase" [("of", TokLowercaseOf)] rest lineNum
  "length"      -> tryMulti "length" [("of", TokLengthOf)] rest lineNum
  "first"       -> tryMulti "first" [("of", TokFirstOf)] rest lineNum
  "last"        -> tryMulti "last" [("of", TokLastOf)] rest lineNum
  "slice"       -> tryMulti "slice" [("of", TokSliceOf)] rest lineNum
  -- Simple keywords
  "print"    -> Located lineNum TokPrint : lexLine rest lineNum
  "set"      -> Located lineNum TokSet : lexLine rest lineNum
  "to"       -> Located lineNum TokTo : lexLine rest lineNum
  "if"       -> Located lineNum TokIf : lexLine rest lineNum
  "otherwise"-> Located lineNum TokOtherwise : lexLine rest lineNum
  "while"    -> Located lineNum TokWhile : lexLine rest lineNum
  "from"     -> Located lineNum TokFrom : lexLine rest lineNum
  "repeat"   -> Located lineNum TokRepeat : lexLine rest lineNum
  "times"    -> Located lineNum TokTimesOp : lexLine rest lineNum
  "define"   -> Located lineNum TokDefine : lexLine rest lineNum
  "with"     -> Located lineNum TokWith : lexLine rest lineNum
  "call"     -> Located lineNum TokCall : lexLine rest lineNum
  "return"   -> Located lineNum TokReturn : lexLine rest lineNum
  "append"   -> Located lineNum TokAppend : lexLine rest lineNum
  "in"       -> Located lineNum TokIn : lexLine rest lineNum
  "stop"     -> Located lineNum TokStop : lexLine rest lineNum
  "skip"     -> Located lineNum TokSkip : lexLine rest lineNum
  "and"      -> Located lineNum TokAnd : lexLine rest lineNum
  "or"       -> Located lineNum TokOr : lexLine rest lineNum
  "not"      -> Located lineNum TokNot : lexLine rest lineNum
  "plus"     -> Located lineNum TokPlus : lexLine rest lineNum
  "minus"    -> Located lineNum TokMinus : lexLine rest lineNum
  "modulo"   -> Located lineNum TokModulo : lexLine rest lineNum
  "contains" -> Located lineNum TokContains : lexLine rest lineNum
  "as"       -> Located lineNum TokAs : lexLine rest lineNum
  "negative" -> Located lineNum TokNegative : lexLine rest lineNum
  "true"     -> Located lineNum TokTrue : lexLine rest lineNum
  "false"    -> Located lineNum TokFalse : lexLine rest lineNum
  "nothing"  -> Located lineNum TokNothing : lexLine rest lineNum
  "of"       -> Located lineNum TokOf : lexLine rest lineNum
  _          -> Located lineNum (TokIdent word) : lexLine rest lineNum

-- Try to match a multi-word keyword
tryMulti :: String -> [(String, Token)] -> String -> Int -> [Located]
tryMulti base options rest lineNum =
  let rest' = dropWhile (== ' ') rest
  in case options of
    [(nextWord, tok)] ->
      if take (length nextWord) rest' == nextWord &&
         (length rest' == length nextWord ||
          not (isAlphaNum (rest' !! length nextWord) || rest' !! length nextWord == '_'))
        then Located lineNum tok : lexLine (drop (length nextWord) rest') lineNum
        else -- Fall back to treating base as identifier or simple keyword
             case base of
               "for"       -> Located lineNum TokFor : lexLine rest lineNum
               "otherwise" -> Located lineNum TokOtherwise : lexLine (rest) lineNum
               _           -> Located lineNum (TokIdent base) : lexLine rest lineNum
    _ -> Located lineNum (TokIdent base) : lexLine rest lineNum

-- Handle "is equal to", "is not equal to", "is greater than", "is less than",
-- "is at least", "is at most"
tryMultiIs :: String -> Int -> [Located]
tryMultiIs rest lineNum =
  let rest' = dropWhile (== ' ') rest
  in
    if matchWords "not equal to" rest'
      then Located lineNum TokIsNotEqualTo : lexLine (dropWords "not equal to" rest') lineNum
    else if matchWords "equal to" rest'
      then Located lineNum TokIsEqualTo : lexLine (dropWords "equal to" rest') lineNum
    else if matchWords "greater than" rest'
      then Located lineNum TokIsGreaterThan : lexLine (dropWords "greater than" rest') lineNum
    else if matchWords "less than" rest'
      then Located lineNum TokIsLessThan : lexLine (dropWords "less than" rest') lineNum
    else if matchWords "at least" rest'
      then Located lineNum TokIsAtLeast : lexLine (dropWords "at least" rest') lineNum
    else if matchWords "at most" rest'
      then Located lineNum TokIsAtMost : lexLine (dropWords "at most" rest') lineNum
    else
      -- "is" is not a standalone keyword; treat as identifier
      Located lineNum (TokIdent "is") : lexLine rest lineNum

matchWords :: String -> String -> Bool
matchWords target input =
  target `isPrefixOf` input &&
  (length input == length target ||
   let c = input !! length target in c == ' ' || c == ':' || c == ')' || c == ']' || c == ',')

dropWords :: String -> String -> String
dropWords target input = drop (length target) input

-- Post-process: remove redundant newlines, ensure proper structure
postProcess :: [Located] -> [Located]
postProcess = filter (\(Located _ t) -> t /= TokNewline)

-- ============================================================================
-- AST
-- ============================================================================

data Expr
  = ENumber Double
  | EString String
  | EBool Bool
  | ENothing
  | EVar String
  | EList [Expr]
  | EBinOp BinOp Expr Expr
  | EUnaryNot Expr
  | EUnaryNeg Expr
  | EJoinedWith Expr Expr
  | EContains Expr Expr
  | EAs Expr TypeName
  | EUppercase Expr
  | ELowercase Expr
  | ELength Expr
  | EFirst Expr
  | ELast Expr
  | EItemOf Expr Expr    -- item <idx> of <list>
  | ESlice Expr Expr Expr -- slice of <target> from <start> to <end>
  | ECall String [Expr]
  deriving (Show)

data BinOp
  = OpPlus | OpMinus | OpTimes | OpDivBy | OpModulo
  | OpEq | OpNeq | OpGt | OpLt | OpGte | OpLte
  | OpAnd | OpOr
  deriving (Show, Eq)

data TypeName = TNumber | TString | TBoolean
  deriving (Show)

data Stmt
  = SPrint Expr
  | SSet String Expr
  | SAppend Expr String
  | SIf [(Expr, [Stmt])] (Maybe [Stmt])   -- (condition, body) branches + optional else
  | SWhile Expr [Stmt]
  | SForEach String Expr [Stmt]
  | SForFrom String Expr Expr [Stmt]
  | SRepeat Expr [Stmt]
  | SDefine String [String] [Stmt]
  | SCall String [Expr]   -- standalone call statement
  | SReturn (Maybe Expr)
  | SStop
  | SSkip
  deriving (Show)

-- ============================================================================
-- Parser
-- ============================================================================

data ParseState = ParseState
  { psToks :: [Located]
  , psLine :: Int
  } deriving (Show)

type Parser a = ParseState -> Either String (a, ParseState)

pPeek :: ParseState -> Token
pPeek (ParseState [] _) = TokEOF
pPeek (ParseState (Located _ t : _) _) = t

pAdvance :: ParseState -> ParseState
pAdvance (ParseState [] ln) = ParseState [] ln
pAdvance (ParseState (Located ln _ : rest) _) = ParseState rest ln

pExpect :: Token -> ParseState -> Either String ParseState
pExpect expected ps =
  if pPeek ps == expected
    then Right (pAdvance ps)
    else Left $ "Error on line " ++ show (psLine ps) ++ ": expected " ++ show expected ++ " but got " ++ show (pPeek ps)

parseProgram :: [Located] -> Either String [Stmt]
parseProgram toks = do
  let ps = ParseState toks 1
  (stmts, _) <- parseStmts ps
  return stmts

parseStmts :: Parser [Stmt]
parseStmts ps = case pPeek ps of
  TokEOF    -> Right ([], ps)
  TokDedent -> Right ([], ps)
  _         -> do
    (stmt, ps') <- parseStmt ps
    (rest, ps'') <- parseStmts ps'
    return (stmt : rest, ps'')

parseStmt :: Parser Stmt
parseStmt ps = case pPeek ps of
  TokPrint    -> parsePrint (pAdvance ps)
  TokSet      -> parseSet (pAdvance ps)
  TokAppend   -> parseAppend (pAdvance ps)
  TokIf       -> parseIf (pAdvance ps)
  TokWhile    -> parseWhile (pAdvance ps)
  TokForEach  -> parseForEach (pAdvance ps)
  TokFor      -> parseFor (pAdvance ps)
  TokRepeat   -> parseRepeat (pAdvance ps)
  TokDefine   -> parseDefine (pAdvance ps)
  TokCall     -> parseCallStmt ps
  TokReturn   -> parseReturn (pAdvance ps)
  TokStop     -> Right (SStop, pAdvance ps)
  TokSkip     -> Right (SSkip, pAdvance ps)
  t           -> Left $ "Error on line " ++ show (psLine ps) ++ ": unexpected token " ++ show t

parsePrint :: Parser Stmt
parsePrint ps = do
  (expr, ps') <- parseExpr ps
  return (SPrint expr, ps')

parseSet :: Parser Stmt
parseSet ps = case pPeek ps of
  TokIdent name -> do
    ps' <- pExpect TokTo (pAdvance ps)
    (expr, ps'') <- parseExpr ps'
    return (SSet name expr, ps'')
  _ -> Left $ "Error on line " ++ show (psLine ps) ++ ": expected identifier after 'set'"

parseAppend :: Parser Stmt
parseAppend ps = do
  (expr, ps') <- parseExpr ps
  ps'' <- pExpect TokTo ps'
  case pPeek ps'' of
    TokIdent name -> Right (SAppend expr name, pAdvance ps'')
    _ -> Left $ "Error on line " ++ show (psLine ps'') ++ ": expected identifier after 'to' in append"

parseIf :: Parser Stmt
parseIf ps = do
  (cond, ps1) <- parseExpr ps
  ps2 <- pExpect TokColon ps1
  (body, ps3) <- parseBlock ps2
  parseIfCont [(cond, body)] ps3

parseIfCont :: [(Expr, [Stmt])] -> Parser Stmt
parseIfCont branches ps = case pPeek ps of
  TokOtherwiseIf -> do
    (cond, ps1) <- parseExpr (pAdvance ps)
    ps2 <- pExpect TokColon ps1
    (body, ps3) <- parseBlock ps2
    parseIfCont (branches ++ [(cond, body)]) ps3
  TokOtherwise -> do
    ps1 <- pExpect TokColon (pAdvance ps)
    (body, ps2) <- parseBlock ps1
    return (SIf branches (Just body), ps2)
  _ -> return (SIf branches Nothing, ps)

parseWhile :: Parser Stmt
parseWhile ps = do
  (cond, ps1) <- parseExpr ps
  ps2 <- pExpect TokColon ps1
  (body, ps3) <- parseBlock ps2
  return (SWhile cond body, ps3)

parseForEach :: Parser Stmt
parseForEach ps = case pPeek ps of
  TokIdent name -> do
    ps1 <- pExpect TokIn (pAdvance ps)
    (expr, ps2) <- parseExpr ps1
    ps3 <- pExpect TokColon ps2
    (body, ps4) <- parseBlock ps3
    return (SForEach name expr body, ps4)
  _ -> Left $ "Error on line " ++ show (psLine ps) ++ ": expected identifier after 'for each'"

parseFor :: Parser Stmt
parseFor ps = case pPeek ps of
  TokIdent name -> do
    ps1 <- pExpect TokFrom (pAdvance ps)
    (fromExpr, ps2) <- parseExpr ps1
    ps3 <- pExpect TokTo ps2
    (toExpr, ps4) <- parseExpr ps3
    ps5 <- pExpect TokColon ps4
    (body, ps6) <- parseBlock ps5
    return (SForFrom name fromExpr toExpr body, ps6)
  _ -> Left $ "Error on line " ++ show (psLine ps) ++ ": expected identifier after 'for'"

parseRepeat :: Parser Stmt
parseRepeat ps = do
  -- Parse at unary level so "times" keyword is not consumed as multiplication
  (expr, ps1) <- parseUnary ps
  ps2 <- pExpect TokTimesOp ps1
  ps3 <- pExpect TokColon ps2
  (body, ps4) <- parseBlock ps3
  return (SRepeat expr body, ps4)

parseDefine :: Parser Stmt
parseDefine ps = case pPeek ps of
  TokIdent name -> do
    let ps1 = pAdvance ps
    case pPeek ps1 of
      TokWith -> do
        (params, ps2) <- parseParams (pAdvance ps1)
        ps3 <- pExpect TokColon ps2
        (body, ps4) <- parseBlock ps3
        return (SDefine name params body, ps4)
      TokColon -> do
        (body, ps3) <- parseBlock (pAdvance ps1)
        return (SDefine name [] body, ps3)
      _ -> Left $ "Error on line " ++ show (psLine ps1) ++ ": expected 'with' or ':' after function name"
  _ -> Left $ "Error on line " ++ show (psLine ps) ++ ": expected function name after 'define'"

parseParams :: Parser [String]
parseParams ps = case pPeek ps of
  TokIdent name -> do
    let ps1 = pAdvance ps
    case pPeek ps1 of
      TokAnd -> do
        (rest, ps2) <- parseParams (pAdvance ps1)
        return (name : rest, ps2)
      _ -> return ([name], ps1)
  _ -> Left $ "Error on line " ++ show (psLine ps) ++ ": expected parameter name"

parseCallStmt :: Parser Stmt
parseCallStmt ps = do
  (expr, ps') <- parseCallExpr ps
  case expr of
    ECall name args -> return (SCall name args, ps')
    _ -> Left $ "Error on line " ++ show (psLine ps) ++ ": expected function call"

parseReturn :: Parser Stmt
parseReturn ps = case pPeek ps of
  TokEOF    -> Right (SReturn Nothing, ps)
  TokDedent -> Right (SReturn Nothing, ps)
  _ ->
    -- Check if there's actually an expression to parse
    -- by looking at whether the next token could start an expression
    if canStartExpr (pPeek ps)
      then do
        (expr, ps') <- parseExpr ps
        return (SReturn (Just expr), ps')
      else Right (SReturn Nothing, ps)

canStartExpr :: Token -> Bool
canStartExpr t = case t of
  TokNumber _  -> True
  TokString _  -> True
  TokTrue      -> True
  TokFalse     -> True
  TokNothing   -> True
  TokIdent _   -> True
  TokLParen    -> True
  TokLBracket  -> True
  TokNot       -> True
  TokNegative  -> True
  TokUppercaseOf -> True
  TokLowercaseOf -> True
  TokLengthOf  -> True
  TokFirstOf   -> True
  TokLastOf    -> True
  TokSliceOf   -> True
  TokCall      -> True
  _            -> False

parseBlock :: Parser [Stmt]
parseBlock ps = do
  ps1 <- pExpect TokIndent ps
  (stmts, ps2) <- parseStmts ps1
  ps3 <- pExpect TokDedent ps2
  return (stmts, ps3)

-- Expression parsing using operator precedence
parseExpr :: Parser Expr
parseExpr = parseOr

parseOr :: Parser Expr
parseOr ps = do
  (left, ps1) <- parseAnd ps
  parseOrCont left ps1

parseOrCont :: Expr -> Parser Expr
parseOrCont left ps = case pPeek ps of
  TokOr -> do
    (right, ps1) <- parseAnd (pAdvance ps)
    parseOrCont (EBinOp OpOr left right) ps1
  _ -> Right (left, ps)

parseAnd :: Parser Expr
parseAnd ps = do
  (left, ps1) <- parseNotExpr ps
  parseAndCont left ps1

parseAndCont :: Expr -> Parser Expr
parseAndCont left ps = case pPeek ps of
  TokAnd -> do
    (right, ps1) <- parseNotExpr (pAdvance ps)
    parseAndCont (EBinOp OpAnd left right) ps1
  _ -> Right (left, ps)

parseNotExpr :: Parser Expr
parseNotExpr ps = case pPeek ps of
  TokNot -> do
    (inner, ps1) <- parseNotExpr (pAdvance ps)
    return (EUnaryNot inner, ps1)
  _ -> parseComparison ps

parseComparison :: Parser Expr
parseComparison ps = do
  (left, ps1) <- parseAddition ps
  parseCompCont left ps1

parseCompCont :: Expr -> Parser Expr
parseCompCont left ps = case pPeek ps of
  TokIsEqualTo     -> binOp OpEq left parseAddition (pAdvance ps)
  TokIsNotEqualTo  -> binOp OpNeq left parseAddition (pAdvance ps)
  TokIsGreaterThan -> binOp OpGt left parseAddition (pAdvance ps)
  TokIsLessThan    -> binOp OpLt left parseAddition (pAdvance ps)
  TokIsAtLeast     -> binOp OpGte left parseAddition (pAdvance ps)
  TokIsAtMost      -> binOp OpLte left parseAddition (pAdvance ps)
  _                -> Right (left, ps)

binOp :: BinOp -> Expr -> Parser Expr -> Parser Expr
binOp op left rightParser ps = do
  (right, ps1) <- rightParser ps
  return (EBinOp op left right, ps1)

parseAddition :: Parser Expr
parseAddition ps = do
  (left, ps1) <- parseMultiplication ps
  parseAddCont left ps1

parseAddCont :: Expr -> Parser Expr
parseAddCont left ps = case pPeek ps of
  TokPlus -> do
    (right, ps1) <- parseMultiplication (pAdvance ps)
    parseAddCont (EBinOp OpPlus left right) ps1
  TokMinus -> do
    (right, ps1) <- parseMultiplication (pAdvance ps)
    parseAddCont (EBinOp OpMinus left right) ps1
  _ -> Right (left, ps)

parseMultiplication :: Parser Expr
parseMultiplication ps = do
  (left, ps1) <- parseUnary ps
  parseMulCont left ps1

parseMulCont :: Expr -> Parser Expr
parseMulCont left ps = case pPeek ps of
  TokTimesOp -> do
    (right, ps1) <- parseUnary (pAdvance ps)
    parseMulCont (EBinOp OpTimes left right) ps1
  TokDividedBy -> do
    (right, ps1) <- parseUnary (pAdvance ps)
    parseMulCont (EBinOp OpDivBy left right) ps1
  TokModulo -> do
    (right, ps1) <- parseUnary (pAdvance ps)
    parseMulCont (EBinOp OpModulo left right) ps1
  _ -> Right (left, ps)

parseUnary :: Parser Expr
parseUnary ps = case pPeek ps of
  TokNegative -> do
    (inner, ps1) <- parsePostfix (pAdvance ps)
    return (EUnaryNeg inner, ps1)
  _ -> parsePostfix ps

parsePostfix :: Parser Expr
parsePostfix ps = do
  (left, ps1) <- parsePrimary ps
  parsePostfixCont left ps1

parsePostfixCont :: Expr -> Parser Expr
parsePostfixCont left ps = case pPeek ps of
  TokJoinedWith -> do
    (right, ps1) <- parsePrimary (pAdvance ps)
    parsePostfixCont (EJoinedWith left right) ps1
  TokContains -> do
    (right, ps1) <- parsePrimary (pAdvance ps)
    parsePostfixCont (EContains left right) ps1
  TokAs -> do
    let ps1 = pAdvance ps
    (typeName, ps2) <- parseTypeName ps1
    parsePostfixCont (EAs left typeName) ps2
  _ -> Right (left, ps)

parseTypeName :: Parser TypeName
parseTypeName ps = case pPeek ps of
  TokIdent "number"  -> Right (TNumber, pAdvance ps)
  TokIdent "string"  -> Right (TString, pAdvance ps)
  TokIdent "boolean" -> Right (TBoolean, pAdvance ps)
  _ -> Left $ "Error on line " ++ show (psLine ps) ++ ": expected type name (number, string, boolean)"

parsePrimary :: Parser Expr
parsePrimary ps = case pPeek ps of
  TokNumber n  -> Right (ENumber n, pAdvance ps)
  TokString s  -> Right (EString s, pAdvance ps)
  TokTrue      -> Right (EBool True, pAdvance ps)
  TokFalse     -> Right (EBool False, pAdvance ps)
  TokNothing   -> Right (ENothing, pAdvance ps)
  TokIdent "item" -> do
    -- Try to parse as "item N of list"
    let ps1 = pAdvance ps
    case parseAddition ps1 of
      Right (idx, ps2) | pPeek ps2 == TokOf -> do
        (list, ps3) <- parsePrimary (pAdvance ps2)
        return (EItemOf idx list, ps3)
      _ -> Right (EVar "item", ps1)
  TokIdent name -> Right (EVar name, pAdvance ps)
  TokLParen -> do
    (expr, ps1) <- parseExpr (pAdvance ps)
    ps2 <- pExpect TokRParen ps1
    return (expr, ps2)
  TokLBracket -> parseListLiteral (pAdvance ps)
  TokUppercaseOf -> do
    (inner, ps1) <- parsePrimary (pAdvance ps)
    return (EUppercase inner, ps1)
  TokLowercaseOf -> do
    (inner, ps1) <- parsePrimary (pAdvance ps)
    return (ELowercase inner, ps1)
  TokLengthOf -> do
    (inner, ps1) <- parsePrimary (pAdvance ps)
    return (ELength inner, ps1)
  TokFirstOf -> do
    (inner, ps1) <- parsePrimary (pAdvance ps)
    return (EFirst inner, ps1)
  TokLastOf -> do
    (inner, ps1) <- parsePrimary (pAdvance ps)
    return (ELast inner, ps1)
  TokSliceOf -> do
    (target, ps1) <- parsePrimary (pAdvance ps)
    ps2 <- pExpect TokFrom ps1
    (fromExpr, ps3) <- parseExpr ps2
    ps4 <- pExpect TokTo ps3
    (toExpr, ps5) <- parseExpr ps4
    return (ESlice target fromExpr toExpr, ps5)
  TokCall -> parseCallExpr ps
  _ -> Left $ "Error on line " ++ show (psLine ps) ++ ": unexpected token in expression: " ++ show (pPeek ps)

parseListLiteral :: Parser Expr
parseListLiteral ps = case pPeek ps of
  TokRBracket -> Right (EList [], pAdvance ps)
  _ -> do
    (first, ps1) <- parseExpr ps
    (rest, ps2) <- parseListRest ps1
    return (EList (first : rest), ps2)

parseListRest :: Parser [Expr]
parseListRest ps = case pPeek ps of
  TokComma -> do
    (expr, ps1) <- parseExpr (pAdvance ps)
    (rest, ps2) <- parseListRest ps1
    return (expr : rest, ps2)
  TokRBracket -> Right ([], pAdvance ps)
  _ -> Left $ "Error on line " ++ show (psLine ps) ++ ": expected ',' or ']' in list"

parseCallExpr :: Parser Expr
parseCallExpr ps = do
  ps1 <- pExpect TokCall ps
  case pPeek ps1 of
    TokIdent name -> do
      let ps2 = pAdvance ps1
      case pPeek ps2 of
        TokWith -> do
          (args, ps3) <- parseArgs (pAdvance ps2)
          return (ECall name args, ps3)
        _ -> return (ECall name [], ps2)
    _ -> Left $ "Error on line " ++ show (psLine ps1) ++ ": expected function name after 'call'"

parseArgs :: Parser [Expr]
parseArgs ps = do
  -- Parse at comparison level so "and" acts as argument separator
  (first, ps1) <- parseComparison ps
  parseArgsCont [first] ps1

parseArgsCont :: [Expr] -> Parser [Expr]
parseArgsCont acc ps = case pPeek ps of
  TokAnd -> do
    (next, ps1) <- parseComparison (pAdvance ps)
    parseArgsCont (acc ++ [next]) ps1
  _ -> Right (acc, ps)

-- ============================================================================
-- Runtime values
-- ============================================================================

data Value
  = VNumber Double
  | VString String
  | VBool Bool
  | VList (IORef [Value])
  | VNothing
  | VFunc [String] [Stmt] Env  -- params, body, closure env

instance Show Value where
  show (VNumber n)  = formatNumber n
  show (VString s)  = s
  show (VBool True) = "true"
  show (VBool False)= "false"
  show VNothing     = "nothing"
  show (VList _)    = "<list>"
  show (VFunc {})   = "<function>"

formatNumber :: Double -> String
formatNumber n
  | isInt n   = show (round n :: Integer)
  | otherwise = formatFixed n 6
  where
    isInt x = x == fromInteger (round x) && not (isInfinite x) && not (isNaN x)

formatFixed :: Double -> Int -> String
formatFixed n maxDec =
  let scaled = round (n * 10 ^ maxDec) :: Integer
      neg = scaled < 0
      absScaled = abs scaled
      s = show absScaled
      padded = replicate (maxDec + 1 - length s) '0' ++ s
      (intPart, decPart) = splitAt (length padded - maxDec) padded
      stripped = stripTrailingZerosStr decPart
      prefix = if neg then "-" else ""
  in if null stripped
       then prefix ++ intPart
       else prefix ++ intPart ++ "." ++ stripped

stripTrailingZerosStr :: String -> String
stripTrailingZerosStr = reverse . dropWhile (== '0') . reverse

-- Format a value for display (print)
displayValue :: Value -> IO String
displayValue (VNumber n) = return $ formatNumber n
displayValue (VString s) = return s
displayValue (VBool True) = return "true"
displayValue (VBool False) = return "false"
displayValue VNothing = return "nothing"
displayValue (VList ref) = do
  items <- readIORef ref
  strs <- mapM displayValueInList items
  return $ "[" ++ intercalate ", " strs ++ "]"
displayValue (VFunc {}) = return "<function>"

-- Format values inside lists (numbers and strings differ)
displayValueInList :: Value -> IO String
displayValueInList (VString s) = return $ "\"" ++ s ++ "\""
displayValueInList v = displayValue v

-- Format for joined with / as string
valueToString :: Value -> IO String
valueToString = displayValue

-- ============================================================================
-- Environment
-- ============================================================================

type Env = IORef [(String, IORef Value)]

newEnv :: IO Env
newEnv = newIORef []

lookupEnv :: String -> Env -> IO (Maybe (IORef Value))
lookupEnv name env = do
  bindings <- readIORef env
  return $ lookup name bindings

setEnv :: String -> Value -> Env -> IO ()
setEnv name val env = do
  bindings <- readIORef env
  case lookup name bindings of
    Just ref -> writeIORef ref val
    Nothing -> do
      ref <- newIORef val
      writeIORef env ((name, ref) : bindings)

-- ============================================================================
-- Interpreter
-- ============================================================================

data ControlFlow
  = CFNone
  | CFReturn Value
  | CFStop
  | CFSkip
  deriving (Show)

type FuncTable = IORef [(String, [String], [Stmt], Env)]

data InterpState = InterpState
  { isEnv   :: Env
  , isFuncs :: FuncTable
  , isInLoop :: Bool
  }

-- Convenience: run interpreter
interpret :: [Stmt] -> IO ()
interpret stmts = do
  env <- newEnv
  funcs <- newIORef []
  let st = InterpState env funcs False
  cf <- runStmts stmts st
  case cf of
    CFStop -> rtError 0 "stop used outside of loop"
    CFSkip -> rtError 0 "skip used outside of loop"
    _ -> return ()

rtError :: Int -> String -> IO a
rtError line msg = do
  hPutStrLn stderr $ "Error on line " ++ show line ++ ": " ++ msg
  exitFailure

runStmts :: [Stmt] -> InterpState -> IO ControlFlow
runStmts [] _ = return CFNone
runStmts (s : ss) st = do
  cf <- runStmt s st
  case cf of
    CFNone -> runStmts ss st
    _      -> return cf

runStmt :: Stmt -> InterpState -> IO ControlFlow
runStmt (SPrint expr) st = do
  val <- evalExpr expr st 0
  s <- displayValue val
  putStrLn s
  hFlush stdout
  return CFNone

runStmt (SSet name expr) st = do
  val <- evalExpr expr st 0
  setEnv name val (isEnv st)
  return CFNone

runStmt (SAppend expr name) st = do
  val <- evalExpr expr st 0
  mRef <- lookupEnv name (isEnv st)
  case mRef of
    Nothing -> rtError 0 $ "undefined variable: " ++ name
    Just ref -> do
      listVal <- readIORef ref
      case listVal of
        VList listRef -> do
          items <- readIORef listRef
          writeIORef listRef (items ++ [val])
          return CFNone
        _ -> rtError 0 $ name ++ " is not a list"

runStmt (SIf branches elseBranch) st = runIfBranches branches elseBranch st

runStmt (SWhile condExpr body) st = do
  let loop = do
        condVal <- evalExpr condExpr st 0
        case condVal of
          VBool True -> do
            cf <- runStmts body (st { isInLoop = True })
            case cf of
              CFStop -> return CFNone
              CFReturn v -> return (CFReturn v)
              _ -> loop  -- CFNone or CFSkip
          VBool False -> return CFNone
          _ -> rtError 0 "condition in 'while' must be a boolean"
  loop

runStmt (SForEach varName listExpr body) st = do
  listVal <- evalExpr listExpr st 0
  case listVal of
    VList listRef -> do
      items <- readIORef listRef
      forLoop items $ \item -> do
        setEnv varName item (isEnv st)
        runStmts body (st { isInLoop = True })
    _ -> rtError 0 "for each requires a list"

runStmt (SForFrom varName fromExpr toExpr body) st = do
  fromVal <- evalExpr fromExpr st 0
  toVal <- evalExpr toExpr st 0
  case (fromVal, toVal) of
    (VNumber f, VNumber t) -> do
      let from' = round f :: Integer
          to' = round t :: Integer
      forLoop [from' .. to'] $ \i -> do
        setEnv varName (VNumber (fromIntegral i)) (isEnv st)
        runStmts body (st { isInLoop = True })
    _ -> rtError 0 "for from/to requires numbers"

runStmt (SRepeat countExpr body) st = do
  countVal <- evalExpr countExpr st 0
  case countVal of
    VNumber n -> do
      let count = round n :: Integer
      forLoop [1..count] $ \_ ->
        runStmts body (st { isInLoop = True })
    _ -> rtError 0 "repeat requires a number"

runStmt (SDefine name params body) st = do
  env <- readIORef (isEnv st)
  closureEnv <- newIORef env
  modifyIORef (isFuncs st) ((name, params, body, closureEnv) :)
  return CFNone

runStmt (SCall name args) st = do
  _ <- callFunction name args st 0
  return CFNone

runStmt (SReturn Nothing) _ = return (CFReturn VNothing)
runStmt (SReturn (Just expr)) st = do
  val <- evalExpr expr st 0
  return (CFReturn val)

runStmt SStop st =
  if isInLoop st
    then return CFStop
    else rtError 0 "stop used outside of loop"

runStmt SSkip st =
  if isInLoop st
    then return CFSkip
    else rtError 0 "skip used outside of loop"

-- Loop helper that handles stop/skip/return
forLoop :: [a] -> (a -> IO ControlFlow) -> IO ControlFlow
forLoop [] _ = return CFNone
forLoop (x : xs) f = do
  cf <- f x
  case cf of
    CFNone -> forLoop xs f
    CFSkip -> forLoop xs f
    CFStop -> return CFNone
    CFReturn v -> return (CFReturn v)

runIfBranches :: [(Expr, [Stmt])] -> Maybe [Stmt] -> InterpState -> IO ControlFlow
runIfBranches [] Nothing _ = return CFNone
runIfBranches [] (Just elseBranch) st = runStmts elseBranch st
runIfBranches ((cond, body) : rest) elseBranch st = do
  condVal <- evalExpr cond st 0
  case condVal of
    VBool True  -> runStmts body st
    VBool False -> runIfBranches rest elseBranch st
    _           -> rtError 0 "condition in 'if' must be a boolean"

-- ============================================================================
-- Expression evaluator
-- ============================================================================

evalExpr :: Expr -> InterpState -> Int -> IO Value
evalExpr (ENumber n) _ _ = return (VNumber n)
evalExpr (EString s) _ _ = return (VString s)
evalExpr (EBool b) _ _ = return (VBool b)
evalExpr ENothing _ _ = return VNothing

evalExpr (EVar name) st ln = do
  mRef <- lookupEnv name (isEnv st)
  case mRef of
    Just ref -> readIORef ref
    Nothing -> rtError ln $ "undefined variable: " ++ name

evalExpr (EList exprs) st ln = do
  vals <- mapM (\e -> evalExpr e st ln) exprs
  ref <- newIORef vals
  return (VList ref)

evalExpr (EBinOp OpAnd left right) st ln = do
  lVal <- evalExpr left st ln
  case lVal of
    VBool False -> return (VBool False)
    VBool True  -> evalExpr right st ln
    _           -> rtError ln "operands to 'and' must be booleans"

evalExpr (EBinOp OpOr left right) st ln = do
  lVal <- evalExpr left st ln
  case lVal of
    VBool True  -> return (VBool True)
    VBool False -> evalExpr right st ln
    _           -> rtError ln "operands to 'or' must be booleans"

evalExpr (EBinOp op left right) st ln = do
  lVal <- evalExpr left st ln
  rVal <- evalExpr right st ln
  evalBinOp op lVal rVal ln

evalExpr (EUnaryNot expr) st ln = do
  val <- evalExpr expr st ln
  case val of
    VBool b -> return (VBool (not b))
    _       -> rtError ln "operand to 'not' must be a boolean"

evalExpr (EUnaryNeg expr) st ln = do
  val <- evalExpr expr st ln
  case val of
    VNumber n -> return (VNumber (negate n))
    _         -> rtError ln "operand to 'negative' must be a number"

evalExpr (EJoinedWith left right) st ln = do
  lVal <- evalExpr left st ln
  rVal <- evalExpr right st ln
  lStr <- valueToString lVal
  rStr <- valueToString rVal
  return (VString (lStr ++ rStr))

evalExpr (EContains left right) st ln = do
  lVal <- evalExpr left st ln
  rVal <- evalExpr right st ln
  case lVal of
    VString s -> case rVal of
      VString sub -> return (VBool (sub `isInfixOf` s))
      _ -> rtError ln "contains on string requires string argument"
    VList ref -> do
      items <- readIORef ref
      found <- anyM (\item -> valuesEqual item rVal) items
      return (VBool found)
    _ -> rtError ln "contains requires a string or list"

evalExpr (EAs expr typeName) st ln = do
  val <- evalExpr expr st ln
  convertType val typeName ln

evalExpr (EUppercase expr) st ln = do
  val <- evalExpr expr st ln
  case val of
    VString s -> return (VString (map toUpper s))
    _ -> rtError ln "uppercase requires a string"

evalExpr (ELowercase expr) st ln = do
  val <- evalExpr expr st ln
  case val of
    VString s -> return (VString (map toLower s))
    _ -> rtError ln "lowercase requires a string"

evalExpr (ELength expr) st ln = do
  val <- evalExpr expr st ln
  case val of
    VString s -> return (VNumber (fromIntegral (length s)))
    VList ref -> do
      items <- readIORef ref
      return (VNumber (fromIntegral (length items)))
    _ -> rtError ln "length requires a string or list"

evalExpr (EFirst expr) st ln = do
  val <- evalExpr expr st ln
  case val of
    VList ref -> do
      items <- readIORef ref
      case items of
        [] -> rtError ln "first of empty list"
        (x:_) -> return x
    _ -> rtError ln "first requires a list"

evalExpr (ELast expr) st ln = do
  val <- evalExpr expr st ln
  case val of
    VList ref -> do
      items <- readIORef ref
      case items of
        [] -> rtError ln "last of empty list"
        _  -> return (last items)
    _ -> rtError ln "last requires a list"

evalExpr (EItemOf idxExpr listExpr) st ln = do
  idxVal <- evalExpr idxExpr st ln
  listVal <- evalExpr listExpr st ln
  case (idxVal, listVal) of
    (VNumber n, VList ref) -> do
      items <- readIORef ref
      let idx = round n :: Int
      if idx >= 0 && idx < length items
        then return (items !! idx)
        else rtError ln "index out of bounds"
    _ -> rtError ln "item requires a number index and a list"

evalExpr (ESlice targetExpr fromExpr toExpr) st ln = do
  target <- evalExpr targetExpr st ln
  fromVal <- evalExpr fromExpr st ln
  toVal <- evalExpr toExpr st ln
  case (fromVal, toVal) of
    (VNumber f, VNumber t) -> do
      let from' = round f :: Int
          to' = round t :: Int
      case target of
        VString s -> return (VString (take (to' - from') (drop from' s)))
        VList ref -> do
          items <- readIORef ref
          let sliced = take (to' - from') (drop from' items)
          newRef <- newIORef sliced
          return (VList newRef)
        _ -> rtError ln "slice requires a string or list"
    _ -> rtError ln "slice indices must be numbers"

evalExpr (ECall name args) st ln = callFunction name args st ln

-- ============================================================================
-- Binary operations
-- ============================================================================

evalBinOp :: BinOp -> Value -> Value -> Int -> IO Value
evalBinOp OpPlus (VNumber a) (VNumber b) _ = return $ VNumber (a + b)
evalBinOp OpMinus (VNumber a) (VNumber b) _ = return $ VNumber (a - b)
evalBinOp OpTimes (VNumber a) (VNumber b) _ = return $ VNumber (a * b)
evalBinOp OpDivBy (VNumber _) (VNumber 0) ln = rtError ln "division by zero"
evalBinOp OpDivBy (VNumber a) (VNumber b) _ = return $ VNumber (a / b)
evalBinOp OpModulo (VNumber a) (VNumber b) ln
  | b == 0    = rtError ln "division by zero"
  | otherwise = return $ VNumber (fromIntegral (mod (round a :: Integer) (round b :: Integer)))
evalBinOp OpEq a b _ = do
  eq <- valuesEqual a b
  return $ VBool eq
evalBinOp OpNeq a b _ = do
  eq <- valuesEqual a b
  return $ VBool (not eq)
evalBinOp OpGt (VNumber a) (VNumber b) _ = return $ VBool (a > b)
evalBinOp OpGt (VString a) (VString b) _ = return $ VBool (a > b)
evalBinOp OpLt (VNumber a) (VNumber b) _ = return $ VBool (a < b)
evalBinOp OpLt (VString a) (VString b) _ = return $ VBool (a < b)
evalBinOp OpGte (VNumber a) (VNumber b) _ = return $ VBool (a >= b)
evalBinOp OpGte (VString a) (VString b) _ = return $ VBool (a >= b)
evalBinOp OpLte (VNumber a) (VNumber b) _ = return $ VBool (a <= b)
evalBinOp OpLte (VString a) (VString b) _ = return $ VBool (a <= b)
evalBinOp op _ _ ln = rtError ln $ "invalid operands for " ++ show op

valuesEqual :: Value -> Value -> IO Bool
valuesEqual (VNumber a) (VNumber b) = return (a == b)
valuesEqual (VString a) (VString b) = return (a == b)
valuesEqual (VBool a) (VBool b) = return (a == b)
valuesEqual VNothing VNothing = return True
valuesEqual (VList refA) (VList refB) = do
  as <- readIORef refA
  bs <- readIORef refB
  if length as /= length bs
    then return False
    else allM (\(a, b) -> valuesEqual a b) (zip as bs)
valuesEqual _ _ = return False

-- ============================================================================
-- Type conversion
-- ============================================================================

convertType :: Value -> TypeName -> Int -> IO Value
convertType val TNumber ln = case val of
  VNumber _ -> return val
  VString s -> case reads s :: [(Double, String)] of
    [(n, "")] -> return (VNumber n)
    _ -> rtError ln $ "cannot convert \"" ++ s ++ "\" to number"
  VBool True -> return (VNumber 1)
  VBool False -> return (VNumber 0)
  _ -> rtError ln "invalid conversion to number"

convertType val TString _ = do
  s <- displayValue val
  return (VString s)

convertType val TBoolean _ = case val of
  VNumber n -> return $ VBool (n /= 0)
  VString s -> return $ VBool (not (null s))
  VBool _ -> return val
  VList ref -> do
    items <- readIORef ref
    return $ VBool (not (null items))
  VNothing -> return $ VBool False
  _ -> return $ VBool False

-- ============================================================================
-- Function calls
-- ============================================================================

callFunction :: String -> [Expr] -> InterpState -> Int -> IO Value
callFunction name argExprs st ln = do
  funcs <- readIORef (isFuncs st)
  case lookup4 name funcs of
    Nothing -> rtError ln $ "undefined function: " ++ name
    Just (params, body, closureEnv) -> do
      argVals <- mapM (\e -> evalExpr e st ln) argExprs
      when (length argVals /= length params) $
        rtError ln $ "wrong number of arguments for " ++ name ++
                     ": expected " ++ show (length params) ++
                     ", got " ++ show (length argVals)
      -- Create new scope: closure env + parameters
      closureBindings <- readIORef closureEnv
      paramBindings <- mapM (\(p, v) -> do
        ref <- newIORef v
        return (p, ref)) (zip params argVals)
      funcEnv <- newIORef (paramBindings ++ closureBindings)
      let funcSt = st { isEnv = funcEnv, isInLoop = False }
      cf <- runStmts body funcSt
      case cf of
        CFReturn v -> return v
        CFNone     -> return VNothing
        CFStop     -> rtError ln "stop used outside of loop"
        CFSkip     -> rtError ln "skip used outside of loop"

lookup4 :: String -> [(String, [String], [Stmt], Env)] -> Maybe ([String], [Stmt], Env)
lookup4 _ [] = Nothing
lookup4 name ((n, params, body, env) : rest)
  | name == n = Just (params, body, env)
  | otherwise = lookup4 name rest

-- ============================================================================
-- Utility
-- ============================================================================

anyM :: (a -> IO Bool) -> [a] -> IO Bool
anyM _ [] = return False
anyM f (x:xs) = do
  b <- f x
  if b then return True else anyM f xs

allM :: (a -> IO Bool) -> [a] -> IO Bool
allM _ [] = return True
allM f (x:xs) = do
  b <- f x
  if b then allM f xs else return False

-- ============================================================================
-- Main
-- ============================================================================

main :: IO ()
main = do
  args <- getArgs
  case args of
    [filename] -> do
      source <- readFile filename
      let tokens = lexAll source
      case parseProgram tokens of
        Left err -> do
          hPutStrLn stderr err
          exitFailure
        Right stmts -> interpret stmts
    _ -> do
      hPutStrLn stderr "Usage: humanlang <file.hl>"
      exitFailure
