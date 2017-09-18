// A Rust-ish WebAssembly self-hosted compiler. github.com/PierreRossouw/rswasm v0.1.20170918

enum Token {
  Identifier,
  StrLiteral, CharLiteral, NumLiteral, True, False,
  LParen, RParen, LBrace, RBrace, Dot, Comma, Colon, Semicolon, DoubleColon, Arrow,

  // Keywords
  Break, Const, Continue, Else, Enum, Fun, If, Let, Loop, Mut, Pub, 
  Return, Static, While,

  // TODO
  As, Crate, Extern, For, Impl, In, Match, Mod, Move, Ref,               
  UpperSelf, Lowerself, Struct, Super, Trait, Type, Unsafe, Use, Where,

  // Operators
  MinPrecedence,
  Assign, AddAssign, BitAndAssign, BitOrAssign, BitXorAssign, DivAssign, MulAssign, 
  RemAssign, ShlAssign, ShrAssign, SubAssign,
  BitOr, BoolOr, BitXor,
  BitAnd, BoolAnd,
  Eql, Ne, Lt, Ltu, Le, Leu, Gt, Gtu, Ge, Geu,
  Shl, Shr, Shru,
  Add, Sub,
  Mul, Div, Divu, Rem, Remu,
  Not,

  // TODO
  Min, Max, CopySign, Rotl, Rotr, Abs, Neg, Ceil, Floor, Trunc, Round, Sqrt, Clz, Ctz, Cnt,

  // Data types
  F64, F32, I64, I32, Bool
}

enum Node {
  Module,
  Data, Enum, 
  Fun, Parameter, Return, Call, 
  Block,  
  Variable, Identifier, Literal,
  Assign, Binary, Unary, 
  DotLoad, DotStore,  
  Iif, If, 
  Loop, Break, BreakIf, Continue,
  Pop
}

enum Error {
  DuplicateName, InvalidToken, MissingToken, Expression, TypeMismatchA, TypeMismatchB, 
  RootStatement, TypeNotInferred, NotDeclared, LiteralToInt, BlockStatement, 
  EmitNode, InvalidOperator, NotMutable, NoIdentifiers, NoParamList, ParseAssignOp
}

// Output Binary (string)
static mut WASM: i32 = 0;

