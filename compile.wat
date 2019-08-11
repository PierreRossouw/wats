;; Self-hosted WebAssembly compiler in a sugared WAT format. github.com/PierreRossouw/wats 2019-08-11

;; Compiler settings
global $PLS_emit_name_section i32 = 0     ;; The name section is optional debugging symbols
global $PLS_memory_pages i32 = 50     ;; Memory size in 64kB pages 

export func $main() i32 {
    local $wats i32 = $read_input_str()
    local mut $root_node i32 = 0
    $ERROR_LIST = $new_list()
    $lexx($wats)
    if !i32.$ERROR_LIST[$list_count] { 
        $root_node = $parse()
    }
    if !i32.$ERROR_LIST[$list_count] {
        $emit($wats, $root_node)
    }
    if i32.$ERROR_LIST[$list_count] { 
        $parse_error_list()
    }
    i32.$WASM[$string_capacity] = $WASM[$string_length]
    $WASM + $string_capacity     ;; Return the memory location of the string
}

func $read_input_str() i32 {     ;; The source code is in the memory as a null-terminated string
    local mut $l i32 = 0
    loop {
        br_if !i32.load8_u($l)
        $l += 1
    }
    drop $allocate($l)     ;; Fix the heap pointer to include the source string
    local mut $wats i32 = $new_string(0)     ;; Create a String struct
    $wats[$string_bytes] = 0     ;; Pointer to the string bytes
    $wats[$string_capacity] = $l
    $wats[$string_length] = $l
    $wats
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Lexer 

func $lexx($wats i32) {
    $TOKEN_LIST = $new_list()
    local mut $str_index i32 = -1
    local mut $line i32 = 1
    local mut $column i32 = 0
    local $length i32 = $wats[$string_length]
    local mut $start i32 = 0
    local mut $value_str i32 = 0
    local mut $prev_chr i32 = 0
    loop {
        br_if $str_index >= $length
        $str_index += 1
        $column += 1
        local mut $chr i32 = $get_chr($wats, $str_index)

        ;; newline
        if $chr == 10 {
            $line += 1
            $column = 0

        ;; keyword
        } else if $chr >= 'a' & $chr <= 'z' {
            $start = $str_index
            loop {
                br_if $str_index >= $length 
                if !$is_keywordchar($chr) {
                    $str_index -= 1
                    $column -= 1
                    br
                }
                $str_index += 1
                $column += 1
                $chr = $get_chr($wats, $str_index)
            }
            $value_str = $sub_str($wats, $start, $str_index - $start + 1)
            $add_keyword_token($value_str, $line, $column)

        ;; Identifier
        } else if $chr == '$' {
            $str_index += 1
            $column += 1
            $chr = $get_chr($wats, $str_index)
            $start = $str_index
            loop {
                br_if $str_index >= $length 
                if !$is_idchar($chr) {
                    $str_index -= 1
                    $column -= 1
                    br
                }
                $str_index += 1
                $column += 1
                $chr = $get_chr($wats, $str_index)
            }
            $value_str = $sub_str($wats, $start, $str_index - $start + 1)
            $add_token($TokenType_Id, $value_str, $line, $column)
        
        ;; Single quoted chars (byte)
        } else if $chr == 39 {
            $str_index += 1
            $column += 1
            $chr = $get_chr($wats, $str_index)
            $start = $str_index
            loop {
                br_if $str_index >= $length 
                br_if $chr == 39
                $str_index += 1
                $column += 1
                $chr = $get_chr($wats, $str_index)
            }
            $value_str = $sub_str($wats, $start, $str_index - $start)
            $decode_str($value_str)
            $add_token($TokenType_CharLiteral, $value_str, $line, $column)

        ;; Double quoted strings
        } else if $chr == '"' {
            $str_index += 1
            $column += 1
            $chr = $get_chr($wats, $str_index)
            $start = $str_index
            loop {
                br_if $str_index >= $length 
                br_if $chr == '"'
                $str_index += 1
                $column += 1
                $chr = $get_chr($wats, $str_index)
            }
            $value_str = $sub_str($wats, $start, $str_index - $start)
            $decode_str($value_str)
            $add_token($TokenType_StrLiteral, $value_str, $line, $column)

        ;; Number literals, for example -42, 3.14, 0x8d4f0
        ;; May contain underscores e.g. 1_234 is the same as 1234
        } else if $is_number($chr, 0) | ($chr == '-' & $is_number($get_chr($wats, $str_index + 1), 0)) {
            $start = $str_index
            local mut $is_hex i32 = 0
            loop {
                br_if $str_index >= $length 
                if !$is_number($chr, $is_hex) & $chr != '-' & $chr != '_' {
                    if $start + 1 == $str_index & $chr == 'x' {
                        $is_hex = 1
                    } else {
                        $str_index -= 1
                        $column -= 1
                        br
                    }
                }
                $str_index += 1
                $column += 1
                $chr = $get_chr($wats, $str_index)
            }
            if $chr == '.' & !$is_hex {
                $str_index += 2
                $column += 2
                $chr = $get_chr($wats, $str_index)
                loop {
                    br_if $str_index >= $length 
                    if !$is_number($chr, $is_hex) & $chr != '_' {
                        $str_index -= 1
                        $column -= 1
                        br
                    }
                    $str_index += 1
                    $column += 1
                    $chr = $get_chr($wats, $str_index)
                }
            }
            $value_str = $sub_str($wats, $start, $str_index - $start + 1)
            $add_token($TokenType_NumLiteral, $value_str, $line, $column)

        ;; Comments
        } else if $chr == ';' & $get_chr($wats, $str_index + 1) == ';' {
            loop {
                br_if $str_index >= $length 
                if $chr == 10 | $chr == 13 {    ;; LF | CR
                    $column = 0
                    $line += 1
                    br
                }
                $str_index += 1
                $column += 1
                $chr = $get_chr($wats, $str_index)
            }
        } else if $chr == '(' & $get_chr($wats, $str_index + 1) == ';' {
            $str_index += 1
            $column += 1
            loop {
                $str_index += 1
                $column += 1
                $prev_chr = $chr
                $chr = $get_chr($wats, $str_index)
                br_if $str_index >= $length 
                br_if $prev_chr == ';' & $chr == ')' 
                if $chr == 10 | $chr == 13 {    ;; LF | CR
                    $column = 0
                    $line += 1
                }
            }
        
        ;; Commas and brackets
        } else if $is_single_chr($chr) {
            $value_str = $sub_str($wats, $str_index, 1)
            $add_single_chr_token($value_str, $line, $column)

        ;; Mathematical operators
        } else if $is_operator_chr($chr) {
            if $is_operator_chr($get_chr($wats, $str_index + 1)) {
                if $is_operator_chr($get_chr($wats, $str_index + 2)) {
                    $value_str = $sub_str($wats, $str_index, 3)
                    $str_index += 2
                    $column += 2
                } else {
                    $value_str = $sub_str($wats, $str_index, 2)
                    $str_index += 1
                    $column += 1
                }
            } else {
                $value_str = $sub_str($wats, $str_index, 1)
            }
            $add_operator_token($value_str, $line, $column)

        }
    }
}

func $add_keyword_token($s i32, $line i32, $column i32) {
    local mut $kind i32 = $TokenType_Builtin
    if $str_eq($s, "i32") { $kind = $TokenType_I32
    } else if $str_eq($s, "i64") { $kind = $TokenType_I64
    } else if $str_eq($s, "f32") { $kind = $TokenType_F32
    } else if $str_eq($s, "f64") { $kind = $TokenType_F64
    } else if $str_eq($s, "br") { $kind = $TokenType_Br
    } else if $str_eq($s, "br_table") { $kind = $TokenType_Br_Table
    } else if $str_eq($s, "call_indirect") { $kind = $TokenType_Call_Indirect
    } else if $str_eq($s, "continue") { $kind = $TokenType_Continue
    } else if $str_eq($s, "else") { $kind = $TokenType_Else
    } else if $str_eq($s, "func") { $kind = $TokenType_Func
    } else if $str_eq($s, "if") { $kind = $TokenType_If 
    } else if $str_eq($s, "br_if") { $kind = $TokenType_Br_If
    } else if $str_eq($s, "local") { $kind = $TokenType_Local
    } else if $str_eq($s, "loop") { $kind = $TokenType_Loop
    } else if $str_eq($s, "drop") { $kind = $TokenType_Drop
    } else if $str_eq($s, "select") { $kind = $TokenType_Select
    } else if $str_eq($s, "mut") { $kind = $TokenType_Mut
    } else if $str_eq($s, "export") { $kind = $TokenType_Export
    } else if $str_eq($s, "return") { $kind = $TokenType_Return
    } else if $str_eq($s, "global") { $kind = $TokenType_Global
    } else if $str_eq($s, "abs") { $kind = $TokenType_Abs
    } else if $str_eq($s, "unreachable") { $kind = $TokenType_Unreachable
    } else if $str_eq($s, "nop") { $kind = $TokenType_Nop }
    $add_token($kind, $s, $line, $column)
}

func $add_operator_token($s i32, $line i32, $column i32) {
    local mut $kind i32 = 0
    if $str_eq($s, "!") { $kind = $TokenType_Eqz
    } else if $str_eq($s, "==") { $kind = $TokenType_Eq
    } else if $str_eq($s, "!=") { $kind = $TokenType_Ne
    } else if $str_eq($s, "<") { $kind = $TokenType_Lt
    } else if $str_eq($s, "<+") { $kind = $TokenType_Ltu
    } else if $str_eq($s, ">") { $kind = $TokenType_Gt
    } else if $str_eq($s, ">+") { $kind = $TokenType_Gtu
    } else if $str_eq($s, "<=") { $kind = $TokenType_Lte
    } else if $str_eq($s, "<=+") { $kind = $TokenType_Leu 
    } else if $str_eq($s, ">=") { $kind = $TokenType_Gte 
    } else if $str_eq($s, ">=+") { $kind = $TokenType_Geu
    } else if $str_eq($s, "+") { $kind = $TokenType_Add
    } else if $str_eq($s, "-") { $kind = $TokenType_Sub
    } else if $str_eq($s, "*") { $kind = $TokenType_Mul 
    } else if $str_eq($s, "/") { $kind = $TokenType_Div 
    } else if $str_eq($s, "/+") { $kind = $TokenType_Divu 
    } else if $str_eq($s, "%") { $kind = $TokenType_Rem
    } else if $str_eq($s, "%+") { $kind = $TokenType_Remu
    } else if $str_eq($s, "&") { $kind = $TokenType_And 
    } else if $str_eq($s, "|") { $kind = $TokenType_Or 
    } else if $str_eq($s, "^") { $kind = $TokenType_Xor
    } else if $str_eq($s, "<<") { $kind = $TokenType_Shl 
    } else if $str_eq($s, ">>") { $kind = $TokenType_Shr
    } else if $str_eq($s, ">>+") { $kind = $TokenType_Shru
    } else if $str_eq($s, "=") { $kind = $TokenType_Set
    } else if $str_eq($s, "+=") { $kind = $TokenType_Add_Set
    } else if $str_eq($s, "-=") { $kind = $TokenType_Sub_Set
    } else if $str_eq($s, "*=") { $kind = $TokenType_Mul_Set
    } else if $str_eq($s, "/=") { $kind = $TokenType_Div_Set }
    $add_token($kind, $s, $line, $column)
}

func $add_single_chr_token($s i32, $line i32, $column i32) {
    local mut $kind i32 = 0
    if $str_eq($s, ",") { $kind = $TokenType_Comma 
    } else if $str_eq($s, ".") { $kind = $TokenType_Dot 
    } else if $str_eq($s, "(") { $kind = $TokenType_LParen    
    } else if $str_eq($s, ")") { $kind = $TokenType_RParen 
    } else if $str_eq($s, "{") { $kind = $TokenType_LBrace 
    } else if $str_eq($s, "}") { $kind = $TokenType_RBrace 
    } else if $str_eq($s, "[") { $kind = $TokenType_LBrack
    } else if $str_eq($s, "]") { $kind = $TokenType_RBrack }
    $add_token($kind, $s, $line, $column)
}

func $is_operator_chr($chr i32) i32 {
    $chr == '=' | $chr == '+' | $chr == '-' | $chr == '*' | $chr == '/' | $chr == '%' 
        | $chr == '<' | $chr == '>' | $chr == '!' | $chr == '&' | $chr == '|' | $chr == '^'
}

func $is_single_chr($chr i32) i32 {    ;; ,.(){}[]
    $chr == ',' | $chr == '.' | $chr == '(' | $chr == ')' | $chr == '{' | $chr == '}' | $chr == '[' | $chr == ']'
}

func $is_idchar($chr i32) i32 {    ;; Symbolic identifiers that stand in lieu of indices start with ‘$’
    ($chr >= '0' & $chr <= '9') 
    | ($chr >= 'a' & $chr <= 'z') 
    | ($chr >= 'A' & $chr <= 'Z') 
    | $chr == '!' | $chr == '#' | $chr == '$' | $chr == '%' | $chr == '&' | $chr == 39
    | $chr == '*' | $chr == '+' | $chr == '-' | $chr == '.' | $chr == '/' 
    | $chr == ':' | $chr == '<' | $chr == '=' | $chr == '>' | $chr == '?' | $chr == '@' 
    | $chr == '\' | $chr == '^' | $chr == '_' | $chr == '`' | $chr == '|' | $chr == '~'
}

func $is_keywordchar($chr i32) i32 {
    ($chr >= '0' & $chr <= '9') | ($chr >= 'a' & $chr <= 'z') | ($chr >= 'A' & $chr <= 'Z') | $chr == '_' 
}

func $add_token($kind i32, $text i32, $line i32, $column i32) {
    local mut $token i32 = $allocate($token_size)
    $token[$token_dec0de] = 6 - $DEC0DE
    $token[$token_kind] = $kind
    $token[$token_Value] = $text
    $token[$token_line] = $line
    $token[$token_column] = $column
    $list_add($TOKEN_LIST, $token)
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Scoper

func $push_scope($node i32) {
    local $scope i32 = $allocate($scope_size)
    $scope[$scope_dec0de] = 3 - $DEC0DE
    $scope[$scope_Symbols] = $new_list()
    $scope[$scope_Node] = $node
    if $CURRENT_SCOPE {
        i32.$scope[$scope_index] = $CURRENT_SCOPE[$scope_index] + 1
        $scope[$scope_Parent] = $CURRENT_SCOPE
    }
    $node[$node_Scope] = $scope
    $CURRENT_SCOPE = $scope
}

func $pop_scope() {
    $CURRENT_SCOPE = $CURRENT_SCOPE[$scope_Parent]
}

func $get_fn_scope($scope i32) i32 {
    local mut $fn_scope i32 = $scope
    loop {
        br_if !$fn_scope 
        br_if i32.$fn_scope[$scope_Node][$node_kind] == $Node_Fun
        br_if i32.$fn_scope[$scope_Node][$node_kind] == $Node_Module
        $fn_scope = $fn_scope[$scope_Parent]
    }
    $fn_scope
}

func $scope_register_name($scope i32, $name i32, $node i32, $token i32) {
    if $list_search($scope[$scope_Symbols], $name) {
        $add_error($Error_DuplicateName, $token)
    }
    local $kind i32 = $node[$node_kind]
    $list_add_name($scope[$scope_Symbols], $node, $name)
    if $kind == $Node_Variable | $kind == $Node_Parameter {
        local $fn_scope i32 = $get_fn_scope($scope)
        local $index i32 = $fn_scope[$scope_localIndex]
        $node[$node_Scope] = $fn_scope
        $node[$node_index] = $index
        $fn_scope[$scope_localIndex] = $index + 1
    }
}

func $scope_resolve($scope i32, $name i32, $token i32) i32 {
    local mut $node i32 = 0
    local mut $recurse_scope i32 = $scope
    loop {
        br_if !$recurse_scope 
        $node = $list_search($recurse_scope[$scope_Symbols], $name)
        br_if $node
        $recurse_scope = $recurse_scope[$scope_Parent]
    }
    if !$node {
        $add_error($Error_NotDeclared, $token)
    }
    $node
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Parser 

func $parse() i32 {
    local $root_node i32 = $new_node($Node_Module)
    $EXPORT_LIST = $new_list()
    $DATA_LIST = $new_list()
    $CURRENT_TOKEN_ITEM = $TOKEN_LIST[$list_First]
    $CURRENT_TOKEN = $CURRENT_TOKEN_ITEM[$item_Object]
    $push_scope($root_node)
    $GLOBAL_SCOPE = $CURRENT_SCOPE
    local $BodyList i32 = $new_list()
    $root_node[$node_Nodes] = $BodyList
    loop {
        br_if !$CURRENT_TOKEN 
        local $Child i32 = $parse_root_statement()
        br_if !$Child
        $list_add($BodyList, $Child)
    }
    $root_node
}

func $parse_root_statement() i32 {
    local mut $node i32 = 0
    local $kind i32 = $CURRENT_TOKEN[$token_kind]
    if $kind == $TokenType_Func {
        $node = $parse_func()
    } else if $kind == $TokenType_Global {
        $node = $parse_global()
        $GLOBAL_COUNT += 1
    } else if $kind == $TokenType_Export {
        $node = $parse_func()
    } else {
        $add_error($Error_RootStatement, $CURRENT_TOKEN)
    }
    $node
}

func $parse_func() i32 {
    local mut $exported i32 = 0
    if i32.$CURRENT_TOKEN[$token_kind] == $TokenType_Export {
        $exported = 1
        $eat_token($TokenType_Export)
    }
    $eat_token($TokenType_Func)
    local mut $token_type i32 = 0    
    local $name i32 = $CURRENT_TOKEN[$token_Value]
    local $node i32 = $new_node($Node_Fun)
    $scope_register_name($CURRENT_SCOPE, $name, $node, $CURRENT_TOKEN)
    $next_token()
    local $Locals i32 = $new_list()
    $node[$node_index] = $FN_INDEX
    $FN_INDEX += 1
    $node[$node_String] = $name
    $node[$node_Nodes] = $Locals
    local $param_list i32 = $parse_func_params()
    $node[$node_ParamNodes] = $param_list
    if i32.$CURRENT_TOKEN[$token_kind] != $TokenType_LBrace {
        $token_type = $CURRENT_TOKEN[$token_kind]
        $next_token()
    }
    $node[$node_type] = $token_type
    $node[$node_dataType] = $token_type
    $push_scope($node)
    local mut $param_item i32 = $param_list[$list_First]
    loop {
        br_if !$param_item 
        local $param_name i32 = $param_item[$item_Name]
        local $param_node i32 = $param_item[$item_Object]
        $scope_register_name($CURRENT_SCOPE, $param_name, $param_node, $param_node[$node_Token])
        $param_item = $param_item[$item_Next]
    }
    if $exported {
        $list_add_name($EXPORT_LIST, $node, $name)
    }
    $eat_token($TokenType_LBrace)
    $node[$node_ANode] = $parse_func_block()
    $pop_scope()
    $eat_token($TokenType_RBrace)
    $node
}

func $parse_func_block() i32 {
    local $node i32 = $new_node($Node_Block)
    local $BodyList i32 = $new_list()
    $node[$node_Nodes] = $BodyList
    $node[$node_Scope] = $CURRENT_SCOPE
    loop {
        br_if !$CURRENT_TOKEN 
        br_if i32.$CURRENT_TOKEN[$token_kind] == $TokenType_RBrace
        local $ChildNode i32 = $parse_statement()
        br_if !$ChildNode
        $list_add($BodyList, $ChildNode)
    }
    $node
}

func $parse_statement() i32 {
    local mut $node i32 = 0
    local $kind i32 = $CURRENT_TOKEN[$token_kind]
    local $next_kind i32 = $NEXT_TOKEN[$token_kind]
    if $kind ==    $TokenType_Local {
        $node = $parse_declaration()
    } else if $kind == $TokenType_If {
        $node = $parse_if_statement()
    } else if $kind == $TokenType_Loop {
        $node = $parse_loop_statement()
    } else if $kind == $TokenType_Continue {
        $node = $parse_continue()
    } else if $kind == $TokenType_Br_If {
        $node = $parse_br_if()
    } else if $kind == $TokenType_Br {
        $node = $parse_br()
    } else if $kind == $TokenType_Return {
        $node = $parse_return_statement()
    } else if $kind == $TokenType_Drop {
        $node = $parse_drop_statement()
    } else if $kind == $TokenType_Nop | $kind == $TokenType_Unreachable {
        $node = $parse_instruction($kind)
    } else if $kind == $TokenType_Builtin {
        $node = $parse_builtin_statement()
    } else if $kind == $TokenType_Id {
        if $next_kind == $TokenType_LParen {
            $node = $parse_call_statement()
        } else if $next_kind == $TokenType_LBrack {
            $node = $parse_bracket_store()
        } else if $next_kind == $TokenType_Set {
            $node = $parse_assign_statement()
        } else if $is_assign_op($NEXT_TOKEN) {
            $node = $parse_assign_op_statement()
        } else {
            $node = $parse_return_expression()
        }
    } else if $is_native_type($CURRENT_TOKEN) {
        $next_token()
        $eat_token($TokenType_Dot)
        $node = $parse_statement()
        $node[$node_dataType] = $kind
        $node[$node_ANode][$node_dataType] = $kind
    } else {
        $node = $parse_return_expression()
    }
    $node
}

func $parse_drop_statement() i32 {
    local $node i32 = $new_node($Node_Drop)
    $eat_token($TokenType_Drop)
    $node[$node_ANode] = $parse_expression($TokenType_MinPrecedence)
    $node
}

func $parse_instruction($token_type i32) i32 {
    local $node i32 = $new_node($Node_Instruction)
    $node[$node_type] = $token_type
    $next_token()
    $node
}

func $parse_expression($level i32) i32 {
    local mut $node i32 = $parse_prefix()
    loop {
        br_if !$CURRENT_TOKEN 
        local $Expr i32 = $parse_infix($level, $node)
        br_if $Expr == 0 | $Expr == $node
        $node = $Expr
    }
    $node
}

func $parse_prefix() i32 {
    local mut $node i32 = 0
    local $kind i32 = $CURRENT_TOKEN[$token_kind]
    if $is_literal($CURRENT_TOKEN) {
        $node = $parse_literal()
    } else if $kind == $TokenType_Id {
        local mut $nextKind i32 = 0
        if $NEXT_TOKEN {
             $nextKind = $NEXT_TOKEN[$token_kind]
        }    
        if $nextKind == $TokenType_LBrack {
            $node = $parse_bracket_load()
        } else {
            $node = $parse_identifier()
        }
    } else if $kind == $TokenType_Builtin {
        $node = $parse_builtin_statement() 
    } else if $is_native_type($CURRENT_TOKEN) {
        $next_token()
        $eat_token($TokenType_Dot)
        $node = $parse_expression($TokenType_MinPrecedence)
        $node[$node_dataType] = $kind
        $node[$node_ANode][$node_dataType] = $kind
    } else if $kind == $TokenType_LParen {
        $next_token()
        $node = $parse_expression($TokenType_MinPrecedence)
        $eat_token($TokenType_RParen)
    } else if $is_unary_op($CURRENT_TOKEN) {
        $node = $parse_unary_expression()
    }
    $node
}

func $parse_literal() i32 {
    local $node i32 = $new_node($Node_Literal)
    i32.$node[$node_String] = $CURRENT_TOKEN[$token_Value]
    i32.$node[$node_type] = $CURRENT_TOKEN[$token_kind]
    $next_token()
    $node
}

func $new_node($kind i32) i32 {
    local $node i32 = $allocate($node_size)
    $node[$node_dec0de] = 2 - $DEC0DE
    $node[$node_Scope] = $CURRENT_SCOPE
    $node[$node_Token] = $CURRENT_TOKEN
    $node[$node_kind] = $kind
    $node
}

func $next_token() {
    if $CURRENT_TOKEN_ITEM {
        $CURRENT_TOKEN_ITEM = $CURRENT_TOKEN_ITEM[$item_Next]
    }
    $NEXT_TOKEN = 0
    if $CURRENT_TOKEN_ITEM {
        $CURRENT_TOKEN = $CURRENT_TOKEN_ITEM[$item_Object]
        local $next_token_item i32 = $CURRENT_TOKEN_ITEM[$item_Next]
        if $next_token_item {
            $NEXT_TOKEN = $next_token_item[$item_Object]
        }
    } else {
        $CURRENT_TOKEN = 0
    }
}

func $is_binary_op($token i32) i32 {
    local $kind i32 = $token[$token_kind]
    $kind == $TokenType_Add | $kind == $TokenType_Sub | $kind == $TokenType_Mul 
        | $kind == $TokenType_Div | $kind == $TokenType_Divu | $kind == $TokenType_Rem | $kind == $TokenType_Remu 
        | $kind == $TokenType_Or | $kind == $TokenType_And | $kind == $TokenType_Xor 
        | $kind == $TokenType_Eq | $kind == $TokenType_Ne 
        | $kind == $TokenType_Lt | $kind == $TokenType_Ltu | $kind == $TokenType_Lte | $kind == $TokenType_Leu
        | $kind == $TokenType_Gt | $kind == $TokenType_Gtu | $kind == $TokenType_Gte | $kind == $TokenType_Geu
        | $kind == $TokenType_Shl | $kind == $TokenType_Shr | $kind == $TokenType_Shru 
        | $kind == $TokenType_Rotl | $kind == $TokenType_Rotr
}

func $is_assign_op($token i32) i32 {
    local $kind i32 = $token[$token_kind]
    $kind == $TokenType_Add_Set | $kind == $TokenType_Div_Set | $kind == $TokenType_Mul_Set | $kind == $TokenType_Sub_Set
}

func $is_unary_op($token i32) i32 {
    local $kind i32 = $token[$token_kind]
    $kind == $TokenType_Sub | $kind == $TokenType_Eqz | $kind == $TokenType_Popcnt | $kind == $TokenType_Clz 
        | $kind == $TokenType_Ctz | $kind == $TokenType_Abs | $kind == $TokenType_Neg | $kind == $TokenType_Ceil
        | $kind == $TokenType_Floor | $kind == $TokenType_Trunc | $kind == $TokenType_Round | $kind == $TokenType_Sqrt 
}

func $is_literal($token i32) i32 {
    local $kind i32 = $token[$token_kind]
    $kind == $TokenType_NumLiteral | $kind == $TokenType_CharLiteral | $kind == $TokenType_StrLiteral
}

func $is_native_type($token i32) i32 {
    local $k i32 = $token[$token_kind]
    $k == $TokenType_I32 | $k == $TokenType_I64 | $k == $TokenType_F32 | $k == $TokenType_F64
}

func $eat_token($kind i32) {
    if $CURRENT_TOKEN {
        if $CURRENT_TOKEN[$token_kind] != $kind {
            $add_error($Error_InvalidToken, $CURRENT_TOKEN)
            $add_error($kind, $CURRENT_TOKEN)
        }
        $next_token()
    } else {
        local $LastToken i32 = $TOKEN_LIST[$list_Last][$item_Object]
        $add_error($Error_MissingToken, $LastToken)
    }
}

func $try_eat_token($kind i32) i32 {
    if $CURRENT_TOKEN {
        if $CURRENT_TOKEN[$token_kind] == $kind {
            $next_token()
            return 1
        }
    } 
    0
}

func $parse_func_params() i32 {
    local $params i32 = $new_list()
    $eat_token($TokenType_LParen)
    loop {
        br_if i32.$CURRENT_TOKEN[$token_kind] == $TokenType_RParen 
        local $mutable i32 = $try_eat_token($TokenType_Mut)
        local $name i32 = $CURRENT_TOKEN[$token_Value]
        $next_token()
        local $token_type i32 = $CURRENT_TOKEN[$token_kind]
        $next_token()
        local $FunParamNode i32 = $new_node($Node_Parameter)
        $FunParamNode[$node_type] = $token_type
        $FunParamNode[$node_dataType] = $token_type
        $FunParamNode[$node_String] = $name
        if $mutable {
            $FunParamNode[$node_assigns] = -1
        } else {
            $FunParamNode[$node_assigns] = 1
        }
        $list_add_name($params, $FunParamNode, $name)
        br_if i32.$CURRENT_TOKEN[$token_kind] != $TokenType_Comma
        $eat_token($TokenType_Comma)
    }
    $eat_token($TokenType_RParen)
    $params
}

func $parse_br() i32 {
    local $node i32 = $new_node($Node_Br)
    $eat_token($TokenType_Br)
    $node
}

func $parse_br_if() i32 {
    local $node i32 = $new_node($Node_Br_If)
    $eat_token($TokenType_Br_If)
    $node[$node_CNode] = $parse_expression($TokenType_MinPrecedence)
    $node
}

func $parse_continue() i32 {
    local $node i32 = $new_node($Node_Continue)
    $eat_token($TokenType_Continue)
    $node
}

func $parse_identifier() i32 {
    local $node i32 = $new_node($Node_Identifier)
    i32.$node[$node_String] = $CURRENT_TOKEN[$token_Value]
    i32.$node[$node_type] = $CURRENT_TOKEN[$token_kind]
    $next_token()
    $node
}

func $copy_node($node i32) i32 {
    local $copy i32 = $new_node($node[$node_kind])
    i32.$copy[$node_String] = $node[$node_String]
    i32.$copy[$node_ANode] = $node[$node_ANode]
    i32.$copy[$node_BNode] = $node[$node_BNode]
    i32.$copy[$node_CNode] = $node[$node_CNode]
    i32.$copy[$node_Nodes] = $node[$node_Nodes]
    i32.$copy[$node_ParamNodes] = $node[$node_ParamNodes]
    i32.$copy[$node_type] = $node[$node_type]
    i32.$copy[$node_Token] = $node[$node_Token]
    $copy
}

func $parse_call_params() i32 {
    local $param_list i32 = $new_list()
    $eat_token($TokenType_LParen)
    loop {
        br_if !$CURRENT_TOKEN 
        br_if i32.$CURRENT_TOKEN[$token_kind] == $TokenType_RParen
        $list_add($param_list, $parse_expression($TokenType_MinPrecedence))
        br_if i32.$CURRENT_TOKEN[$token_kind] != $TokenType_Comma
        $eat_token($TokenType_Comma)
    }
    $eat_token($TokenType_RParen)
    $param_list
}

func $parse_unary_expression() i32 {
    local $node i32 = $new_node($Node_Unary)
    i32.$node[$node_type] = $CURRENT_TOKEN[$token_kind]
    i32.$node[$node_String] = $CURRENT_TOKEN[$token_Value]
    $next_token()
    $node[$node_BNode] = $parse_expression($TokenType_Add)
    $node
}

func $parse_bracket_load() i32 {
    local $node i32 = $new_node($Node_DotLoad)
    local $BodyList i32 = $new_list()
    $node[$node_Nodes] = $BodyList
    $list_add($BodyList, $parse_identifier())
    loop {
        br_if !$CURRENT_TOKEN 
        br_if i32.$CURRENT_TOKEN[$token_kind] != $TokenType_LBrack
        $eat_token($TokenType_LBrack)
        $list_add($BodyList, $parse_identifier())
        $eat_token($TokenType_RBrack)
    }
    $node
}

func $parse_bracket_store() i32 {
    local $node i32 = $new_node($Node_DotStore)
    local $BodyList i32 = $new_list()
    local mut $data_type i32 = 0
    $node[$node_Nodes] = $BodyList
    $list_add($BodyList, $parse_identifier())
    loop {
        br_if !$CURRENT_TOKEN 
        br_if i32.$CURRENT_TOKEN[$token_kind] != $TokenType_LBrack
        $eat_token($TokenType_LBrack)
        $list_add($BodyList, $parse_identifier())
        $eat_token($TokenType_RBrack)
    }
    $eat_token($TokenType_Set)
    $node[$node_ANode] = $parse_expression($TokenType_MinPrecedence)
    $node[$node_ANode][$node_dataType] = $data_type
    $node
}

func $parse_binary_expression($level i32, $Left i32) i32 {
    local mut $node i32 = 0
    local $precedence i32 = $CURRENT_TOKEN[$token_kind]    ;; node_kind doubles as the precedence
    if $level > $precedence {
        $node = $Left
    } else {
        $node = $new_node($Node_Binary)
        i32.$node[$node_type] = $CURRENT_TOKEN[$token_kind]
        i32.$node[$node_String] = $CURRENT_TOKEN[$token_Value]
        $node[$node_ANode] = $Left
        $next_token()
        $node[$node_BNode] = $parse_expression($precedence)
    }
    $node
}

func $parse_assign_statement() i32 {
    local $node i32 = $new_node($Node_Assign)
    $node[$node_ANode] = $parse_identifier()
    $node[$node_type] = $TokenType_Set
    i32.$node[$node_String] = $CURRENT_TOKEN[$token_Value]
    $eat_token($TokenType_Set)
    $node[$node_BNode] = $parse_expression($TokenType_MinPrecedence)
    $node
}

func $parse_assign_op_statement() i32 {
    local $node i32 = $new_node($Node_Assign)
    $node[$node_ANode] = $parse_identifier()
    $node[$node_type] = $TokenType_Set
    i32.$node[$node_String] = $CURRENT_TOKEN[$token_Value]
    local $copy i32 = $copy_node($node[$node_ANode])
    local $b_node i32 = $new_node($Node_Binary)
    i32.$b_node[$node_String] = $CURRENT_TOKEN[$token_Value]
    $b_node[$node_ANode] = $copy
    local mut $b_type i32 = 0
    if $try_eat_token($TokenType_Add_Set) { $b_type = $TokenType_Add
    } else if $try_eat_token($TokenType_Div_Set) { $b_type = $TokenType_Div
    } else if $try_eat_token($TokenType_Mul_Set) { $b_type = $TokenType_Mul
    } else if $try_eat_token($TokenType_Sub_Set) { $b_type = $TokenType_Sub 
    } else {
        $add_error($Error_ParseAssignOp, $CURRENT_TOKEN)
        $next_token()
    }
    i32.$b_node[$node_type] = $b_type
    $b_node[$node_BNode] = $parse_expression($TokenType_MinPrecedence)
    $node[$node_BNode] = $b_node
    $node
}

func $parse_infix($level i32, $Left i32) i32 {
    local mut $node i32 = 0
    if $is_binary_op($CURRENT_TOKEN) {
        $node = $parse_binary_expression($level, $Left)
    } else if i32.$CURRENT_TOKEN[$token_kind] == $TokenType_LParen {
        $node = $parse_call_expression($Left)
        i32.$node[$node_Token] = $Left[$node_Token]
    } else {
        $node = $Left
    }
    $node
}

func $parse_call_statement() i32 {
    local $IdentifierNode i32 = $parse_identifier()
    local mut $node i32 = $parse_call_expression($IdentifierNode)
    if $is_binary_op($CURRENT_TOKEN) {
        local $rnode i32 = $new_node($Node_Expression)
        local $Expression i32 = $parse_binary_expression($TokenType_MinPrecedence, $node)
        $rnode[$node_ANode] = $Expression
        $node = $rnode
    }
    $node
}

func $parse_call_expression($Callee i32) i32 {
    local $node i32 = $new_node($Node_Call)
    $node[$node_ANode] = $Callee
    $node[$node_ParamNodes] = $parse_call_params()
    $node
}

func $parse_builtin_statement() i32 {
    local $node i32 = $new_node($Node_Builtin)
    $node[$node_ANode] = $parse_identifier()
    $node[$node_ParamNodes] = $parse_call_params()
    $node
}

func $parse_return_statement() i32 {
    local $node i32 = $new_node($Node_Return)
    $eat_token($TokenType_Return)
    $node[$node_ANode] = $parse_expression($TokenType_MinPrecedence)
    $node
}

func $parse_return_expression() i32 {
    local $node i32 = $new_node($Node_Expression)
    local $Expression i32 = $parse_expression($TokenType_MinPrecedence)
    $node[$node_ANode] = $Expression
    if !$Expression {
        $add_error($Error_BlockStatement, $CURRENT_TOKEN)
        $next_token()
    }
    $node
}

func $parse_if_block() i32 {
    $eat_token($TokenType_LBrace)
    local $node i32 = $new_node($Node_Block)
    local $BodyList i32 = $new_list()
    $node[$node_Nodes] = $BodyList
    $node[$node_Scope] = $CURRENT_SCOPE
    loop {
        br_if !$CURRENT_TOKEN 
        br_if i32.$CURRENT_TOKEN[$token_kind] == $TokenType_RBrace
        local $ChildNode i32 = $parse_statement()
        br_if !$ChildNode
        $list_add($BodyList, $ChildNode)
    }
    $eat_token($TokenType_RBrace)
    $node
}

func $parse_if_statement() i32 {
    local $node i32 = $new_node($Node_If)
    $eat_token($TokenType_If)
    $node[$node_CNode] = $parse_expression($TokenType_MinPrecedence)
    $push_scope($node)
    $node[$node_ANode] = $parse_if_block()
    $pop_scope()
    if i32.$CURRENT_TOKEN[$token_kind] == $TokenType_Else {
        $eat_token($TokenType_Else)
        $push_scope($node)
        if i32.$CURRENT_TOKEN[$token_kind] == $TokenType_If {
            $node[$node_BNode] = $parse_if_statement()
        } else {
            $node[$node_BNode] = $parse_if_block()
        }
        $pop_scope()
    }
    $node
}

func $parse_loop_block() i32 {
    local $node i32 = $new_node($Node_Block)
    local $BodyList i32 = $new_list()
    $node[$node_Nodes] = $BodyList
    $node[$node_Scope] = $CURRENT_SCOPE
    loop {
        br_if !$CURRENT_TOKEN 
        br_if i32.$CURRENT_TOKEN[$token_kind] == $TokenType_RBrace
        local $ChildNode i32 = $parse_statement()
        br_if !$ChildNode
        $list_add($BodyList, $ChildNode)
    }
    $node
}

func $parse_loop_statement() i32 {
    local $node i32 = $new_node($Node_Loop)
    $eat_token($TokenType_Loop)
    $eat_token($TokenType_LBrace)
    $push_scope($node)
    $node[$node_ANode] = $parse_loop_block()
    $pop_scope()
    $eat_token($TokenType_RBrace)
    $node
}

func $parse_global() i32 {
    $eat_token($TokenType_Global)
    local $mutable i32 = $try_eat_token($TokenType_Mut)
    local $name i32 = $CURRENT_TOKEN[$token_Value]
    local $NameToken i32 = $CURRENT_TOKEN
    $next_token()
    local $token_type i32 = $CURRENT_TOKEN[$token_kind]
    $next_token()
    local $node i32 = $new_node($Node_Variable)
    $node[$node_type] = $token_type
    $node[$node_dataType] = $token_type
    $node[$node_String] = $name
    if $mutable {
        $node[$node_assigns] = -1
    } else {
        $node[$node_assigns] = 1
    }
    $scope_register_name($CURRENT_SCOPE, $name, $node, $NameToken)
    $eat_token($TokenType_Set)
    $node[$node_BNode] = $parse_expression($TokenType_MinPrecedence)
    if i32.$CURRENT_SCOPE[$scope_Parent] {
        local $fn_scope i32 = $get_fn_scope($CURRENT_SCOPE)
        local $FunNode i32 = $fn_scope[$scope_Node]
        local mut $FunLocalsList i32 = $FunNode[$node_Nodes]
        if !$FunLocalsList {
            $FunLocalsList = $new_list()
            $FunNode[$node_Nodes] = $FunLocalsList
        }
        $list_add($FunLocalsList, $node)
    }
    $node
}

func $parse_declaration() i32 {
    $eat_token($TokenType_Local)
    local $mutable i32 = $try_eat_token($TokenType_Mut)
    local $name i32 = $CURRENT_TOKEN[$token_Value]
    local $NameToken i32 = $CURRENT_TOKEN
    $next_token()
    local $token_type i32 = $CURRENT_TOKEN[$token_kind]
    $next_token()
    local $node i32 = $new_node($Node_Variable)
    $node[$node_type] = $token_type
    $node[$node_dataType] = $token_type
    $node[$node_String] = $name
    if $mutable {
        $node[$node_assigns] = -1    ;; mutables have infinite assigns
    } else {
        $node[$node_assigns] = 0    ;; non-mutables can only be assigned once
    }
    $scope_register_name($CURRENT_SCOPE, $name, $node, $NameToken)
    $eat_token($TokenType_Set)
    $node[$node_BNode] = $parse_expression($TokenType_MinPrecedence)
    if i32.$CURRENT_SCOPE[$scope_Parent] {
        local $fn_scope i32 = $get_fn_scope($CURRENT_SCOPE)
        local $FunNode i32 = $fn_scope[$scope_Node]
        local mut $FunLocalsList i32 = $FunNode[$node_Nodes]
        if !$FunLocalsList {
            $FunLocalsList = $new_list()
            $FunNode[$node_Nodes] = $FunLocalsList
        }
        $list_add($FunLocalsList, $node)
    }
    $node
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Compiler 

func $emit($wats i32, $root_node i32) {
    $WASM = $new_empty_string($wats[$string_length] + 256)    ;; Guess
    $CURRENT_SCOPE = $root_node[$node_Scope]
    $TYPE_LIST = $new_list()
    $FN_TYPE_LIST = $new_list()
    $emit_preamble()
    $emit_type_section($root_node)
    $emit_function_section()
    $emit_memory_section()
    $emit_global_section($root_node)
    $emit_export_section($root_node)
    $emit_code_section($root_node)
    $emit_data_section()
    if $PLS_emit_name_section {
        $emit_name_section($root_node)
    }
}

func $emit_name_section($root_node i32) {
    local $BodyList i32 = $root_node[$node_Nodes]
    if $BodyList {
        $append_byte($WASM, 0x00)    ;; Custom section
        $append_byte($WASM, 0x00)    ;; Section size (guess)
        local $start i32 = $WASM[$string_length]
        $append_uleb($WASM, 4)    
        $append_str($WASM, "name")    ;; Section name
        $emit_funcnamesubsec($root_node)
        $emit_localnamesubsec($root_node)
        $emit_globalnamesubsec($root_node)
        local $length i32 = $WASM[$string_length] - $start
        local $offset i32 = $uleb_length($length) - 1
        $offset_tail($WASM, $start, $offset)
        $WASM[$string_length] = $start - 1
        $append_uleb($WASM, $length)
        $WASM[$string_length] = $WASM[$string_length] + $length
    }
}

func $emit_globalnamesubsec($root_node i32) {
    $append_byte($WASM, 0x07)    ;; Id: 7, Subjection: global names
    $append_byte($WASM, 0x00)    ;; Section size (guess)
    local $start i32 = $WASM[$string_length]
    $append_uleb($WASM, $GLOBAL_COUNT)
    local mut $count i32 = 0
    local mut $GlobalItem i32 = $root_node[$node_Nodes][$list_First]
    loop {
        br_if !$GlobalItem 
        local $GlobalNode i32 = $GlobalItem[$item_Object]
        if i32.$GlobalNode[$node_kind] == $Node_Variable {
            $append_uleb($WASM, $count)
            $append_uleb($WASM, $GlobalNode[$node_String][$string_length])    
            $append_str($WASM, $GlobalNode[$node_String])
            $count += 1
        }
        $GlobalItem = $GlobalItem[$item_Next]
    }
    local $length i32 = $WASM[$string_length] - $start
    local $offset i32 = $uleb_length($length) - 1
    $offset_tail($WASM, $start, $offset)
    $WASM[$string_length] = $start - 1
    $append_uleb($WASM, $length)
    $WASM[$string_length] = $WASM[$string_length] + $length
}

func $emit_localnamesubsec($root_node i32) {
    $append_byte($WASM, 0x02)    ;; Id: 2, Subjection: local names
    $append_byte($WASM, 0x00)    ;; Section size (guess)
    local $start i32 = $WASM[$string_length]
    $append_uleb($WASM, $FN_TYPE_LIST[$list_count])    ;; function count
    local mut $count i32 = 0
    local mut $FunItem i32 = $root_node[$node_Nodes][$list_First]
    loop {
        br_if !$FunItem 
        local $FunNode i32 = $FunItem[$item_Object]
        if i32.$FunNode[$node_kind] == $Node_Fun {
            $append_uleb($WASM, $count)
            $emit_localnames($FunNode)
            $count += 1
        }
        $FunItem = $FunItem[$item_Next]
    }
    local $length i32 = $WASM[$string_length] - $start
    local $offset i32 = $uleb_length($length) - 1
    $offset_tail($WASM, $start, $offset)
    $WASM[$string_length] = $start - 1
    $append_uleb($WASM, $length)
    $WASM[$string_length] = $WASM[$string_length] + $length
}

func $emit_localnames($node i32) {
    $append_byte($WASM, 0x00)    ;; Local declaration count (guess)
    local $start i32 = $WASM[$string_length]
    local mut $declCount i32 = 0
    local mut $LocalItem i32 = $node[$node_ParamNodes][$list_First]
    loop {
        br_if !$LocalItem 
        $append_uleb($WASM, $declCount)    ;; count
        $append_uleb($WASM, $LocalItem[$item_Object][$node_String][$string_length])
        $append_str($WASM, $LocalItem[$item_Object][$node_String])
        $LocalItem = $LocalItem[$item_Next]
        $declCount += 1
    }
    $LocalItem = $node[$node_Nodes][$list_First]
    loop {
        br_if !$LocalItem 
        $append_uleb($WASM, $declCount)    ;; count
        $append_uleb($WASM, $LocalItem[$item_Object][$node_String][$string_length])
        $append_str($WASM, $LocalItem[$item_Object][$node_String])
        $LocalItem = $LocalItem[$item_Next]
        $declCount += 1
    }
    local $length i32 = $WASM[$string_length] - $start
    local $offset i32 = $uleb_length($declCount) - 1
    $offset_tail($WASM, $start, $offset)
    $WASM[$string_length] = $start - 1
    $append_uleb($WASM, $declCount)
    $WASM[$string_length] = $WASM[$string_length] + $length
}

func $emit_funcnamesubsec($root_node i32) {
    $append_byte($WASM, 0x01)    ;; Id: 1, Subjection: function names
    $append_byte($WASM, 0x00)    ;; Section size (guess)
    local $start i32 = $WASM[$string_length]
    $append_uleb($WASM, $FN_TYPE_LIST[$list_count])    ;; function count
    local mut $count i32 = 0
    local mut $FunItem i32 = $root_node[$node_Nodes][$list_First]
    loop {
        br_if !$FunItem 
        local $FunNode i32 = $FunItem[$item_Object]
        if i32.$FunNode[$node_kind] == $Node_Fun {
            $append_uleb($WASM, $count)
            $append_uleb($WASM, $FunNode[$node_String][$string_length])    
            $append_str($WASM, $FunNode[$node_String])
            $count += 1
        }
        $FunItem = $FunItem[$item_Next]
    }
    local $length i32 = $WASM[$string_length] - $start
    local $offset i32 = $uleb_length($length) - 1
    $offset_tail($WASM, $start, $offset)
    $WASM[$string_length] = $start - 1
    $append_uleb($WASM, $length)
    $WASM[$string_length] = $WASM[$string_length] + $length
}

func $emit_preamble() {
    $append_str($WASM, "\00asm")    ;; WASM magic 00 61 73 6d
    $append_i32($WASM, 1)                 ;; WASM version
}

func $emit_type_section($root_node i32) {
    local $BodyList i32 = $root_node[$node_Nodes]
    local $skip i32 = $WASM[$string_length]
    if $BodyList {
        $append_byte($WASM, 0x01)    ;; Type section
        $append_byte($WASM, 0x00)    ;; section size (guess)
        local $Start i32 = $WASM[$string_length]
        $append_byte($WASM, 0x00)    ;; types count (guess)    
        local mut $index i32 = 0
        local mut $item i32 = $BodyList[$list_First]
        loop {
            br_if !$item 
            local $node i32 = $item[$item_Object]
            if i32.$node[$node_kind] == $Node_Fun {
                $emit_type($node, $index)
                $index += 1
            }
            $item = $item[$item_Next]
        }
        local $count i32 = $TYPE_LIST[$list_count]
        local $length i32 = $WASM[$string_length] - $Start
        local $offset i32 = $uleb_length($count) - 1 + $uleb_length($length) - 1
        $offset_tail($WASM, $Start, $offset)
        $WASM[$string_length] = $Start - 1
        $append_uleb($WASM, $length + $uleb_length($count) - 1)
        $append_uleb($WASM, $count)
        $WASM[$string_length] = $WASM[$string_length] + $length - 1
    }
    if i32.$FN_TYPE_LIST[$list_count] == 0 { 
        $WASM[$string_length] = $skip
    }
}

func $append_data_type($string i32, $data_type i32) {
    if $data_type == $TokenType_F64 {
        $append_byte($string, 0x7c)
    } else if $data_type == $TokenType_F32 {
        $append_byte($string, 0x7d)
    } else if $data_type == $TokenType_I64 {
        $append_byte($string, 0x7e)
    } else {
        $append_byte($string, 0x7f)
    }
}

func $emit_type($node i32, $funcNo i32) {
    local $param_list i32 = $node[$node_ParamNodes]
    local $params i32 = $param_list[$list_count]
    local mut $returns i32 = 0
    if i32.$node[$node_type] { 
        $returns = 1
    }
    local $TypeString i32 = $new_empty_string(
        1 + $uleb_length($params) + $params + $uleb_length($returns) + $returns
    )
    $append_byte($TypeString, 0x60)    ;; func token_type
    $append_uleb($TypeString, $params)
    local mut $param_item i32 = $param_list[$list_First]
    loop {
        br_if !$param_item 
        local $data_type i32 = $param_item[$item_Object][$node_type]
        $append_data_type($TypeString, $data_type)
        $param_item = $param_item[$item_Next]
    }
    local $returnType i32 = $node[$node_type]
    if $returnType {
        $append_uleb($TypeString, 0x01)    ;; return count
        $append_data_type($TypeString, $returnType)
    } else {
        $append_uleb($TypeString, 0x00)    ;; return count
    }
    local mut $typeIndex i32 = $index_list_search($TYPE_LIST, $TypeString)
    if $typeIndex == -1 {
        $typeIndex = $TYPE_LIST[$list_count]
        $list_add_name($TYPE_LIST, 0, $TypeString)
        $append_str($WASM, $TypeString)
    }
    $list_add($FN_TYPE_LIST, $typeIndex)
}

func $emit_function_section() {
    local $funCount i32 = $FN_TYPE_LIST[$list_count]
    if $funCount {
        $append_byte($WASM, 0x03)    ;; Function section
        $append_byte($WASM, 0x00)    ;; section size (guess)
        local $start i32 = $WASM[$string_length]
        $append_uleb($WASM, $funCount)    ;; types count
        local mut $FunType i32 = $FN_TYPE_LIST[$list_First]
        loop {
            br_if !$FunType 
            $append_uleb($WASM, $FunType[$item_Object])
            $FunType = $FunType[$item_Next]
        }
        local $length i32 = $WASM[$string_length] - $start
        local $offset i32 = $uleb_length($length) - 1
        $offset_tail($WASM, $start, $offset)
        $WASM[$string_length] = $start - 1
        $append_uleb($WASM, $length)
        $WASM[$string_length] = $WASM[$string_length] + $length
    }
}

func $emit_memory_section() {
    $append_byte($WASM, 0x05)     ;; Memory section
    $append_uleb($WASM, 2 + $uleb_length($PLS_memory_pages))   ;; Size in bytes
    $append_byte($WASM, 0x01)     ;; Count
    $append_byte($WASM, 0x00)     ;; Resizable
    $append_uleb($WASM, $PLS_memory_pages)    ;; Pages
}

func $emit_global_section($root_node i32) {
    local $skip i32 = $WASM[$string_length]
    local mut $count i32 = 0 
    if i32.$root_node[$node_Nodes] {
        $append_byte($WASM, 0x06)    ;; Section code
        $append_byte($WASM, 0x00)    ;; Section size (guess)
        local $start i32 = $WASM[$string_length]
        $append_byte($WASM, 0x00)    ;; Globals $count (guess)
        local mut $item i32 = $root_node[$node_Nodes][$list_First]
        loop {
            br_if !$item 
            if i32.$item[$item_Object][$node_kind] == $Node_Variable {
                $emit_native_global($item[$item_Object])
                $count += 1
            }
            $item = $item[$item_Next]
        }
        local $length i32 = $WASM[$string_length] - $start
        local $offset i32 = $uleb_length($count) - 1 + $uleb_length($length) - 1
        $offset_tail($WASM, $start, $offset)
        $WASM[$string_length] = $start - 1
        $append_uleb($WASM, $length + $uleb_length($count) - 1)
        $append_uleb($WASM, $count)
        $WASM[$string_length] = $WASM[$string_length] + $length - 1
    }
    if !$count {
        $WASM[$string_length] = $skip
    }
}

func $emit_native_global($node i32) {
    local $data_type i32 = $node[$node_type]    ;; Native type
    if $data_type == $TokenType_F64 { 
        $append_byte($WASM, 0x7c)
        $append_byte($WASM, 0x01)    ;; Mutable
        $append_byte($WASM, 0x44)    ;; f64.const
    } else if $data_type == $TokenType_F32 { 
        $append_byte($WASM, 0x7d)
        $append_byte($WASM, 0x01)    ;; Mutable
        $append_byte($WASM, 0x43)    ;; f32.const
    } else if $data_type == $TokenType_I64 {
        $append_byte($WASM, 0x7e)
        $append_byte($WASM, 0x01)    ;; Mutable
        $append_byte($WASM, 0x42)    ;; i64.const
    } else {                         
        $append_byte($WASM, 0x7f)
        $append_byte($WASM, 0x01)    ;; Mutable
        $append_byte($WASM, 0x41)    ;; i32.const
    }
    local $text i32 = $node[$node_BNode][$node_String]
    local $nodeType i32 = $node[$node_BNode][$node_type]
    if $data_type == $TokenType_F64 {
        $append_f64($WASM, $str_to_f64($text))
    } else if $data_type == $TokenType_F32 {
        $append_f32($WASM, $str_to_f32($text))
    } else if $data_type == $TokenType_I64 {
        $append_sleb64($WASM, $str_to_i64($text, $node[$node_BNode][$node_Token]))
    } else {
        $append_sleb32($WASM, $str_to_i32($text, $node[$node_BNode][$node_Token]))
    }
    $append_byte($WASM, 0x0b)    ;; end
}

func $emit_export_section($root_node i32) {
    local $BodyList i32 = $root_node[$node_Nodes]
    if $BodyList {
        local mut $count i32 = $EXPORT_LIST[$list_count]
        $count += 1    ;; +1 because we are also exporting the Memory
        if $count {
            $append_byte($WASM, 0x07)    ;; Export section
            $append_byte($WASM, 0x00)    ;; Section size (guess)
            local $start i32 = $WASM[$string_length]
            $append_uleb($WASM, $count)    ;; Export $count
            $emit_export_mem()
            $emit_export_fns()
            local $length i32 = $WASM[$string_length] - $start
            local $offset i32 = $uleb_length($length) - 1
            $offset_tail($WASM, $start, $offset)
            $WASM[$string_length] = $start - 1
            $append_uleb($WASM, $length)
            $WASM[$string_length] = $WASM[$string_length] + $length
        }
    }
}

func $emit_export_fns() {
    local mut $item i32 = $EXPORT_LIST[$list_First]
    loop {
        br_if !$item 
        local $name i32 = $item[$item_Name]
        $append_uleb($WASM, $name[$string_length])
        $append_str($WASM, $name)
        $append_byte($WASM, 0x00)    ;; Type function
        $append_uleb($WASM, $item[$item_Object][$node_index])
        $item = $item[$item_Next]
    }
}

func $emit_export_mem() {
    $append_uleb($WASM, 6)
    $append_str($WASM, "memory")
    $append_byte($WASM, 0x02)    ;; Type memory
    $append_byte($WASM, 0x00)    ;; Memory number 0 
}

func $emit_data_section() {
    local $count i32 = $DATA_LIST[$list_count]
    if $count {
        $append_byte($WASM, 0x0b)    ;; Data section
        $append_byte($WASM, 0x00)    ;; Section size (guess)
        local $start i32 = $WASM[$string_length]
        $append_uleb($WASM, $count)
        local mut $DataItem i32 = $DATA_LIST[$list_First]
        loop {
            br_if !$DataItem 
            $append_byte($WASM, 0x00)    ;; memory index 
            $append_byte($WASM, 0x41)    ;; i32.const
            $append_uleb($WASM, $DataItem[$item_Object])    ;; offset
            $append_byte($WASM, 0x0b)    ;; end
            local $DataString i32 = $DataItem[$item_Name]
            local $dataLength i32 = $DataString[$string_length] + $str_size
            $append_uleb($WASM, $dataLength)
            $append_i32($WASM, $DataItem[$item_Object] + $str_size)   ;; string_bytes
            $append_i32($WASM, $DataString[$string_length])    ;; string_length
            $append_str($WASM, $DataString)
            $DataItem = $DataItem[$item_Next]
        }
        local $length i32 = $WASM[$string_length] - $start
        local $offset i32 = $uleb_length($length) - 1
        $offset_tail($WASM, $start, $offset)
        $WASM[$string_length] = $start - 1
        $append_uleb($WASM, $length)
        $WASM[$string_length] = $WASM[$string_length] + $length
    }
}

func $emit_code_section($root_node i32) {
    $OFFSET = 65_536 * $PLS_memory_pages
    if i32.$FN_TYPE_LIST[$list_count] {
        $append_byte($WASM, 0x0a)    ;; Code section
        $append_byte($WASM, 0x00)    ;; Section size (guess)
        local $start i32 = $WASM[$string_length]
        $append_uleb($WASM, $FN_TYPE_LIST[$list_count])
        local mut $FunItem i32 = $root_node[$node_Nodes][$list_First]
        loop {
            br_if !$FunItem 
            local $FunNode i32 = $FunItem[$item_Object]
            if i32.$FunNode[$node_kind] == $Node_Fun {
                $emit_fn_node($FunNode)
            }
            $FunItem = $FunItem[$item_Next]
        }
        local $length i32 = $WASM[$string_length] - $start
        local $offset i32 = $uleb_length($length) - 1
        $offset_tail($WASM, $start, $offset)
        $WASM[$string_length] = $start - 1
        $append_uleb($WASM, $length)
        $WASM[$string_length] = $WASM[$string_length] + $length
    }
}

func $emit_fn_node($node i32) {
    $CURRENT_FN_NODE = $node
    $append_byte($WASM, 0x00)    ;; Function size (guess)
    local $start i32 = $WASM[$string_length]
    $append_byte($WASM, 0x00)    ;; Local declaration count (guess)
    local $LocalList i32 = $node[$node_Nodes]
    local mut $LocalItem i32 = $LocalList[$list_First]
    local mut $declCount i32 = 0
    loop {
        br_if !$LocalItem 
        local $data_type i32 = $LocalItem[$item_Object][$node_type]
        local mut $count i32 = 1
        loop {
            local $NextItem i32 = $LocalItem[$item_Next]
            br_if !$NextItem
            br_if $data_type != $NextItem[$item_Object][$node_type]
            $LocalItem = $NextItem
            $count += 1
        }
        $append_uleb($WASM, $count)    ;; count
        $append_data_type($WASM, $data_type)
        $LocalItem = $LocalItem[$item_Next]
        $declCount += 1
    }
    $emit_node($node[$node_ANode])    ;; Body Block node
    $append_byte($WASM, 0x0b)    ;; end
    local $length i32 = $WASM[$string_length] - $start
    local $offset i32 = $uleb_length($length) - 1 + $uleb_length($declCount) - 1
    $offset_tail($WASM, $start, $offset)
    $WASM[$string_length] = $start - 1
    $append_uleb($WASM, $length)
    $append_uleb($WASM, $declCount)
    $WASM[$string_length] = $WASM[$string_length] + $length - 1
}

func $emit_node($node i32) {
    local $kind i32 = $node[$node_kind]
    if $kind == $Node_Block {
        $emit_block($node)
    } else if $kind == $Node_Assign {
        $emit_assign($node, 0)
    } else if $kind == $Node_Unary {
        $emit_unary($node)
    } else if $kind == $Node_Call {
        $emit_call($node)
    } else if $kind == $Node_Builtin {
        $emit_builtin($node)
    } else if $kind == $Node_Return {
        $emit_return($node)
    } else if $kind == $Node_Expression {
        $emit_expression($node)
    } else if $kind == $Node_Instruction {
        if $node[$node_type] == $TokenType_Nop {
            $append_byte($WASM, 0x01)    ;; nop
        } else if $node[$node_type] == $TokenType_Unreachable {
            $append_byte($WASM, 0x00)    ;; unreachable
        }
    } else if $kind == $Node_If {
        $emit_if($node)
    } else if $kind == $Node_Br_If {
        $emit_br_if($node)
    } else if $kind == $Node_Drop {
        $emit_drop($node)
    } else if $kind == $Node_Loop {
        $emit_loop($node)
    } else if $kind == $Node_Literal {
        $emit_literal($node)
    } else if $kind == $Node_Identifier {
        $emit_identifier($node)
    } else if $kind == $Node_DotLoad {
        $emit_dot_load($node)
    } else if $kind == $Node_DotStore {
        $emit_dot_store($node)
    } else if $kind == $Node_Variable {
        $emit_variable($node)
    } else if $kind == $Node_Continue {
        $append_byte($WASM, 0x0c)    ;; br
        $append_uleb($WASM, $scope_level($node, $Node_Loop))
    } else if $kind == $Node_Br {
        $append_byte($WASM, 0x0c)    ;; br
        $append_uleb($WASM, $scope_level($node, $Node_Loop) + 1)
    } else {
        $add_error($Error_EmitNode, $node[$node_Token])
    }
}

func $emit_instruction($node i32) {
    if $node {
        local $kind i32 = $node[$node_kind]
        if $kind == $Node_Binary {
            $emit_binary($node)
        } else if $kind == $Node_Unary {
            $emit_unary($node)
        } else if $kind == $Node_Call {
            $emit_call($node)
        } else if $kind == $Node_Builtin {
            $emit_builtin($node)
        } else if $kind == $Node_Literal {
            $emit_literal($node)
        } else if $kind == $Node_Identifier {
            $emit_identifier($node)
        } else if $kind == $Node_DotLoad {
            $emit_dot_load($node)
        } else if $kind == $Node_Variable {
            $emit_variable($node)
        } else {
            $add_error($Error_Expression, $node[$node_Token])
            $add_error($kind , $node[$node_Token])
        }
    } else {
        $add_error($Error_Expression, 0)
        $add_error($node, 0)
    }
}

func $emit_assign($node i32, $isExpression i32) {
    local $resolved_node i32 = $scope_resolve($CURRENT_SCOPE, $node[$node_ANode][$node_String], $node[$node_Token])
    local $data_type i32 = $resolved_node[$node_type]
    local $BNode i32 = $node[$node_BNode]
    local $assigns i32 = $resolved_node[$node_assigns]
    if $assigns == 0 { 
        $add_error($Error_NotMutable, $node[$node_Token])
    }
    if $assigns > 0 {
        $resolved_node[$node_assigns] = $assigns - 1
    }
    $node[$node_dataType] = $data_type
    if $BNode[$node_dataType] != 0 & $BNode[$node_dataType] != $data_type {
        $add_error($Error_TypeMismatchA, $node[$node_Token])
    }
    $BNode[$node_dataType] = $data_type
    $emit_instruction($BNode)
    if $resolved_node[$node_Scope] == $GLOBAL_SCOPE {
        $append_byte($WASM, 0x24)    ;; set_global
        if $isExpression {
            $append_uleb($WASM, $resolved_node[$node_index])
            $append_byte($WASM, 0x23)    ;; get_global
        }
    } else {
        if $isExpression {
            $append_byte($WASM, 0x22)    ;; tee_local
        } else {
            $append_byte($WASM, 0x21)    ;; set_local
        }
    }
    $append_uleb($WASM, $resolved_node[$node_index])
}

func $emit_binary($node i32) {
    local $token_type i32 = $node[$node_type]
    local mut $data_type i32 = $node[$node_dataType]
    local $ANode i32 = $node[$node_ANode]
    local $BNode i32 = $node[$node_BNode]
    if !$data_type {
        $data_type = $infer_data_type($node)
        if !$data_type {
            $add_error($Error_TypeNotInferred, $node[$node_Token])
        }
        $node[$node_dataType] = $data_type
    }
    $ANode[$node_dataType] = $data_type
    $BNode[$node_dataType] = $data_type
    $emit_instruction($ANode)
    $emit_instruction($BNode)
    $emit_operator($token_type, $data_type, $node)
}

func $emit_operator($token_type i32, $data_type i32, $node i32) {
    if $data_type == $TokenType_F64 {
        if $token_type == $TokenType_Eq { $append_byte($WASM, 0x61) 
        } else if $token_type == $TokenType_Ne { $append_byte($WASM, 0x62) 
        } else if $token_type == $TokenType_Lt { $append_byte($WASM, 0x63) 
        } else if $token_type == $TokenType_Gt { $append_byte($WASM, 0x64) 
        } else if $token_type == $TokenType_Lte { $append_byte($WASM, 0x65) 
        } else if $token_type == $TokenType_Gte { $append_byte($WASM, 0x66) 
        } else if $token_type == $TokenType_Add { $append_byte($WASM, 0xa0) 
        } else if $token_type == $TokenType_Sub { $append_byte($WASM, 0xa1) 
        } else if $token_type == $TokenType_Mul { $append_byte($WASM, 0xa2) 
        } else if $token_type == $TokenType_Div { $append_byte($WASM, 0xa3) 
        } else if $token_type == $TokenType_Min { $append_byte($WASM, 0xa4) 
        } else if $token_type == $TokenType_Max { $append_byte($WASM, 0xa5) 
        } else if $token_type == $TokenType_Abs { $append_byte($WASM, 0x99) 
        } else if $token_type == $TokenType_Neg { $append_byte($WASM, 0x9a) 
        } else if $token_type == $TokenType_Sqrt { $append_byte($WASM, 0x9f) 
        } else if $token_type == $TokenType_Ceil { $append_byte($WASM, 0x9b) 
        } else if $token_type == $TokenType_Floor { $append_byte($WASM, 0x9c) 
        } else if $token_type == $TokenType_Trunc { $append_byte($WASM, 0x9d) 
        } else if $token_type == $TokenType_Round { $append_byte($WASM, 0x9e) 
        } else if $token_type == $TokenType_CopySign { $append_byte($WASM, 0xa6) 
        } else { 
            $add_error($Error_InvalidOperator, $node[$node_Token]) 
        }
    } else if $data_type == $TokenType_F32 {
        if $token_type == $TokenType_Eq { $append_byte($WASM, 0x5b) 
        } else if $token_type == $TokenType_Ne { $append_byte($WASM, 0x5c)
        } else if $token_type == $TokenType_Lt { $append_byte($WASM, 0x5d)
        } else if $token_type == $TokenType_Gt { $append_byte($WASM, 0x5e)
        } else if $token_type == $TokenType_Lte { $append_byte($WASM, 0x5f)
        } else if $token_type == $TokenType_Gte { $append_byte($WASM, 0x60) 
        } else if $token_type == $TokenType_Abs { $append_byte($WASM, 0x8b) 
        } else if $token_type == $TokenType_Neg { $append_byte($WASM, 0x8c) 
        } else if $token_type == $TokenType_Ceil { $append_byte($WASM, 0x8d)
        } else if $token_type == $TokenType_Floor { $append_byte($WASM, 0x8e)
        } else if $token_type == $TokenType_Trunc { $append_byte($WASM, 0x8f)
        } else if $token_type == $TokenType_Round { $append_byte($WASM, 0x90)
        } else if $token_type == $TokenType_Sqrt { $append_byte($WASM, 0x91)
        } else if $token_type == $TokenType_Add { $append_byte($WASM, 0x92)
        } else if $token_type == $TokenType_Sub { $append_byte($WASM, 0x93)
        } else if $token_type == $TokenType_Mul { $append_byte($WASM, 0x94)
        } else if $token_type == $TokenType_Div { $append_byte($WASM, 0x95)
        } else if $token_type == $TokenType_Min { $append_byte($WASM, 0x96)
        } else if $token_type == $TokenType_Max { $append_byte($WASM, 0x97)
        } else if $token_type == $TokenType_CopySign { $append_byte($WASM, 0x98)
        } else {
            $add_error($Error_InvalidOperator, $node[$node_Token]) 
        }
    } else if $data_type == $TokenType_I64 {
        if $token_type == $TokenType_Eqz { $append_byte($WASM, 0x50) 
        } else if $token_type == $TokenType_Eq { $append_byte($WASM, 0x51) 
        } else if $token_type == $TokenType_Ne { $append_byte($WASM, 0x52) 
        } else if $token_type == $TokenType_Lt { $append_byte($WASM, 0x53) 
        } else if $token_type == $TokenType_Ltu { $append_byte($WASM, 0x54) 
        } else if $token_type == $TokenType_Gt { $append_byte($WASM, 0x55) 
        } else if $token_type == $TokenType_Gtu { $append_byte($WASM, 0x56) 
        } else if $token_type == $TokenType_Lte { $append_byte($WASM, 0x57)
        } else if $token_type == $TokenType_Leu { $append_byte($WASM, 0x58)
        } else if $token_type == $TokenType_Gte { $append_byte($WASM, 0x59) 
        } else if $token_type == $TokenType_Geu { $append_byte($WASM, 0x5a)
        } else if $token_type == $TokenType_Clz { $append_byte($WASM, 0x79)
        } else if $token_type == $TokenType_Ctz { $append_byte($WASM, 0x7a) 
        } else if $token_type == $TokenType_Popcnt { $append_byte($WASM, 0x7b)
        } else if $token_type == $TokenType_Add { $append_byte($WASM, 0x7c)
        } else if $token_type == $TokenType_Sub { $append_byte($WASM, 0x7d)
        } else if $token_type == $TokenType_Mul { $append_byte($WASM, 0x7e)
        } else if $token_type == $TokenType_Div { $append_byte($WASM, 0x7f)
        } else if $token_type == $TokenType_Divu { $append_byte($WASM, 0x80)
        } else if $token_type == $TokenType_Rem { $append_byte($WASM, 0x81)
        } else if $token_type == $TokenType_Remu { $append_byte($WASM, 0x82)
        } else if $token_type == $TokenType_And { $append_byte($WASM, 0x83)
        } else if $token_type == $TokenType_Or { $append_byte($WASM, 0x84)
        } else if $token_type == $TokenType_Xor { $append_byte($WASM, 0x85)
        } else if $token_type == $TokenType_Shl { $append_byte($WASM, 0x86)
        } else if $token_type == $TokenType_Shr { $append_byte($WASM, 0x87)
        } else if $token_type == $TokenType_Shru { $append_byte($WASM, 0x88)
        } else if $token_type == $TokenType_Rotl { $append_byte($WASM, 0x89)
        } else if $token_type == $TokenType_Rotr { $append_byte($WASM, 0x8a) 
        } else {
            $add_error($Error_InvalidOperator, $node[$node_Token]) 
        }
    } else {
        if $token_type == $TokenType_Eqz { $append_byte($WASM, 0x45) 
        } else if $token_type == $TokenType_Eq { $append_byte($WASM, 0x46) 
        } else if $token_type == $TokenType_Ne { $append_byte($WASM, 0x47) 
        } else if $token_type == $TokenType_Lt { $append_byte($WASM, 0x48) 
        } else if $token_type == $TokenType_Ltu { $append_byte($WASM, 0x49) 
        } else if $token_type == $TokenType_Gt { $append_byte($WASM, 0x4a) 
        } else if $token_type == $TokenType_Gtu { $append_byte($WASM, 0x4b) 
        } else if $token_type == $TokenType_Lte { $append_byte($WASM, 0x4c) 
        } else if $token_type == $TokenType_Leu { $append_byte($WASM, 0x4d) 
        } else if $token_type == $TokenType_Gte { $append_byte($WASM, 0x4e) 
        } else if $token_type == $TokenType_Geu { $append_byte($WASM, 0x4f) 
        } else if $token_type == $TokenType_Clz { $append_byte($WASM, 0x67) 
        } else if $token_type == $TokenType_Ctz { $append_byte($WASM, 0x68) 
        } else if $token_type == $TokenType_Popcnt { $append_byte($WASM, 0x69) 
        } else if $token_type == $TokenType_Add { $append_byte($WASM, 0x6a) 
        } else if $token_type == $TokenType_Sub { $append_byte($WASM, 0x6b) 
        } else if $token_type == $TokenType_Mul { $append_byte($WASM, 0x6c) 
        } else if $token_type == $TokenType_Div { $append_byte($WASM, 0x6d) 
        } else if $token_type == $TokenType_Divu { $append_byte($WASM, 0x6e) 
        } else if $token_type == $TokenType_Rem { $append_byte($WASM, 0x6f) 
        } else if $token_type == $TokenType_Remu { $append_byte($WASM, 0x70) 
        } else if $token_type == $TokenType_And { $append_byte($WASM, 0x71) 
        } else if $token_type == $TokenType_Or { $append_byte($WASM, 0x72) 
        } else if $token_type == $TokenType_Xor { $append_byte($WASM, 0x73) 
        } else if $token_type == $TokenType_Shl { $append_byte($WASM, 0x74) 
        } else if $token_type == $TokenType_Shr { $append_byte($WASM, 0x75) 
        } else if $token_type == $TokenType_Shru { $append_byte($WASM, 0x76) 
        } else if $token_type == $TokenType_Rotl { $append_byte($WASM, 0x77) 
        } else if $token_type == $TokenType_Rotr { $append_byte($WASM, 0x78) 
        } else { 
            $add_error($Error_InvalidOperator, $node[$node_Token]) 
        }
    }
}

func $emit_unary($node i32) {
    local $token_type i32 = $node[$node_type]
    local $data_type i32 = $node[$node_dataType]
    if $token_type == $TokenType_Sub {
        if $data_type == $TokenType_F64 {
            $append_byte($WASM, 0x44)    ;; f64.const
            $append_f64($WASM, 0) 
        } else if $data_type == $TokenType_F32 {
            $append_byte($WASM, 0x43)    ;; f32.const
            $append_f32($WASM, 0)
        } else if $data_type == $TokenType_I64 {
            $append_byte($WASM, 0x42)    ;; i64.const 
            $append_byte($WASM, 0x00)    ;; 0
        } else {
            $append_byte($WASM, 0x41)    ;; i32.const 
            $append_byte($WASM, 0x00)    ;; 0
        }
    }
    $emit_instruction($node[$node_BNode])
    $emit_operator($token_type, $data_type, $node)
}

func $emit_identifier($node i32) {
    local $resolved_node i32 = $scope_resolve($CURRENT_SCOPE, $node[$node_String], $node[$node_Token])
    local mut $data_type i32 = $resolved_node[$node_dataType]
    local mut $node_data_type i32 = $node[$node_dataType]
    if $node_data_type != 0 & $node_data_type != $data_type {
        $add_error($Error_TypeMismatchB, $node[$node_Token])
    }
    $node[$node_dataType] = $data_type
    if $resolved_node[$node_Scope] == $GLOBAL_SCOPE {
        $append_byte($WASM, 0x23)    ;; get_global
    } else {
        $append_byte($WASM, 0x20)    ;; get_local
    }
    $append_uleb($WASM, $resolved_node[$node_index])
}

func $emit_dot_load($node i32) {    ;;    f32.$A[$B][$C]    ->    f32.load(load($A + $B) + $C)
    local $data_type i32 = $node[$node_dataType]
    local $ident_list i32 = $node[$node_Nodes]
    local mut $item i32 = $ident_list[$list_First]
    local $item_count i32 = $ident_list[$list_count]
    local mut $item_no i32 = 1
    $emit_identifier($item[$item_Object])
    $item = $item[$item_Next]
    loop {
        br_if !$item 
        $item_no += 1
        $emit_identifier($item[$item_Object])
        $append_byte($WASM, 0x6a)    ;; i32.Plus
        if $item_no < $item_count {
            $append_byte($WASM, 0x28)    ;; i32.load
        } else {
            if !$data_type {
                $add_error($Error_TypeNotInferred, $node[$node_Token])
            }
            if $data_type == $TokenType_F64 {
                $append_byte($WASM, 0x2b)    ;; f64.load
            } else if $data_type == $TokenType_F32 {
                $append_byte($WASM, 0x2a)    ;; f32.load
            } else if $data_type == $TokenType_I64 {
                $append_byte($WASM, 0x29)    ;; i64.load
            } else {
                $append_byte($WASM, 0x28)    ;; i32.load
            }
        }
        $append_byte($WASM, 0x00)    ;; alignment
        $append_byte($WASM, 0x00)    ;; offset
        $item = $item[$item_Next]
    }
}

func $emit_dot_store($node i32) {    ;; f64.$A[$B][$C] = $x  ->  f64.store(load(load($A + $B) + $C), $x)
    local mut $data_type i32 = $node[$node_dataType]
    if !$data_type {
        $data_type = $infer_data_type($node[$node_ANode])
        $node[$node_dataType] = $data_type
    }
    local $ident_list i32 = $node[$node_Nodes]
    if $ident_list {
        local mut $item i32 = $ident_list[$list_First]
        local $item_count i32 = $ident_list[$list_count]
        local mut $item_no i32 = 1
        $emit_identifier($item[$item_Object])
        $item = $item[$item_Next]
        loop {
            br_if !$item 
            $item_no += 1
            $emit_identifier($item[$item_Object])
            $append_byte($WASM, 0x6a)    ;; i32.Plus
            if $item_no < $item_count {
                $append_byte($WASM, 0x28)    ;; i32.load
            } else {
                $emit_instruction($node[$node_ANode])
                if $data_type == $TokenType_F64 {
                    $append_byte($WASM, 0x39)    ;; f64.store
                } else if $data_type == $TokenType_F32 {
                    $append_byte($WASM, 0x38)    ;; f32.store
                } else if $data_type == $TokenType_I64 {
                    $append_byte($WASM, 0x37)    ;; i64.store
                } else {
                    $append_byte($WASM, 0x36)    ;; i32.store
                }
            }
            $append_byte($WASM, 0x00)    ;; alignment
            $append_byte($WASM, 0x00)    ;; offset
            $item = $item[$item_Next]
        }
    } else {
        $add_error($Error_NoIdentifiers, $node[$node_Token])
    }
}

func $emit_num_literal($node i32, $data_type i32) {
    if $data_type == $TokenType_F64 {
        $append_byte($WASM, 0x44)    ;; f64.const
        $append_f64($WASM, $str_to_f64($node[$node_String]))
    } else if $data_type == $TokenType_F32 {
        $append_byte($WASM, 0x43)    ;; f32.const
        $append_f32($WASM, $str_to_f32($node[$node_String]))
    } else if $data_type == $TokenType_I64 {
        $append_byte($WASM, 0x42)    ;; i64.const
        $append_sleb64($WASM, $str_to_i64($node[$node_String], $node[$node_Token]))
    } else {
        $append_byte($WASM, 0x41)    ;; i32.const
        $append_sleb32($WASM, $str_to_i32($node[$node_String], $node[$node_Token]))
    }
}

func $emit_chr_literal($node i32, $data_type i32) {
    local $name i32 = $node[$node_String]
    if $data_type == $TokenType_I64 {
        $append_byte($WASM, 0x42)    ;; i64.const
        if i32.$name[$string_length] > 4 {
            $append_sleb64($WASM, i64.load($name[$string_bytes]))
        } else {
            $append_sleb32($WASM, i32.load($name[$string_bytes]))
        }
    } else {
        $append_byte($WASM, 0x41)    ;; i32.const
        $append_sleb32($WASM, i32.load($name[$string_bytes]))
    }
}

func $emit_literal($node i32) {
    local $token_type i32 = $node[$node_type]
    local $data_type i32 = $node[$node_dataType]
    if $token_type == $TokenType_NumLiteral {
        $emit_num_literal($node, $data_type)
    } else if $token_type == $TokenType_CharLiteral {
        $emit_chr_literal($node, $data_type)
    } else if $token_type == $TokenType_StrLiteral {        
        $append_byte($WASM, 0x41)    ;; i32.const
        $append_sleb32($WASM, $add_static_str($node[$node_Token]))
    }
}

;; Static strings are compiled to a pointer (i32.const) 
;; and a string is added to Data section list
func $add_static_str($token i32) i32 {
    $OFFSET -= $str_size + $token[$token_Value][$string_length]
    if $OFFSET % $ALIGNMENT {
        $OFFSET -= $ALIGNMENT + $OFFSET % $ALIGNMENT
    }
    $list_add_name($DATA_LIST, $OFFSET, $token[$token_Value])
    $OFFSET
}

func $emit_fn_call_args($call_node i32, $FunNode i32) {
    local $argument_list i32 = $call_node[$node_ParamNodes]
    if $argument_list {
        local mut $argument_item i32 = $argument_list[$list_First]
        local $param_list i32 = $FunNode[$node_ParamNodes]
        if $param_list {
            local mut $param_item i32 = $param_list[$list_First]
            loop {
                br_if !$argument_item 
                local $argument_node i32 = $argument_item[$item_Object]
                local $param_node i32 = $param_item[$item_Object]
                i32.$argument_node[$node_dataType] = $param_node[$node_dataType]
                $emit_instruction($argument_node)
                $argument_item = $argument_item[$item_Next]
                $param_item = $param_item[$item_Next]
            }
        } else {
            $add_error($Error_NoParamList, $call_node[$node_Token])
        }
    }
}

func $emit_call_args($call_node i32, $data_Type i32) {
    local $argument_list i32 = $call_node[$node_ParamNodes]
    local mut $argument_item i32 = $argument_list[$list_First]
    loop {
        br_if !$argument_item 
        local $argument_node i32 = $argument_item[$item_Object]
        $argument_node[$node_dataType] = $data_Type
        $emit_instruction($argument_node)
        $argument_item = $argument_item[$item_Next]
    }
}

func $emit_call_args2($call_node i32, $data_TypeA i32, $data_TypeB i32) {
    local $argument_list i32 = $call_node[$node_ParamNodes]
    local mut $argument_item i32 = $argument_list[$list_First]
    local mut $is_first i32 = 1
    loop {
        br_if !$argument_item 
        local $argument_node i32 = $argument_item[$item_Object]
        if $is_first {
            $argument_node[$node_dataType] = $data_TypeA
        } else {        
            $argument_node[$node_dataType] = $data_TypeB
        }
        $emit_instruction($argument_node)
        $argument_item = $argument_item[$item_Next]
        $is_first = 0
    }
}

func $emit_call($node i32) {
    local $name i32 = $node[$node_ANode][$node_String]
    local $resolved_node i32 = $scope_resolve($CURRENT_SCOPE, $name, $node[$node_Token])
    if $resolved_node {
        $emit_fn_call_args($node, $resolved_node)
        $append_byte($WASM, 0x10)    ;; Call
        $append_uleb($WASM, $resolved_node[$node_index])
    }
}

func $emit_builtin($node i32) {
    local $name i32 = $node[$node_ANode][$node_String]
    local mut $t i32 = $node[$node_ANode][$node_dataType]
    if !$t {
        $t = $node[$node_dataType]
    }
    if $str_eq($name, "load") {
        $emit_call_args($node, $TokenType_I32)
        if $t == $TokenType_I32 {
            $append_byte($WASM, 0x28)
        } else if $t == $TokenType_I64 {
            $append_byte($WASM, 0x29) 
        } else if $t == $TokenType_F32 {
            $append_byte($WASM, 0x2a) 
        } else if $t == $TokenType_F64 {
            $append_byte($WASM, 0x2b) 
        } else { $add_error($Error_BuiltinType, $node[$node_Token]) }
        $append_byte($WASM, 0x00)    ;; alignment
        $append_byte($WASM, 0x00)    ;; offset
    } else if $str_eq($name, "load8_s") {
        $emit_call_args($node, $TokenType_I32)
        if $t == $TokenType_I32 {
            $append_byte($WASM, 0x2c)
        } else if $t == $TokenType_I64 {
            $append_byte($WASM, 0x30) 
        } else { $add_error($Error_BuiltinType, $node[$node_Token]) }
        $append_byte($WASM, 0x00)    ;; alignment
        $append_byte($WASM, 0x00)    ;; offset
    } else if $str_eq($name, "load8_u") {
        $emit_call_args($node, $TokenType_I32)
        if $t == $TokenType_I32 {
            $append_byte($WASM, 0x2d)
        } else if $t == $TokenType_I64 {
            $append_byte($WASM, 0x31) 
        } else { $add_error($Error_BuiltinType, $node[$node_Token]) }
        $append_byte($WASM, 0x00)    ;; alignment
        $append_byte($WASM, 0x00)    ;; offset
    } else if $str_eq($name, "load16_s") {
        $emit_call_args($node, $TokenType_I32)
        if $t == $TokenType_I32 {
            $append_byte($WASM, 0x2e)
        } else if $t == $TokenType_I64 {
            $append_byte($WASM, 0x32) 
        } else { $add_error($Error_BuiltinType, $node[$node_Token]) }
        $append_byte($WASM, 0x00)    ;; alignment
        $append_byte($WASM, 0x00)    ;; offset
    } else if $str_eq($name, "load16_u") {
        $emit_call_args($node, $TokenType_I32)
        if $t == $TokenType_I32 {
            $append_byte($WASM, 0x2f)
        } else if $t == $TokenType_I64 {
            $append_byte($WASM, 0x33) 
        } else { $add_error($Error_BuiltinType, $node[$node_Token]) }
        $append_byte($WASM, 0x00)    ;; alignment
        $append_byte($WASM, 0x00)    ;; offset
    } else if $str_eq($name, "load32_s") {
        $emit_call_args($node, $TokenType_I32)
        $append_byte($WASM, 0x34)
        $append_byte($WASM, 0x00)    ;; alignment
        $append_byte($WASM, 0x00)    ;; offset        
    } else if $str_eq($name, "load32_u") {
        $emit_call_args($node, $TokenType_I32)
        $append_byte($WASM, 0x35)
        $append_byte($WASM, 0x00)    ;; alignment
        $append_byte($WASM, 0x00)    ;; offset        
    } else if $str_eq($name, "store") {
        if $t == $TokenType_I32 {
            $emit_call_args($node, $TokenType_I32)
            $append_byte($WASM, 0x36)
        } else if $t == $TokenType_I64 {
            $emit_call_args2($node, $TokenType_I32, $TokenType_I64)
            $append_byte($WASM, 0x37) 
        } else if $t == $TokenType_F32 {
            $emit_call_args2($node, $TokenType_I32, $TokenType_F32)
            $append_byte($WASM, 0x38) 
        } else if $t == $TokenType_F64 {
            $emit_call_args2($node, $TokenType_I32, $TokenType_F64)
            $append_byte($WASM, 0x39) 
        } else { $add_error($Error_BuiltinType, $node[$node_Token]) }
        $append_byte($WASM, 0x00)    ;; alignment
        $append_byte($WASM, 0x00)    ;; offset
    } else if $str_eq($name, "store8") {
        if $t == $TokenType_I32 {
            $emit_call_args($node, $TokenType_I32)
            $append_byte($WASM, 0x3a)
        } else if $t == $TokenType_I64 {
            $emit_call_args2($node, $TokenType_I32, $TokenType_I64)
            $append_byte($WASM, 0x3c) 
        } else { $add_error($Error_BuiltinType, $node[$node_Token]) }
        $append_byte($WASM, 0x00)    ;; alignment
        $append_byte($WASM, 0x00)    ;; offset
    } else if $str_eq($name, "store16") {
        if $t == $TokenType_I32 {
            $emit_call_args($node, $TokenType_I32)
            $append_byte($WASM, 0x3b)
        } else if $t == $TokenType_I64 {
            $emit_call_args2($node, $TokenType_I32, $TokenType_I64)
            $append_byte($WASM, 0x3d) 
        } else { $add_error($Error_BuiltinType, $node[$node_Token]) }
        $append_byte($WASM, 0x00)    ;; alignment
        $append_byte($WASM, 0x00)    ;; offset
    } else if $str_eq($name, "store32") {
        $emit_call_args2($node, $TokenType_I32, $TokenType_I64)
        $append_byte($WASM, 0x3e)    ;; i64.store32
        $append_byte($WASM, 0x00)    ;; alignment
        $append_byte($WASM, 0x00)    ;; offset
    } else if $str_eq($name, "current_memory") {
        $append_byte($WASM, 0x3f) 
        $append_byte($WASM, 0x00)    ;; memory number
    } else if $str_eq($name, "grow_memory") {
        $emit_call_args($node, $TokenType_I32)
        $append_byte($WASM, 0x40)
        $append_byte($WASM, 0x00)    ;; memory number
    } else if $str_eq($name, "wrap") {
        $emit_call_args($node, $TokenType_I64)
        $append_byte($WASM, 0xa7)
    } else if $str_eq($name, "extend_s") {
        $emit_call_args($node, $TokenType_I32)
        $append_byte($WASM, 0xac)
    } else if $str_eq($name, "extend_u") {
        $emit_call_args($node, $TokenType_I32)
        $append_byte($WASM, 0xad) 
    } else if $str_eq($name, "demote") {
        $emit_call_args($node, $TokenType_F64)
        $append_byte($WASM, 0xb6)
    } else if $str_eq($name, "promote") {
        $emit_call_args($node, $TokenType_F32)
        $append_byte($WASM, 0xbb)
    } else if $str_eq($name, "trunc_s_f32") {
        $emit_call_args($node, $TokenType_F32)
        if $t == $TokenType_I32 {
            $append_byte($WASM, 0xa8)
        } else if $t == $TokenType_I64 {
            $append_byte($WASM, 0xae) 
        } else { $add_error($Error_BuiltinType, $node[$node_Token]) }
    } else if $str_eq($name, "trunc_u_f32") {
        $emit_call_args($node, $TokenType_F32)
        if $t == $TokenType_I32 {
            $append_byte($WASM, 0xa9)
        } else if $t == $TokenType_I64 {
            $append_byte($WASM, 0xaf) 
        } else { $add_error($Error_BuiltinType, $node[$node_Token]) }
    } else if $str_eq($name, "trunc_u_f64") {
        $emit_call_args($node, $TokenType_F64)
        if $t == $TokenType_I32 {
            $append_byte($WASM, 0xab)
        } else if $t == $TokenType_I64 {
            $append_byte($WASM, 0xb1) 
        } else { $add_error($Error_BuiltinType, $node[$node_Token]) }
    } else if $str_eq($name, "convert_s_i32") {
        $emit_call_args($node, $TokenType_I32)
        if $t == $TokenType_F32 {
            $append_byte($WASM, 0xb2)
        } else if $t == $TokenType_F64 {
            $append_byte($WASM, 0xb7) 
        } else { $add_error($Error_BuiltinType, $node[$node_Token]) }
    } else if $str_eq($name, "convert_s_i64") {
        $emit_call_args($node, $TokenType_I64)
        if $t == $TokenType_F32 {
            $append_byte($WASM, 0xb4)
        } else if $t == $TokenType_F64 {
            $append_byte($WASM, 0xb9) 
        } else { $add_error($Error_BuiltinType, $node[$node_Token]) }
    } else if $str_eq($name, "convert_u_i32") {
        $emit_call_args($node, $TokenType_I32)
        if $t == $TokenType_F32 {
            $append_byte($WASM, 0xb3)
        } else if $t == $TokenType_F64 {
            $append_byte($WASM, 0xb8) 
        } else { $add_error($Error_BuiltinType, $node[$node_Token]) }
    } else if $str_eq($name, "convert_u_i64") {
        $emit_call_args($node, $TokenType_I64)
        if $t == $TokenType_F32 {
            $append_byte($WASM, 0xba)
        } else if $t == $TokenType_F64 {
            $append_byte($WASM, 0xb5) 
        } else { $add_error($Error_BuiltinType, $node[$node_Token]) }
    } else {
        $add_error($Error_BuiltinType, $node[$node_Token])
    }
}

func $emit_block($node i32) {
    local $scope i32 = $node[$node_Scope]
    $CURRENT_SCOPE = $scope
    local $BlockList i32 = $node[$node_Nodes]
    local mut $item i32 = $BlockList[$list_First]
    loop {
        br_if !$item 
        $emit_node($item[$item_Object])
        $item = $item[$item_Next]
    }
    $CURRENT_SCOPE = $scope[$scope_Parent]
}

func $emit_if($node i32) {
    local $data_type i32 = $node[$node_dataType]
    $emit_instruction($node[$node_CNode])    ;; If condition Expression
    $append_byte($WASM, 0x04)    ;; if
    if $data_type == $TokenType_F64 {
        $append_byte($WASM, 0x7c)
    } else if $data_type == $TokenType_F32 {
        $append_byte($WASM, 0x7d)
    } else if $data_type == $TokenType_I64 {
        $append_byte($WASM, 0x7e)
    } else if $data_type == $TokenType_I32 {
        $append_byte($WASM, 0x7f)
    } else {
        $append_byte($WASM, 0x40) ;; void
    }
    $emit_node($node[$node_ANode])    ;; Then Block
    local $ElseBlock i32 = $node[$node_BNode]
    if $ElseBlock {
        $append_byte($WASM, 0x05)    ;; else
        $emit_node($ElseBlock)
    }
    $append_byte($WASM, 0x0b)    ;; end
}

func $scope_level($node i32, $kind i32) i32 {
    local mut $scope i32 = $node[$node_Scope]
    local mut $level i32 = 0
    loop { 
        br_if !$scope 
        br_if $scope[$scope_Node][$node_kind] == $kind
        $level += 1
        $scope = $scope[$scope_Parent]
    }
    $level
}

func $emit_loop($node i32) {
    $append_byte($WASM, 0x02)    ;; Block
    $append_byte($WASM, 0x40)    ;; void 
    $append_byte($WASM, 0x03)    ;; loop
    $append_byte($WASM, 0x40)    ;; void 
    $emit_node($node[$node_ANode])
    $append_byte($WASM, 0x0c)    ;; br
    $append_byte($WASM, 0x00)    ;; level 
    $append_byte($WASM, 0x0b)    ;; end
    $append_byte($WASM, 0x0b)    ;; end
}

func $infer_call_data_type($node i32) i32 {
    local $name i32 = $node[$node_String]
    if $str_eq($name, "current_memory") { return $TokenType_I32
    } else if $str_eq($name, "load32_s") { return $TokenType_I64
    } else if $str_eq($name, "load32_u") { return $TokenType_I64
    } else if $str_eq($name, "wrap") { return $TokenType_I32
    } else if $str_eq($name, "extend_s") { return $TokenType_I64
    } else if $str_eq($name, "extend_u") { return $TokenType_I64
    } else if $str_eq($name, "demote") { return $TokenType_F32
    } else if $str_eq($name, "promote") { return $TokenType_F64
    } else {
        local $resolved_node i32 = $scope_resolve($CURRENT_SCOPE, $name, $node[$node_Token])
        return $resolved_node[$node_dataType]
    }
    0
}

func $infer_data_type($node i32) i32 {
    local mut $data_type i32 = $node[$node_dataType]
    local $kind i32 = $node[$node_kind]
    if $kind == $Node_Binary | $kind == $Node_Iif | $kind == $Node_Assign {
        $data_type = $infer_data_type($node[$node_ANode])
        if !$data_type {
            $data_type = $infer_data_type($node[$node_BNode])
        }
    } else if $kind == $Node_Identifier {
        local $resolved_node i32 = $scope_resolve($CURRENT_SCOPE, $node[$node_String], $node[$node_Token])
        $data_type = $resolved_node[$node_dataType]
    } else if $kind == $Node_Unary {
        $data_type = $infer_data_type($node[$node_BNode])
    } else if $kind == $Node_Call {
        $data_type = $infer_call_data_type($node[$node_ANode])
    } else if $kind == $Node_Builtin {
        $data_type = $infer_call_data_type($node[$node_ANode])
    }
    $data_type
}

func $emit_variable($node i32) {
    local $token_type i32 = $node[$node_type]
    local $BNode i32 = $node[$node_BNode]
    $BNode[$node_dataType] = $token_type
    $emit_instruction($BNode)
    $append_byte($WASM, 0x21)    ;; set_local
    $append_uleb($WASM, $node[$node_index])
}

func $emit_return($node i32) {
    local $ANode i32 = $node[$node_ANode]
    local $data_type i32 = $CURRENT_FN_NODE[$node_dataType]
    if $data_type {
        $node[$node_dataType] = $data_type
        $ANode[$node_dataType] = $data_type
        $emit_instruction($ANode)
    }
    $append_byte($WASM, 0x0f)    ;; return
}

func $emit_expression($node i32) {
    local $ANode i32 = $node[$node_ANode]
    local $data_type i32 = $CURRENT_FN_NODE[$node_dataType]
    if $data_type {
        $node[$node_dataType] = $data_type
        $ANode[$node_dataType] = $data_type
        $emit_instruction($ANode)
    }
}

func $emit_br_if($node i32) {
    $emit_instruction($node[$node_CNode])    ;; If condition Expression
    $append_byte($WASM, 0x0d)    ;; br_if
    $append_uleb($WASM, $scope_level($node, $Node_Loop) + 1)
}

func $emit_drop($node i32) {
    $emit_instruction($node[$node_ANode])
    $append_byte($WASM, 0x1a)    ;; drop
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ERRORS

global mut $ERROR_LIST i32 = 0

func $add_error($errorNo i32, $token i32) {
    $list_add_name($ERROR_LIST, $token, $errorNo)
}

func $parse_error_list() {
    local mut $ErrorItem i32 = $ERROR_LIST[$list_First]
    if $ErrorItem {
        local $error_message i32 = $new_empty_string(1_000)
        loop {
            br_if !$ErrorItem 
            local $token i32 = $ErrorItem[$item_Object]
            local $errorNo i32 = $ErrorItem[$item_number]
            if $errorNo == $Error_DuplicateName {
                $append_str($error_message, "Duplicate identifier")
            } else if $errorNo == $Error_InvalidToken {
                $append_str($error_message, "Invalid token")
            } else if $errorNo == $Error_MissingToken {
                $append_str($error_message, "Missing token")
            } else if $errorNo == $Error_RootStatement {
                $append_str($error_message, "Invalid root statement")
            } else if $errorNo == $Error_BlockStatement {
                $append_str($error_message, "Invalid block statement")
            } else if $errorNo == $Error_TypeMismatchA {
                $append_str($error_message, "Type mismatch A")
            } else if $errorNo == $Error_TypeMismatchB {
                $append_str($error_message, "Type mismatch B")
            } else if $errorNo == $Error_NotDeclared {
                $append_str($error_message, "Identifier Not declared")
            } else if $errorNo == $Error_LiteralToInt {
                $append_str($error_message, "Could not convert to int")
            } else if $errorNo == $Error_Expression {
                $append_str($error_message, "Expression expected")
            } else if $errorNo == $Error_BuiltinType {
                $append_str($error_message, "Builtin func type error")
            } else if $errorNo == $Error_TypeNotInferred {
                $append_str($error_message, "Could not determine type")
            } else if $errorNo == $Error_NotMutable {
                $append_str($error_message, "Not mutable")
            } else if $errorNo == $Error_NoParamList {
                $append_str($error_message, "No param list")    
            } else if $errorNo == $Error_ParseAssignOp {
                $append_str($error_message, "Parsing failed assignop")    
            } else if $errorNo == $Error_EmitNode {
                $append_str($error_message, "Unexpected node type")
            } else if $errorNo == $Error_InvalidOperator {
                $append_str($error_message, "Invalid operator")
            } else {    
                $append_str($error_message, "Error ")
                $append_i32_as_str($error_message, $errorNo)
            }
            if $token {
                $append_str($error_message, " line ")
                $append_i32_as_str($error_message, $token[$token_line])
                $append_str($error_message, " column ")
                if i32.$token[$token_Value] {
                    $append_i32_as_str($error_message, $token[$token_column] - $token[$token_Value][$string_length])
                    $append_str($error_message, " token ")
                    $append_str($error_message, $token[$token_Value])
                } else {
                    $append_i32_as_str($error_message, $token[$token_column])
                }
                $append_byte($error_message, 13)
            }
            $WASM = $error_message
            $ErrorItem = $ErrorItem[$item_Next]
        }
    }
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Function library

func $str_to_i32($string i32, $token i32) i32 {
    wrap($str_to_i64($string, $token))
}

func $str_to_i64($string i32, $token i32) i64 {    ;; Supports ints & 0x-prefixed hex
    local mut $is_hex i32 = 0
    local mut $i i64 = 0
    local $length i32 = $string[$string_length]
    local mut $offset i32 = 0
    local mut $chr i32 = 0
    if $length >= 3 {
        if $get_chr($string, 0) == '0' & $get_chr($string, 1) == 'x' {
            $is_hex = 1
        }
    }
    if $is_hex {
        $offset = 2
        loop {
            br_if $offset >= $length 
            $chr = $get_chr($string, $offset)
            if $chr != '_' {
                $i = $i * 16
                if $chr >= '0' & $chr <= '9' {
                    $i += extend_s($chr) - '0'
                } else if $chr >= 'a' & $chr <= 'f' {
                    $i += extend_s($chr) - 'a' + 10
                } else if $chr >= 'A' & $chr <= 'F' {
                    $i += extend_s($chr) - 'A' + 10
                } else {
                    $add_error($Error_LiteralToInt, $token)
                }
            }
            $offset += 1
        }
    } else {
        loop {
            br_if $offset >= $length 
            $chr = $get_chr($string, $offset)
            if $chr != '_' {
                $i = $i * 10
                if $chr >= '0' & $chr <= '9' {
                    $i += extend_s($chr) - '0'
                } else if $offset == 0 & $chr == '-' {
                } else {
                    $add_error($Error_LiteralToInt, $token)
                }
            }
            $offset += 1
        }
    }
    if $get_chr($string, 0) == '-' { 
        $i = -$i
    }
    $i
}

func $str_to_f32($string i32) f32 {
    demote($str_to_f64($string))
}

func $str_to_f64($string i32) f64 {
    local mut $f f64 = 0
    local $length i32 = $string[$string_length]
    local mut $offset i32 = 0
    local mut $d f64 = 1
    local mut $isAfterDot i32 = 0
    loop {
        br_if $offset >= $length 
        local $chr i32 = $get_chr($string, $offset)
        if $chr == '.' {
            $isAfterDot = 1
        } else {
            if $isAfterDot { 
                $f += convert_s_i32($chr - '0') / $d    ;; TODO
                $d = $d * 10
            } else {
                if $chr >= '0' & $chr <= '9' {
                    $f = $f * 10 + convert_s_i32($chr - '0')    ;; TODO
                }
            }
        }
        $offset += 1
    }
    if $get_chr($string, 0) == '-' { 
        $f = -$f 
    }
    $f
}

func $uleb_length($i i32) i32 {
    if $i >+ 268_435_456 {
        return 5
    } else if $i >+ 2_097_151 { 
        return 4 
    } else if $i >+ 16_383 {
        return 3
    } else if $i >+ 127 {
        return 2
    }
    1
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Strings

func $new_string($length i32) i32 {
    local $debug i32 = $allocate(4)
    $debug[$debug_magic] = 7 - $DEC0DE
    local $string i32 = $allocate($string_size)
    $string[$string_capacity] = $length
    $string[$string_length] = $length
    $string[$string_bytes] = $allocate($length)
    $string
}

func $new_empty_string($max_length i32) i32 {
    local $debug i32 = $allocate(4)
    $debug[$debug_magic] = 7 - $DEC0DE
    local $string i32 = $allocate($string_size)
    $string[$string_capacity] = $max_length
    $string[$string_length] = 0
    $string[$string_bytes] = $allocate($max_length)
    $string
}

func $append_str($string i32, $append i32) {
    local $append_length i32 = $append[$string_length]
    local $max_length i32 = $string[$string_capacity]
    local mut $offset i32 = 0
    loop {
        br_if $offset >= $append_length 
        $append_byte($string, $get_chr($append, $offset))
        br_if $string[$string_length] >= $max_length
        $offset += 1
    }
}

func $append_i32_as_str($string i32, $i i32) {
    local $length i32 = $string[$string_length]
    local $append_length i32 = $decimal_str_length($i)
    local mut $offset i32 = $append_length
    if $length + $append_length <= $string[$string_capacity] {
        loop {
            br_if !$offset 
            local $chr i32 = '0' + $i % 10
            $offset = $offset - 1
            $set_chr($string, $length + $offset, $chr)
            $i = $i / 10
            br_if !$i
        }    
        $string[$string_length] = $length + $append_length
    }
}

func $i32_to_str($i i32) i32 {
    local $S i32 = $new_empty_string(12)
    $append_i32_as_str($S, $i)
    $S
}

func $append_i32($string i32, $i i32) {
    local $length i32 = $string[$string_length]
    if $length + 4 <= $string[$string_capacity] {
        $string[$string_bytes][$length] = $i
        $string[$string_length] = $length + 4
    }
}

func $append_f32($string i32, $f f32) {
    local $length i32 = $string[$string_length]
    if $length + 4 <= $string[$string_capacity] {
        $string[$string_bytes][$length] = $f
        $string[$string_length] = $length + 4
    }
}

func $append_f64($string i32, $f f64) {
    local $length i32 = $string[$string_length]
    if $length + 8 <= $string[$string_capacity] {
        $string[$string_bytes][$length] = $f
        $string[$string_length] = $length + 8
    }
}

func $append_byte($string i32, $i i32) {
    local $length i32 = $string[$string_length]
    if $length + 1 <= $string[$string_capacity] {
        i32.store8($string[$string_bytes] + $length, $i)
        $string[$string_length] = $length + 1
    }
}

func $append_uleb($string i32, $i i32) {
    local $length i32 = $string[$string_length]
    if $length + $uleb_length($i) <= $string[$string_capacity] {
        loop {
            br_if !($i >=+ 128) 
            local $chr i32 = 128 + ($i % 128)
            $append_byte($string, $chr)
            $i = $i >>+ 7
        }
        $append_byte($string, $i)
    }
}

func $append_sleb32($string i32, $i i32) {
    $append_sleb64($string, extend_s($i))
}

func $append_sleb64($string i32, mut $i i64) {
    if $i >= 0 { 
        loop {
            br_if $i < 64
            $append_byte($string, wrap(128 + ($i % 128)))
            $i = $i >> 7
        }
        $append_byte($string, wrap($i))
    } else {
        loop {
            br_if $i >= -64
            $append_byte($string, wrap(($i %+ 128) - 128))
            $i = $i >> 7
        }
        $append_byte($string, wrap($i - 128))
    }
}

func $offset_tail($string i32, $start i32, $offset i32) {
    if $offset > 0 {
        if $string[$string_length] + $offset <= $string[$string_capacity] {
            $string[$string_length] = $string[$string_length] + $offset
            local mut $copy i32 = $string[$string_length]
            loop {
                br_if $copy < $start 
                $set_chr($string, $copy + $offset, $get_chr($string, $copy))
                $copy = $copy - 1
            }
        }
    }
}

func $decimal_str_length($i i32) i32 {
    local mut $length i32 = 1
    loop {
        $i = $i / 10
        br_if !$i
        $length += 1
    }
    $length
}

func $get_chr($string i32, $offset i32) i32 {
    i32.load8_u($string[$string_bytes] + $offset)
}

func $set_chr($string i32, $offset i32, $chr i32) {
    i32.store8($string[$string_bytes] + $offset, $chr)
}

func $sub_str($string i32, $offset i32, mut $length i32) i32 {
    if $offset >= $string[$string_length] {
        $length = 0
    }
    if $offset + $length >= $string[$string_length] {
        $length = $string[$string_length] - $offset
    }
    local $result i32 = $new_string($length)
    loop {
        br_if $length <= 0 
        $length -= 1
        if $offset + $length >= 0 {
            $set_chr($result, $length, $get_chr($string, $offset + $length))
        }
    }
    $result
}

func $str_eq($A i32, $B i32) i32 {
    local $length i32 = $A[$string_length]
    if $length == $B[$string_length] {
        local mut $offset i32 = 0
        loop {
            br_if $offset >= $length 
            if $get_chr($A, $offset) != $get_chr($B, $offset) {
                return 0
            }
            $offset += 1
        }
    } else {
        return 0
    }
    1
}

func $hex_chr_to_i32($chr i32) i32 {
    if $chr >= '0' & $chr <= '9' {
        return $chr - '0'
    } else if $chr >= 'a' & $chr <= 'f' {
        return $chr - 'a' + 10
    } else if $chr >= 'A' & $chr <= 'F' {
        return $chr - 'A' + 10
    }
    0
}

;; Strings may contain escaped hex bytes for example "\5a" "Z"
func $decode_str($S i32) {
    local $length i32 = $S[$string_length]
    local mut $i i32 = 0
    local mut $o i32 = 0
    loop {
        br_if $i >= $length 
        if $get_chr($S, $i) == '\' { 
            $i += 1
            if $is_number($get_chr($S, $i), 1) & $is_number($get_chr($S, $i + 1), 1) {
                local mut $chr i32 = $hex_chr_to_i32($get_chr($S, $i))
                $chr *= 16
                $chr += $hex_chr_to_i32($get_chr($S, $i + 1))
                $set_chr($S, $o, $chr)
                $i += 1
            }
        } else if $i > $o {
            $set_chr($S, $o, $get_chr($S, $i))
        }
        $i += 1
        $o += 1
    }
    $S[$string_length] = $o
    loop {
        br_if $o >= $length 
        $set_chr($S, $o, 0)
        $o += 1
    }
}

func $is_number($chr i32, $hexNum i32) i32 {
    if $chr >= '0' & $chr <= '9' {
        return 1
    } else if $hexNum {
        if ($chr >= 'a' & $chr <= 'f') | ($chr >= 'A' & $chr <= 'F') { 
            return 1
        }
    }
    0
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Lists

func $new_list() i32 {
    local $list i32 = $allocate($list_size)
    $list[$list_dec0de] = 4 - $DEC0DE
    $list
}

func $list_add($list i32, $Object i32) {
    local $item i32 = $allocate($item_size)
    $item[$item_dec0de] = 5 - $DEC0DE
    $item[$item_Object] = $Object
    if !i32.$list[$list_First] {
        $list[$list_First] = $item
    } else {
        $list[$list_Last][$item_Next] = $item
    }
    $list[$list_Last] = $item
    i32.$list[$list_count] = $list[$list_count] + 1
}

func $list_add_name($list i32, $Object i32, $name i32) {
    local $item i32 = $allocate($item_size)
    $item[$item_dec0de] = 5 - $DEC0DE
    $item[$item_Object] = $Object
    $item[$item_Name] = $name
    if !i32.$list[$list_First] {
        $list[$list_First] = $item
    } else {
        $list[$list_Last][$item_Next] = $item
    }
    $list[$list_Last] = $item
    i32.$list[$list_count] = $list[$list_count] + 1
}

;; Find a $string in a $list & return the object
func $list_search($list i32, $FindName i32) i32 {
    local mut $item i32 = $list[$list_First]
    loop {
        br_if !$item 
        if $str_eq($item[$item_Name], $FindName) {
            return $item[$item_Object]
        }
        $item = $item[$item_Next]
    }
    0
}

;; Find a $string in a $list & return the index
func $index_list_search($list i32, $FindName i32) i32 {
    local mut $item i32 = $list[$list_First]
    local mut $index i32 = 0
    loop {
        br_if !$item
        if $str_eq($item[$item_Name], $FindName) {
            return $index
        }
        $item = $item[$item_Next]
        $index += 1
    }
    -1
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Memory management

func $allocate($length i32) i32 {
    $HEAP
    $HEAP += $length
    if $HEAP % $ALIGNMENT {
        $HEAP += $ALIGNMENT - $HEAP % $ALIGNMENT
    }
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Globals

global mut $WASM               i32 = 0  ;; Output Binary (string)
global mut $HEAP               i32 = 0  ;; Next free memory location
global mut $TOKEN_LIST         i32 = 0
global mut $CURRENT_TOKEN_ITEM i32 = 0
global mut $CURRENT_TOKEN      i32 = 0
global mut $NEXT_TOKEN         i32 = 0
global mut $CURRENT_SCOPE      i32 = 0
global mut $GLOBAL_SCOPE       i32 = 0
global mut $GLOBAL_COUNT       i32 = 0
global mut $EXPORT_LIST        i32 = 0
global mut $DATA_LIST          i32 = 0
global mut $FN_INDEX           i32 = 0  ;; Next function index number
global mut $CURRENT_FN_NODE    i32 = 0
global mut $TYPE_LIST          i32 = 0
global mut $FN_TYPE_LIST       i32 = 0
global mut $OFFSET             i32 = 0

;; Token struct offsets
global $token_dec0de i32 = 0  ;; debugging marker
global $token_kind   i32 = 4
global $token_Value  i32 = 8
global $token_line   i32 = 12
global $token_column i32 = 16
global $token_size   i32 = 20

global $scope_dec0de     i32 = 0   ;; debugging marker
global $scope_Node       i32 = 4
global $scope_index      i32 = 8
global $scope_Parent     i32 = 12
global $scope_Symbols    i32 = 16
global $scope_localIndex i32 = 20
global $scope_size       i32 = 24

;; Node struct offsets
global $node_dec0de     i32 = 0   ;; debugging marker
global $node_kind       i32 = 4   ;; Node enum
global $node_index      i32 = 8   ;; Zero based index number for funs, variables, parameters
global $node_String     i32 = 12  ;; Literal value, or fn/var/Parameter name
global $node_Scope      i32 = 16  ;; scope for Module/Block/loop/fun used for name resolution
global $node_ANode      i32 = 20  ;; Binary left, Call fn, return Expression, Block, or fun body
global $node_BNode      i32 = 24  ;; Binary/Unary right, else Block, fun return, Variable assignment
global $node_CNode      i32 = 28  ;; If statement condition node
global $node_Nodes      i32 = 32  ;; list of child Node for Module/Block, or fun locals
global $node_ParamNodes i32 = 36  ;; list of params for Call/fn
global $node_type       i32 = 40  ;; TokenType enum
global $node_dataType   i32 = 44  ;; inferred data type
global $node_Token      i32 = 48
global $node_assigns    i32 = 52
global $node_size       i32 = 56

;; String structs
global $str_bytes  i32 = 0
global $str_length i32 = 4
global $str_size   i32 = 8

global $string_bytes    i32 = 0
global $string_length   i32 = 4
global $string_capacity i32 = 8
global $string_size     i32 = 12

;; List structs
global $list_dec0de i32 = 0  ;; debugging marker
global $list_First  i32 = 4
global $list_Last   i32 = 8
global $list_count  i32 = 12
global $list_size   i32 = 16

global $item_dec0de i32 = 0  ;; debugging marker
global $item_Next   i32 = 4
global $item_Object i32 = 8
global $item_Name   i32 = 12   global $item_number i32 = 12
global $item_size   i32 = 16

;; Magic number -0x00dec0de - used for debugging
global $DEC0DE      i32 = 557785600
global $debug_magic i32 = 0
global $ALIGNMENT   i32 = 4

;; Enums
global $TokenType_NumLiteral    i32 = 2
global $TokenType_Id            i32 = 3
global $TokenType_StrLiteral    i32 = 4
global $TokenType_CharLiteral   i32 = 5
global $TokenType_LBrack        i32 = 6  ;; Symbols
global $TokenType_RBrack        i32 = 7
global $TokenType_LParen        i32 = 8 
global $TokenType_RParen        i32 = 9
global $TokenType_LBrace        i32 = 10
global $TokenType_RBrace        i32 = 11
global $TokenType_Comma         i32 = 12
global $TokenType_Dot           i32 = 13
global $TokenType_MinPrecedence i32 = 20  ;; Operators
global $TokenType_Set           i32 = 21
global $TokenType_Add_Set       i32 = 22
global $TokenType_Sub_Set       i32 = 23
global $TokenType_Mul_Set       i32 = 24
global $TokenType_Div_Set       i32 = 25
global $TokenType_Or            i32 = 32
global $TokenType_Xor           i32 = 33
global $TokenType_And           i32 = 34
global $TokenType_Eq            i32 = 35
global $TokenType_Ne            i32 = 36
global $TokenType_Lt            i32 = 37
global $TokenType_Ltu           i32 = 38
global $TokenType_Lte           i32 = 39
global $TokenType_Leu           i32 = 40
global $TokenType_Gt            i32 = 41
global $TokenType_Gtu           i32 = 42
global $TokenType_Gte           i32 = 43
global $TokenType_Geu           i32 = 44
global $TokenType_Shl           i32 = 45
global $TokenType_Shr           i32 = 46
global $TokenType_Shru          i32 = 47
global $TokenType_Add           i32 = 48
global $TokenType_Sub           i32 = 49
global $TokenType_Mul           i32 = 50
global $TokenType_Div           i32 = 51
global $TokenType_Divu          i32 = 52
global $TokenType_Rem           i32 = 53
global $TokenType_Remu          i32 = 54
global $TokenType_Eqz           i32 = 55
global $TokenType_Min           i32 = 56
global $TokenType_Max           i32 = 57
global $TokenType_CopySign      i32 = 58
global $TokenType_Rotl          i32 = 59  ;; TODO
global $TokenType_Rotr          i32 = 60  ;; TODO
global $TokenType_Abs           i32 = 61
global $TokenType_Neg           i32 = 62  ;; TODO
global $TokenType_Ceil          i32 = 63  ;; TODO
global $TokenType_Floor         i32 = 64  ;; TODO
global $TokenType_Trunc         i32 = 65  ;; TODO
global $TokenType_Round         i32 = 66  ;; TODO
global $TokenType_Sqrt          i32 = 67  ;; TODO
global $TokenType_Clz           i32 = 68  ;; TODO
global $TokenType_Ctz           i32 = 69  ;; TODO
global $TokenType_Popcnt        i32 = 70  ;; TODO
global $TokenType_F64           i32 = 80  ;; Data types
global $TokenType_F32           i32 = 81
global $TokenType_I64           i32 = 82
global $TokenType_I32           i32 = 83
global $TokenType_Export        i32 = 90  ;; Keywords
global $TokenType_Mut           i32 = 91
global $TokenType_Global        i32 = 92
global $TokenType_Func          i32 = 94
global $TokenType_Local         i32 = 96
global $TokenType_If            i32 = 97
global $TokenType_Else          i32 = 98
global $TokenType_Loop          i32 = 99
global $TokenType_Continue      i32 = 101
global $TokenType_Br            i32 = 102
global $TokenType_Br_If         i32 = 103
global $TokenType_Return        i32 = 104
global $TokenType_Builtin       i32 = 105
global $TokenType_Nop           i32 = 106
global $TokenType_Unreachable   i32 = 107
global $TokenType_Br_Table      i32 = 108
global $TokenType_Call_Indirect i32 = 109
global $TokenType_Drop          i32 = 110
global $TokenType_Select        i32 = 111

;; Enum list of node types
global $Node_Module      i32 = 1  ;; The root node
global $Node_Data        i32 = 2
global $Node_Return      i32 = 3
global $Node_Fun         i32 = 4 
global $Node_Parameter   i32 = 5
global $Node_Expression  i32 = 6
global $Node_Call        i32 = 7
global $Node_Block       i32 = 8
global $Node_Variable    i32 = 9
global $Node_Identifier  i32 = 10
global $Node_Literal     i32 = 11
global $Node_Assign      i32 = 12
global $Node_Binary      i32 = 13
global $Node_Unary       i32 = 14
global $Node_DotLoad     i32 = 15
global $Node_DotStore    i32 = 16
global $Node_Iif         i32 = 17
global $Node_If          i32 = 18
global $Node_Loop        i32 = 19
global $Node_Br          i32 = 20
global $Node_Br_If       i32 = 21
global $Node_Continue    i32 = 22
global $Node_Drop        i32 = 23
global $Node_Instruction i32 = 24
global $Node_Builtin     i32 = 25

global $Error_DuplicateName   i32 = 121
global $Error_InvalidToken    i32 = 122
global $Error_MissingToken    i32 = 123
global $Error_Expression      i32 = 124
global $Error_TypeMismatchA   i32 = 125
global $Error_TypeMismatchB   i32 = 126
global $Error_RootStatement   i32 = 127
global $Error_TypeNotInferred i32 = 128
global $Error_NotDeclared     i32 = 129
global $Error_LiteralToInt    i32 = 110
global $Error_BlockStatement  i32 = 111
global $Error_EmitNode        i32 = 112
global $Error_InvalidOperator i32 = 113
global $Error_NotMutable      i32 = 114
global $Error_NoIdentifiers   i32 = 115
global $Error_NoParamList     i32 = 116
global $Error_ParseAssignOp   i32 = 117
global $Error_BuiltinType     i32 = 118

;; Pierre Rossouw https://github.com/PierreRossouw/
