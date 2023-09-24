#!/bin/bash
as exit.asm -o exit.o
ld exit.o -L /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib/ -lSystem -o exit

