#!/bin/bash
# Assumes that the following files are present in this directory
# - crt0.s 	: basic runtime to jump to beginning of function
# - riscv32.ld 	: linker script specifying memory

riscv32-unknown-elf-gcc -g -ffreestanding -O0 -Wl,--gc-sections \
    -nostartfiles -nostdlib -nodefaultlibs -Wl,-T,riscv32.ld \
    crt0.s  $@ -o out.elf

riscv32-unknown-elf-objcopy -O binary out.elf out.bin
hexdump -e '/4 "%08X\n"' out.bin

# Command below is only for reference to help you debug if necessary
riscv32-unknown-elf-objdump -d -S -Mnumeric,no-aliases out.elf  > out.src
#awk '{print $2}' out.dump

