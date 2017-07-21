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
2017-07-21: Support bool as a synonym for i32, added true and false keywords  
2017-07-10: Inline hex binary literals - for example use x00 to trap or x01 for NOP  
2017-07-09: Support elseif and negative integers.  
2017-07-05: Added a play area to index.html, fixed signed LEB128 output for negative ints.  
2017-07-04: Wasmat now successfully compiles itself! The output binary matches the source binary.  
2017-07-03: Fixed several bugs, improved debugging symbols.  
2017-06-29: Added http://prismjs.com/ syntax highlighting.  

### Useful links
WebAssembly binary specification: https://github.com/WebAssembly/design/blob/master/BinaryEncoding.md  
The WebAssembly Binary Toolkit https://github.com/WebAssembly/wabt  
Based on https://github.com/maierfelix/mini-c by Felix Maier http://www.felixmaier.info/
