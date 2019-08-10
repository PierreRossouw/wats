# compile.wats
A quick and simple and WebAssembly self-hosted compiler. The language is just the standard .WAT keywords and conventions with a bit of syntactic sugar to make it easier on the eyes. 

Try it out at https://pierrerossouw.github.io/wats

### Using the compiler
WebAssembly does not have IO so some JavaScript is needed to use the compiler  
Write the source code to the shared memory starting at byte 12  
Write the length as a 32 bit int in bytes 8-11  
The compiler will return a memory location for the compiled binary  

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

```
export func $main() i32 {
    $do_nothing() ;; call the other function
    40 + 2  ;; should return 42 
}

func $do_nothing() {
}
```

### Globals

Global variables are static unless marked using the mut keyword. They can appear in any order together with the Functions at root level.

```
global $STATIC i32 = 42
global mut $current_year = 2019
```

### Locals

Local variables are statuc unless marked as mutable using the mut modifier. They can appear in any part of a function.

```
func $f() {
    local mut $variable i32 = 1
    $variable = 10
}
```

### Control Instructions

Loops run until it reaches a br or evaluates to non-zero on a br_if statement

```
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

```
if $pigs_fly {
    ;; do stuff
} else {
    ;; do other stuff
}

i32.if $pickfirst {  ;; The data type decoration requires
    42
} else {
    44
}
```


### Instructions

```
$var = 42  ;; Assignment of local or global variables (must be mutable)
$var += 1  ;; Shortened assignment statement. Also supports  -=  /=  *=
$var = 40 / 10 + 4  ;; 8
... TODO
```
