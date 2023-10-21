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
#../obnc/oac -ms E.Mod
#codesign -s - E.bin
../obnc/oac -ms F.Mod
codesign -s - F.bin
../obnc/oac -ms V.Mod
codesign -s - V.bin
objdump -d -j __c000 V.bin
../obnc/oac -ms M.Mod
codesign -s - M.bin
objdump -d -j __c000 M.bin
../obnc/oac -ms Out.Mod
#codesign -s - Out.bin
#objdump -d -j __c000 Out.bin
../obnc/oac -ms Files.Mod
#codesign -s - Files.bin
#objdump -d -j __c000 Files.bin
../obnc/oac -s Fonts.Mod
../obnc/oac -s Texts.Mod
../obnc/oac -s OAS.Mod
../obnc/oac -s OAB.Mod
../obnc/oac -s OAG.Mod
../obnc/oac -s Macho.Mod
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
../interim/oac -s Macho.Mod
../interim/oac -s OAL.Mod
../interim/oac -s OAP.Mod
../interim/oac -ms oac.Mod
popd 2>&1 >> /dev/null


