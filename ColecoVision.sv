//============================================================================
//  ColecoVision
//
//  Port to MiSTer
//  Copyright (C) 2017-2019 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================
//LLAPI NOTE: 
// llapi.sv needs to be in rtl folder and needs to be declared in file.qip (set_global_assignment -name SYSTEMVERILOG_FILE rtl/llapi.sv)

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign ADC_BUS = 'Z;

//LLAPI
//assign USER_OUT = '1;
//LLAPI

assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0;
 
assign LED_USER   = ioctl_download;
assign LED_DISK   = 0;
assign LED_POWER  = 0;
//LLAPI: OSD combinaison
assign BUTTONS   = llapi_osd;
//LLAPI
assign VGA_SCALER = 0;
assign VGA_DISABLE= 0;
assign HDMI_FREEZE= 0;

wire [1:0] ar = status[2:1];
wire vga_de;
reg  en216p;
always @(posedge CLK_VIDEO) en216p <= ((HDMI_WIDTH == 1920) && (HDMI_HEIGHT == 1080) && !forced_scandoubler && !scale);

video_freak video_freak
(
	.*,
	.VGA_DE_IN(vga_de),
	.ARX((!ar) ? 12'd4 : (ar - 1'd1)),
	.ARY((!ar) ? 12'd3 : 12'd0),
	.CROP_SIZE(en216p ? 10'd216 : 10'd0),
	.CROP_OFF(0),
	.SCALE(status[11:10])
);

`include "build_id.v" 
parameter CONF_STR = {
	"Coleco;;",
	//LLAPI: OSD menu item
	//LLAPI Always ON
	"-,>> LLAPI enabled core    <<;",		
	"-,>> Connect USER I/O port <<;",
	"-;",
	//END LLAPI
	"F,COLBINROM;",
	"F,SG,Load SG-1000;",
	"-;",
	//LLAPI notes
	"P1,LLAPI notes;",
	"P1-;",
	"P1-,Supported controllers :;",
	"P1-,-Coleco/SAC (press RIGHT trg;",
	"P1-, or PURPLE btn + Reset port);",	
	"P1-,-Atari Jaguar,;",
	"P1-,-SNES NTT Data,;",
	"P1-,-Atari 5200,;",
	"P1-,-Sega SG-1000,;",
	"-;",
	//END LLAPI	
	"O12,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O79,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
	"-;",
	"O6,Border,No,Yes;",
	"OAB,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"-;",
	"O3,Joysticks swap,No,Yes;",
	"-;",
	"O45,RAM Size,1KB,8KB,SGM;",
	"R0,Reset;",
	"J1,Fire 1,Fire 2,*,#,0,1,2,3,4,5,6,7,8,9,Purple Tr,Blue Tr;",
	"I,",
	"LLAPI device detected,",
	"LLAPI device not detetected,",
	"V,v",`BUILD_DATE
};

/////////////////  CLOCKS  ////////////////////////

wire clk_sys;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.locked(pll_locked)
);

reg ce_10m7 = 0;
reg ce_5m3 = 0;
always @(posedge clk_sys) begin
	reg [2:0] div;
	
	div <= div+1'd1;
	ce_10m7 <= !div[1:0];
	ce_5m3  <= !div[2:0];
end

/////////////////  HPS  ///////////////////////////

wire [31:0] status;
wire  [1:0] buttons;

//LLAPI: Distinguish hps_io (usb) josticks from llapi joysticks
wire [31:0] joy_usb_0, joy_usb_1;
//LLAPI

//LLAPI: Info pop-up
reg llapi_info_req;
reg [7:0] llapi_info;
//LLAPI

wire [31:0] joy0 = joy_ll_a;
wire [31:0] joy1 = joy_ll_b;

wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        forced_scandoubler;
wire [21:0] gamma_bus;
 
hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
	.status(status),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),

	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	//LLAPI
	.joystick_0(joy0_usb_0),
	.joystick_1(joy1_usb_1),
	.info_req(llapi_info_req),
	.info(llapi_info),
	//LLAPI
);

//////////////////   LLAPI   ///////////////////

