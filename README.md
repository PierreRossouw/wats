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

Data Types
----------

```
i32
i64
f32
f64
```




