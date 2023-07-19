/////////////////////////////////////////////////////////////////////////
//  File: brddefs.h     FPGA board specific pin definitions 
//
/////////////////////////////////////////////////////////////////////////

// *********************************************************
// Copyright (c) 2022 Demand Peripherals, Inc.
// 
// This file is licensed separately for private and commercial
// use.  See LICENSE.txt which should have accompanied this file
// for details.  If LICENSE.txt is not available please contact
// support@demandperipherals.com to receive a copy.
// 
// In general, you may use, modify, redistribute this code, and
// use any associated patent(s) as long as
// 1) the above copyright is included in all redistributions,
// 2) this notice is included in all source redistributions, and
// 3) this code or resulting binary is not sold as part of a
//    commercial product.  See LICENSE.txt for definitions.
// 
// DPI PROVIDES THE SOFTWARE "AS IS," WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING
// WITHOUT LIMITATION ANY WARRANTIES OR CONDITIONS OF TITLE,
// NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR
// PURPOSE.  YOU ARE SOLELY RESPONSIBLE FOR DETERMINING THE
// APPROPRIATENESS OF USING OR REDISTRIBUTING THE SOFTWARE (WHERE
// ALLOWED), AND ASSUME ANY RISKS ASSOCIATED WITH YOUR EXERCISE OF
// PERMISSIONS UNDER THIS AGREEMENT.
// *********************************************************

/////////////////////////////////////////////////////////////////////////
//
`define BRD_CLOCK          0
`define BRD_TX             1
`define BRD_RX             2
`define BRD_BTN_0          3
`define BRD_BTN_1          4
`define BRD_BLU_LED        5
`define BRD_GRN_LED        6
`define BRD_RED_LED        7
`define BRD_LED_0          8
`define BRD_LED_3          11
`define BRD_MX_IO         (`BRD_LED_3)

`define NUM_CORE          11   // can address up to NUM_CORE peripherals
`define MX_PCPIN          37   // Slot 10 has only two pins