wire [31:0] llapi_buttons, llapi_buttons2;
wire [71:0] llapi_analog, llapi_analog2;
wire [7:0]  llapi_type, llapi_type2;
wire llapi_en, llapi_en2;

wire llapi_latch_o, llapi_latch_o2, llapi_data_o, llapi_data_o2;

// LLAPI Indexes:
// 0 = D+    = P1 Latch
// 1 = D-    = P1 Data
// 2 = TX-   = LLAPI Enable
// 3 = GND_d = N/C
// 4 = RX+   = P2 Latch
// 5 = RX-   = P2 Data


always_comb begin
		USER_OUT[0] = llapi_latch_o;
		USER_OUT[1] = llapi_data_o;
		USER_OUT[2] = OSD_STATUS; // LED for Blister
		USER_OUT[4] = llapi_latch_o2;
		USER_OUT[5] = llapi_data_o2;
end


//Port 1 conf
LLAPI llapi
(
	.CLK_50M(CLK_50M),
	.LLAPI_SYNC(vblank),
	.IO_LATCH_IN(USER_IN[0]),
	.IO_LATCH_OUT(llapi_latch_o),
	.IO_DATA_IN(USER_IN[1]),
	.IO_DATA_OUT(llapi_data_o),
	.ENABLE(~OSD_STATUS),
	.LLAPI_BUTTONS(llapi_buttons),
	.LLAPI_ANALOG(llapi_analog),
	.LLAPI_TYPE(llapi_type),
	.LLAPI_EN(llapi_en)
);

//Port 2 conf
LLAPI llapi2
(
	.CLK_50M(CLK_50M),
	.LLAPI_SYNC(vblank),
	.IO_LATCH_IN(USER_IN[4]),
	.IO_LATCH_OUT(llapi_latch_o2),
	.IO_DATA_IN(USER_IN[5]),
	.IO_DATA_OUT(llapi_data_o2),
	.ENABLE(~OSD_STATUS),
	.LLAPI_BUTTONS(llapi_buttons2),
	.LLAPI_ANALOG(llapi_analog2),
	.LLAPI_TYPE(llapi_type2),
	.LLAPI_EN(llapi_en2)
);

reg llapi_button_pressed, llapi_button_pressed2;

always @(posedge CLK_50M) begin
        if (reset) begin
                llapi_button_pressed  <= 0;
                llapi_button_pressed2 <= 0;
	end else begin
	       	if (|llapi_buttons)
                	llapi_button_pressed  <= 1;
        	if (|llapi_buttons2)
                	llapi_button_pressed2 <= 1;
	end
end

/*
//llapi status detection wip
//LLAPI Port 1 Atari mode
//LLAPI Port 1 Searching
//LLAPI Port 1 Detected
//LLAPI Port 2 Atari mode
//LLAPI Port 2 Searching
//LLAPI Port 2 Detected

reg old_llapi_status;
wire toggle_llapi = ~old_llapi_status && llapi_en;

assign llapi_info_req = llapi_enabled | llapi_disabled;

always_comb begin
	llapi_info = 8'd0;
	if (llapi_enabled)
		info = 8'd1;
	if (llapi_disabled)
		info = 8'd2;
end

reg [31:0] timer;

always @(posedge CLK_50M) begin
		old_llapi_status <= llapi_en;
		if (old_llapi_status == ~llapi_en) begin
			if (status[53] && ~old_resetsw)
			timer <= 1_000_000;
			if (|timer)
				timer <= timer - 1'd1;
		end
end*/


// controller id is 0 if there is either an Atari controller or no controller
// if id is 0, assume there is no controller until a button is pressed
// also check for 255 and treat that as 'no controller' as well
wire use_llapi  = llapi_en  && ((|llapi_type  && ~(&llapi_type))  || llapi_button_pressed);
wire use_llapi2 = llapi_en2 && ((|llapi_type2 && ~(&llapi_type2)) || llapi_button_pressed2);


//Controller string provided by core for reference (order is important)
//Controller specific mapping based on type. More info here : https://docs.google.com/document/d/12XpxrmKYx_jgfEPyw-O2zex1kTQZZ-NSBdLO2RQPRzM/edit
//llapi_Buttons id are HID id - 1

