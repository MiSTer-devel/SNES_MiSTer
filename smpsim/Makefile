#
# Makefile
#

SRC=../src
SPC_SRC = $(SRC)/SPC700
SRCS = dpram.vhd aram.vhd audio.vhd $(SPC_SRC)/SPC700_pkg.vhd $(SPC_SRC)/BCDAdj.vhd $(SPC_SRC)/AddSub.vhd $(SPC_SRC)/MulDiv.vhd $(SPC_SRC)/ALU.vhd $(SPC_SRC)/AddrGen.vhd $(SPC_SRC)/MCode.vhd $(SPC_SRC)/SPC700.vhd $(SRC)/SMP.vhd $(SRC)/CEGen.vhd $(SRC)/DSP_PKG.vhd $(SRC)/DSP.vhd
OBJS = $(notdir $(SRCS:.vhd=.o)) aram_c.o audio_c.o

FLAGS=--ieee=synopsys -fexplicit 

all: smp_tb

aram_c.o: aram_c.c
aram_o: aram_c.o
audio_c.o: audio_c.c
audio_o: audio_c.o

smp_tb.o: $(OBJS) smp_tb.vhd

%.o: %.vhd
	ghdl -a $(FLAGS) $<

%.o: $(SRC)/%.vhd
	ghdl -a $(FLAGS) $<

%.o: $(SPC_SRC)/%.vhd
	ghdl -a $(FLAGS) $<

work-obj93.cf: $(SRCS)
	ghdl -i $(SRCS)

run: smp_tb Makefile
	ghdl -r $< --ieee-asserts=disable

aud: snes.aud
	ffmpeg -f s16le -ar 32k -ac 2 -i snes.aud snes.wav

smp_tb: smp_tb.o
	ghdl -e $(FLAGS) -Wl,aram_c.o -Wl,audio_c.o $@

smp.ghw:  smp_tb Makefile
	ghdl -r $< --ieee-asserts=disable --read-wave-opt=waveopt --wave=$@

wave: smp.ghw

clean::
	rm -f work-obj93.cf *.o *~ *.lst *.ghw $(ROOT) *.wav
