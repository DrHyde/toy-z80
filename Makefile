build: deps OS.o loader.o

deps:
	cpanm CPU::Emulator::Z80 CPU::Z80::Assembler

OS.o: OS.z80 _macros.z80 _constants.z80
	z80masm OS.z80 OS.o

loader.o: loader.z80 _constants.z80
	z80masm loader.z80 loader.o
