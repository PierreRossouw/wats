# compile.wats
A quick and simple and WebAssembly self-hosted compiler. The language is just the standard .WAT keywords and conventions with a bit of syntactic sugar to make it easier on the eyes. 

Try it out at https://pierrerossouw.github.io/wats

### Using the compiler
WebAssembly does not have IO so some JavaScript is needed to use the compiler. Write the source code to the shared memory as a null-terminated string and the compiler will return a memory location for the compiled binary.

# Disassembler
Coming soon

# Language reference

### Data Types

Wasm has four native data types. i32 also serves as a memory pointer or as a binary type.

```
i32
i64
f32
f64
```

### Identifiers

All identifiers must start with a dollar sign. This includes names of functions, variables, and globals.

```
$main()
$i
$GLOBAL_VAR
```

### Comments

Comments are treated as whitespace

```wat
;; Single line comments start anywhere and run until a linebreak
(; Multi line comments 
   are also supported. ;)
```

### Integers and Floats

Both decimal and 0x prefixed hex integers are supported. Underscores can be used between digits.
Single-quoted characters also converts to integers.
Decimal floats work, hex float literals not yet implemented.

```
1000
1_000
0x0f
0.25
'Z'  ;; 90
```

### Functions

Functions can not be nested. They optionally return a value of one of the four native data types. 
The export keyword adds the function to the module's export list.

```wat
export func $main() i32 {
    $do_nothing() ;; call the other function
    40 + 2  ;; should return 42 
}

func $do_nothing() {
}
```

### Globals

Global variables are static unless marked using the mut keyword. They can appear in any order together with the Functions at root level.

```wat
global $STATIC i32 = 42
global mut $current_year = 2019
```

### Locals

Local variables are statuc unless marked as mutable using the mut modifier. They can appear in any part of a function.

```wat
func $f() {
    local mut $variable i32 = 1
    $variable = 10
}
```

### Control Instructions

Loops run until it reaches a br or evaluates to non-zero on a br_if statement

```wat
$i = 0
loop {
    br_if $i > 10 
    $i += 1
}

loop {
    br  ;; exit the loop immediately
}  
```

If statements have an optional else clause. Wasm also supports returning a value but this is not yet fully supported in this compiler

```wat
if $pigs_fly {
    ;; do stuff
} else {
    ;; do other stuff
}

i32.if $pickfirst {   ;; data type decoration is currently required
    42
} else {
    44
}
```

### Instructions

```wat
$var = 42     ;; Assignment of local or global variables (must be mutable)
$var += 1     ;; Shorthand for $var = $var + 1
-=  /=  *=    ;; other supported shorthand assignment operators

+ - / * %     ;; add sub mul div_s rem_s
& | ^ << >>   ;; and or xor shl shr_s
== !=         ;; eq ne
! < > <= >=   ;; eqz lt_s gt_s le_s ge_s

<+ >+ <=+ >=+   ;; lt_u gt_u le_u ge_u  (unsigned integer comparison)
/+ %+ >>+       ;; div_u rem_u shr_u

current_memory() i32   ;; Memory ops
grow_memory(i32) i32

load(i32) i32         ;; also: load8_s load8_u load16_s load16_u
                      ;;       load32_s load32_u
store(i32, i32)       ;; also: store8 store16 store32

wrap extend_s extend_u   ;; i32 <--> i64 conversions
demote promote wrap      ;; float conversions
trunc_s trunc_u
convert_s convert_u
```

### Memory access shortcuts

The bracket-load and bracket-save shortcuts are handy for common memory access patters. They allow you to use pointers almost like structs.

```wat
global $list_first_item i32 = 0   ;; memory offsets we want to use
global $list_count i32      = 4   ;; i32s take 4 bytes, 
global $list_stuct_size i32 = 8   ;; so we need 8 bytes for a $list

...

$item = $MyList[$list_first_item]   ;; $item = i32.load($MyList + $list_first_item)
$MyList[$list_count] = 2            ;; i32.store($MyList + $list_count, 2)
```


