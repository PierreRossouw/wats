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

Global variables can be mutable or static. They can appear in any order together with the Functions at root level.

```
global $STATIC i32 = 42
global mut $current_year i32 = 2019
```
