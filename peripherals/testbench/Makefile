# *********************************************************
# Copyright (c) 2021 Demand Peripherals, Inc.
# 
# This file is licensed separately for private and commercial
# use.  See LICENSE.txt which should have accompanied this file
# for details.  If LICENSE.txt is not available please contact
# support@demandperipherals.com to receive a copy.
# 
# In general, you may use, modify, redistribute this code, and
# use any associated patent(s) as long as
# 1) the above copyright is included in all redistributions,
# 2) this notice is included in all source redistributions, and
# 3) this code or resulting binary is not sold as part of a
#    commercial product.  See LICENSE.txt for definitions.
# 
# DPI PROVIDES THE SOFTWARE "AS IS," WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING
# WITHOUT LIMITATION ANY WARRANTIES OR CONDITIONS OF TITLE,
# NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR
# PURPOSE.  YOU ARE SOLELY RESPONSIBLE FOR DETERMINING THE
# APPROPRIATENESS OF USING OR REDISTRIBUTING THE SOFTWARE (WHERE
# ALLOWED), AND ASSUME ANY RISKS ASSOCIATED WITH YOUR EXERCISE OF
# PERMISSIONS UNDER THIS AGREEMENT.
# 
# *********************************************************

# Makefile to run Verilog tests for some of the peripherals


default: patgen64_tb.xt2

all: 

patgen64_tb.xt2: patgen64_tb.v ../patgen64.v
	iverilog -o patgen64_tb.vvp ../sysdefs.h patgen64_tb.v ../patgen64.v 
	vvp patgen64_tb.vvp -lxt2

rcc8_tb.xt2: rcc8_tb.v ../rcc8.v
	iverilog -o rcc8_tb.vvp ../sysdefs.h rcc8_tb.v ../rcc8.v
	vvp rcc8_tb.vvp -lxt2

sr04_tb.xt2: sr04_tb.v ../sr04.v
	iverilog -o sr04_tb.vvp ../sysdefs.h sr04_tb.v ../sr04.v
	vvp sr04_tb.vvp -lxt2

bb4out4_tb.xt2: ../../fpgaboards/baseboard4/build/main.v bb4out4_tb.v
	iverilog -o bb4out4_tb.vvp ../../fpgaboards/baseboard4/brddefs.h ../sysdefs.h \
	bb4out4_tb.v ../../fpgaboards/baseboard4/build/main.v ../busif.v ../slip.v \
	../../fpgaboards/baseboard4/bb4io.v \
	../crc.v ../clocks.v ../hostparallel.v ../in4.v ../out4.v
	vvp bb4out4_tb.vvp -lxt2

bb4sndgen_tb.xt2: ../../fpgaboards/baseboard4/build/main.v bb4sndgen_tb.v ../sndgen.v
	iverilog -o bb4sndgen_tb.vvp ../../fpgaboards/baseboard4/brddefs.h ../sysdefs.h \
	bb4sndgen_tb.v ../../fpgaboards/baseboard4/build/main.v ../busif.v ../slip.v \
	../../fpgaboards/baseboard4/bb4io.v \
	../crc.v ../clocks.v ../hostparallel.v ../sndgen.v ../out4.v
	vvp bb4sndgen_tb.vvp -lxt2

mainin4_tb.xt2: ../../fpgaboards/baseboard4/build/main.v mainin4_tb.v
	iverilog -o mainin4_tb.vvp ../sysdefs.h \
	mainin4_tb.v ../../fpgaboards/baseboard4/build/main.v ../busif.v ../slip.v \
	../../fpgaboards/baseboard4/bb4io.v \
	../crc.v ../clocks.v ../hostserial.v ../in4.v ../out4.v
	vvp mainin4_tb.vvp -lxt2

bb4spi_tb.xt2: ../../fpgaboards/baseboard4/build/main.v bb4spi_tb.v ../dgspi.v
	iverilog -o bb4spi_tb.vvp ../../fpgaboards/baseboard4/brddefs.h ../sysdefs.h \
	bb4spi_tb.v ../../fpgaboards/baseboard4/build/main.v ../busif.v ../slip.v \
	../../fpgaboards/baseboard4/bb4io.v ../dgspi.v ../dpespi.v \
	../crc.v ../clocks.v ../hostparallel.v ../in4.v ../out4.v
	vvp bb4spi_tb.vvp -lxt2

bb4ps2_tb.xt2: ../../fpgaboards/baseboard4/build/main.v bb4ps2_tb.v ../ps2.v
	iverilog -o bb4ps2_tb.vvp ../../fpgaboards/baseboard4/brddefs.h ../sysdefs.h \
	bb4ps2_tb.v ../../fpgaboards/baseboard4/build/main.v ../busif.v ../slip.v \
	../../fpgaboards/baseboard4/bb4io.v ../ps2.v ../in4.v \
	../crc.v ../clocks.v ../hostparallel.v
	vvp bb4ps2_tb.vvp -lxt2

clean:
	rm -rf *.vvp *.xt2


