import Data.Char
import Language.Haskell.TH (safe)
import Control.Monad.RWS (MonadState(put))
--Worked with Kevin Portillo

type FunList = Either AExpr BExpr 

type Vars = String -- Variables
data AExpr = Var Vars | Const Integer -- Arithmetic expressions
    | Add AExpr AExpr | Sub AExpr AExpr
    | Mul AExpr AExpr | Div AExpr AExpr
    | Mod AExpr |  FCall [FunList]
    deriving Show
data BExpr = TT | FF -- Boolean expressions
    | And BExpr BExpr | Or BExpr BExpr | Not BExpr
    | Eql AExpr AExpr -- equality of arithmetic expressions
    | Lt AExpr AExpr -- true if the first is less than the second
    | Lte AExpr AExpr -- true if it’s less than or equal to
    | Gre BExpr BExpr | Gr BExpr BExpr --NEW
    deriving Show

data Instr = Assign Vars AExpr -- assignment
    | IfThenElse BExpr Instr Instr -- conditional
    | While BExpr Instr -- looping construct
    | Do [Instr] -- a block of several instructions
    | Nop -- the "do nothing" instruction
    | Return AExpr -- the final value to return
    deriving Show

type Env = [(Vars,Integer)]

-- update (x,v) e sets the value of x to v and keeps other variables in e the same
update :: (Vars, Integer) -> Env -> Env
update (x, v) [] = [(x, v)]
update (x, v) ((e, val):env)
    | x /= e    = (e, val) : update (x, v) env
    | otherwise = (x, v) : env


evala :: Env -> AExpr -> Integer
evala env (Var v) = case lookup v env of 
                Just val -> val
                Nothing -> error $ "Variable Not Found" ++ v
evala env (Const b) = b
evala env (Add e1 e2) = evala env e1 + evala env e2
evala env (Sub e1 e2) = evala env e1 - evala env e2
evala env (Mul e1 e2) = evala env e1 * evala env e2
evala env (Div e1 e2) = evala env e1 `div` evala env e2

evalb :: Env -> BExpr -> Bool
evalb env TT = True
evalb env FF = False
evalb env (And p1 p2) = evalb env p1 && evalb env p2
evalb env (Or p1 p2) = evalb env p1 || evalb env p2
evalb env (Not p1) = not (evalb env p1)
evalb env (Eql p1 p2)
    | evala env p1 == evala env p2 = evalb env TT
    | otherwise = evalb env FF
evalb env (Lt p1 p2)
    | evala env p1 < evala env p2 = evalb env TT
    | otherwise = evalb env FF
evalb env (Lte p1 p2)
    | evala env p1 <= evala env p2 = evalb env TT
    | otherwise = evalb env FF

exec :: Instr -> Env -> Env
exec (Assign v a) env = update (v, evala env a) env
exec (IfThenElse condI thenI elseI) env =
    if evalb env condI
        then exec thenI env
        else exec elseI env
exec (While condI doI) env =
    if evalb env condI
        then exec (While condI doI) (exec doI env)
        else env
exec (Do instrs) env = foldl (\e i -> exec i e) env instrs
exec Nop env = env
exec (Return a) env = update ("", evala env a) env 

execList :: [Instr] -> Env -> Env
execList instrs env = foldl (\e i -> exec i e) env instrs

run :: [Instr] -> Integer
run p = case lookup "" (execList p []) of
    Just x -> x
    Nothing -> error "No value returned."

--Example
sum100 :: [Instr] -- a program to add together all the numbers up to 100
sum100 = [
    Assign "X" (Const 0), -- initialize the sum at X=0
    Assign "C" (Const 1), -- initialize the counter at C=1
    While (Lt (Var "C") (Const 101)) -- while C < 101, do:
        (Do [Assign "X" (Add (Var "X") (Var "C")), -- X := X + C;
            Assign "C" (Add (Var "C") (Const 1))]), -- C := C + 1
    Return (Var "X")]

sum100output = run sum100



