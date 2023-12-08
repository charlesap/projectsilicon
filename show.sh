#!/usr/bin/env bash

objdump -l -j __k000 $1.bin | grep '\.\.\.\|^10' | awk '{print $1" "$2;}'
objdump -l -j __d000 $1.bin | grep '\.\.\.\|^10' | awk '{print $1" "$2;}'
objdump -d -j __c000 $1.bin | grep '\.\.\.\|^10'