// "J1,Fire 1,Fire 2,*,#,0,1,2,3,4,5,6,7,8,9,Purple Tr,Blue Tr;",

//Port 1 mapping

wire [31:0] joy_ll_a;
wire a_left, a_right, a_down, a_up;

always_comb begin
	// button layout for Coleco controller (spinner not supported)
	if (llapi_type == 1 || llapi_type == 34) begin
		joy_ll_a = {
			12'b0, llapi_buttons[3], llapi_buttons[2], // Blue Tr, Purple Tr
			llapi_buttons[16],llapi_buttons[15], llapi_buttons[14], llapi_buttons[13],llapi_buttons[12], // 9, 8, 7, 6, 5
			llapi_buttons[11], llapi_buttons[10],llapi_buttons[9], llapi_buttons[8], llapi_buttons[18],  // 4, 3, 2, 1, 0 
			llapi_buttons[19], llapi_buttons[17], // #, *
			llapi_buttons[1], llapi_buttons[0], // Fire 2, Fire 1
			llapi_buttons[27], llapi_buttons[26], llapi_buttons[25], llapi_buttons[24] // d-pad
		};
	// button layout for Jaguar controller
	end else if (llapi_type == 11) begin
		joy_ll_a = {
			12'b0, llapi_buttons[4], llapi_buttons[5], // Blue Tr, Purple Tr
			llapi_buttons[16],llapi_buttons[15], llapi_buttons[14], llapi_buttons[13],llapi_buttons[12], // 9, 8, 7, 6, 5
			llapi_buttons[11], llapi_buttons[10],llapi_buttons[9], llapi_buttons[8], llapi_buttons[18],  // 4, 3, 2, 1, 0 
			llapi_buttons[19], llapi_buttons[17], // #, *
			llapi_buttons[7], llapi_buttons[0], // Fire 2, Fire 1
			llapi_buttons[27], llapi_buttons[26], llapi_buttons[25], llapi_buttons[24] // d-pad
		};
	// button layout for NTT SNES controller
	end else if (llapi_type == 47 || llapi_type == 27) begin
		joy_ll_a = {
			12'b0, llapi_buttons[3], llapi_buttons[2], // Blue Tr, Purple Tr
			llapi_buttons[16],llapi_buttons[15], llapi_buttons[14], llapi_buttons[13],llapi_buttons[12], // 9, 8, 7, 6, 5
			llapi_buttons[11], llapi_buttons[10],llapi_buttons[9], llapi_buttons[8], llapi_buttons[18],  // 4, 3, 2, 1, 0 
			llapi_buttons[19], llapi_buttons[17], // #, *
			llapi_buttons[1] || llapi_buttons[7] , llapi_buttons[0] || llapi_buttons[6], // Fire 2, Fire 1
			llapi_buttons[27], llapi_buttons[26], llapi_buttons[25], llapi_buttons[24] // d-pad
		};
	// button layout for Atari 5200 controller
	end else if (llapi_type == 6) begin
		joy_ll_a = {
			14'b0, // Blue Tr, Purple Tr
			llapi_buttons[16],llapi_buttons[15], llapi_buttons[14], llapi_buttons[13],llapi_buttons[12], // 9, 8, 7, 6, 5
			llapi_buttons[11], llapi_buttons[10],llapi_buttons[9], llapi_buttons[8], llapi_buttons[18],  // 4, 3, 2, 1, 0 
			llapi_buttons[19], llapi_buttons[17], // #, *
			llapi_buttons[1], llapi_buttons[0], // Fire 2, Fire 1
			a_up, a_down, a_left, a_right // d-pad
		};
	end else begin
		joy_ll_a = {
			12'b0, llapi_buttons[3], llapi_buttons[2], // Blue Tr, Purple Tr
			llapi_buttons[16],llapi_buttons[15], llapi_buttons[14], llapi_buttons[13],llapi_buttons[12], // 9, 8, 7, 6, 5
			llapi_buttons[11], llapi_buttons[10],llapi_buttons[9], llapi_buttons[8], llapi_buttons[18],  // 4, 3, 2, 1, 0 
			llapi_buttons[19], llapi_buttons[17], // #, *
			llapi_buttons[1] || llapi_buttons[7] , llapi_buttons[0] || llapi_buttons[6], // Fire 2, Fire 1
			llapi_buttons[27], llapi_buttons[26], llapi_buttons[25], llapi_buttons[24] // d-pad
		};
	end
