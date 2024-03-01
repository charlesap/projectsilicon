#!/bin/bash
pushd . 2>&1 >> /dev/null
cd obnc
echo
echo
echo "in obnc"
obnc oac.Mod
echo "result:"
echo $?
popd 2>&1 >> /dev/null
pushd . 2>&1 >> /dev/null
cd interim
echo
echo
echo "in interim"
#rm tmp.entitlements
#/usr/libexec/PlistBuddy -c "Add :com.apple.security.get-task-allow bool true" tmp.entitlements
#/usr/libexec/PlistBuddy -c "Add :com.apple.security.cs.allow-jit bool true" tmp.entitlements
#/usr/libexec/PlistBuddy -c "Add :com.apple.security.cs.allow-unsigned-executable-memory bool true" tmp.entitlements
#/usr/libexec/PlistBuddy -c "Add :com.apple.security.cs.disable-library-validation bool true" tmp.entitlements
#/usr/libexec/PlistBuddy -c "Add :com.apple.security.cs.disable-executable-page-protection bool true" tmp.entitlements

# runtime for -mso
#../obnc/oac -s Kernel.Mod
#../obnc/oac -s FileDir.Mod
#../obnc/oac -s Files.Mod
#../obnc/oac -s Modules.Mod

../obnc/oac -es E.Mod; chmod 755 E.a64-lin
../obnc/oac -ms E.Mod; chmod 755 E.a64-osx
codesign -s - E.a64-osx
#objdump -l -j __k000 E.bin | grep '\.\.\.\|^10' | awk '{print $1" "$2;}'
#objdump -l -j __d000 E.bin | grep '\.\.\.\|^10' | awk '{print $1" "$2;}'
#objdump -d -j __c000 E.bin | grep '\.\.\.\|^10'

../obnc/oac -es F.Mod; chmod 755 F.a64-lin
../obnc/oac -ms F.Mod; chmod 755 F.a64-osx
codesign -s - F.a64-osx
#objdump -l -j __k000 F.bin | grep '\.\.\.\|^10' | awk '{print $1" "$2;}'
#objdump -l -j __d000 F.bin | grep '\.\.\.\|^10' | awk '{print $1" "$2;}'
#objdump -d -j __c000 F.bin | grep '\.\.\.\|^10'

../obnc/oac -es G.Mod; chmod 755 G.a64-lin
../obnc/oac -ms G.Mod; chmod 755 G.a64-osx
codesign -s - G.a64-osx
#objdump -l -j __k000 G.bin | grep '\.\.\.\|^10' | awk '{print $1" "$2;}'
#objdump -l -j __d000 G.bin | grep '\.\.\.\|^10' | awk '{print $1" "$2;}'
#objdump -d -j __c000 G.bin | grep '\.\.\.\|^10'

../obnc/oac -es H.Mod; chmod 755 H.a64-lin
../obnc/oac -ms H.Mod; chmod 755 H.a64-osx
codesign -s - H.a64-osx
#objdump -l -j __k000 H.bin | grep '\.\.\.\|^10' | awk '{print $1" "$2;}'
#objdump -l -j __d000 H.bin | grep '\.\.\.\|^10' | awk '{print $1" "$2;}'
#objdump -d -j __c000 H.bin | grep '\.\.\.\|^10'

../obnc/oac -es I.Mod; chmod 755 I.a64-lin
../obnc/oac -ms I.Mod; chmod 755 I.a64-osx
codesign -s - I.a64-osx
#objdump -l -j __k000 I.bin | grep '\.\.\.\|^10' | awk '{print $1" "$2;}'
#objdump -l -j __d000 I.bin | grep '\.\.\.\|^10' | awk '{print $1" "$2;}'
#objdump -d -j __c000 I.bin | grep '\.\.\.\|^10'

../obnc/oac -s Out.Mod

../obnc/oac -es J.Mod; chmod 755 J.a64-lin
../obnc/oac -ms J.Mod; chmod 755 J.a64-osx
codesign -s - J.a64-osx
#objdump -l -j __k000 J.bin | grep '\.\.\.\|^10' | awk '{print $1" "$2;}'
#objdump -l -j __d000 J.bin | grep '\.\.\.\|^10' | awk '{print $1" "$2;}'
#objdump -d -j __c000 J.bin | grep '\.\.\.\|^10'

../obnc/oac -es K.Mod; chmod 755 K.a64-lin
../obnc/oac -ms K.Mod; chmod 755 K.a64-osx
codesign -s - K.a64-osx
#codesign -s - --entitlements tmp.entitlements K.bin
objdump -l -j __k000 K.a64-osx | grep '\.\.\.\|^10' | awk '{print $1" "$2;}'
objdump -l -j __d000 K.a64-osx | grep '\.\.\.\|^10' | awk '{print $1" "$2;}'
objdump -d -j __c000 K.a64-osx | grep '\.\.\.\|^10'

#../obnc/oac -ms L.Mod
#codesign -s - L.bin
##codesign -s - --entitlements tmp.entitlements L.bin
#objdump -l -j __k000 L.bin | grep '\.\.\.\|^10' | awk '{print $1" "$2;}'
#objdump -l -j __d000 L.bin | grep '\.\.\.\|^10' | awk '{print $1" "$2;}'
#objdump -d -j __c000 L.bin | grep '\.\.\.\|^10'


#../obnc/oac -s V.Mod
#codesign -s - V.bin
#objdump -d -j __c000 V.bin

#../obnc/oac -s R.Mod
#codesign -s - R.bin
#objdump -d -j __c000 R.bin

#../obnc/oac -ms M.Mod
#codesign -s - M.bin
#objdump -d -j __c000 M.bin
#codesign -s - Out.bin
#objdump -d -j __c000 Out.bin
#../obnc/oac -s Files.Mod
#codesign -s - Files.bin
#objdump -d -j __c000 Files.bin

../obnc/oac -s Fonts.Mod
../obnc/oac -s Texts.Mod
../obnc/oac -s OAS.Mod
../obnc/oac -s OAB.Mod
../obnc/oac -s OAG.Mod
../obnc/oac -s Elf.Mod
../obnc/oac -s Macho.Mod
../obnc/oac -s OAL.Mod
../obnc/oac -s OAP.Mod
../obnc/oac -s oac.Mod
#as exit.asm -o exit.o       #dummy compiler until interim one works
#ld exit.o -L /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib/ -lSystem -o oac




popd 2>&1 >> /dev/null

#pushd . 2>&1 >> /dev/null
#cd native
#echo
#echo
#echo "in native"
#../interim/oac -s Out.Mod
#../interim/oac -s Files.Mod
#../interim/oac -s Fonts.Mod
#../interim/oac -s Texts.Mod
#../interim/oac -s OAS.Mod
#../interim/oac -s OAB.Mod
#../interim/oac -s OAG.Mod
#../interim/oac -s Macho.Mod
#../interim/oac -s OAL.Mod
#../interim/oac -s OAP.Mod
#../interim/oac -ms oac.Mod
#popd 2>&1 >> /dev/null