data Keywords = IfK | ThenK | ElseK | WhileK | NopK | ReturnK 
    | ClassK | MainK | VoidK | IntegerK | BooleanK | NewK  
    deriving Show
data UOps = NotOp deriving Show
data BOps = AddOp | SubOp | MulOp | DivOp
    | AndOp | OrOp | EqlOp | LtOp | LteOp
    | ModOp | GreOp | GrOp
    deriving Show
data Token = VSym String | CSym Integer | BSym Bool
    | LPar | RPar | LBra | RBra | Semi
    | UOp UOps | BOp BOps | AssignOp
    | Keyword Keywords
    | Err String
    | PA AExpr | PB BExpr | PI Instr | Block [Instr]
    deriving Show


--FUNCTIONS, CLASSES 
type FName = String

type VName = String 
type Value = String 
type VEnv = [(VName, Value)] 
type FEnv = [(FName, [(VName, Instr)])]

type ClassName = String 
type Class = (VEnv, FEnv) 
type Object = [(ClassName, Class)] 


lexer :: String -> [Token]
lexer "" = []
--Punctuation
lexer ('(':xs)      = LPar : lexer xs                --Left parenthesis case 
lexer (')':xs)      = RPar : lexer xs                --Right parenthesis case
lexer ('{':xs)      = LBra : lexer xs                --Left bracket case 
lexer ('}':xs)      = RBra : lexer xs                --Right bracket case
lexer (';':xs)      = Semi : lexer xs
--Constants
lexer ('T':'r':'u':'e':xs)          = BSym True : lexer xs      --Boolean constant True
lexer ('F':'a':'l':'s':'e':xs)      = BSym False : lexer xs     --Boolean constant False
--Keywords
lexer ('w':'h':'i':'l':'e':xs)      = Keyword WhileK : lexer xs
lexer ('i':'f':xs)                  = Keyword IfK : lexer xs
lexer ('t':'h':'e':'n':xs)          = Keyword ThenK : lexer xs
lexer ('e':'l':'s':'e':xs)          = Keyword ElseK : lexer xs
lexer ('n':'o':'p':xs)              = Keyword NopK : lexer xs
lexer ('r':'e':'t':'u':'r':'n':xs)  = Keyword ReturnK : lexer xs
--Variables
--Operators
lexer ('+':xs)          = BOp AddOp : lexer xs
lexer ('-':xs)          = BOp SubOp : lexer xs
lexer ('*':xs)          = BOp MulOp : lexer xs
lexer ('/':'\\':xs)         = BOp AndOp : lexer xs
lexer ('/':xs)          = BOp DivOp : lexer xs
lexer ('\\' : '/':xs)       = BOp OrOp : lexer xs
lexer ('!':xs)              = UOp NotOp : lexer xs
lexer ('=':'=':xs)          = BOp EqlOp : lexer xs
lexer ('<':'=':xs)          = BOp LteOp : lexer xs
lexer ('<':xs)              = BOp LtOp : lexer xs
lexer (':':'=':xs)          = AssignOp : lexer xs
--space
lexer (x:xs) | isSpace x = lexer xs
lexer (x:xs) | isDigit x = let (ys,zs) = span isDigit xs    in CSym (read (x:ys)) : lexer zs
lexer (x:xs) | isLower x = let (ys,zs) = span isAlphaNum xs in VSym (x:ys) : lexer zs
lexer xs                 = [Err xs]


readProg :: [Token] -> Either [Instr] String
readProg tokens = case sr [] tokens of
    (Block instructions : []) -> Left instructions
    (Err e : _) -> Right ("Lexical Error: " ++ e)
    _ -> Right "Parse Error: Invalid program structure"

sr :: [Token] -> [Token] -> [Token]
--reduce phase
    --Variable (PA)
sr (VSym v : ts) i = sr (PA (Var v) : ts) i     --Variable AEXpr
    --Constants (PA or PB) 
sr (CSym c : ts) i = sr (PA (Const c) : ts) i   --Constant AExpr
sr (BSym True : ts) i = sr (PB (TT) : ts) i     --Constant True
sr (BSym False : ts) i = sr (PB (FF) : ts) i    --Constant False
    --Unary Operations (PA, PB or PI)