end

wire [7:0] joy_ll_ax = llapi_analog[7:0]; //Left stick X;
wire [7:0] joy_ll_ay = llapi_analog[15:8]; //Left stick Y;

always_comb begin
	if (llapi_type == 6) begin
	//If directions dont work, we can lower the bounderies. 100 and 20 might be a good alternative. To be tested based on feedback from community
		a_right = (joy_ll_ax > 200) ? 1 : 0;
		a_left = (joy_ll_ax < 50) ? 1 : 0;
		a_down = (joy_ll_ay > 200) ? 1 : 0; 
		a_up = (joy_ll_ay < 50) ? 1 : 0;				
	end else begin
		a_right = 0;
		a_left = 0;
		a_down = 0;
		a_up = 0;
	end
end

//Port 2 mapping

wire [31:0] joy_ll_b;
wire b_left, b_right, b_down, b_up;

always_comb begin
		// button layout for Coleco controller (spinner not supported)
	if (llapi_type2 == 1 || llapi_type2 == 34) begin
		joy_ll_b = {
			12'b0, llapi_buttons2[3], llapi_buttons2[2], // Blue Tr, Purple Tr
			llapi_buttons2[16],llapi_buttons2[15], llapi_buttons2[14], llapi_buttons2[13],llapi_buttons2[12], // 9, 8, 7, 6, 5
			llapi_buttons2[11], llapi_buttons2[10],llapi_buttons2[9], llapi_buttons2[8], llapi_buttons2[18],  // 4, 3, 2, 1, 0 
			llapi_buttons2[19], llapi_buttons2[17], // #, *
			llapi_buttons2[1], llapi_buttons2[0], // Fire 2, Fire 1
			llapi_buttons2[27], llapi_buttons2[26], llapi_buttons2[25], llapi_buttons2[24] // d-pad
		};
	// button layout for Jaguar controller
	end else if (llapi_type2 == 11) begin
		joy_ll_b = {
			12'b0, llapi_buttons2[4], llapi_buttons2[5], // Blue Tr, Purple Tr
			llapi_buttons2[16],llapi_buttons2[15], llapi_buttons2[14], llapi_buttons2[13],llapi_buttons2[12], // 9, 8, 7, 6, 5
			llapi_buttons2[11], llapi_buttons2[10],llapi_buttons2[9], llapi_buttons2[8], llapi_buttons2[18],  // 4, 3, 2, 1, 0 
			llapi_buttons2[19], llapi_buttons2[17], // #, *
			llapi_buttons2[7], llapi_buttons2[0], // Fire 2, Fire 1
			llapi_buttons2[27], llapi_buttons2[26], llapi_buttons2[25], llapi_buttons2[24] // d-pad
		};
	// button layout for NTT SNES controller
	end else if (llapi_type2 == 47 || llapi_type2 == 27) begin
		joy_ll_b = {
			12'b0, llapi_buttons2[3], llapi_buttons2[2], // Blue Tr, Purple Tr
			llapi_buttons2[16],llapi_buttons2[15], llapi_buttons2[14], llapi_buttons2[13],llapi_buttons2[12], // 9, 8, 7, 6, 5
			llapi_buttons2[11], llapi_buttons2[10],llapi_buttons2[9], llapi_buttons2[8], llapi_buttons2[18],  // 4, 3, 2, 1, 0 
			llapi_buttons2[19], llapi_buttons2[17], // #, *
			llapi_buttons2[1] || llapi_buttons2[7], llapi_buttons2[0] || llapi_buttons2[6], // Fire 2, Fire 1
			llapi_buttons2[27], llapi_buttons2[26], llapi_buttons2[25], llapi_buttons2[24] // d-pad
		};
	// button layout for Atari 5200 controller
	end else if (llapi_type2 == 6) begin
		joy_ll_b = {
			14'b0, // Blue Tr, Purple Tr
			llapi_buttons2[16],llapi_buttons2[15], llapi_buttons2[14], llapi_buttons2[13],llapi_buttons2[12], // 9, 8, 7, 6, 5
			llapi_buttons2[11], llapi_buttons2[10],llapi_buttons2[9], llapi_buttons2[8], llapi_buttons2[18],  // 4, 3, 2, 1, 0 
			llapi_buttons2[19], llapi_buttons2[17], // #, *
			llapi_buttons2[1], llapi_buttons2[0], // Fire 2, Fire 1
			b_up, b_down, b_left, b_right // d-pad
		};
	end else begin
		joy_ll_b = {
			12'b0, llapi_buttons2[3], llapi_buttons2[2], // Blue Tr, Purple Tr
			llapi_buttons2[16],llapi_buttons2[15], llapi_buttons2[14], llapi_buttons2[13],llapi_buttons2[12], // 9, 8, 7, 6, 5
			llapi_buttons2[11], llapi_buttons2[10],llapi_buttons2[9], llapi_buttons2[8], llapi_buttons2[18],  // 4, 3, 2, 1, 0 
			llapi_buttons2[19], llapi_buttons2[17], // #, *
			llapi_buttons2[1] || llapi_buttons2[7], llapi_buttons2[0] || llapi_buttons2[6], // Fire 2, Fire 1
			llapi_buttons2[27], llapi_buttons2[26], llapi_buttons2[25], llapi_buttons2[24] // d-pad
		};		
	end
