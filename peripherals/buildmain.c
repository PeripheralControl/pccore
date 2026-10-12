/*
 *  buildmain.c:   A program to help generate main.v
 *  This program builds a chain of peripherals by linking the outputs of
 *  one peripheral to the inputs of the next.
 */

/* *********************************************************
 * Copyright (c) 2026 Demand Peripherals, Inc.
 * 
 * DPI PROVIDES THE SOFTWARE "AS IS," WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING
 * WITHOUT LIMITATION ANY WARRANTIES OR CONDITIONS OF TITLE,
 * NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR
 * PURPOSE.  YOU ARE SOLELY RESPONSIBLE FOR DETERMINING THE
 * APPROPRIATENESS OF USING OR REDISTRIBUTING THE SOFTWARE (WHERE
 * ALLOWED), AND ASSUME ANY RISKS ASSOCIATED WITH YOUR EXERCISE OF
 * PERMISSIONS UNDER THIS AGREEMENT.
 * 
 * *********************************************************/


#include "brddefs_c.h"
#include "../../../peripherals/drivlist.h"    // list to relate drivers IDs to FPGA peripherals
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


// Maximume line length in the perilist config file
#define MXPERILINE   120
// Maximum name length for a peripheral
#define PERILEN       20
// Number of entries in the drivlist table
#define NUMDRIVR      32


// Give forward references for the peripheral invocation functions
// Note that these are the "real" peripherals as defined in the FPGA.
void perilist(int, int, int, int, char *);

int main(int argc, char *argv[])
{
    FILE *pdescfile;        // The description file
    FILE *psources;         // The sources file that drives compilation
    char  peri[PERILEN];    // The peripheral name
    char  line[MXPERILINE]; // Contains a line from perilist
    int   dirs;             // Pin directions, set==output
    int   ret;
    int   slot = 0;         // First peripheral is at address 0
    int   pin = 0;          // Pins are numbered from zero
    int   i;                // Peripheral loop index
    int   lnlen,j;          // Library Name LENgth, char index into lib name
          // In the FPGA peripherals are called "cores", in pcdaemon "slots".
          // We sometimes use "slot" to mean "core".  This distinction it to
          // allow pcdeamon to have peripherals that are not FPGA related.
    int   drividtbl[NUMDRIVR];  // Driver ID for each peripheral


    if (argc != 2) {
        fprintf(stderr, "FATAL: %s expects a single filename argument %d\n",
                argv[0], argc);
        exit(1);
    }

    // Open the sources file and get it started
    psources = fopen("sources.tmp", "w");
    if (psources == (FILE *)0) {
        fprintf(stderr, "FATAL: %s: Unable to open 'sources.tmp' for writing\n",
                argv[0]);
        exit(1);
    }

    // Open the file with the list of peripherals
    pdescfile = fopen(argv[1], "r");
    if (pdescfile == (FILE *)0) {
        fprintf(stderr, "FATAL: %s: Unable to open %s for reading\n",
                argv[0], argv[1]);
        exit(1);
    }

    // Skip the first 8 lines of the perilist config file.  Copyright stuff.
    for (j = 0; j < 8; j++) {
        if (0 == fgets(line, MXPERILINE-1, pdescfile)) {
            printf("Not enough ROM strings\n");
            exit(1);
        }
    }

    // init table of driver IDs to zero
    for (i = 0; i < NUMDRIVR; i++)
        drividtbl[i] = 0;

    // Loop through the list of peripherals
    while (1) {
        ret = fscanf(pdescfile, "%s", peri);
        if (ret == EOF) {   // no more peripherals to process
            fclose(psources);
            break;
        }
        else if (ret < 0) {
            fprintf(stderr, "FATAL: %s: Read error on %s.\n", argv[0], argv[1]);
            exit(1);
        }

        // Skip lines beginning with a #
        if (peri[0] == '#')
            continue;

        for (i = 0; i < NPERI; i++) {
            if (0 == strncmp(peri, pdesc[i].periname, (PERILEN - 1)))
                break;
        }
        if (i == NPERI) {
            fprintf(stderr, "FATAL: %s: Unknown peripheral: %s\n",
                    argv[0], peri);
            exit(1);
        }
 
        // Found the peripheral.  Generate its invocation.
        perilist(slot, pin, pdesc[i].dirs, pdesc[i].npins, pdesc[i].incname);

        // Add it to the sources file.  The source file for the board is added
        // to the sources file by the makefile.  Do not add it here.`
        if (slot != 0)
            fprintf(psources, "`include \"../../../peripherals/%s.v\"\n", pdesc[i].incname);

        // Add it to the list of driver IDs
        drividtbl[slot] = pdesc[i].drivid;

        // Go to next slot/peripheral
        slot = slot + 1;
        pin = pin + pdesc[i].npins;
    }

    // Add the strobe lines and the link between DAT_I and DAT_O
    printf("\n");
    printf("assign bi0datin = p00DAT_O;\n");
    printf("\n");
    for (i = 0; i < slot -1; i++) {
        printf("assign p%02dDAT_I = p%02dDAT_O;\n", i, (i + 1));
    }
    printf("assign p%02dDAT_I = bi0datout;\n", slot - 1);

    // Add the composite stall and ack lines
    printf("\n");
    printf("assign STALL_I = \n");
    for (i = 0; i < slot -1; i++) {
        printf("              p%02dSTALL_O |\n", i);
    }
    printf("              p%02dSTALL_O;\n", i);
    printf("\n");
    printf("assign ACK_I = \n");
    for (i = 0; i < slot -1; i++) {
        printf("              p%02dACK_O |\n", i);
    }
    printf("              p%02dACK_O;\n", i);

    printf("\nendmodule\n");
    printf("\n");

    // Add the list of peripheral driver IDs
    printf("\n");
    printf("module perilist(core, id);\n");
    printf("    input  [4:0] core;\n");
    printf("    output [15:0] id;\n");
    printf("    assign id = \n");
    for (i = 0; i < NUMDRIVR -1; i++)
        printf("            (core == 5'h%1x) ? 16'h%04x : \n", i, drividtbl[i]);
    printf("                             16'h%04x ; \n", drividtbl[i]);
    printf("endmodule\n");
    printf("\n");

    exit(0);
}



