# using the interim compiler to create the penultimate native oac compiler from source files

Invoke the built compiler like this:

`../obnc/oac -sv <module>.Mod` to create object files for each required module and then

`../obnc/oac -sov oac.Mod` to create the mach-o penultimate native compiler using the intermediate compiler.

