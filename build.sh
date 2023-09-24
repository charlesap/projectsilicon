#!/bin/bash
pushd . 2>&1 >> /dev/null
cd obnc
echo
echo
echo "in obnc"
obnc oac.Mod
popd 2>&1 >> /dev/null
pushd . 2>&1 >> /dev/null
cd interim
echo
echo
echo "in interim"
../obnc/oac -s Out.Mod
../obnc/oac -s Files.Mod
../obnc/oac -s Fonts.Mod
../obnc/oac -s Texts.Mod
../obnc/oac -s OAS.Mod
../obnc/oac -s OAB.Mod
../obnc/oac -s OAG.Mod
../obnc/oac -s OAL.Mod
../obnc/oac -s OAP.Mod
../obnc/oac -ms oac.Mod
as exit.asm -o exit.o       #dummy compiler until interim one works
ld exit.o -L /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib/ -lSystem -o oac
popd 2>&1 >> /dev/null
pushd . 2>&1 >> /dev/null
cd native
echo
echo
echo "in native"
../interim/oac -s Out.Mod
../interim/oac -s Files.Mod
../interim/oac -s Fonts.Mod
../interim/oac -s Texts.Mod
../interim/oac -s OAS.Mod
../interim/oac -s OAB.Mod
../interim/oac -s OAG.Mod
../interim/oac -s OAL.Mod
../interim/oac -s OAP.Mod
../interim/oac -ms oac.Mod
popd 2>&1 >> /dev/null