end

wire [7:0] joy_ll_bx = llapi_analog2[7:0]; //Left stick X;
wire [7:0] joy_ll_by = llapi_analog2[15:8]; //Left stick Y;

always_comb begin
	if (llapi_type2 == 6) begin
		//If directions dont work, we can lower the bounderies. 100 and 20 might be a good alternative. To be tested based on feedback from community
		b_right = (joy_ll_bx > 200) ? 1 : 0;
		b_left = (joy_ll_bx < 50) ? 1 : 0;
		b_down = (joy_ll_by > 200) ? 1 : 0; 
		b_up = (joy_ll_by < 50) ? 1 : 0;				
	end else begin
		b_right = 0;
		b_left = 0;
		b_down = 0;
		b_up = 0;
	end
end

//Assign (DOWN + START + FIRST BUTTON) Combinaison to bring the OSD up - P1 and P2 ports.
wire llapi_osd = (llapi_buttons[26] & llapi_buttons[5] & llapi_buttons[0]) || (llapi_buttons2[26] & llapi_buttons2[5] & llapi_buttons2[0]);



/////////////////  RESET  /////////////////////////

wire reset = RESET | status[0] | buttons[1] | ioctl_download;

/////////////////  Memory  ////////////////////////

wire [12:0] bios_a;
wire  [7:0] bios_d;

spram #(13,8,"rtl/bios.mif") rom
(
	.clock(clk_sys),
	.address(bios_a),
	.q(bios_d)
);

wire [14:0] cpu_ram_a;
wire        ram_we_n, ram_ce_n;
wire  [7:0] ram_di;
wire  [7:0] ram_do;

wire [14:0] ram_a = (extram)            ? cpu_ram_a       :
                    (status[5:4] == 1)  ? cpu_ram_a[12:0] : // 8k
                    (status[5:4] == 0)  ? cpu_ram_a[9:0]  : // 1k
                    (sg1000)            ? cpu_ram_a[12:0] : // SGM means 8k on SG1000
                                          cpu_ram_a;        // SGM/32k

spram #(15) ram
(
	.clock(clk_sys),
	.address(ram_a),
	.wren(ce_10m7 & ~(ram_we_n | ram_ce_n)),
	.data(ram_do),
	.q(ram_di)
);

wire [13:0] vram_a;
wire        vram_we;
wire  [7:0] vram_di;
wire  [7:0] vram_do;

spram #(14) vram
(
	.clock(clk_sys),
	.address(vram_a),
	.wren(vram_we),
	.data(vram_do),
	.q(vram_di)
);

wire [19:0] cart_a;
wire  [7:0] cart_d;
wire        cart_rd;

