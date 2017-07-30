# compile.dwasm
dWasm is a simple and readable WebAssembly language with a self-hosted compiler

Try it out at https://pierrerossouw.github.io/dwasm/

### Using the compiler
WebAssembly does not have IO so some JavaScript is needed to use the compiler.  
Write the source code to the shared memory starting at byte 12.  
Write the length as a 32 bit int in bytes 8-11.  
The compiler will return a memory location for the compiled binary.  

### Roadmap
- Implement rest of WebAssembly spec
- Better playground
- Inline string support
- Decompiler to dwasm

### Updates
2017-07-30: Support tee_local, added some compiler error messages   
2017-07-29: Specify data types to load or store using a dotted suffix:  a.b.f32   
2017-07-27: Syntactic sugar: a.b.c.d := e ->  storeX(load32(load32(a + b) + c) + d, e)  
2017-07-26: Syntactic sugar: a.b.c.d  ->  loadX(load32(load32(a + b) + c) + d)  
2017-07-25: Named exports of functions and memory. Wasm data section support   
2017-07-23: i64, f32 and f64 types. All native types are now supported  
2017-07-21: Support bool as a synonym for i32, added true and false keywords  
2017-07-10: Inline hex binary literals - for example use x00 to trap or x01 for NOP  
2017-07-09: Support elseif and negative integers.  
2017-07-05: Added a play area to index.html, fixed signed LEB128 output for negative ints.  
2017-07-04: dWasm now successfully compiles itself! The output binary matches the source binary.  
2017-07-03: Fixed several bugs, improved debugging symbols.  
2017-06-29: Added http://prismjs.com/ syntax highlighting.  

### Useful links
WebAssembly binary specification: https://github.com/WebAssembly/design/blob/master/BinaryEncoding.md  
The WebAssembly Binary Toolkit https://github.com/WebAssembly/wabt  
Originally based on https://github.com/maierfelix/mini-c by Felix Maier http://www.felixmaier.info/