// The peripheral invocation functions.
// This takes in the peripheral address and current PIN
// number, and returns the PIN number of the next available PIN. 
// Slot 0 is the board IO peripheral and has a special invocation.
// Peripherals without pins have a special invocation.

void perilist(int addr, int startpin, int dirs, int numpins, char *peri)
{
    int    i;

    printf("\n");
    printf("// Slot: %d   %s\n", addr, peri);
    printf("    wire p%02dSTALL_O;      // ==1 if we need more clk cycles\n", addr);
    printf("    wire p%02dACK_O;        // ==1 for peri to acknowledge transfer\n", addr);
    printf("    wire [7:0] p%02dDAT_I;  // Data INto the peripheral;\n", addr);
    printf("    wire [7:0] p%02dDAT_O;  // Data OUT from peripheral, = DAT_I if not us.\n", addr);
    if (addr == 0) {     // the board peripheral?
        printf("    %s p00(\n", peri);
        printf("        .CLK_O(CLK_O),\n");
        printf("        .WE_I(WE_O),\n");
        printf("        .TGA_I(TGA_O),\n");
        printf("        .STB_I(cs_io & (slotid == 5'd0)),\n");
        printf("        .ADR_I(ADR_O[7:0]),\n");
        printf("        .STALL_O(p00STALL_O),\n");
        printf("        .ACK_O(p00ACK_O),\n");
        printf("        .DAT_I(p00DAT_I),\n");
        printf("        .DAT_O(p00DAT_O),\n");
        printf("        .clocks(bc0clocks),\n");
        printf("        .BRDIO(BRDIO),\n");
        printf("        .PCPIN(PCPIN));\n");
        return;
    }

    // CPU peripherals with no pins (timers, interrupt controllers, ...)
    if (numpins == 0) {
        printf("    %s p%02d(\n", peri, addr);
        printf("        .CLK_I(CLK_O),\n");
        printf("        .WE_I(WE_O),\n");
        printf("        .TGA_I(TGA_O),\n");
        printf("        .STB_I(cs_io & (slotid == 5'd%02d)),\n", addr);
        printf("        .ADR_I(ADR_O[7:0]),\n");
        printf("        .STALL_O(p%02dSTALL_O),\n", addr);
        printf("        .ACK_O(p%02dACK_O),\n", addr);
        printf("        .DAT_I(p%02dDAT_I),\n", addr);
        printf("        .DAT_O(p%02dDAT_O),\n", addr);
        printf("        .clocks(bc0clocks));\n");
        return;
    }

    // Regular peripherals have pins but not BRDIO and PCPIN
    printf("    tri [%d:0] p%02dpins;\n", numpins -1, addr);

    printf("    %s p%02d(\n", peri, addr);
    printf("        .CLK_I(CLK_O),\n");
    printf("        .WE_I(WE_O),\n");
    printf("        .TGA_I(TGA_O),\n");
    printf("        .STB_I(cs_io & (slotid == 5'd%02d)),\n", addr);
    printf("        .ADR_I(ADR_O[7:0]),\n");
    printf("        .STALL_O(p%02dSTALL_O),\n", addr);
    printf("        .ACK_O(p%02dACK_O),\n", addr);
    printf("        .DAT_I(p%02dDAT_I),\n", addr);
    printf("        .DAT_O(p%02dDAT_O),\n", addr);
    printf("        .clocks(bc0clocks),\n");
    printf("        .pins(p%02dpins));\n", addr);

    for (i = 0; i < numpins; i++) {
        // Ignore assignments above max PCPIN.  IO pins are not always in multiples of 4
        if (startpin + i > MX_PCPIN)
            break;

        if (dirs & (1<<i))     // set direction from 'dirs' bit mask. 1==output
            printf("    assign PCPIN[%d] = p%02dpins[%d];\n", startpin+i, addr, i);
        else
            printf("    assign p%02dpins[%d] = PCPIN[%2d];\n", addr, i, startpin+i);
    }
    return;
}


