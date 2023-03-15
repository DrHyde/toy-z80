build: deps OS.o loader.o

clean:
	rm *.o

deps:
	perl -MCPU::Emulator::Z80 -e0 || cpanm CPU::Emulator::Z80

OS.o: OS.z80 _macros.z80 _constants.z80
	pasmo OS.z80 OS.o

loader.o: loader.z80 _constants.z80
	pasmo loader.z80 loader.o
