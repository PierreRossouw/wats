# Wasmat
Wasmat is a toy language with a self-compiling compiler to WebAssembly

Try it out at https://pierrerossouw.github.io/Wasmat/

### Using the compiler
WebAssembly does not have IO so some JavaScript is needed to use the compiler.  
Write the source code to the shared memory starting at byte 12.  
Write the length as a 32 bit int in bytes 8-11.  
The compiler will return a memory location for the compiled binary.  

### Roadmap
- Better playground
- Add support for floats and 64 bit numbers
- Inline string support
- Implement rest of WebAssembly spec
- Decompiler to Wasmat

### Updates
2017-07-09: Support elseif and negative integers.  
2017-07-05: Added a play area to index.html, fixed signed LEB128 output for negative ints.  
2017-07-04: Wasmat now successfully compiles itself! The output binary matches the source binary.  
2017-07-03: Fixed several bugs, improved debugging symbols.  
2017-06-29: Added http://prismjs.com/ syntax highlighting.  

The wasmat compiler is based on https://github.com/maierfelix/momo by Felix Maier http://www.felixmaier.info/
