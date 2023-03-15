build: deps OS.o loader.o

deps:
	perl -MCPU::Emulator::Z80 -MCPU::Z80::Assembler -e0 || cpanm CPU::Emulator::Z80 CPU::Z80::Assembler

OS_nmi.bin: OS_nmi.z80 _macros.z80 _global_constants.z80 _OS_constants.z80
	z80masm OS_nmi.z80 OS_nmi.bin

OS.bin: OS.z80 _macros.z80 _global_constants.z80
	z80masm OS.z80 OS.bin

_OS_constants.z80: OS.bin
	z80masm OS.z80 /dev/null 2>/dev/null|grep -iE ^0x[0-9a-f]{4}:\ \\w+:|awk '{print $$2 " = " $$1}'|sed 's/://g' > _OS_constants.z80

OS.o: OS.bin OS_nmi.bin
	./z80link OS.o OS.z80 OS.bin OS_nmi.z80 OS_nmi.bin

loader.bin: loader.z80 _global_constants.z80
	z80masm loader.z80 loader.bin

loader.o: loader.bin
	./z80link loader.o loader.z80 loader.bin