pub fn main() -> i32 {
  let dwasm: i32 = 4;  // Input (string)
  
  // Fix the heap pointer to include the source string
  let ignore: i32 = allocate(4 + string_size + dwasm.string_length);  
  ERROR_LIST = new_list();
  lexx(dwasm);
  let mut root_node: i32 = 0;
  if ERROR_LIST.list_count.i32 == 0 { 
    root_node = parse();
  }
  if ERROR_LIST.list_count.i32 == 0 {
    emit(dwasm, root_node);
  }
  if ERROR_LIST.list_count.i32 > 0 { 
    parse_error_list();
  }
  WASM.string_capacity.i32 = WASM.string_length;
  WASM + string_capacity  // Return the memory location of the string
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// Lexer 

// Struct
const token_dec0de: i32 = 0;  // debugging marker
const token_kind:   i32 = 4;
const token_Value:  i32 = 8;
const token_line:   i32 = 12;
const token_column: i32 = 16;
const token_size:   i32 = 20;

static mut TOKEN_LIST: i32 = 0;
static mut CURRENT_TOKEN_ITEM: i32 = 0;
static mut CURRENT_TOKEN: i32 = 0;
static mut NEXT_TOKEN: i32 = 0;

fn add_token(kind: i32, text: i32, line: i32, column: i32) {
  let mut token: i32 = allocate(token_size);
  token.token_dec0de = 6 - DEC0DE;
  token.token_kind = kind;
  token.token_Value = text;
  token.token_line = line;
  token.token_column = column;
  list_add(TOKEN_LIST, token);
}

fn process_token(s: i32, line: i32, column: i32) {
  let mut kind: i32 = Token::Identifier;
  if str_eq(s, "(") { kind = Token::LParen;  
  } else if str_eq(s, ",") { kind = Token::Comma; 
  } else if str_eq(s, ")") { kind = Token::RParen; 
  } else if str_eq(s, "{") { kind = Token::LBrace; 
  } else if str_eq(s, "}") { kind = Token::RBrace; 
  } else if str_eq(s, ":") { kind = Token::Colon; 
  } else if str_eq(s, ";") { kind = Token::Semicolon; 
  } else if str_eq(s, "=") { kind = Token::Assign; 
  } else if str_eq(s, "<") { kind = Token::Lt;
  } else if str_eq(s, ">") { kind = Token::Gt;
  } else if str_eq(s, "+") { kind = Token::Add;
  } else if str_eq(s, "-") { kind = Token::Sub;
  } else if str_eq(s, "*") { kind = Token::Mul; 
  } else if str_eq(s, "/") { kind = Token::Div; 
  } else if str_eq(s, "!") { kind = Token::Not;
  } else if str_eq(s, "%") { kind = Token::Rem;
  } else if str_eq(s, "^") { kind = Token::BitXor;
  } else if str_eq(s, "&") { kind = Token::BitAnd; 
  } else if str_eq(s, "|") { kind = Token::BitOr; 
  } else if str_eq(s, "+=") { kind = Token::AddAssign;
  } else if str_eq(s, "-=") { kind = Token::SubAssign;
  } else if str_eq(s, "&=") { kind = Token::BitAndAssign;
  } else if str_eq(s, "|=") { kind = Token::BitOrAssign;
  } else if str_eq(s, "^=") { kind = Token::BitXorAssign;
  } else if str_eq(s, "/=") { kind = Token::DivAssign;
  } else if str_eq(s, "*=") { kind = Token::MulAssign;
  } else if str_eq(s, "%=") { kind = Token::RemAssign;
  } else if str_eq(s, "<<=") { kind = Token::ShlAssign;
  } else if str_eq(s, ">>=") { kind = Token::ShrAssign;
  } else if str_eq(s, "<<") { kind = Token::Shl; 
  } else if str_eq(s, ">>") { kind = Token::Shr;
  } else if str_eq(s, "::") { kind = Token::DoubleColon; 
  } else if str_eq(s, "&&") { kind = Token::BoolAnd; 
  } else if str_eq(s, "||") { kind = Token::BoolOr; 
  } else if str_eq(s, "->") { kind = Token::Arrow; 
  } else if str_eq(s, "==") { kind = Token::Eql; 
  } else if str_eq(s, "!=") { kind = Token::Ne;
  } else if str_eq(s, "<=") { kind = Token::Le;
  } else if str_eq(s, ">=") { kind = Token::Ge; 
  } else if str_eq(s, "%+") { kind = Token::Remu;
  } else if str_eq(s, "/+") { kind = Token::Divu; 
  } else if str_eq(s, ">+") { kind = Token::Gtu;
  } else if str_eq(s, "<+") { kind = Token::Ltu;
  } else if str_eq(s, "<=+") { kind = Token::Leu; 
  } else if str_eq(s, ">=+") { kind = Token::Geu;
  } else if str_eq(s, ">>+") { kind = Token::Shru;
  } else if str_eq(s, "fn") { kind = Token::Fun;
  } else if str_eq(s, "if") { kind = Token::If; 
  } else if str_eq(s, "pub") { kind = Token::Pub;
  } else if str_eq(s, "let") { kind = Token::Let;
  } else if str_eq(s, "mut") { kind = Token::Mut;
  } else if str_eq(s, "mod") { kind = Token::Mod;
  } else if str_eq(s, "loop") { kind = Token::Loop;
  } else if str_eq(s, "enum") { kind = Token::Enum;
  } else if str_eq(s, "else") { kind = Token::Else;
  } else if str_eq(s, "true") { kind = Token::True; 
  } else if str_eq(s, "false") { kind = Token::False;
  } else if str_eq(s, "break") { kind = Token::Break;
  } else if str_eq(s, "const") { kind = Token::Const;
  } else if str_eq(s, "while") { kind = Token::While;
  } else if str_eq(s, "static") { kind = Token::Static;
  } else if str_eq(s, "return") { kind = Token::Return;
  } else if str_eq(s, "continue") { kind = Token::Continue;
  } else if str_eq(s, "i32") { kind = Token::I32;
  } else if str_eq(s, "i64") { kind = Token::I64;
  } else if str_eq(s, "f32") { kind = Token::F32;
  } else if str_eq(s, "f64") { kind = Token::F64;
  } else if str_eq(s, "bool") { kind = Token::Bool; }
  add_token(kind, s, line, column);
}

fn is_single_chr(chr: i32) -> i32 {
  (chr == '(') | (chr == ')') | (chr == ',') | (chr == '{') | (chr == '}') | (chr == ';')
}

fn is_operator_chr(chr: i32) -> i32 {
  (chr == '=') | (chr == '+') | (chr == '-') | (chr == '/') | (chr == '*') | (chr == '<') 
    | (chr == '>') | (chr == '^') | (chr == '!') | (chr == '%') | (chr == ':') 
    | (chr == '&') | (chr == '|')
}

fn lexx(dwasm: i32) {
  TOKEN_LIST = new_list();
  let mut str_index: i32 = -1;
  let mut line: i32 = 1;
  let mut column: i32 = 0;
  let length: i32 = dwasm.string_length;
  let mut start: i32 = 0;
  let mut value_str: i32 = 0;
  while str_index < length { 
    str_index += 1;
    column += 1;
    let mut chr: i32 = get_chr(dwasm, str_index);

    // newline chr
    if chr == 10 {
      line += 1;
      column = 0;

    // Identifiers & reserved words
    } else if is_alpha(chr) {
      start = str_index;
       while str_index < length {
        if (!is_alpha(chr)) & (!is_number(chr, false)) {
          str_index = str_index - 1;
          column = column - 1;
          break;
        }
        str_index += 1;
        column += 1;
        chr = get_chr(dwasm, str_index);
      }
      value_str = sub_str(dwasm, start, str_index - start + 1);
      process_token(value_str, line, column);
      if get_chr(dwasm, str_index + 1) == '.' & is_alpha(get_chr(dwasm, str_index + 2)) {
        str_index += 1;
        column += 1;
        chr = get_chr(dwasm, str_index);
        add_token(Token::Dot, value_str, line, column);
      }
    
    // Single quoted chars (byte)
    } else if chr == 39 {
      str_index += 1;
      column += 1;
      chr = get_chr(dwasm, str_index);
      start = str_index;
      while str_index < length {
        if chr == 39 { break; }
        str_index += 1;
        column += 1;
        chr = get_chr(dwasm, str_index);
      }
      value_str = sub_str(dwasm, start, str_index - start);
      decode_str(value_str);
      add_token(Token::CharLiteral, value_str, line, column);

    // Double quoted strings
    } else if chr == '"' {
      str_index += 1;
      column += 1;
      chr = get_chr(dwasm, str_index);
      start = str_index;
      while str_index < length {
        if chr == '"' { break; }
        str_index += 1;
        column += 1;
        chr = get_chr(dwasm, str_index);
      }
      value_str = sub_str(dwasm, start, str_index - start);
      decode_str(value_str);
      add_token(Token::StrLiteral, value_str, line, column);

    // Number literals, for example -42, 3.14, 0x8d4f0
    // May contain underscores e.g. 1_234 is the same as 1234
    } else if is_number(chr, false) | ((chr == '-') & is_number(get_chr(dwasm, str_index + 1), false)) {
      start = str_index;
      let mut is_hex: bool = false;
      while str_index < length {
        if (!is_number(chr, is_hex)) & (chr != '-') & (chr != '_') {
          if (start + 1 == str_index) & (chr == 'x') {
            is_hex = true;
          } else {
            str_index = str_index - 1;
            column = column - 1;
            break;
          }
        }
        str_index += 1;
        column += 1;
        chr = get_chr(dwasm, str_index);
      }
      if chr == '.' & !is_hex {
        str_index += 2;
        column += 2;
        chr = get_chr(dwasm, str_index);
        while str_index < length {
          if (!is_number(chr, is_hex) & (chr != '_')) {
            str_index = str_index - 1;
            column = column - 1;
            break;
          }
          str_index += 1;
          column += 1;
          chr = get_chr(dwasm, str_index);
        }
      }
      value_str = sub_str(dwasm, start, str_index - start + 1);
      add_token(Token::NumLiteral, value_str, line, column);

    // Comments
    } else if (chr == '/') & (get_chr(dwasm, str_index + 1) == '/') {
      while str_index < length {
        if (chr == 10) | (chr == 13) {  // LF | CR
          column = 0;
          line += 1;
          break;
        }
        str_index += 1;
        column += 1;
        chr = get_chr(dwasm, str_index);
      }
    
    // Parenthases & commas
    } else if is_single_chr(chr) {
      value_str = sub_str(dwasm, str_index, 1);
      process_token(value_str, line, column);

    // Mathematical operators
    } else if is_operator_chr(chr) {
      if is_operator_chr(get_chr(dwasm, str_index + 1)) {
        if is_operator_chr(get_chr(dwasm, str_index + 2)) {
          value_str = sub_str(dwasm, str_index, 3);
          str_index += 2;
          column += 2;
        } else {
          value_str = sub_str(dwasm, str_index, 2);
          str_index += 1;
          column += 1;
        }
      } else {
        value_str = sub_str(dwasm, str_index, 1);
      }
      process_token(value_str, line, column);

    }
  }
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// Scoper

// Struct
const scope_dec0de:     i32 = 0;   // debugging marker
const scope_Node:       i32 = 4;
const scope_index:      i32 = 8;
const scope_Parent:     i32 = 12;
const scope_Symbols:    i32 = 16;
const scope_localIndex: i32 = 20;
const scope_size:       i32 = 24;

static mut CURRENT_SCOPE: i32 = 0;
static mut GLOBAL_SCOPE:  i32 = 0;

fn push_scope(node: i32) {
  let scope: i32 = allocate(scope_size);
  scope.scope_dec0de = 3 - DEC0DE;
  scope.scope_Symbols = new_list();
  scope.scope_Node = node;
  if CURRENT_SCOPE {
    scope.scope_index.i32 = CURRENT_SCOPE.scope_index + 1;
    scope.scope_Parent = CURRENT_SCOPE;
  }
  node.node_Scope = scope;
  CURRENT_SCOPE = scope;
}

fn pop_scope() {
  CURRENT_SCOPE = CURRENT_SCOPE.scope_Parent;
}

fn get_fn_scope(scope: i32) -> i32 {
  let mut fn_scope: i32 = scope;
  while fn_scope {
    if fn_scope.scope_Node.node_kind.i32 == Node::Fun { break; }
    if fn_scope.scope_Node.node_kind.i32 == Node::Module { break; }
    fn_scope = fn_scope.scope_Parent;
  }
  fn_scope
}

fn scope_register_name(scope: i32, name: i32, node: i32, token: i32) {
  if list_search(scope.scope_Symbols, name) {
    add_error(Error::DuplicateName, token);
  }
  let kind: i32 = node.node_kind;
  list_add_name(scope.scope_Symbols, node, name);
  if (kind == Node::Variable) | (kind == Node::Parameter) {
    let fn_scope: i32 = get_fn_scope(scope);
    let index: i32 = fn_scope.scope_localIndex;
    node.node_Scope = fn_scope;
    node.node_index = index;
    fn_scope.scope_localIndex = index + 1;
  }
}

fn scope_resolve(scope: i32, name: i32, token: i32) -> i32 {
  let mut node: i32 = 0;
  let mut recurse_scope: i32 = scope;
  while recurse_scope {
    node = list_search(recurse_scope.scope_Symbols, name);
    if node { break; }
    recurse_scope = recurse_scope.scope_Parent;
  }
  if !node {
    add_error(Error::NotDeclared, token);
  }
  node
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// Parser 

// Structs
const node_dec0de:     i32 = 0;   // debugging marker
const node_kind:       i32 = 4;   // From the Node enum
const node_index:      i32 = 8;   // Zero based index number for funs, variables, parameters
const node_String:     i32 = 12;  // Literal value, or fn/var/Parameter name
const node_Scope:      i32 = 16;  // scope for Module/Block/loop/fun used for name resolution
const node_ANode:      i32 = 20;  // Binary left, Call fn, return Expression, Block, or fun body
const node_BNode:      i32 = 24;  // Binary/Unary right, else Block, fun return, Variable assignment
const node_CNode:      i32 = 28;  // If statement condition node
const node_Nodes:      i32 = 32;  // list of child Node for Module/Block, enums, or fun locals
const node_ParamNodes: i32 = 36;  // list of params for Call/fn
const node_type:       i32 = 40;  // From the Token::_ enum
const node_dataType:   i32 = 44;  // inferred data type
const node_Token:      i32 = 48;
const node_assigns:    i32 = 52;
const node_size:       i32 = 56;

static mut EXPORT_LIST: i32 = 0;
static mut DATA_LIST:   i32 = 0;

fn parse() -> i32 {
  let root_node: i32 = new_node(Node::Module);
  EXPORT_LIST = new_list();
  DATA_LIST = new_list();
  CURRENT_TOKEN_ITEM = TOKEN_LIST.list_First;
  CURRENT_TOKEN = CURRENT_TOKEN_ITEM.item_Object;
  push_scope(root_node);
  GLOBAL_SCOPE = CURRENT_SCOPE;
  let BodyList: i32 = new_list();
  root_node.node_Nodes = BodyList;
  while CURRENT_TOKEN {
    let Child: i32 = parse_root_statement();
    if !Child { break; }
    list_add(BodyList, Child);
  }
  root_node
}

fn parse_root_statement() -> i32 {
  let mut node: i32 = 0;
  let kind: i32 = CURRENT_TOKEN.token_kind;
  if kind == Token::Fun {
    node = parse_fn();
  } else if kind == Token::Const {
    node = parse_const();
  } else if kind == Token::Static {
    node = parse_static();
  } else if kind == Token::Enum {
    node = parse_enum();
  } else if kind == Token::Pub {
    node = parse_fn();
  } else {
    add_error(Error::RootStatement, CURRENT_TOKEN);
  }
  node
}

// Next function index number
static mut FN_INDEX: i32 = 0; 

fn parse_fn() -> i32 {
  let mut exported: bool = false;
  if CURRENT_TOKEN.token_kind.i32 == Token::Pub {
    exported = true;
    eat_token(Token::Pub);
  }
  eat_token(Token::Fun);
  let mut token_type: i32 = 0;  
  let name: i32 = CURRENT_TOKEN.token_Value;
  let node: i32 = new_node(Node::Fun);
  scope_register_name(CURRENT_SCOPE, name, node, CURRENT_TOKEN);
  next_token();
  let Locals: i32 = new_list();
  node.node_index = FN_INDEX;
  FN_INDEX += 1;
  node.node_String = name;
  node.node_Nodes = Locals;
  let param_list: i32 = parse_fn_params();
  node.node_ParamNodes = param_list;
  if CURRENT_TOKEN.token_kind.i32 == Token::Arrow {
    eat_token(Token::Arrow);
    token_type = CURRENT_TOKEN.token_kind;
    next_token();
  }
  node.node_type = token_type;
  node.node_dataType = token_type;
  push_scope(node);
  let mut param_item: i32 = param_list.list_First;
  while param_item {
    let param_name: i32 = param_item.item_Name;
    let param_node: i32 = param_item.item_Object;
    scope_register_name(CURRENT_SCOPE, param_name, param_node, param_node.node_Token);
    param_item = param_item.item_Next;
  }
  if exported {
    list_add_name(EXPORT_LIST, node, name);
  }
  eat_token(Token::LBrace);
  node.node_ANode = parse_fn_block();
  pop_scope();
  eat_token(Token::RBrace);
  node
}

fn parse_fn_block() -> i32 {
  let node: i32 = new_node(Node::Block);
  let BodyList: i32 = new_list();
  node.node_Nodes = BodyList;
  node.node_Scope = CURRENT_SCOPE;
  while CURRENT_TOKEN {
    if CURRENT_TOKEN.token_kind.i32 == Token::RBrace { break; }
    let ChildNode: i32 = parse_statement();
    if !ChildNode { break; }
    list_add(BodyList, ChildNode);
  }
  node
}

fn parse_statement() -> i32 {
  let mut node: i32 = 0;
  let kind: i32 = CURRENT_TOKEN.token_kind;
  if kind == Token::Let {
    node = parse_declaration();
  } else if kind == Token::If {
    node = parse_if_statement();
  } else if kind == Token::Loop {
    node = parse_loop_statement();
  } else if kind == Token::While {
    node = parse_while_statement();
  } else if kind == Token::Continue {
    node = parse_continue();
  } else if kind == Token::Break {
    node = parse_break();
  } else if kind == Token::Return {
    node = parse_return_statement();
  } else if kind == Token::Identifier {
    let next_kind: i32 = NEXT_TOKEN.token_kind;
    if next_kind == Token::Dot {
      node = parse_dot_store();
    } else if next_kind == Token::LParen {
      node = parse_call_statement();
    } else if next_kind == Token::Assign {
      node = parse_assign_statement();
    } else if is_assign_op(NEXT_TOKEN) {
      node = parse_assign_op_statement();
    } else {
      node = parse_return_expression();
    }
  } else {
    node = parse_return_expression();
  }
  node
}

fn parse_expression(level: i32) -> i32 {
  let mut node: i32 = parse_prefix();
  while CURRENT_TOKEN {
    let Expr: i32 = parse_infix(level, node);
    if Expr == 0 | Expr == node { break; }
    node = Expr;
  }
  node
}

fn parse_prefix() -> i32 {
  let mut node: i32 = 0;
  let kind: i32 = CURRENT_TOKEN.token_kind;
  if is_literal(CURRENT_TOKEN) {
    node = parse_literal();
  } else if kind == Token::Identifier {
    let mut nextKind: i32 = 0;
    if NEXT_TOKEN {
       nextKind = NEXT_TOKEN.token_kind; 
    }
    if nextKind == Token::Dot {
      node = parse_dot_load();
    } else if nextKind == Token::DoubleColon {
      node = parse_double_colon();
    } else {
      node = parse_identifier();
    }
  } else if kind == Token::LParen {
    next_token();
    node = parse_expression(Token::MinPrecedence);
    eat_token(Token::RParen);
  } else if is_unary_op(CURRENT_TOKEN) {
    node = parse_unary_expression();
  }
  node
}

fn parse_literal() -> i32 {
  let node: i32 = new_node(Node::Literal);
  node.node_String.i32 = CURRENT_TOKEN.token_Value;
  node.node_type.i32 = CURRENT_TOKEN.token_kind;
  next_token();
  node
}

fn new_node(kind: i32) -> i32 {
  let node: i32 = allocate(node_size);
  node.node_dec0de = 2 - DEC0DE;
  node.node_Scope = CURRENT_SCOPE;
  node.node_Token = CURRENT_TOKEN;
  node.node_kind = kind;
  node
}

fn next_token() {
  CURRENT_TOKEN_ITEM = CURRENT_TOKEN_ITEM.item_Next;
  if CURRENT_TOKEN_ITEM {
    CURRENT_TOKEN = CURRENT_TOKEN_ITEM.item_Object;
  } else {
    CURRENT_TOKEN = 0;
  }
  let next_token_item: i32 = CURRENT_TOKEN_ITEM.item_Next;
  if next_token_item {
    NEXT_TOKEN = next_token_item.item_Object;
  } else {
    NEXT_TOKEN = 0;
  }
}

fn is_binary_op(token: i32) -> bool {
  let kind: i32 = token.token_kind;
  kind == Token::Add | kind == Token::Sub | kind == Token::Mul | kind == Token::Div | kind == Token::Rem
    | kind == Token::Remu | kind == Token::BitOr | kind == Token::BitAnd | kind == Token::Lt | kind == Token::Eql 
    | kind == Token::Ne | kind == Token::Lt | kind == Token::Le | kind == Token::Gt | kind == Token::Ge 
    | kind == Token::Shl | kind == Token::Shr | kind == Token::BitXor | kind == Token::Ltu | kind == Token::Leu 
    | kind == Token::Gtu | kind == Token::Geu | kind == Token::Shru | kind == Token::Rotl 
    | kind == Token::Rotr
}

fn is_assign_op(token: i32) -> bool {
  let kind: i32 = token.token_kind;
  kind == Token::AddAssign | kind == Token::BitAndAssign | kind == Token::BitOrAssign | kind == Token::BitXorAssign
    | kind == Token::DivAssign | kind == Token::MulAssign | kind == Token::RemAssign | kind == Token::ShlAssign
    | kind == Token::ShrAssign | kind == Token::SubAssign
}

fn is_unary_op(token: i32) -> bool {
  let kind: i32 = token.token_kind;
  kind == Token::Sub | kind == Token::Not | kind == Token::Cnt | kind == Token::Clz | kind == Token::Ctz
    | kind == Token::Abs | kind == Token::Neg | kind == Token::Ceil | kind == Token::Floor
    | kind == Token::Trunc | kind == Token::Round | kind == Token::Sqrt 
}

fn is_literal(token: i32) -> bool {
  let kind: i32 = token.token_kind;
  kind == Token::NumLiteral | kind == Token::CharLiteral | kind == Token::StrLiteral
    | kind == Token::True | kind == Token::False
}

fn is_native_type(token: i32) -> bool {
  let k: i32 = token.token_kind;
  k == Token::I32 | k == Token::I64 | k == Token::F32 | k == Token::F64 | k == Token::Bool
}

fn eat_token(kind: i32) {
  if CURRENT_TOKEN {
    if CURRENT_TOKEN.token_kind != kind {
      add_error(Error::InvalidToken, CURRENT_TOKEN);
    }
    next_token();
  } else {
    let LastToken: i32 = TOKEN_LIST.list_Last.item_Object;
    add_error(Error::MissingToken, LastToken);
  }
}

fn try_eat_token(kind: i32) -> bool {
  if CURRENT_TOKEN {
    if CURRENT_TOKEN.token_kind == kind {
      next_token();
      return true;
    }
  } 
  false
}

fn parse_fn_params() -> i32 {
  let params: i32 = new_list();
  eat_token(Token::LParen);
  while CURRENT_TOKEN.token_kind.i32 != Token::RParen {
    let mutable: i32 = try_eat_token(Token::Mut);
    let name: i32 = CURRENT_TOKEN.token_Value;
    next_token();
    eat_token(Token::Colon);
    let token_type: i32 = CURRENT_TOKEN.token_kind;
    next_token();
    let FunParamNode: i32 = new_node(Node::Parameter);
    FunParamNode.node_type = token_type;
    FunParamNode.node_dataType = token_type;
    FunParamNode.node_String = name;
    if mutable {
      FunParamNode.node_assigns = -1;
    } else {
      FunParamNode.node_assigns = 1;
    }
    list_add_name(params, FunParamNode, name);
    if CURRENT_TOKEN.token_kind.i32 != Token::Comma { break; }
    eat_token(Token::Comma);
  }
  eat_token(Token::RParen);
  params
}

fn parse_enum() -> i32 {
  eat_token(Token::Enum);
  let node: i32 = new_node(Node::Enum);
  let name: i32 = CURRENT_TOKEN.token_Value;
  node.node_String = name;
  let Enums: i32 = new_list();
  node.node_Nodes = Enums;
  scope_register_name(CURRENT_SCOPE, name, node, CURRENT_TOKEN);
  next_token();
  eat_token(Token::LBrace);
  let mut enum_value: i32 = 1;
  while CURRENT_TOKEN {
    if CURRENT_TOKEN.token_kind.i32 == Token::RParen { break; }
    list_add_name(Enums, enum_value, CURRENT_TOKEN.token_Value);
    next_token();
    if CURRENT_TOKEN.token_kind.i32 != Token::Comma { break; }
    eat_token(Token::Comma);
    enum_value += 1;
  }
  eat_token(Token::RBrace);
  node
}

fn parse_break() -> i32 {
  let node: i32 = new_node(Node::Break);
  eat_token(Token::Break);
  eat_token(Token::Semicolon);
  node
}

fn parse_continue() -> i32 {
  let node: i32 = new_node(Node::Continue);
  eat_token(Token::Continue);
  eat_token(Token::Semicolon);
  node
}

fn parse_identifier() -> i32 {
  let node: i32 = new_node(Node::Identifier);
  node.node_String.i32 = CURRENT_TOKEN.token_Value;
  node.node_type.i32 = CURRENT_TOKEN.token_kind;
  next_token();
  node
}

fn copy_node(node: i32) -> i32 {
  let copy: i32 = new_node(node.node_kind);
  copy.node_String.i32 = node.node_String;
  copy.node_ANode.i32 = node.node_ANode;
  copy.node_BNode.i32 = node.node_BNode;
  copy.node_CNode.i32 = node.node_CNode;
  copy.node_Nodes.i32 = node.node_Nodes;
  copy.node_ParamNodes.i32 = node.node_ParamNodes;
  copy.node_type.i32 = node.node_type;
  copy.node_Token.i32 = node.node_Token;
  copy
}

fn parse_call_params() -> i32 {
  let param_list: i32 = new_list();
  eat_token(Token::LParen);
  while CURRENT_TOKEN {
    if CURRENT_TOKEN.token_kind.i32 == Token::RParen { break; }
    list_add(param_list, parse_expression(Token::MinPrecedence));
    if CURRENT_TOKEN.token_kind.i32 != Token::Comma { break; }
    eat_token(Token::Comma);
  }
  eat_token(Token::RParen);
  param_list
}

fn parse_call_expression(Callee: i32) -> i32 {
  let node: i32 = new_node(Node::Call);
  node.node_ANode = Callee;
  node.node_ParamNodes = parse_call_params();
  node
}

fn parse_unary_expression() -> i32 {
  let node: i32 = new_node(Node::Unary);
  node.node_type.i32 = CURRENT_TOKEN.token_kind;
  node.node_String.i32 = CURRENT_TOKEN.token_Value;
  next_token();
  node.node_BNode = parse_expression(Token::Add);
  node
}

fn parse_double_colon() -> i32 {
  let node: i32 = new_node(Node::Literal);
  node.node_type = Token::NumLiteral;
  let EnumName: i32 = CURRENT_TOKEN.token_Value;
  let EnumNode: i32 = scope_resolve(CURRENT_SCOPE, EnumName, CURRENT_TOKEN);
  next_token();
  eat_token(Token::DoubleColon);
  let EnumMember: i32 = CURRENT_TOKEN.token_Value;
  let enum_value: i32 = list_search(EnumNode.node_Nodes, EnumMember);
  if !enum_value {
    add_error(Error::InvalidToken, CURRENT_TOKEN);
  }
  node.node_String = i32_to_str(enum_value);
  next_token();
  node
}

fn parse_dot_load() -> i32 {
  let node: i32 = new_node(Node::DotLoad);
  let BodyList: i32 = new_list();
  node.node_Nodes = BodyList;
  list_add(BodyList, parse_identifier());
  while CURRENT_TOKEN {
    if CURRENT_TOKEN.token_kind.i32 != Token::Dot { break; }
    eat_token(Token::Dot);
    if is_native_type(CURRENT_TOKEN) {
      node.node_dataType.i32 = CURRENT_TOKEN.token_kind;
      next_token();
      break;
    } else {
      list_add(BodyList, parse_identifier());
    }
  }
  node
}

// A.B.C.i32 = x
fn parse_dot_store() -> i32 {
  let node: i32 = new_node(Node::DotStore);
  let BodyList: i32 = new_list();
  let mut data_type: i32 = 0;
  node.node_Nodes = BodyList;
  list_add(BodyList, parse_identifier());
  while CURRENT_TOKEN {
    if CURRENT_TOKEN.token_kind.i32 != Token::Dot { break; }
    eat_token(Token::Dot);
    if is_native_type(CURRENT_TOKEN) {
      data_type = CURRENT_TOKEN.token_kind;
      node.node_dataType = data_type;
      next_token();
      break;
    } else {
      list_add(BodyList, parse_identifier());
    }
  }
  eat_token(Token::Assign);
  node.node_ANode = parse_expression(Token::MinPrecedence);
  node.node_ANode.node_dataType = data_type;
  eat_token(Token::Semicolon);
  node
}

fn parse_binary_expression(level: i32, Left: i32) -> i32 {
  let mut node: i32 = 0;
  let precedence: i32 = CURRENT_TOKEN.token_kind;  // node_kind doubles as the precedence
  if level > precedence {
    node = Left;
  } else {
    node = new_node(Node::Binary);
    node.node_type.i32 = CURRENT_TOKEN.token_kind;
    node.node_String.i32 = CURRENT_TOKEN.token_Value;
    node.node_ANode = Left;
    next_token();
    node.node_BNode = parse_expression(precedence);
  }
  node
}

fn parse_assign_statement() -> i32 {
  let node: i32 = new_node(Node::Assign);
  node.node_ANode = parse_identifier();
  node.node_type = Token::Assign;
  node.node_String.i32 = CURRENT_TOKEN.token_Value;
  eat_token(Token::Assign);
  node.node_BNode = parse_expression(Token::MinPrecedence);
  eat_token(Token::Semicolon);
  node
}

fn parse_assign_op_statement() -> i32 {
  let node: i32 = new_node(Node::Assign);
  node.node_ANode = parse_identifier();
  node.node_type = Token::Assign;
  node.node_String.i32 = CURRENT_TOKEN.token_Value;
  let copy: i32 = copy_node(node.node_ANode);
  let b_node: i32 = new_node(Node::Binary);
  b_node.node_String.i32 = CURRENT_TOKEN.token_Value;
  b_node.node_ANode = copy;
  let mut b_type: i32 = 0;
  if try_eat_token(Token::AddAssign) { b_type = Token::Add;
  } else if try_eat_token(Token::BitAndAssign) { b_type = Token::BitAnd;
  } else if try_eat_token(Token::BitOrAssign) { b_type = Token::BitOr;
  } else if try_eat_token(Token::BitXorAssign) { b_type = Token::BitXor;
  } else if try_eat_token(Token::DivAssign) { b_type = Token::Div;
  } else if try_eat_token(Token::MulAssign) { b_type = Token::Mul;
  } else if try_eat_token(Token::RemAssign) { b_type = Token::Rem;
  } else if try_eat_token(Token::ShlAssign) { b_type = Token::Shl;
  } else if try_eat_token(Token::ShrAssign) { b_type = Token::Shr;
  } else if try_eat_token(Token::SubAssign) { b_type = Token::Sub; 
  } else {
    add_error(Error::ParseAssignOp, CURRENT_TOKEN);
    next_token();
  }
  b_node.node_type.i32 = b_type;
  b_node.node_BNode = parse_expression(Token::MinPrecedence);
  node.node_BNode = b_node;
  eat_token(Token::Semicolon);
  node
}

fn parse_infix(level: i32, Left: i32) -> i32 {
  let mut node: i32 = 0;
  if is_binary_op(CURRENT_TOKEN) {
    node = parse_binary_expression(level, Left);
  } else if CURRENT_TOKEN.token_kind.i32 == Token::LParen {
    node = parse_call_expression(Left);
    node.node_Token.i32 = Left.node_Token;
  } else {
    node = Left;
  }
  node
}

fn parse_call_statement() -> i32 {
  let IdentifierNode: i32 = parse_identifier();
  let node: i32 = parse_call_expression(IdentifierNode);
  eat_token(Token::Semicolon);
  node
}

// TODO: reintegrate
fn parse_breakif() -> i32 {
  let node: i32 = new_node(Node::BreakIf);
  node.node_CNode = parse_expression(Token::MinPrecedence);
  eat_token(Token::Semicolon);
  node
}

// TODO: reintegrate
fn parse_drop() -> i32 {
  let node: i32 = new_node(Node::Pop);
  node.node_CNode = parse_expression(Token::MinPrecedence);
  eat_token(Token::Semicolon);
  node
}

fn parse_return_statement() -> i32 {
  let node: i32 = new_node(Node::Return);
  eat_token(Token::Return);
  node.node_ANode = parse_expression(Token::MinPrecedence);
  eat_token(Token::Semicolon);
  node
}

fn parse_return_expression() -> i32 {
  let node: i32 = new_node(Node::Return);
  let Expression: i32 = parse_expression(Token::MinPrecedence);
  node.node_ANode = Expression;
  if !Expression {
    add_error(Error::BlockStatement, CURRENT_TOKEN);
    next_token();
  }
  node
}

fn parse_if_block() -> i32 {
  eat_token(Token::LBrace);
  let node: i32 = new_node(Node::Block);
  let BodyList: i32 = new_list();
  node.node_Nodes = BodyList;
  node.node_Scope = CURRENT_SCOPE;
  while CURRENT_TOKEN {
    if CURRENT_TOKEN.token_kind.i32 == Token::RBrace { break; }
    let ChildNode: i32 = parse_statement();
    if !ChildNode { break; }
    list_add(BodyList, ChildNode);
  }
  eat_token(Token::RBrace);
  node
}

fn parse_if_statement() -> i32 {
  let node: i32 = new_node(Node::If);
  eat_token(Token::If);
  node.node_CNode = parse_expression(Token::MinPrecedence);
  push_scope(node);
  node.node_ANode = parse_if_block();
  pop_scope();
  if CURRENT_TOKEN.token_kind.i32 == Token::Else {
    eat_token(Token::Else);
    push_scope(node);
    if CURRENT_TOKEN.token_kind.i32 == Token::If {
      node.node_BNode = parse_if_statement();
    } else {
      node.node_BNode = parse_if_block();
    }
    pop_scope();
  }
  node
}

fn parse_loop_block() -> i32 {
  let node: i32 = new_node(Node::Block);
  let BodyList: i32 = new_list();
  node.node_Nodes = BodyList;
  node.node_Scope = CURRENT_SCOPE;
  while CURRENT_TOKEN {
    if CURRENT_TOKEN.token_kind.i32 == Token::RBrace { break; }
    let ChildNode: i32 = parse_statement();
    if !ChildNode { break; }
    list_add(BodyList, ChildNode);
  }
  node
}

fn parse_loop_statement() -> i32 {
  let node: i32 = new_node(Node::Loop);
  eat_token(Token::Loop);
  eat_token(Token::LBrace);
  push_scope(node);
  node.node_ANode = parse_loop_block();
  pop_scope();
  eat_token(Token::RBrace);
  node
}

fn parse_while_statement() -> i32 {
  let node: i32 = new_node(Node::Loop);
  eat_token(Token::While);
  node.node_CNode = parse_expression(Token::MinPrecedence);
  eat_token(Token::LBrace);
  push_scope(node);
  node.node_ANode = parse_loop_block();
  pop_scope();
  eat_token(Token::RBrace);
  node
}

fn parse_const() -> i32 {
  eat_token(Token::Const);
  let name: i32 = CURRENT_TOKEN.token_Value;
  let NameToken: i32 = CURRENT_TOKEN;
  next_token();
  eat_token(Token::Colon);
  let token_type: i32 = CURRENT_TOKEN.token_kind;
  next_token();
  let node: i32 = new_node(Node::Variable);
  node.node_type = token_type;
  node.node_dataType = token_type;
  node.node_String = name;
  scope_register_name(CURRENT_SCOPE, name, node, NameToken);
  eat_token(Token::Assign);
  node.node_BNode = parse_expression(Token::MinPrecedence);
  if CURRENT_SCOPE.scope_Parent.i32 {
    let fn_scope: i32 = get_fn_scope(CURRENT_SCOPE);
    let FunNode: i32 = fn_scope.scope_Node;
    let mut FunLocalsList: i32 = FunNode.node_Nodes;
    if !FunLocalsList {
      FunLocalsList = new_list();
      FunNode.node_Nodes = FunLocalsList;
    }
    list_add(FunLocalsList, node);
  }
  eat_token(Token::Semicolon);
  node
}

fn parse_static() -> i32 {
  eat_token(Token::Static);
  let mutable: i32 = try_eat_token(Token::Mut);
  let name: i32 = CURRENT_TOKEN.token_Value;
  let NameToken: i32 = CURRENT_TOKEN;
  next_token();
  eat_token(Token::Colon);
  let token_type: i32 = CURRENT_TOKEN.token_kind;
  next_token();
  let node: i32 = new_node(Node::Variable);
  node.node_type = token_type;
  node.node_dataType = token_type;
  node.node_String = name;
  if mutable {
    node.node_assigns = -1;
  } else {
    node.node_assigns = 1;
  }
  scope_register_name(CURRENT_SCOPE, name, node, NameToken);
  eat_token(Token::Assign);
  node.node_BNode = parse_expression(Token::MinPrecedence);
  if CURRENT_SCOPE.scope_Parent.i32 {
    let fn_scope: i32 = get_fn_scope(CURRENT_SCOPE);
    let FunNode: i32 = fn_scope.scope_Node;
    let mut FunLocalsList: i32 = FunNode.node_Nodes;
    if !FunLocalsList {
      FunLocalsList = new_list();
      FunNode.node_Nodes = FunLocalsList;
    }
    list_add(FunLocalsList, node);
  }
  eat_token(Token::Semicolon);
  node
}

fn parse_declaration() -> i32 {
  eat_token(Token::Let);
  let mutable: i32 = try_eat_token(Token::Mut);
  let name: i32 = CURRENT_TOKEN.token_Value;
  let NameToken: i32 = CURRENT_TOKEN;
  next_token();
  eat_token(Token::Colon);
  let token_type: i32 = CURRENT_TOKEN.token_kind;
  next_token();
  let node: i32 = new_node(Node::Variable);
  node.node_type = token_type;
  node.node_dataType = token_type;
  node.node_String = name;
  if mutable {
    node.node_assigns = -1;  // mutables have infinite assigns
  } else {
    node.node_assigns = 0;  // non-mutables can only be assigned once
  }
  scope_register_name(CURRENT_SCOPE, name, node, NameToken);
  eat_token(Token::Assign);
  node.node_BNode = parse_expression(Token::MinPrecedence);
  if CURRENT_SCOPE.scope_Parent.i32 {
    let fn_scope: i32 = get_fn_scope(CURRENT_SCOPE);
    let FunNode: i32 = fn_scope.scope_Node;
    let mut FunLocalsList: i32 = FunNode.node_Nodes;
    if !FunLocalsList {
      FunLocalsList = new_list();
      FunNode.node_Nodes = FunLocalsList;
    }
    list_add(FunLocalsList, node);
  }
  eat_token(Token::Semicolon);
  node
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// Compiler 

static mut CURRENT_FN_NODE: i32 = 0;
static mut TYPE_LIST: i32 = 0;
static mut FN_TYPE_LIST: i32 = 0;

fn emit(dwasm: i32, root_node: i32) {
  WASM = new_empty_string(dwasm.string_length + 256);  // Guess
  CURRENT_SCOPE = root_node.node_Scope;
  emit_header();
  TYPE_LIST = new_list();
  FN_TYPE_LIST = new_list();
  emit_type_section(root_node);
  emit_function_section();
  emit_memory_section();
  emit_global_section(root_node);
  emit_export_section(root_node);
  emit_code_section(root_node);
  emit_data_section();
}

fn emit_header() {
  append_str(WASM, "\00asm");  // WASM magic: 00 61 73 6d
  append_i32(WASM, 1);         // WASM version
}

fn emit_type_section(root_node: i32) {
  let BodyList: i32 = root_node.node_Nodes;
  let skip: i32 = WASM.string_length;
  if BodyList {
    append_byte(WASM, 0x01);  // Type section
    append_byte(WASM, 0x00);  // section size (guess)
    let Start: i32 = WASM.string_length;
    append_byte(WASM, 0x00);  // types count (guess)  
    let mut index: i32 = 0;
    let mut item: i32 = BodyList.list_First;
    while item {
      let node: i32 = item.item_Object;
      if node.node_kind.i32 == Node::Fun {
        emit_type(node, index);
        index += 1;
      }
      item = item.item_Next;
    }
    let count: i32 = TYPE_LIST.list_count;
    let length: i32 = WASM.string_length - Start;
    let offset: i32 = uleb_length(count) - 1 + uleb_length(length) - 1;
    offset_tail(WASM, Start, offset);
    WASM.string_length = Start - 1;
    append_uleb(WASM, length + uleb_length(count) - 1);
    append_uleb(WASM, count);
    WASM.string_length = WASM.string_length + length - 1;
  }
  if !FN_TYPE_LIST.list_count.i32 { 
    WASM.string_length = skip;
  }
}

fn append_data_type(string: i32, data_type: i32) {
  if data_type == Token::F64 {
    append_byte(string, 0x7c);
  } else if data_type == Token::F32 {
    append_byte(string, 0x7d);
  } else if data_type == Token::I64 {
    append_byte(string, 0x7e);
  } else {
    append_byte(string, 0x7f);
  }
}

fn emit_type(node: i32, funcNo: i32) {
  let param_list: i32 = node.node_ParamNodes;
  let params: i32 = param_list.list_count;
  let mut returns: i32 = 0;
  if node.node_type.bool { 
    returns = 1;
  }
  let TypeString: i32 = new_empty_string(1 + uleb_length(params) + params + uleb_length(returns) + returns);
  append_byte(TypeString, 0x60);  // fn token_type
  append_uleb(TypeString, params);
  let mut param_item: i32 = param_list.list_First;
  while param_item {
    let data_type: i32 = param_item.item_Object.node_type;
    append_data_type(TypeString, data_type);
    param_item = param_item.item_Next;
  }
  let returnType: i32 = node.node_type;
  if returnType {
    append_uleb(TypeString, 0x01);  // return count
    append_data_type(TypeString, returnType);
  } else {
    append_uleb(TypeString, 0x00);  // return count
  }
  let mut typeIndex: i32 = index_list_search(TYPE_LIST, TypeString);
  if typeIndex == -1 {
    typeIndex = TYPE_LIST.list_count;
    list_add_name(TYPE_LIST, 0, TypeString);
    append_str(WASM, TypeString);
  }
  list_add(FN_TYPE_LIST, typeIndex);
}

fn emit_function_section() {
  let funCount: i32 = FN_TYPE_LIST.list_count;
  if funCount {
    append_byte(WASM, 0x03);  // Function section
    append_byte(WASM, 0x00);  // section size (guess)
    let start: i32 = WASM.string_length;
    append_uleb(WASM, funCount);  // types count
    let mut FunType: i32 = FN_TYPE_LIST.list_First;
    while FunType {
      append_uleb(WASM, FunType.item_Object);
      FunType = FunType.item_Next;
    }
    let length: i32 = WASM.string_length - start;
    let offset: i32 = uleb_length(length) - 1;
    offset_tail(WASM, start, offset);
    WASM.string_length = start - 1;
    append_uleb(WASM, length);
    WASM.string_length = WASM.string_length + length;
  }
}

fn emit_memory_section() {
  append_byte(WASM, 0x05);  // Memory section
  append_uleb(WASM, 2 + uleb_length(1_000));  // Size in bytes
  append_byte(WASM, 0x01);    // Count
  append_byte(WASM, 0x00);    // Resizable
  append_uleb(WASM, 1_000);  // Pages
}

fn emit_global_section(root_node: i32) {
  let skip: i32 = WASM.string_length;
  let mut count: i32 = 0; 
  if root_node.node_Nodes.i32 {
    append_byte(WASM, 0x06);  // Section code
    append_byte(WASM, 0x00);  // Section size (guess)
    let start: i32 = WASM.string_length;
    append_byte(WASM, 0x00);  // Globals count (guess)
    let mut item: i32 = root_node.node_Nodes.list_First;
    while item {
      if item.item_Object.node_kind.i32 == Node::Variable {
        emit_native_global(item.item_Object);
        count += 1;
      }
      item = item.item_Next;
    }
    let length: i32 = WASM.string_length - start;
    let offset: i32 = uleb_length(count) - 1 + uleb_length(length) - 1;
    offset_tail(WASM, start, offset);
    WASM.string_length = start - 1;
    append_uleb(WASM, length + uleb_length(count) - 1);
    append_uleb(WASM, count);
    WASM.string_length = WASM.string_length + length - 1;
  }
  if !count {
    WASM.string_length = skip;
  }
}

fn emit_native_global(node: i32) {
  let data_type: i32 = node.node_type;  // Native type
  if data_type == Token::F64 { 
    append_byte(WASM, 0x7c);
    append_byte(WASM, 0x01);  // Mutable
    append_byte(WASM, 0x44);  // f64.const
  } else if data_type == Token::F32 { 
    append_byte(WASM, 0x7d);
    append_byte(WASM, 0x01);  // Mutable
    append_byte(WASM, 0x43);  // f32.const
  } else if data_type == Token::I64 {
    append_byte(WASM, 0x7e);
    append_byte(WASM, 0x01);  // Mutable
    append_byte(WASM, 0x42);  // i64.const
  } else {  // i32, bool
    append_byte(WASM, 0x7f);
    append_byte(WASM, 0x01);  // Mutable
    append_byte(WASM, 0x41);  // i32.const
  }
  let text: i32 = node.node_BNode.node_String;
  let nodeType: i32 = node.node_BNode.node_type;
  if nodeType == Token::True {
    append_byte(WASM, 0x01); 
  } else if nodeType == Token::False { 
    append_byte(WASM, 0x00); 
  } else if data_type == Token::F64 {
    append_f64(WASM, str_to_f64(text));
  } else if data_type == Token::F32 {
    append_f32(WASM, str_to_f32(text));
  } else if data_type == Token::I64 {
    append_sleb64(WASM, str_to_i64(text, node.node_BNode.node_Token));
  } else {
    append_sleb32(WASM, str_to_i32(text, node.node_BNode.node_Token));
  }
  append_byte(WASM, 0x0b);  // end
}

fn emit_export_section(root_node: i32) {
  let BodyList: i32 = root_node.node_Nodes;
  if BodyList {
    let mut count: i32 = EXPORT_LIST.list_count;
    count += 1;  // +1 because we are also exporting the Memory
    if count {
      append_byte(WASM, 0x07);  // Export section
      append_byte(WASM, 0x00);  // Section size (guess)
      let start: i32 = WASM.string_length;
      append_uleb(WASM, count);  // Export count
      emit_export_mem();
      emit_export_fns();
      let length: i32 = WASM.string_length - start;
      let offset: i32 = uleb_length(length) - 1;
      offset_tail(WASM, start, offset);
      WASM.string_length = start - 1;
      append_uleb(WASM, length);
      WASM.string_length = WASM.string_length + length;
    }
  }
}

fn emit_export_fns() {
  let mut item: i32 = EXPORT_LIST.list_First;
  while item {
    let name: i32 = item.item_Name;
    append_uleb(WASM, name.string_length);
    append_str(WASM, name);
    append_byte(WASM, 0x00);  // Type: function
    append_uleb(WASM, item.item_Object.node_index);
    item = item.item_Next;
  }
}

fn emit_export_mem() {
  append_uleb(WASM, 6);
  append_str(WASM, "memory");
  append_byte(WASM, 0x02);  // Type: memory
  append_byte(WASM, 0x00);  // Memory number 0 
}

fn emit_data_section() {
  let count: i32 = DATA_LIST.list_count;
  if count {
    append_byte(WASM, 0x0b);  // Data section
    append_byte(WASM, 0x00);  // Section size (guess)
    let start: i32 = WASM.string_length;
    append_uleb(WASM, count);
    let mut DataItem: i32 = DATA_LIST.list_First;
    while DataItem {
      append_byte(WASM, 0x00);  // memory index 
      append_byte(WASM, 0x41);  // i32.const
      append_uleb(WASM, DataItem.item_Object);  // offset
      append_byte(WASM, 0x0b);  // end
      let DataString: i32 = DataItem.item_Name;
      let dataLength: i32 = DataString.string_length + string_size;
      append_uleb(WASM, dataLength);
      append_i32(WASM, DataItem.item_Object + string_size);  // string_bytes
      append_i32(WASM, DataString.string_length);  // string_length
      append_i32(WASM, DataString.string_length);  // string_capacity
      append_str(WASM, DataString);
      DataItem = DataItem.item_Next;
    }
    let length: i32 = WASM.string_length - start;
    let offset: i32 = uleb_length(length) - 1;
    offset_tail(WASM, start, offset);
    WASM.string_length = start - 1;
    append_uleb(WASM, length);
    WASM.string_length = WASM.string_length + length;
  }
}

fn emit_code_section(root_node: i32) {
  if FN_TYPE_LIST.list_count.i32 {
    append_byte(WASM, 0x0a);  // Code section
    append_byte(WASM, 0x00);  // Section size (guess)
    let start: i32 = WASM.string_length;
    append_uleb(WASM, FN_TYPE_LIST.list_count);
    let mut FunItem: i32 = root_node.node_Nodes.list_First;
    while FunItem {
      let FunNode: i32 = FunItem.item_Object;
      if FunNode.node_kind.i32 == Node::Fun {
        emit_fn_node(FunNode);
      }
      FunItem = FunItem.item_Next;
    }
    let length: i32 = WASM.string_length - start;
    let offset: i32 = uleb_length(length) - 1;
    offset_tail(WASM, start, offset);
    WASM.string_length = start - 1;
    append_uleb(WASM, length);
    WASM.string_length = WASM.string_length + length;
  }
}

fn emit_fn_node(node: i32) {
  CURRENT_FN_NODE = node;
  append_byte(WASM, 0x00);  // Function size (guess)
  let start: i32 = WASM.string_length;
  append_byte(WASM, 0x00);  // Local declaration count (guess)
  let LocalList: i32 = node.node_Nodes;
  let mut LocalItem: i32 = LocalList.list_First;
  let mut declCount: i32 = 0;
  while LocalItem {
    let data_type: i32 = LocalItem.item_Object.node_type;
    let mut count: i32 = 1;
    loop {
      let NextItem: i32 = LocalItem.item_Next;
      if !NextItem { break; }
      if data_type != NextItem.item_Object.node_type { break; }
      LocalItem = NextItem;
      count += 1;
    }
    append_uleb(WASM, count);  // count
    append_data_type(WASM, data_type);
    LocalItem = LocalItem.item_Next;
    declCount += 1;
  }
  emit_node(node.node_ANode);  // Body Block node
  append_byte(WASM, 0x0b);  // end
  let length: i32 = WASM.string_length - start;
  let offset: i32 = uleb_length(length) - 1 + uleb_length(declCount) - 1;
  offset_tail(WASM, start, offset);
  WASM.string_length = start - 1;
  append_uleb(WASM, length);
  append_uleb(WASM, declCount);
  WASM.string_length = WASM.string_length + length - 1;
}

fn emit_node(node: i32) {
  let kind: i32 = node.node_kind;
  if kind == Node::Block {
    emit_block(node);
  } else if kind == Node::Assign {
    emit_assign(node, false);
  } else if kind == Node::Unary {
    emit_unary(node);
  } else if kind == Node::Call {
    emit_call(node);
  } else if kind == Node::Return {
    emit_return(node);
  } else if kind == Node::If {
    emit_if(node);
  } else if kind == Node::BreakIf {
    emit_breakif(node);
  } else if kind == Node::Pop {
    emit_drop(node);
  } else if kind == Node::Loop {
    emit_loop(node);
  } else if kind == Node::Literal {
    emit_literal(node);
  } else if kind == Node::Identifier {
    emit_identifier(node);
  } else if kind == Node::DotLoad {
    emit_dot_load(node);
  } else if kind == Node::DotStore {
    emit_dot_store(node);
  } else if kind == Node::Variable {
    emit_variable(node);
  } else if kind == Node::Continue {
    append_byte(WASM, 0x0c);  // br
    append_uleb(WASM, scope_level(node, Node::Loop));
  } else if kind == Node::Break {
    append_byte(WASM, 0x0c);  // br
    append_uleb(WASM, scope_level(node, Node::Loop) + 1);
  } else {
    add_error(Error::EmitNode, node.node_Token);
  }
}

fn emit_expression(node: i32) {
  if node {
    let kind: i32 = node.node_kind;
    if kind == Node::Binary {
      emit_binary(node);
    } else if kind == Node::Unary {
      emit_unary(node);
    } else if kind == Node::Call {
      emit_call(node);
    } else if kind == Node::Literal {
      emit_literal(node);
    } else if kind == Node::Identifier {
      emit_identifier(node);
    } else if kind == Node::DotLoad {
      emit_dot_load(node);
    } else if kind == Node::Variable {
      emit_variable(node);
    } else {
      add_error(Error::Expression, node.node_Token);
    }
  } else {
    add_error(Error::Expression, 0);
  }
}

fn emit_assign(node: i32, isExpression: bool) {
  let resolved_node: i32 = scope_resolve(CURRENT_SCOPE, node.node_ANode.node_String, node.node_Token);
  let data_type: i32 = resolved_node.node_type;
  let BNode: i32 = node.node_BNode;
  let assigns: i32 = resolved_node.node_assigns;
  if assigns == 0 { 
    add_error(Error::NotMutable, node.node_Token);
  }
  if assigns > 0 {
    resolved_node.node_assigns = assigns - 1;
  }
  node.node_dataType = data_type;
  if BNode.node_dataType != 0 & BNode.node_dataType != data_type {
    add_error(Error::TypeMismatchA, node.node_Token);
  }
  BNode.node_dataType = data_type;
  emit_expression(BNode);
  if resolved_node.node_Scope == GLOBAL_SCOPE {
    append_byte(WASM, 0x24);  // set_global
    if isExpression {
      append_uleb(WASM, resolved_node.node_index);
      append_byte(WASM, 0x23);  // get_global
    }
  } else {
    if isExpression {
      append_byte(WASM, 0x22);  // tee_local
    } else {
      append_byte(WASM, 0x21);  // set_local
    }
  }
  append_uleb(WASM, resolved_node.node_index);
}

fn emit_binary(node: i32) {
  let token_type: i32 = node.node_type;
  let mut data_type: i32 = node.node_dataType;
  let ANode: i32 = node.node_ANode;
  let BNode: i32 = node.node_BNode;
  if !data_type {
    data_type = infer_data_type(node);
    if !data_type {
      add_error(Error::TypeNotInferred, node.node_Token);
    }
    node.node_dataType = data_type;
  }
  ANode.node_dataType = data_type;
  BNode.node_dataType = data_type;
  emit_expression(ANode);
  emit_expression(BNode);
  emit_operator(token_type, data_type, node);
}

fn emit_operator(token_type: i32, data_type: i32, node: i32) {
  if data_type == Token::F64 {
    if token_type == Token::Eql { append_byte(WASM, 0x61); 
    } else if token_type == Token::Ne { append_byte(WASM, 0x62); 
    } else if token_type == Token::Lt { append_byte(WASM, 0x63); 
    } else if token_type == Token::Gt { append_byte(WASM, 0x64); 
    } else if token_type == Token::Le { append_byte(WASM, 0x65); 
    } else if token_type == Token::Ge { append_byte(WASM, 0x66); 
    } else if token_type == Token::Add { append_byte(WASM, 0xa0); 
    } else if token_type == Token::Sub { append_byte(WASM, 0xa1); 
    } else if token_type == Token::Mul { append_byte(WASM, 0xa2); 
    } else if token_type == Token::Div { append_byte(WASM, 0xa3); 
    } else if token_type == Token::Min { append_byte(WASM, 0xa4); 
    } else if token_type == Token::Max { append_byte(WASM, 0xa5); 
    } else if token_type == Token::Abs { append_byte(WASM, 0x99); 
    } else if token_type == Token::Neg { append_byte(WASM, 0x9a); 
    } else if token_type == Token::Sqrt { append_byte(WASM, 0x9f); 
    } else if token_type == Token::Ceil { append_byte(WASM, 0x9b); 
    } else if token_type == Token::Floor { append_byte(WASM, 0x9c); 
    } else if token_type == Token::Trunc { append_byte(WASM, 0x9d); 
    } else if token_type == Token::Round { append_byte(WASM, 0x9e); 
    } else if token_type == Token::CopySign { append_byte(WASM, 0xa6); 
    } else { 
      add_error(Error::InvalidOperator, node.node_Token); 
    }
  } else if data_type == Token::F32 {
    if token_type == Token::Eql { append_byte(WASM, 0x5b); 
    } else if token_type == Token::Ne { append_byte(WASM, 0x5c);
    } else if token_type == Token::Lt { append_byte(WASM, 0x5d);
    } else if token_type == Token::Gt { append_byte(WASM, 0x5e);
    } else if token_type == Token::Le { append_byte(WASM, 0x5f);
    } else if token_type == Token::Ge { append_byte(WASM, 0x60); 
    } else if token_type == Token::Abs { append_byte(WASM, 0x8b); 
    } else if token_type == Token::Neg { append_byte(WASM, 0x8c); 
    } else if token_type == Token::Ceil { append_byte(WASM, 0x8d);
    } else if token_type == Token::Floor { append_byte(WASM, 0x8e);
    } else if token_type == Token::Trunc { append_byte(WASM, 0x8f);
    } else if token_type == Token::Round { append_byte(WASM, 0x90);
    } else if token_type == Token::Sqrt { append_byte(WASM, 0x91);
    } else if token_type == Token::Add { append_byte(WASM, 0x92);
    } else if token_type == Token::Sub { append_byte(WASM, 0x93);
    } else if token_type == Token::Mul { append_byte(WASM, 0x94);
    } else if token_type == Token::Div { append_byte(WASM, 0x95);
    } else if token_type == Token::Min { append_byte(WASM, 0x96);
    } else if token_type == Token::Max { append_byte(WASM, 0x97);
    } else if token_type == Token::CopySign { append_byte(WASM, 0x98);
    } else {
      add_error(Error::InvalidOperator, node.node_Token); 
    }
  } else if data_type == Token::I64 {
    if token_type == Token::Not { append_byte(WASM, 0x50); 
    } else if token_type == Token::Eql { append_byte(WASM, 0x51); 
    } else if token_type == Token::Ne { append_byte(WASM, 0x52); 
    } else if token_type == Token::Lt { append_byte(WASM, 0x53); 
    } else if token_type == Token::Ltu { append_byte(WASM, 0x54); 
    } else if token_type == Token::Gt { append_byte(WASM, 0x55); 
    } else if token_type == Token::Gtu { append_byte(WASM, 0x56); 
    } else if token_type == Token::Le { append_byte(WASM, 0x57);
    } else if token_type == Token::Leu { append_byte(WASM, 0x58);
    } else if token_type == Token::Ge { append_byte(WASM, 0x59); 
    } else if token_type == Token::Geu { append_byte(WASM, 0x5a);
    } else if token_type == Token::Clz { append_byte(WASM, 0x79);
    } else if token_type == Token::Ctz { append_byte(WASM, 0x7a); 
    } else if token_type == Token::Cnt { append_byte(WASM, 0x7b);
    } else if token_type == Token::Add { append_byte(WASM, 0x7c);
    } else if token_type == Token::Sub { append_byte(WASM, 0x7d);
    } else if token_type == Token::Mul { append_byte(WASM, 0x7e);
    } else if token_type == Token::Div { append_byte(WASM, 0x7f);
    } else if token_type == Token::Divu { append_byte(WASM, 0x80);
    } else if token_type == Token::Rem { append_byte(WASM, 0x81);
    } else if token_type == Token::Remu { append_byte(WASM, 0x82);
    } else if token_type == Token::BitAnd { append_byte(WASM, 0x83);
    } else if token_type == Token::BitOr { append_byte(WASM, 0x84);
    } else if token_type == Token::BitXor { append_byte(WASM, 0x85);
    } else if token_type == Token::Shl { append_byte(WASM, 0x86);
    } else if token_type == Token::Shr { append_byte(WASM, 0x87);
    } else if token_type == Token::Shru { append_byte(WASM, 0x88);
    } else if token_type == Token::Rotl { append_byte(WASM, 0x89);
    } else if token_type == Token::Rotr { append_byte(WASM, 0x8a); 
    } else {
      add_error(Error::InvalidOperator, node.node_Token); 
    }
  } else {
    if token_type == Token::Not { append_byte(WASM, 0x45); 
    } else if token_type == Token::Eql { append_byte(WASM, 0x46); 
    } else if token_type == Token::Ne { append_byte(WASM, 0x47); 
    } else if token_type == Token::Lt { append_byte(WASM, 0x48); 
    } else if token_type == Token::Ltu { append_byte(WASM, 0x49); 
    } else if token_type == Token::Gt { append_byte(WASM, 0x4a); 
    } else if token_type == Token::Gtu { append_byte(WASM, 0x4b); 
    } else if token_type == Token::Le { append_byte(WASM, 0x4c); 
    } else if token_type == Token::Leu { append_byte(WASM, 0x4d); 
    } else if token_type == Token::Ge { append_byte(WASM, 0x4e); 
    } else if token_type == Token::Geu { append_byte(WASM, 0x4f); 
    } else if token_type == Token::Clz { append_byte(WASM, 0x67); 
    } else if token_type == Token::Ctz { append_byte(WASM, 0x68); 
    } else if token_type == Token::Cnt { append_byte(WASM, 0x69); 
    } else if token_type == Token::Add { append_byte(WASM, 0x6a); 
    } else if token_type == Token::Sub { append_byte(WASM, 0x6b); 
    } else if token_type == Token::Mul { append_byte(WASM, 0x6c); 
    } else if token_type == Token::Div { append_byte(WASM, 0x6d); 
    } else if token_type == Token::Divu { append_byte(WASM, 0x6e); 
    } else if token_type == Token::Rem { append_byte(WASM, 0x6f); 
    } else if token_type == Token::Remu { append_byte(WASM, 0x70); 
    } else if token_type == Token::BitAnd { append_byte(WASM, 0x71); 
    } else if token_type == Token::BitOr { append_byte(WASM, 0x72); 
    } else if token_type == Token::BitXor { append_byte(WASM, 0x73); 
    } else if token_type == Token::Shl { append_byte(WASM, 0x74); 
    } else if token_type == Token::Shr { append_byte(WASM, 0x75); 
    } else if token_type == Token::Shru { append_byte(WASM, 0x76); 
    } else if token_type == Token::Rotl { append_byte(WASM, 0x77); 
    } else if token_type == Token::Rotr { append_byte(WASM, 0x78); 
    } else { 
      add_error(Error::InvalidOperator, node.node_Token); 
    }
  }
}

fn emit_unary(node: i32) {
  let token_type: i32 = node.node_type;
  let data_type: i32 = node.node_dataType;
  if token_type == Token::Sub {
    if data_type == Token::F64 {
      append_byte(WASM, 0x44);  // f64.const
      append_f64(WASM, 0); 
    } else if data_type == Token::F32 {
      append_byte(WASM, 0x43);  // f32.const
      append_f32(WASM, 0);
    } else if data_type == Token::I64 {
      append_byte(WASM, 0x42);  // i64.const 
      append_byte(WASM, 0x00);  // 0
    } else {
      append_byte(WASM, 0x41);  // i32.const 
      append_byte(WASM, 0x00);  // 0
    }
  }
  emit_expression(node.node_BNode);
  emit_operator(token_type, data_type, node);
}

fn emit_identifier(node: i32) {
  let resolved_node: i32 = scope_resolve(CURRENT_SCOPE, node.node_String, node.node_Token);
  let mut data_type: i32 = resolved_node.node_dataType;
  let mut node_data_type: i32 = node.node_dataType;
  if data_type == Token::Bool {
    data_type = Token::I32;
  }
  if node_data_type == Token::Bool {
    node_data_type = Token::I32;
  }
  if node_data_type != 0 & node_data_type != data_type {
    add_error(Error::TypeMismatchB, node.node_Token);
  }
  node.node_dataType = data_type;
  if resolved_node.node_Scope == GLOBAL_SCOPE {
    append_byte(WASM, 0x23);  // get_global
  } else {
    append_byte(WASM, 0x20);  // get_local
  }
  append_uleb(WASM, resolved_node.node_index);
}

// A.B.C.D
// loadX(load(load(A + B) + C) + D)
// A B + load() C + load() D + loadX()
fn emit_dot_load(node: i32) {
  let data_type: i32 = node.node_dataType;
  let ident_list: i32 = node.node_Nodes;
  let mut item: i32 = ident_list.list_First;
  let item_count: i32 = ident_list.list_count;
  let mut item_no: i32 = 1;
  emit_identifier(item.item_Object);
  item = item.item_Next;
  while item {
    item_no += 1;
    emit_identifier(item.item_Object);
    append_byte(WASM, 0x6a);  // i32.Add
    if item_no < item_count {
      append_byte(WASM, 0x28);  // i32.load
    } else {
      if !data_type {
        add_error(Error::TypeNotInferred, node.node_Token);
      }
      if data_type == Token::F64 {
        append_byte(WASM, 0x2b);  // f64.load
      } else if data_type == Token::F32 {
        append_byte(WASM, 0x2a);  // f32.load
      } else if data_type == Token::I64 {
        append_byte(WASM, 0x29);  // i64.load
      } else {
        append_byte(WASM, 0x28);  // i32.load
      }
    }
    append_byte(WASM, 0x00);  // alignment
    append_byte(WASM, 0x00);  // offset
    item = item.item_Next;
  }
}

// A.B.C.D = x
// storeX(load(load(A + B) + C) + D, x)
// A B + load() C + load() D + x storeX()
fn emit_dot_store(node: i32) {
  let mut data_type: i32 = node.node_dataType;
  if !data_type {
    data_type = infer_data_type(node.node_ANode);
    node.node_dataType = data_type;
  }
  let ident_list: i32 = node.node_Nodes;
  if ident_list {
    let mut item: i32 = ident_list.list_First;
    let item_count: i32 = ident_list.list_count;
    let mut item_no: i32 = 1;
    emit_identifier(item.item_Object);
    item = item.item_Next;
    while item {
      item_no += 1;
      emit_identifier(item.item_Object);
      append_byte(WASM, 0x6a);  // i32.Add
      if item_no < item_count {
        append_byte(WASM, 0x28);  // i32.load
      } else {
        emit_expression(node.node_ANode);
        if data_type == Token::F64 {
          append_byte(WASM, 0x39);  // f64.store
        } else if data_type == Token::F32 {
          append_byte(WASM, 0x38);  // f32.store
        } else if data_type == Token::I64 {
          append_byte(WASM, 0x37);  // i64.store
        } else {
          append_byte(WASM, 0x36);  // i32.store
        }
      }
      append_byte(WASM, 0x00);  // alignment
      append_byte(WASM, 0x00);  // offset
      item = item.item_Next;
    }
  } else {
  add_error(Error::NoIdentifiers, node.node_Token);
  }
}

fn emit_num_literal(node: i32, data_type: i32) {
  if data_type == Token::F64 {
    append_byte(WASM, 0x44);  // f64.const
    append_f64(WASM, str_to_f64(node.node_String));
  } else if data_type == Token::F32 {
    append_byte(WASM, 0x43);  // f32.const
    append_f32(WASM, str_to_f32(node.node_String));
  } else if data_type == Token::I64 {
    append_byte(WASM, 0x42);  // i64.const
    append_sleb64(WASM, str_to_i64(node.node_String, node.node_Token));
  } else {
    append_byte(WASM, 0x41);  // i32.const
    append_sleb32(WASM, str_to_i32(node.node_String, node.node_Token));
  }
}

fn emit_chr_literal(node: i32, data_type: i32) {
  let name: i32 = node.node_String;
  if data_type == Token::I64 {
    append_byte(WASM, 0x42);  // i64.const
    if name.string_length.i32 > 4 {
      append_sleb64(WASM, load64(name.string_bytes));
    } else {
      append_sleb32(WASM, load32(name.string_bytes));
    }
  } else {
    append_byte(WASM, 0x41);  // i32.const
    append_sleb32(WASM, load32(name.string_bytes));
  }
}

fn emit_literal(node: i32) {
  let token_type: i32 = node.node_type;
  let data_type: i32 = node.node_dataType;
  if token_type == Token::NumLiteral {
    emit_num_literal(node, data_type);
  } else if token_type == Token::CharLiteral {
    emit_chr_literal(node, data_type);
  } else if token_type == Token::StrLiteral {    
    append_byte(WASM, 0x41);  // i32.const
    append_sleb32(WASM, add_static_str(node.node_Token));
  } else if token_type == Token::True {
    append_byte(WASM, 0x41);  // i32.const
    append_byte(WASM, 0x01);  // 1
  } else if token_type == Token::False {
    append_byte(WASM, 0x41);  // i32.const
    append_byte(WASM, 0x00);  // 0
  }
}

static mut OFFSET: i32 = 65_536_000;

// Static strings are compiled to a pointer (i32.const) 
// and a string is added to Data section list
fn add_static_str(token: i32) -> i32 {
  OFFSET -= string_size + token.token_Value.string_length;
  if OFFSET % ALIGNMENT {
    OFFSET -= ALIGNMENT + OFFSET % ALIGNMENT;
  }
  list_add_name(DATA_LIST, OFFSET, token.token_Value);
  OFFSET
}

fn emit_fn_call_args(CallNode: i32, FunNode: i32) {
  let argument_list: i32 = CallNode.node_ParamNodes;
  if argument_list {
    let mut argument_item: i32 = argument_list.list_First;
    let param_list: i32 = FunNode.node_ParamNodes;
    if param_list {
      let mut param_item: i32 = param_list.list_First;
      while argument_item {
        let argument_node: i32 = argument_item.item_Object;
        let param_node: i32 = param_item.item_Object;
        argument_node.node_dataType.i32 = param_node.node_dataType;
        emit_expression(argument_node);
        argument_item = argument_item.item_Next;
        param_item = param_item.item_Next;
      }
    } else {
      add_error(Error::NoParamList, CallNode.node_Token);
    }
  }
}

fn emit_call_args(CallNode: i32, data_Type: i32) {
  let argument_list: i32 = CallNode.node_ParamNodes;
  let mut argument_item: i32 = argument_list.list_First;
  while argument_item {
    let argument_node: i32 = argument_item.item_Object;
    argument_node.node_dataType = data_Type;
    emit_expression(argument_node);
    argument_item = argument_item.item_Next;
  }
}

fn emit_call_args2(CallNode: i32, data_TypeA: i32, data_TypeB: i32) {
  let argument_list: i32 = CallNode.node_ParamNodes;
  let mut argument_item: i32 = argument_list.list_First;
  let mut isFirst: bool = true;
  while argument_item {
    let argument_node: i32 = argument_item.item_Object;
    if isFirst {
      argument_node.node_dataType = data_TypeA;
    } else {    
      argument_node.node_dataType = data_TypeB;
    }
    emit_expression(argument_node);
    argument_item = argument_item.item_Next;
    isFirst = false;
  }
}

fn emit_call(node: i32) {
  let name: i32 = node.node_ANode.node_String;
  if str_eq(name, "i64_i32") {
    emit_call_args(node, Token::I64);
    append_byte(WASM, 0xa7);  // i32.wrap/i64
  } else if str_eq(name, "f32_i32") {
    emit_call_args(node, Token::F32);
    append_byte(WASM, 0xa8);  // i32.trunc_s/f32
  } else if str_eq(name, "f32_i32u") {
    emit_call_args(node, Token::F32);
    append_byte(WASM, 0xa9);  // i32.trunc_u/f32
  } else if str_eq(name, "f64_i32") {
    emit_call_args(node, Token::F64);
    append_byte(WASM, 0xaa);  // i32.trunc_s/f64
  } else if str_eq(name, "f64_i32u") {
    emit_call_args(node, Token::F64);
    append_byte(WASM, 0xab);  // i32.trunc_u/f64
  } else if str_eq(name, "i32_i64") {
    emit_call_args(node, Token::I32);
    append_byte(WASM, 0xac);  // i64.extend_s/i32
  } else if str_eq(name, "i32_i64u") {
    emit_call_args(node, Token::I32);
    append_byte(WASM, 0xad);  // i64.extend_u/i32
  } else if str_eq(name, "f32_i64") {
    emit_call_args(node, Token::F32);
    append_byte(WASM, 0xae);  // i64.trunc_s/f32
  } else if str_eq(name, "f32_i64u") {
    emit_call_args(node, Token::F32);
    append_byte(WASM, 0xaf);  // i64.trunc_u/f32
  } else if str_eq(name, "f64_i64") {
    emit_call_args(node, Token::F64);
    append_byte(WASM, 0xb0);  // i64.trunc_s/f64
  } else if str_eq(name, "f64_i64u") {
    emit_call_args(node, Token::F64);
    append_byte(WASM, 0xb1);  // i64.trunc_u/f64
  } else if str_eq(name, "i32_f32") {
    emit_call_args(node, Token::I32);
    append_byte(WASM, 0xb2);  // f32.convert_s/i32    
  } else if str_eq(name, "i32_f32u") {
    emit_call_args(node, Token::I32);
    append_byte(WASM, 0xb3);  // f32.convert_u/i32   
  } else if str_eq(name, "i64_f32") {
    emit_call_args(node, Token::I64);
    append_byte(WASM, 0xb4);  // f32.convert_s/i64
  } else if str_eq(name, "i64_f32u") {
    emit_call_args(node, Token::I64);
    append_byte(WASM, 0xb5);  // f32.convert_u/i64
  } else if str_eq(name, "f64_f32") {
    emit_call_args(node, Token::F64);
    append_byte(WASM, 0xb6);  // f32.demote/f64
  } else if str_eq(name, "i32_f64") {
    emit_call_args(node, Token::I32);
    append_byte(WASM, 0xb7);  // f64.convert_s/i32
  } else if str_eq(name, "i32_f64u") {
    emit_call_args(node, Token::I32);
    append_byte(WASM, 0xb8);  // f64.convert_u/i32
  } else if str_eq(name, "i64_f64") {
    emit_call_args(node, Token::I64);
    append_byte(WASM, 0xb9);  // f64.convert_s/i64
  } else if str_eq(name, "i64_f64u") {
    emit_call_args(node, Token::I64);
    append_byte(WASM, 0xba);  // f64.convert_u/i64
  } else if str_eq(name, "f32_f64") {
    emit_call_args(node, Token::F32);
    append_byte(WASM, 0xbb);  // f64.promote/f32
  } else if str_eq(name, "load32") {
    emit_call_args(node, Token::I32);
    append_byte(WASM, 0x28);  // i32.load
    append_byte(WASM, 0x00);  // alignment
    append_byte(WASM, 0x00);  // offset
  } else if str_eq(name, "load64") {
    emit_call_args(node, Token::I32);
    append_byte(WASM, 0x29);  // i64.load
    append_byte(WASM, 0x00);  // alignment
    append_byte(WASM, 0x00);  // offset
  } else if str_eq(name, "loadf32") {
    emit_call_args(node, Token::I32);
    append_byte(WASM, 0x2a);  // f32.load
    append_byte(WASM, 0x00);  // alignment
    append_byte(WASM, 0x00);  // offset
  } else if str_eq(name, "loadf64") {
    emit_call_args(node, Token::I32);
    append_byte(WASM, 0x2b);  // f64.load
    append_byte(WASM, 0x00);  // alignment
    append_byte(WASM, 0x00);  // offset
  } else if str_eq(name, "load8") {
    emit_call_args(node, Token::I32);
    append_byte(WASM, 0x2c);  // i32.load8_s
    append_byte(WASM, 0x00);  // alignment
    append_byte(WASM, 0x00);  // offset
  } else if str_eq(name, "load8u") {
    emit_call_args(node, Token::I32);
    append_byte(WASM, 0x2d);  // i32.load8_u
    append_byte(WASM, 0x00);  // alignment
    append_byte(WASM, 0x00);  // offset
  } else if str_eq(name, "load16") {
    emit_call_args(node, Token::I32);
    append_byte(WASM, 0x2e);  // i32.load16_s
    append_byte(WASM, 0x00);  // alignment
    append_byte(WASM, 0x00);  // offset
  } else if str_eq(name, "load16u") {
    emit_call_args(node, Token::I32);
    append_byte(WASM, 0x2f);  // i32.load16_u
    append_byte(WASM, 0x00);  // alignment
    append_byte(WASM, 0x00);  // offset
  } else if str_eq(name, "loa8i64") {
    emit_call_args(node, Token::I32);
    append_byte(WASM, 0x30);  // i64.load8_s
    append_byte(WASM, 0x00);  // alignment
    append_byte(WASM, 0x00);  // offset
  } else if str_eq(name, "loa8u64") {
    emit_call_args(node, Token::I32);
    append_byte(WASM, 0x31);  // i64.load8_u
    append_byte(WASM, 0x00);  // alignment
    append_byte(WASM, 0x00);  // offset
  } else if str_eq(name, "loa16i64") {
    emit_call_args(node, Token::I32);
    append_byte(WASM, 0x32);  // i64.load16_s
    append_byte(WASM, 0x00);  // alignment
    append_byte(WASM, 0x00);  // offset    
  } else if str_eq(name, "loa16u64") {
    emit_call_args(node, Token::I32);
    append_byte(WASM, 0x33);  // i64.load16_u
    append_byte(WASM, 0x00);  // alignment
    append_byte(WASM, 0x00);  // offset 
  } else if str_eq(name, "loa32i64") {
    emit_call_args(node, Token::I32);
    append_byte(WASM, 0x34);  // i64.load32_s
    append_byte(WASM, 0x00);  // alignment
    append_byte(WASM, 0x00);  // offset    
  } else if str_eq(name, "loa32u64") {
    emit_call_args(node, Token::I32);
    append_byte(WASM, 0x35);  // i64.load32_u
    append_byte(WASM, 0x00);  // alignment
    append_byte(WASM, 0x00);  // offset    
  } else if str_eq(name, "store32") {
    emit_call_args(node, Token::I32);
    append_byte(WASM, 0x36);  // i32.store
    append_byte(WASM, 0x00);  // alignment
    append_byte(WASM, 0x00);  // offset
  } else if str_eq(name, "store64") {
    emit_call_args2(node, Token::I32, Token::I64);
    append_byte(WASM, 0x37);  // i64.store
    append_byte(WASM, 0x00);  // alignment
    append_byte(WASM, 0x00);  // offset
  } else if str_eq(name, "storeF32") {
    emit_call_args2(node, Token::I32, Token::F32);
    append_byte(WASM, 0x38);  // f32.store
    append_byte(WASM, 0x00);  // alignment
    append_byte(WASM, 0x00);  // offset
  } else if str_eq(name, "storeF64") {
    emit_call_args2(node, Token::I32, Token::F64);
    append_byte(WASM, 0x39);  // f64.store
    append_byte(WASM, 0x00);  // alignment
    append_byte(WASM, 0x00);  // offset
  } else if str_eq(name, "store8") {
    emit_call_args(node, Token::I32);
    append_byte(WASM, 0x3a);  // i32.store8
    append_byte(WASM, 0x00);  // alignment
    append_byte(WASM, 0x00);  // offset
  } else if str_eq(name, "store16") {
    emit_call_args(node, Token::I32);
    append_byte(WASM, 0x3b);  // i32.store16
    append_byte(WASM, 0x00);  // alignment
    append_byte(WASM, 0x00);  // offset
  } else if str_eq(name, "i64sto8") {
    emit_call_args2(node, Token::I32, Token::I64);
    append_byte(WASM, 0x3c);  // i64.store8
    append_byte(WASM, 0x00);  // alignment
    append_byte(WASM, 0x00);  // offset
  } else if str_eq(name, "i64sto16") {
    emit_call_args2(node, Token::I32, Token::I64);
    append_byte(WASM, 0x3d);  // i64.store16
    append_byte(WASM, 0x00);  // alignment
    append_byte(WASM, 0x00);  // offset
  } else if str_eq(name, "i64sto32") {
    emit_call_args2(node, Token::I32, Token::I64);
    append_byte(WASM, 0x3e);  // i64.store32
    append_byte(WASM, 0x00);  // alignment
    append_byte(WASM, 0x00);  // offset
  } else if str_eq(name, "memsize") {
    append_byte(WASM, 0x3f);  // current_memory
    append_byte(WASM, 0x00);  // memory number
  } else if str_eq(name, "memgrow") {
    emit_call_args(node, Token::I32);
    append_byte(WASM, 0x40);  // grow_memory
    append_byte(WASM, 0x00);  // memory number
  } else {
    let resolved_node: i32 = scope_resolve(CURRENT_SCOPE, name, node.node_Token);
    if resolved_node {
      emit_fn_call_args(node, resolved_node);
      append_byte(WASM, 0x10);  // Call
      append_uleb(WASM, resolved_node.node_index);
    }
  }
}

fn emit_block(node: i32) {
  let scope: i32 = node.node_Scope;
  CURRENT_SCOPE = scope;
  let BlockList: i32 = node.node_Nodes;
  let mut item: i32 = BlockList.list_First;
  while item {
    emit_node(item.item_Object);
    item = item.item_Next;
  }
  CURRENT_SCOPE = scope.scope_Parent;
}

fn emit_if(node: i32) {
  emit_expression(node.node_CNode);  // If condition Expression
  append_byte(WASM, 0x04);  // if
  append_byte(WASM, 0x40);  // void
  emit_node(node.node_ANode);  // Then Block
  let ElseBlock: i32 = node.node_BNode;
  if ElseBlock {
    append_byte(WASM, 0x05);  // else
    emit_node(ElseBlock);
  }
  append_byte(WASM, 0x0b);  // end
}

fn scope_level(node: i32, kind: i32) -> i32 {
  let mut scope: i32 = node.node_Scope;
  let mut level: i32 = 0;
  while scope {
    if scope.scope_Node.node_kind == kind { break; }
    level += 1;
    scope = scope.scope_Parent;
  }
  level
}

fn emit_loop(node: i32) {
  append_byte(WASM, 0x02);  // Block
  append_byte(WASM, 0x40);  // void 
  append_byte(WASM, 0x03);  // loop
  append_byte(WASM, 0x40);  // void 
  let WhileNode: i32 = node.node_CNode;
  if WhileNode {
    emit_expression(WhileNode);
    let mut data_type: i32 = WhileNode.node_dataType;
    if !data_type {
      data_type = infer_data_type(WhileNode);
      if !data_type {
        add_error(Error::TypeNotInferred, WhileNode.node_Token);
      }
      WhileNode.node_dataType = data_type;
    }
    emit_operator(Token::Not, data_type, WhileNode);
    append_byte(WASM, 0x0d);  // br_if
    append_uleb(WASM, scope_level(node, Node::Loop) + 1);
  }
  emit_node(node.node_ANode);
  append_byte(WASM, 0x0c);  // br
  append_byte(WASM, 0x00);  // level 
  append_byte(WASM, 0x0b);  // end
  append_byte(WASM, 0x0b);  // end
}

fn infer_call_data_type(node: i32) -> i32 {
  let name: i32 = node.node_String;
  if str_eq(name, "load64") { return Token::I64;
  } else if str_eq(name, "load32") { return Token::I32;
  } else if str_eq(name, "load8") { return Token::I32;
  } else if str_eq(name, "load8u") { return Token::I32;
  } else if str_eq(name, "memsize") { return Token::I32;
  } else if str_eq(name, "loa_f32") { return Token::F32;
  } else if str_eq(name, "loa_f64") { return Token::F64;
  } else if str_eq(name, "f32_i32") { return Token::I32;
  } else if str_eq(name, "f32_i32u") { return Token::I32;
  } else if str_eq(name, "f64_i32") { return Token::I32;
  } else if str_eq(name, "f64_i32u") { return Token::I32;
  } else if str_eq(name, "i32_i64") { return Token::I64;
  } else if str_eq(name, "i32_i64u") { return Token::I64;
  } else if str_eq(name, "f32_i64") { return Token::I64;
  } else if str_eq(name, "f32_i64u") { return Token::I64;
  } else if str_eq(name, "f64_i64") { return Token::I64;
  } else if str_eq(name, "f64_i64u") { return Token::I64;
  } else if str_eq(name, "i32_f32") { return Token::F32;
  } else if str_eq(name, "i32_f32u") { return Token::F32;
  } else if str_eq(name, "i64_f32") { return Token::F32;
  } else if str_eq(name, "i64_f32u") { return Token::F32;
  } else if str_eq(name, "f64_f32") { return Token::F32;
  } else if str_eq(name, "i32_f64") { return Token::F64;
  } else if str_eq(name, "i32_f64u") { return Token::F64;
  } else if str_eq(name, "i64_f64") { return Token::F64;
  } else if str_eq(name, "i64_f64u") { return Token::F64;
  } else if str_eq(name, "f32_f64") { return Token::F64;
  } else {
    let resolved_node: i32 = scope_resolve(CURRENT_SCOPE, name, node.node_Token);
    return resolved_node.node_dataType;
  }
  0
}

fn infer_data_type(node: i32) -> i32 {
  let mut data_type: i32 = node.node_dataType;
  let kind: i32 = node.node_kind;
  if kind == Node::Binary | kind == Node::Iif | kind == Node::Assign {
    data_type = infer_data_type(node.node_ANode);
    if !data_type {
      data_type = infer_data_type(node.node_BNode);
    }
  } else if kind == Node::Identifier {
    let resolved_node: i32 = scope_resolve(CURRENT_SCOPE, node.node_String, node.node_Token);
    data_type = resolved_node.node_dataType;
  } else if kind == Node::Unary {
    data_type = infer_data_type(node.node_BNode);
  } else if kind == Node::Call {
    data_type = infer_call_data_type(node.node_ANode);
  }
  data_type
}

fn emit_iif(node: i32) {
  let mut data_type: i32  = node.node_dataType;
  let ANode: i32  = node.node_ANode;
  let BNode: i32  = node.node_BNode;
  let CNode: i32  = node.node_CNode;
  if !data_type {
    data_type = infer_data_type(node);
    if !data_type {
      add_error(Error::TypeNotInferred, node.node_Token);
    }
    node.node_dataType = data_type;
  }
  ANode.node_dataType = data_type;
  BNode.node_dataType = data_type;
  emit_expression(ANode);
  emit_expression(BNode);
  emit_expression(CNode);
  append_byte(WASM, 0x1b);  // select
}

fn emit_variable(node: i32) {
  let token_type: i32  = node.node_type;
  let BNode: i32  = node.node_BNode;
  BNode.node_dataType = token_type;
  emit_expression(BNode);
  append_byte(WASM, 0x21);  // set_local
  append_uleb(WASM, node.node_index);
}

fn emit_return(node: i32) {
  let ANode: i32  = node.node_ANode;
  let data_type: i32  = CURRENT_FN_NODE.node_dataType;
  if data_type {
    node.node_dataType = data_type;
    ANode.node_dataType = data_type;
    emit_expression(ANode);
  }
  if scope_level(node, Node::Fun) > 0 {
    append_byte(WASM, 0x0f);  // return
  }
}

fn emit_breakif(node: i32) {
  emit_expression(node.node_CNode);  // If condition Expression
  append_byte(WASM, 0x0d);  // br_if
  append_uleb(WASM, scope_level(node, Node::Loop) + 1);
}

fn emit_drop(node: i32) {
  emit_expression(node.node_CNode);
  append_byte(WASM, 0x1a);  // drop
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// ERRORS

static mut ERROR_LIST: i32 = 0;

fn add_error(errorNo: i32, token: i32) {
  list_add_name(ERROR_LIST, token, errorNo);
}

fn parse_error_list() {
  let mut ErrorItem: i32 = ERROR_LIST.list_First;
  if ErrorItem {
    let error_message: i32 = new_empty_string(1_000);
    while ErrorItem {
      let token: i32 = ErrorItem.item_Object;
      let errorNo: i32 = ErrorItem.item_number;
      if errorNo == Error::DuplicateName {
        append_str(error_message, "Duplicate identifier");
      } else if errorNo == Error::InvalidToken {
        append_str(error_message, "Invalid token");
      } else if errorNo == Error::MissingToken {
        append_str(error_message, "Missing token");
      } else if errorNo == Error::RootStatement {
        append_str(error_message, "Invalid root statement");
      } else if errorNo == Error::BlockStatement {
        append_str(error_message, "Invalid block statement");
      } else if errorNo == Error::TypeMismatchA {
        append_str(error_message, "Type mismatch A");
      } else if errorNo == Error::TypeMismatchB {
        append_str(error_message, "Type mismatch B");
      } else if errorNo == Error::NotDeclared {
        append_str(error_message, "Identifier Not declared");
      } else if errorNo == Error::LiteralToInt {
        append_str(error_message, "Could not convert to int");
      } else if errorNo == Error::Expression {
        append_str(error_message, "Expression expected");
      } else if errorNo == Error::TypeNotInferred {
        append_str(error_message, "Could not determine token_type");
      } else if errorNo == Error::NotMutable {
        append_str(error_message, "Not mutable");
      } else if errorNo == Error::NoParamList {
        append_str(error_message, "No param list");  
      } else if errorNo == Error::ParseAssignOp {
        append_str(error_message, "Parsing failed assignop");  
      } else if errorNo == Error::EmitNode {
        append_str(error_message, "Unexpected node token_type");
      } else if errorNo == Error::InvalidOperator {
        append_str(error_message, "Invalid operator");
      } else {  
        append_str(error_message, "Error ");
        append_i32_as_str(error_message, errorNo);
      }
      if token {
        append_str(error_message, " line ");
        append_i32_as_str(error_message, token.token_line);
        append_str(error_message, " column ");
        if token.token_Value.i32 {
          append_i32_as_str(error_message, token.token_column - token.token_Value.string_length);
          append_str(error_message, " token ");
          append_str(error_message, token.token_Value);
        } else {
          append_i32_as_str(error_message, token.token_column);
        }
        append_byte(error_message, 13);
      }
      WASM = error_message;
      ErrorItem = ErrorItem.item_Next;
    }
  }
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// Function library

fn str_to_i32(string: i32, token: i32) -> i32 {
  return i64_i32(str_to_i64(string, token));
}

fn str_to_i64(string: i32, token: i32) -> i64 {  // Supports ints & 0x-prefixed hex
  let mut is_hex: bool = false;
  let mut i: i64 = 0;
  let length: i32 = string.string_length;
  let mut offset: i32 = 0;
  let mut chr: i32 = 0;
  if length >= 3 {
    if get_chr(string, 0) == '0' & get_chr(string, 1) == 'x' {
      is_hex = true;
    }
  }
  if is_hex {
    offset = 2;
    while offset < length {
      chr = get_chr(string, offset);
      if chr != '_' {
        i = i * 16;
        if chr >= '0' & chr <= '9' {
          i += i32_i64(chr) - '0';
        } else if chr >= 'a' & chr <= 'f' {
          i += i32_i64(chr) - 'a' + 10;
        } else if chr >= 'A' & chr <= 'F' {
          i += i32_i64(chr) - 'A' + 10;
        } else {
          add_error(Error::LiteralToInt, token);
        }
      }
      offset += 1;
    }
  } else {
    while offset < length {
      chr = get_chr(string, offset);
      if chr != '_' {
        i = i * 10;
        if chr >= '0' & chr <= '9' {
          i += i32_i64(chr) - '0';
        } else if offset == 0 & chr == '-' {
        } else {
          add_error(Error::LiteralToInt, token);
        }
      }
      offset += 1;
    }
  }
  if get_chr(string, 0) == '-' { 
    i = -i;
  }
  i
}

fn str_to_f32(string: i32) -> f32 {
  return f64_f32(str_to_f64(string));
}

fn str_to_f64(string: i32) -> f64 {
  let mut f: f64 = f;
  let length: i32 = string.string_length;
  let mut offset: i32 = 0;
  let mut d: f64 = 1;
  let mut isAfterDot: bool = false;
  while offset < length {
    let chr: i32 = get_chr(string, offset);
    if chr == '.' {
      isAfterDot = true;
    } else {
      if isAfterDot { 
        f += i32_f64(chr - '0') / d;
        d = d * 10;
      } else {
        if chr >= '0' & chr <= '9' {
          f = f * 10 + i32_f64(chr - '0');
        }
      }
    }
    offset += 1;
  }
  if get_chr(string, 0) == '-' { 
    f = -f; 
  }
  f
}

fn uleb_length(i: i32) -> i32 {
  if i >+ 268_435_456 {
    return 5;
  } else if i >+ 2_097_151 { 
    return 4; 
  } else if i >+ 16_383 {
    return 3;
  } else if i >+ 127 {
    return 2;
  }
  1
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// Strings

// Structs
const string_bytes:    i32 = 0;
const string_length:   i32 = 4;
const string_capacity: i32 = 8;
const string_size:     i32 = 12;

// Pascal-style strings: We store the length instead of using a null terminator
fn new_string(length: i32) -> i32 {
  let debug: i32 = allocate(4);
  debug.debug_magic = 7 - DEC0DE;
  let string: i32 = allocate(string_size);
  string.string_capacity = length;
  string.string_length = length;
  string.string_bytes = allocate(length);
  string
}

fn new_empty_string(max_length: i32) -> i32 {
  let debug: i32 = allocate(4);
  debug.debug_magic = 7 - DEC0DE;
  let string: i32 = allocate(string_size);
  string.string_capacity = max_length;
  string.string_length = 0;
  string.string_bytes = allocate(max_length);
  string
}

fn append_str(string: i32, append: i32) {
  let append_length: i32 = append.string_length;
  let max_length: i32 = string.string_capacity;
  let mut offset: i32 = 0;
  while offset < append_length {
    append_byte(string, get_chr(append, offset));
    if string.string_length >= max_length { break; }
    offset += 1;
  }
}

fn append_i32_as_str(string: i32, i: i32) {
  let length: i32 = string.string_length;
  let append_length: i32 = decimal_str_length(i);
  let mut offset: i32 = append_length;
  if length + append_length <= string.string_capacity {
    while offset {
      let chr: i32 = '0' + i % 10;
      offset = offset - 1;
      set_chr(string, length + offset, chr);
      i = i / 10;
      if !i { break; }
    }  
    string.string_length = length + append_length;
  }
}

fn i32_to_str(i: i32) -> i32 {
  let S: i32 = new_empty_string(12);
  append_i32_as_str(S, i);
  S
}

fn append_i32(string: i32, i: i32) {
  let length: i32 = string.string_length;
  if length + 4 <= string.string_capacity {
    string.string_bytes.length = i;
    string.string_length = length + 4;
  }
}

fn append_f32(string: i32, f: f32) {
  let length: i32 = string.string_length;
  if length + 4 <= string.string_capacity {
    string.string_bytes.length = f;
    string.string_length = length + 4;
  }
}

fn append_f64(string: i32, f: f64) {
  let length: i32 = string.string_length;
  if length + 8 <= string.string_capacity {
    string.string_bytes.length = f;
    string.string_length = length + 8;
  }
}

fn append_byte(string: i32, i: i32) {
  let length: i32 = string.string_length;
  if length + 1 <= string.string_capacity {
    store8(string.string_bytes + length, i);
    string.string_length = length + 1;
  }
}

fn append_uleb(string: i32, i: i32) {
  let length: i32 = string.string_length;
  if length + uleb_length(i) <= string.string_capacity {
    while i >=+ 128 {
      let chr: i32 = 128 + (i % 128);
      append_byte(string, chr);
      i = i >>+ 7;
    }
    append_byte(string, i);
  }
}

fn append_sleb32(string: i32, i: i32) {
  append_sleb64(string, i32_i64(i));
}

fn append_sleb64(string: i32, mut i: i64) {
  if i >= 0 { 
    loop {
      if i < 64 { break; }
      append_byte(string, i64_i32(128 + (i % 128)));
      i = i >> 7;
    }
    append_byte(string, i64_i32(i));
  } else {
    loop {
      if i >= -64 { break; }
      append_byte(string, i64_i32((i %+ 128) - 128));
      i = i >> 7;
    }
    append_byte(string, i64_i32(i - 128));
  }
}

fn offset_tail(string: i32, start: i32, offset: i32) {
  if offset > 0 {
    if string.string_length + offset <= string.string_capacity {
      string.string_length = string.string_length + offset;
      let mut copy: i32 = string.string_length;
      while copy >= start {
        set_chr(string, copy + offset, get_chr(string, copy));
        copy = copy - 1;
      }
    }
  }
}

fn decimal_str_length(i: i32) -> i32 {
  let mut length: i32 = 1;
  loop {
    i = i / 10;
    if !i { break; }
    length += 1;
  }
  length
}

fn get_chr(string: i32, offset: i32) -> i32 {
  return load8u(string.string_bytes + offset);
}

fn set_chr(string: i32, offset: i32, chr: i32) {
  store8(string.string_bytes + offset, chr);
}

fn sub_str(string: i32, offset: i32, mut length: i32) -> i32 {
  if offset >= string.string_length {
    length = 0;
  }
  if offset + length >= string.string_length {
    length = string.string_length - offset;
  }
  let result: i32 = new_string(length);
  while length > 0 {
    length = length - 1;
    if offset + length >= 0 {
      set_chr(result, length, get_chr(string, offset + length));
    }
  }
  result
}

fn str_eq(A: i32, B: i32) -> bool {
  let length: i32 = A.string_length;
  if length == B.string_length {
    let mut offset: i32 = 0;
    while offset < length {
      if get_chr(A, offset) != get_chr(B, offset) {
        return false;
      }
      offset += 1;
    }
  } else {
    return false;
  }
  true
}

fn hex_chr_to_i32(chr: i32) -> i32 {
  if chr >= '0' & chr <= '9' {
    return chr - '0';
  } else if chr >= 'a' & chr <= 'f' {
    return chr - 'a' + 10;
  } else if chr >= 'A' & chr <= 'F' {
    return chr - 'A' + 10;
  }
  0
}

// Strings may contain escaped hex bytes for example "\5a" -> "Z"
fn decode_str(S: i32) {
  let length: i32 = S.string_length;
  let mut i: i32 = 0;
  let mut o: i32 = 0;
  while i < length {
    if get_chr(S, i) == 92 {  // \
      i += 1;
      if is_number(get_chr(S, i), true) & is_number(get_chr(S, i + 1), true) {
        let mut chr: i32 = hex_chr_to_i32(get_chr(S, i));
        chr *= 16;
        chr += hex_chr_to_i32(get_chr(S, i + 1));
        set_chr(S, o, chr);
        i += 1;
      }
    } else if i > o {
      set_chr(S, o, get_chr(S, i));
    }
    i += 1;
    o += 1;
  }
  S.string_length = o;
  while o < length {
    set_chr(S, o, 0);
    o += 1;
  }
}

fn is_alpha(chr: i32) -> bool {
  (chr >= 'a' & chr <= 'z') | (chr >= 'A' & chr <= 'Z') | (chr == '_')
}

fn is_number(chr: i32, hexNum: bool) -> bool {
  if chr >= '0' & chr <= '9' {
    return true;
  } else if hexNum {
    if (chr >= 'a' & chr <= 'f') | (chr >= 'A' & chr <= 'F') { 
      return true;
    }
  }
  false
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// Lists

// Structs
const list_dec0de: i32 = 0;  // debugging marker
const list_First:  i32 = 4;
const list_Last:   i32 = 8;
const list_count:  i32 = 12;
const list_size:   i32 = 16;

const item_dec0de: i32 = 0;  // debugging marker
const item_Next:   i32 = 4;
const item_Object: i32 = 8;
const item_Name:   i32 = 12;   const item_number: i32 = 12;
const item_size:   i32 = 16;

fn new_list() -> i32 {
  let list: i32 = allocate(list_size);
  list.list_dec0de = 4 - DEC0DE;
  list
}

fn list_add(list: i32, Object: i32) {
  let item: i32 = allocate(item_size);
  item.item_dec0de = 5 - DEC0DE;
  item.item_Object = Object;
  if !list.list_First.i32 {
    list.list_First = item;
  } else {
    list.list_Last.item_Next = item;
  }
  list.list_Last = item;
  list.list_count.i32 = list.list_count + 1;
}

fn list_add_name(list: i32, Object: i32, name: i32) {
  let item: i32 = allocate(item_size);
  item.item_dec0de = 5 - DEC0DE;
  item.item_Object = Object;
  item.item_Name = name;
  if !list.list_First.i32 {
    list.list_First = item;
  } else {
    list.list_Last.item_Next = item;
  }
  list.list_Last = item;
  list.list_count.i32 = list.list_count + 1;
}

// Find a string in a list & return the object
fn list_search(list: i32, FindName: i32) -> i32 {
  let mut item: i32 = list.list_First;
  while item {
    if str_eq(item.item_Name, FindName) {
      return item.item_Object;
    }
    item = item.item_Next;
  }
  0
}

// Find a string in a list & return the index
fn index_list_search(list: i32, FindName: i32) -> i32 {
  let mut item: i32 = list.list_First;
  let mut index: i32 = 0;
  while item {
    if str_eq(item.item_Name, FindName) {
      return index;
    }
    item = item.item_Next;
    index += 1;
  }
  -1
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// Memory management

// debugging struct
const debug_magic: i32 = 0;

// Magic number -0x00dec0de - used for debugging
const DEC0DE: i32 = 557785600;

const ALIGNMENT: i32 = 4;

// Next free memory location
static mut HEAP: i32 = 0;

fn allocate(length: i32) -> i32 {
  let R: i32 = HEAP;
  HEAP += length;
  if HEAP % ALIGNMENT {
    HEAP += ALIGNMENT - HEAP % ALIGNMENT;
  }
  R
}

// Pierre Rossouw 2017  https://github.com/PierreRossouw/rswasm
