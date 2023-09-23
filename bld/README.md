# Bld
Linuz or Mac Compiler for Oberon

Requires the obnc Oberon to C translater from http://miasap.se/obnc/

Expects a 64-bit INTEGER and REAL, e.g. in /usr/local/include/obnc/OBNCConfig.h set the following:
```
#ifndef OBNC_CONFIG_C_INT_TYPE
#define OBNC_CONFIG_C_INT_TYPE OBNC_CONFIG_LONG_LONG
#endif

#ifndef OBNC_CONFIG_C_REAL_TYPE
#define OBNC_CONFIG_C_REAL_TYPE OBNC_CONFIG_LONG_DOUBLE
#endif
```

#On an Apple Silicon Mac


#Using osc

With obnc configured for 64-bit then:

`obnc osc.Mod`

That should recursively build the osc compiler.

Invoke the built compiler like this:

`./osc -v M.mod`

to build M.Mod for the Arm 64-bit architecture.