sr (UOp u : ts) i = sr (UOp (NotOp) : ts) i  --UOp
    --Binary Operations 
sr s@(PB e1 : BOp o : PB e2 : ts) (BOp o2 : i) | rank o > rank o2 = sr (BOp o2 : s) i -- Binary Op BExpr
sr s@(PA e1 : BOp o : PA e2 : ts) (BOp o2 : i) | rank o > rank o2 = sr (BOp o2 : s) i -- Binary Op AExpr
    --Boolean Operators 
sr (PB e2 : BOp AndOp : PB e1 : ts) i = sr (PB (And e1 e2) : ts) i
sr (PB e2 : BOp OrOp : PB e1 : ts) i = sr (PB (Or e1 e2) : ts) i
sr (PA e2 : BOp EqlOp : PA e1 : ts) i = sr (PB (Eql e1 e2) : ts) i
sr (PA e2 : BOp LteOp : PA e1 : ts) i = sr (PB (Lte e1 e2) : ts) i
sr (PA e2 : BOp LtOp : PA e1 : ts) i = sr (PB (Lt e1 e2) : ts) i
    --Mathematical Operators 
sr (PA e2 : BOp AddOp : PA e1 : ts) i = sr (PA (Add e1 e2) : ts) i
sr (PA e2 : BOp SubOp : PA e1 : ts) i = sr (PA (Sub e1 e2) : ts) i
sr (PA e2 : BOp MulOp : PA e1 : ts) i = sr (PA (Mul e1 e2) : ts) i  
sr (PA e2 : BOp DivOp : PA e1 : ts) i = sr (PA (Div e1 e2) : ts) i   
    --Assign
sr (PA e : AssignOp : PA (Var v) : ts) q = sr (PI (Assign v e) : ts) q  
    --IfThenElse
sr (PI i2 : Keyword ElseK : PI i1 : Keyword ThenK : PB b : Keyword IfK : ts ) q
    = sr (PI (IfThenElse b i1 i2 ) : ts ) q                             
    --Nop
sr (Keyword NopK : ts) q = sr (PI (Nop) : ts) q

    --Block
sr (LBra: ts) q = sr (Block []: ts) q
sr (Semi : PI i : Block is : ts) q = sr (Block (i:is) : ts) q
sr (Semi : RBra : Block i : PB b : Keyword WhileK : ts) q = sr (PI (Do (reverse i)): PB b: Keyword WhileK : ts) q
sr (PI i : PB b : Keyword WhileK : ts) q = sr (PI (While b i) : ts) q

    --Return
sr (PA e :Keyword ReturnK : ts) q = sr (PI (Return e) : ts) q

    --Syntax
sr (RPar : PI e : LPar : s) q = sr (PI e : s) q --parenthesis
sr (RPar : PA e : LPar : s) q = sr (PA e : s) q --parenthesis
sr (RPar : PB e : LPar : s) q = sr (PB e : s) q --parenthesis
--shift 
sr s (i:q) = sr (i:s) q 
--exit 
sr (Err e : s) _ = [Err e]
sr [Block i] [] = [Block i]
sr s [] = blocker s (Block [] : [])

blocker :: [Token] -> [Token] -> [Token]
blocker [] x = x
blocker (x:xs) (Block(i):[]) = case x of 
    Semi -> blocker xs (Block(i):[])
    PI x -> blocker xs (Block(x:i):[])
    _ -> [Err "Block Error"]



rank :: BOps -> Int
rank AddOp = 1
rank SubOp = 1
rank MulOp = 3
rank DivOp = 3
rank AndOp = 3
rank OrOp = 2

main :: IO ()
main = repl

repl :: IO ()
repl = do
    putStrLn "Enter file name:"
    fileName <- getLine
    contents <- readFile fileName
    case contents of 
        "quit" -> return () 
        s -> case readProg (lexer contents) of 
            Left expr -> putStrLn ("Evaluates to: " ++ show (run expr))
            Right err -> putStrLn err
        
        