reg [5:0] cart_pages;
always @(posedge clk_sys) if(ioctl_wr) cart_pages <= ioctl_addr[19:14];

assign SDRAM_CLK = ~clk_sys;
sdram sdram
(
	.*,
	.init(~pll_locked),
	.clk(clk_sys),

   .wtbt(0),
   .addr(ioctl_download ? ioctl_addr : cart_a),
   .rd(cart_rd),
   .dout(cart_d),
   .din(ioctl_dout),
   .we(ioctl_wr),
   .ready()
);

reg sg1000 = 0;
reg extram = 0;
always @(posedge clk_sys) begin
	if(ioctl_wr) begin
		if(!ioctl_addr) begin
			extram <= 0;
			sg1000 <= (ioctl_index[4:0] == 2);
		end
		if(ioctl_addr[24:13] == 1 && sg1000) extram <= (!ioctl_addr[12:0] | extram) & &ioctl_dout; // 2000-3FFF on SG-1000
	end
end


////////////////  Console  ////////////////////////

wire [13:0] audio;
assign AUDIO_L = {1'b0,audio,1'b0};
assign AUDIO_R = {1'b0,audio,1'b0};
assign AUDIO_S = 0;
assign AUDIO_MIX = 0;

assign CLK_VIDEO = clk_sys;

wire [1:0] ctrl_p1;
wire [1:0] ctrl_p2;
wire [1:0] ctrl_p3;
wire [1:0] ctrl_p4;
wire [1:0] ctrl_p5;
wire [1:0] ctrl_p6;
wire [1:0] ctrl_p7 = 2'b11;
wire [1:0] ctrl_p8;
wire [1:0] ctrl_p9 = 2'b11;

wire [7:0] R,G,B;
wire hblank, vblank;
wire hsync, vsync;

wire [31:0] joya = status[3] ? joy1 : joy0;
wire [31:0] joyb = status[3] ? joy0 : joy1;

