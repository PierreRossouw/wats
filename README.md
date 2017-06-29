# Wasmat
Wasmat is a toy language with a self-compiling compiler to WebAssembly

Using the compiler: 
Write the source code to the shared memory starting at byte 8.
Write the length as a 32 bit int in bytes 4-7. 
The compiler will return a memory location for the compiled binary.

2017-06-29: Added http://prismjs.com/ syntax highlighting. 
Check out the wasmat source code at https://pierrerossouw.github.io/Wasmat/

The wasmat compiler is based on https://github.com/maierfelix/momo by Felix Maier http://www.felixmaier.info/
