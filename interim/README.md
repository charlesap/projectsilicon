# using obnc to create oac from source files
Linux or Mac Compiler for Oberon

Requires the obnc Oberon to C translater from http://miasap.se/obnc/

Expects a 64-bit INTEGER and REAL

#On an Apple Silicon Mac

brew install bdw-gc
 export CFLAGS="-L/opt/homebrew/Cellar/bdw-gc/8.2.4/include"
 export LDFLAGS="-L/opt/homebrew/Cellar/bdw-gc/8.2.4/lib"
 ./build --c-int-type=longlong --c-real-type=longdouble --prefix=/opt/homebrew

#Using oac

With obnc configured for 64-bit and LDFLAGS set then:

`obnc oac.Mod`

That should recursively build the oac compiler.

Invoke the built compiler like this:

`./oac -v M.mod`

to build M.Mod for the Arm 64-bit architecture.