cv_console console
(
	.clk_i(clk_sys),
	.clk_en_10m7_i(ce_10m7),
	.reset_n_i(~reset),
	.por_n_o(),
	.sg1000(sg1000),
	.dahjeeA_i(extram),

	.ctrl_p1_i(ctrl_p1),
	.ctrl_p2_i(ctrl_p2),
	.ctrl_p3_i(ctrl_p3),
	.ctrl_p4_i(ctrl_p4),
	.ctrl_p5_o(ctrl_p5),
	.ctrl_p6_i(ctrl_p6),
	.ctrl_p7_i(ctrl_p7),
	.ctrl_p8_o(ctrl_p8),
	.ctrl_p9_i(ctrl_p9),
	.joy0_i(~{|joya[19:6], 1'b0, joya[5:0]}),
	.joy1_i(~{|joyb[19:6], 1'b0, joyb[5:0]}),

	.bios_rom_a_o(bios_a),
	.bios_rom_d_i(bios_d),

	.cpu_ram_a_o(cpu_ram_a),
	.cpu_ram_we_n_o(ram_we_n),
	.cpu_ram_ce_n_o(ram_ce_n),
	.cpu_ram_d_i(ram_di),
	.cpu_ram_d_o(ram_do),

	.vram_a_o(vram_a),
	.vram_we_o(vram_we),
	.vram_d_o(vram_do),
	.vram_d_i(vram_di),

	.cart_pages_i(cart_pages),
	.cart_a_o(cart_a),
	.cart_d_i(cart_d),
	.cart_rd(cart_rd),

	.border_i(status[6]),
	.rgb_r_o(R),
	.rgb_g_o(G),
	.rgb_b_o(B),
	.hsync_n_o(hsync),
	.vsync_n_o(vsync),
	.hblank_o(hblank),
	.vblank_o(vblank),

	.audio_o(audio)
);

assign VGA_F1 = 0;
assign VGA_SL = sl[1:0];

wire [2:0] scale = status[9:7];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;

reg hs_o, vs_o;
always @(posedge CLK_VIDEO) begin
	hs_o <= ~hsync;
	if(~hs_o & ~hsync) vs_o <= ~vsync;
end

video_mixer #(.LINE_LENGTH(290), .GAMMA(1)) video_mixer
(
	.*,

	.ce_pix(ce_5m3),
	.freeze_sync(),

	.scandoubler(scale || forced_scandoubler),
	.hq2x(scale==1),

	.VGA_DE(vga_de),
	.R(R),
	.G(G),
	.B(B),

	// Positive pulses.
	.HSync(hs_o),
	.VSync(vs_o),
	.HBlank(hblank),
	.VBlank(vblank)
);



////////////////  Control  ////////////////////////

wire [0:19] keypad0 = {joya[8],joya[9],joya[10],joya[11],joya[12],joya[13],joya[14],joya[15],joya[16],joya[17],joya[6],joya[7],joya[18],joya[19],joya[3],joya[2],joya[1],joya[0],joya[4],joya[5]};
wire [0:19] keypad1 = {joyb[8],joyb[9],joyb[10],joyb[11],joyb[12],joyb[13],joyb[14],joyb[15],joyb[16],joyb[17],joyb[6],joyb[7],joyb[18],joyb[19],joyb[3],joyb[2],joyb[1],joyb[0],joyb[4],joyb[5]};
wire [0:19] keypad[2] = '{keypad0,keypad1};

reg [3:0] ctrl1[2] = '{'0,'0};
assign {ctrl_p1[0],ctrl_p2[0],ctrl_p3[0],ctrl_p4[0]} = ctrl1[0];
assign {ctrl_p1[1],ctrl_p2[1],ctrl_p3[1],ctrl_p4[1]} = ctrl1[1];

localparam cv_key_0_c        = 4'b0011;
localparam cv_key_1_c        = 4'b1110;
localparam cv_key_2_c        = 4'b1101;
localparam cv_key_3_c        = 4'b0110;
localparam cv_key_4_c        = 4'b0001;
localparam cv_key_5_c        = 4'b1001;
localparam cv_key_6_c        = 4'b0111;
localparam cv_key_7_c        = 4'b1100;
localparam cv_key_8_c        = 4'b1000;
localparam cv_key_9_c        = 4'b1011;
localparam cv_key_asterisk_c = 4'b1010;
localparam cv_key_number_c   = 4'b0101;
localparam cv_key_pt_c       = 4'b0100;
localparam cv_key_bt_c       = 4'b0010;
localparam cv_key_none_c     = 4'b1111;

generate 
	genvar i;
	for (i = 0; i <= 1; i++) begin : ctl
		always_comb begin
			reg [3:0] ctl1, ctl2;
			reg p61,p62;
			
			ctl1 = 4'b1111;
			ctl2 = 4'b1111;
			p61 = 1;
			p62 = 1;

			if (~ctrl_p5[i]) begin
				casex(keypad[i][0:13]) 
					'b1xxxxxxxxxxxxx: ctl1 = cv_key_0_c;
					'b01xxxxxxxxxxxx: ctl1 = cv_key_1_c;
					'b001xxxxxxxxxxx: ctl1 = cv_key_2_c;
					'b0001xxxxxxxxxx: ctl1 = cv_key_3_c;
					'b00001xxxxxxxxx: ctl1 = cv_key_4_c;
					'b000001xxxxxxxx: ctl1 = cv_key_5_c;
					'b0000001xxxxxxx: ctl1 = cv_key_6_c;
					'b00000001xxxxxx: ctl1 = cv_key_7_c;
					'b000000001xxxxx: ctl1 = cv_key_8_c;
					'b0000000001xxxx: ctl1 = cv_key_9_c;
					'b00000000001xxx: ctl1 = cv_key_asterisk_c;
					'b000000000001xx: ctl1 = cv_key_number_c;
					'b0000000000001x: ctl1 = cv_key_pt_c;
					'b00000000000001: ctl1 = cv_key_bt_c;
					'b00000000000000: ctl1 = cv_key_none_c;
				endcase
				p61 = ~keypad[i][19]; // button 2
			end

			if (~ctrl_p8[i]) begin
				ctl2 = ~keypad[i][14:17];
				p62 = ~keypad[i][18];  // button 1
			end
			
			ctrl1[i] = ctl1 & ctl2;
			ctrl_p6[i] = p61 & p62;
		end
	end
endgenerate


endmodule
