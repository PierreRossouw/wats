# compile.rs
A quick and simple and WebAssembly language with a self-hosted compiler. The language syntax looks a bit like Rust but it's closer to C in functionality.

Try it out at https://pierrerossouw.github.io/rswasm

### Using the compiler
WebAssembly does not have IO so some JavaScript is needed to use the compiler  
Write the source code to the shared memory starting at byte 12  
Write the length as a 32 bit int in bytes 8-11  
The compiler will return a memory location for the compiled binary  

### Language reference
Coming soon
