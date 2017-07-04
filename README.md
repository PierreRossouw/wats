# Wasmat
Wasmat is a toy language with a self-compiling compiler to WebAssembly

Check out the wasmat source code at https://pierrerossouw.github.io/Wasmat/

### Using the compiler
WebAssembly does not have IO so some JavaScript is needed to use the compiler.  
Write the source code to the shared memory starting at byte 8.  
Write the length as a 32 bit int in bytes 4-7.  
The compiler will return a memory location for the compiled binary.  

### Updates
2017-07-04: Wasmat now successfully compiles itself! The output binary matches the source binary.  
2017-07-03: Fixed several bugs, improved debugging symbols.  
2017-06-29: Modified to use https://github.com/dracula/dracula-theme/  
2017-06-29: Added http://prismjs.com/ syntax highlighting.  

The wasmat compiler is based on https://github.com/maierfelix/momo by Felix Maier http://www.felixmaier.info/
