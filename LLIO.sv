/* HDL implementation of Low-Latency API protocol for Bliss-Box
* 
* Copyright 2019 Jamie Dickson aka Kitrinx
* 
* Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
* documentation files (the "Software"), to deal in the Software without restriction, including without limitation
* the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
* and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
* 
* The above copyright notice and this permission notice shall be included in all copies or substantial portions
* of the Software.
* 
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
* TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
* THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
* CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
* IN THE SOFTWARE.
*/

// Feb, 1 2019 - Initial Release

// ***** NOTE ******
// On IO board 5.5 the bliss box requires external pull-up resistors to communicate properly

// Data payload bit order:

// Byte 0:
// uint8_t Controller Type (or error code)
// Notable ID's are:
// 18 - NES
// 21 - Gen 3 button
// 22 - Gen 6 button
// 27 - SNES
// 28 - NES Zapper
// 41 - Atari Paddles
// 51 - NeGcon
// 65 - PSX Digital
// 11 - PSX DS
// 12 - PSX DS2
// more info: https://docs.google.com/document/d/12XpxrmKYx_jgfEPyw-O2zex1kTQZZ-NSBdLO2RQPRzM/edit

// Bytes 1-2:
// Buttons
// System SNES    Genesis PSX    Gun   Saturn
//  0:     Y       A       □      Click A
//  1:     B       B       ×      Light B
//  2:     X       X       △      NA    X
//  3:     A       Y       ○      NA    Y
//  4:     Select  Mode    Select NA    NA
//  5:     Start   Start   Start  NA    Start
//  6:     LT      NA      L1     NA    L
//  7:     RT      NA      R1     NA    R

//  8:     NA      Z       L2     NA    Z
//  9:     NA      C       R2     NA    C
// 10:     U       U       U      NA    NA
// 11:     D       D       D      NA    NA
// 12:     L       L       L      NA    NA
// 13:     R       R       R      NA    NA
// 14:     0       NA      L3     NA    NA
// 15:     1       NA      R3     NA    NA

// 16:     2       NA      NA     NA    NA
// 17:     3       NA      NA     NA    NA
// 18:     4       NA      NA     NA    NA
// 19:     5       NA      NA     NA    NA
// 20:     6       NA      NA     NA    NA
// 21:     7       NA      NA     NA    NA
// 22:     8       NA      NA     NA    NA
// 23: This bit can be the "special" trigger button for retroarch
// more info: https://docs.google.com/spreadsheets/d/1Bk3j5kaKfV1tOfzCq3GLKFsff027RdmwOuSfBLM3Ims/edit#gid=0

// Bytes 4-12: (uint8_t's)
// 04: Axis 1 X
// 05: Axis 1 Y
// 06: Axis 1 Z
// 07: Axis 2 X
// 08: Axis 2 Y
// 09: Axis 2 Z
// 10: Slider
// 11: Dial
// 12: Hat

// Modes:
// 0: autopause state
// 1:
// 2: 
// 3: Hotswap Disabled
// 4: UDLR mode
// 5: Analog to D-pad
// 6: autopause dis.
// 7: d-pad only mode

module LLIO
(
	input         CLK_50M,
	input         ENABLE,        // If 0, module will be disabled and pins will be set to Z
	input         IO_LATCH_IN,   // D+ top level IO pin
	output        IO_LATCH_OUT,
	input         IO_DATA_IN,    // D- top level IO pin
	output        IO_DATA_OUT,
	input         LLIO_SYNC,     // Pos edge corresponds with when the core needs the data, from core
	output        LLIO_EN,       // High when device is communicating, passed to core
	output [7:0]  LLIO_TYPE,     // Enumerated controller type, passed to core
	output [7:0]  LLIO_MODES,    // Modes that the bliss box may be in, passed to core
	output [31:0] LLIO_BUTTONS,  // Vector of buttons, 1 == pressed, passed to core
	output [71:0] LLIO_ANALOG    // Unsigned 8 bit vector of analog axis, passed to core
);

// Commands
enum bit [7:0] {
	LLIO_POLL               = 8'h00, // Holds latch low until done
	LLIO_STATUS             = 8'h01, // Returns 13 bytes, see above
	LLIO_PRESSURE_STATUS    = 8'h02, // Returns ?? bytes
	LLIO_SET_MODES          = 8'h20, // Requires 1 byte payload
	LLIO_GET_MODES          = 8'h21, // Returns bit field of active modes, 1 byte. see above
	// Rumble
	LLIO_RUMBLE_CONST_START_FROM_PARMS = 8'h11, //must set parms first
	LLIO_RUBMLE_CONST_END              = 8'h12,
	LLIO_RUMBLE_SINE_START_FROM_PARMS  = 8'h14, //must set parms first
	LLIO_RUMBLE_SINE_END               = 8'h18,
	LLIO_RUMBLE_CONST_JOLT             = 8'h1A,
	LLIO_RUMBLE_SINE_JOLT              = 8'h1B,
	LLIO_RUMBLE_PARMS                  = 8'h1C //followed by 2 bytes of data containing the parms (rumbleLevel and then rumbleLoop)
} commands;

// Errors
enum bit [7:0] {
	LLIO_ERROR_NODATA       = 8'h00,
	LLIO_ERROR_AP_NO_REPORT = 8'hFF
} errors;

// Timing (one 50mhz cycle == 0.02us)
enum bit [20:0] {
	TIME_POLL   = 21'd820000, // 16.4ms - default polling period if no sync is used
	TIME_SETTLE = 21'd150,    // 3us - to account for bidirectional IO pins slew rate
	TIME_WAIT   = 21'd500,    // 10us - time to wait after a reply before writing again
	TIME_LEADIN = 21'd84,     // 1.5us - at start of new transactions
	TIME_BIT_H  = 21'd109,    // 2.2us - always-high first bit-half
	TIME_BIT_R  = 21'd115,    // 2.3us - variable second bit-half
	TIME_SYNC_H = 21'd49,     // 1us - sync pulse between bytes high time
	TIME_SYNC_L = 21'd50      // 1us - sync pulse between bytes low time
} time_periods;

typedef enum bit [2:0] {
	READ_IDLE,
	READ_POLL,
	WRITE_STATUS,
	READ_STATUS,
	WRITE_SETUP,
	WRITE_MODES,
	READ_MODES
} execution_stage;

typedef enum bit [3:0] {
	STATE_IDLE,
	STATE_WRITE_START,
	STATE_WRITE,
	STATE_WRITE_END,
	STATE_READ_START,
	STATE_READ_WAIT,
	STATE_READ,
	STATE_READ_END
} execution_state;

logic [20:0]  cycle, count, poll_offset, poll_counter, sync_counter;
logic [31:0]  write_buffer;
logic [3:0]   write_length;
logic [2:0]   read_bit; // Relies on overflow
logic [3:0]   read_byte;
logic [7:0]   read_buffer[13];
logic [3:0]   read_length;

logic [31:0]  lljs_buttons;
logic [71:0]  lljs_analog;
logic [7:0]   lljs_type;
logic [7:0]   lljs_modes;

reg   [20:0]  poll_time = TIME_POLL;

logic latch;
logic is_latched;
logic data_in, data_out;
logic enable;
logic old_sync, new_sync, old_data;

execution_stage stage = READ_IDLE;
execution_state state = STATE_IDLE;

assign LLIO_TYPE = lljs_type;
assign LLIO_BUTTONS = lljs_buttons;
assign LLIO_ANALOG = lljs_analog;
assign LLIO_MODES = lljs_modes;
assign LLIO_EN = enable;

always_comb begin
	if (latch) begin
		IO_LATCH_OUT <= 1'b0;
		IO_DATA_OUT <= data_out;
	end else begin
		IO_LATCH_OUT <= 1'b1;
		IO_DATA_OUT <= 1'b1;
	end
end

always_ff @(posedge CLK_50M) begin
	if (ENABLE) begin
	old_sync <= new_sync;
	new_sync <= LLIO_SYNC;
	cycle <= cycle + 1'b1;

	if (~latch) begin
		is_latched <= ~IO_LATCH_IN;
		old_data <= data_in;
		data_in <= IO_DATA_IN;
	end

	if (~old_sync && new_sync) begin
		sync_counter <= 0;
		poll_time <= poll_counter - 21'd9500; // about 3 scanlines of wobble room
		poll_counter <= 0;
	end else begin
		sync_counter <= sync_counter + 1'b1;
		poll_counter <= poll_counter + 1'b1;
	end

	if (stage == READ_POLL || stage == READ_STATUS)
		poll_offset <= poll_offset + 1'b1;

	case (state)
		STATE_IDLE: begin
			if (is_latched) begin // remote device wants to talk
				enable <= 1'b1;
				cycle <= 0;
				count <= 0;
				read_byte <= 0;
				state <= STATE_READ_START;
			end else if (stage == WRITE_STATUS) begin // We just got a poll result
				if (cycle > TIME_WAIT) begin
					cycle <= 0;
					state <= STATE_WRITE_START;
					stage <= READ_STATUS;
					read_length <= 'd13;
					write_buffer <= {24'd0, LLIO_STATUS};
				end
			end else if (stage == WRITE_MODES) begin
				if (cycle > TIME_WAIT) begin
					cycle <= 0;
					stage <= READ_MODES;
					read_length <= 1'd1;
					state <= STATE_WRITE_START;
					write_buffer <= {24'd0, LLIO_GET_MODES};
				end
			end else if (sync_counter >= (((poll_offset < (poll_time >> 1)) && enable) ?
				(poll_time - poll_offset) : poll_time)) begin // Trigger timed device poll. Offset can not be > half the poll time.
				count <= count + 1'b1;
				if (count > TIME_WAIT) begin
					if (stage != READ_IDLE) begin // IO timeout, device disconnect/defunct
						enable <= 1'b0;
						poll_offset <= 0;
						poll_time <= TIME_POLL;
						lljs_buttons <= 24'h0;
						lljs_type <= 8'h0;
						lljs_analog <= 48'h808080808080;
					end
					poll_offset <= 0;
					sync_counter <= 0;
					cycle <= 0;
					count <= 0;
					read_length <= 0;
					state <= STATE_WRITE_START;
					stage <= READ_POLL;
					write_buffer <= {24'd0, LLIO_POLL};
				end
			end
		end

		STATE_WRITE_START: begin
			if (cycle == 0) begin
				data_out <= 1'b0; 
				latch <= 1'b1; // Take control
				write_length <= 'h8; // Always 8 for now
			end else if (cycle >= TIME_LEADIN) begin
				cycle <= 0;
				state <= STATE_WRITE;
			end
		end

		STATE_WRITE: begin
			if (write_length == 0) begin
				state <= STATE_WRITE_END;
				cycle <= 0;
			end else if (cycle == 'd0) begin // high half-bit
				data_out <= 1'b1;
			end else if (cycle == TIME_BIT_H) begin // data half-bit
				data_out <= ~write_buffer[0];
				write_buffer <= {1'b0, write_buffer[31:1]};
			end else if (cycle >= (TIME_BIT_R + TIME_BIT_H)) begin
				write_length <= write_length - 1'b1;
				cycle <= 0;
			end
		end

		STATE_WRITE_END: begin
			if (cycle == 0)
				data_out <= 1'b1;
			else if (cycle == TIME_SYNC_H)
				data_out <= 1'b0;
			else if (cycle == (TIME_SYNC_H + TIME_SYNC_L)) begin
				latch <= 1'b0; // Release
			end else if (cycle >= (TIME_SYNC_H + TIME_SYNC_L + TIME_SETTLE)) begin
				state <= STATE_IDLE;
				cycle <= 0;
			end
		end

		STATE_READ_START: begin
			if (cycle >= TIME_SETTLE && ~is_latched) begin // Just a busy wait/poll/blip
				cycle <= 0;
				if (stage == READ_POLL) // If expecting a busy reply from poll, advance
					stage <= WRITE_STATUS;
				state <= STATE_IDLE;
			end else if (count >= 'd10) begin // Allows for latch to be seen if both are released together
				cycle <= 'd10;
				read_bit <= 3'h0;
				state <= STATE_READ;
			end else if (cycle >= TIME_LEADIN && data_in) begin // If we get data high it means we're reading
				count <= count + 1'b1;
			end
		end

		STATE_READ_WAIT: begin // the space between the bytes
			if (cycle > (TIME_SYNC_H + TIME_SYNC_L + 'd5) ||
				((cycle > 'd25) && ~old_data && data_in)) begin // Re align during wait if needed
				cycle <= 0;
				read_bit <= 3'h0;
				state <= (read_byte >= read_length) ? STATE_READ_END : STATE_READ;
			end
		end

		STATE_READ: begin
			if (~is_latched) begin // Accounts from random timing errors or unexpected events
				cycle <= 0;
				state <= STATE_IDLE;
			end if (cycle == (TIME_BIT_H + (TIME_BIT_R >> 1))) begin // latch in the middle of the data window
				read_buffer[read_byte][read_bit] <= ~data_in;
				read_bit <= read_bit + 1'b1;
			end else if (cycle >= TIME_BIT_H + TIME_BIT_R) begin
				cycle <= 0;
				if (read_bit == 3'h0) begin // This relies on overflow behavior
					if (read_byte == 0) begin
						if (stage == READ_STATUS) begin
							lljs_type <= read_buffer[0];
						end else if (stage == READ_MODES) begin
							lljs_modes <= read_buffer[0];
						end
					end else if (read_byte == 'd12) begin
						lljs_buttons[31:0] <= {
							4'd0, 
							(read_buffer[12][3] ? 4'd0 :
							{
								(read_buffer[12][2:0] == 3'h0 || read_buffer[12][2:0] == 3'h1 || read_buffer[12][2:0] == 3'h7), //U
								(read_buffer[12][2:0] == 3'h4 || read_buffer[12][2:0] == 3'h3 || read_buffer[12][2:0] == 3'h5), //D
								(read_buffer[12][2:0] == 3'h6 || read_buffer[12][2:0] == 3'h5 || read_buffer[12][2:0] == 3'h7), //L
								(read_buffer[12][2:0] == 3'h2 || read_buffer[12][2:0] == 3'h1 || read_buffer[12][2:0] == 3'h3), //R
							}),
							read_buffer[3],
							read_buffer[2],
							read_buffer[1]
						};

						lljs_analog[71:0] <= {
							read_buffer[12],
							read_buffer[11],
							read_buffer[10],
							read_buffer[9],
							read_buffer[8],
							read_buffer[7],
							read_buffer[6],
							read_buffer[5],
							read_buffer[4]
						};
					end
					read_byte <= read_byte + 1'd1;
					state <= STATE_READ_WAIT;
				end
			end
		end
		/*
		#define DPAD_UP      0x04    00000100
		#define DPAD_DOWN    0x08    00001000
		#define DPAD_LEFT    0x10    00010000  
		#define DPAD_RIGHT   0x20    00100000

		#define DPAD_UPLEFT        0x14
		#define DPAD_DOWNLEFT    0x18
		#define DPAD_UPRIGHT    0x24
		#define DPAD_DOWNRIGHT    0x28
		#define DPAD_REST    0xff
		*/

		STATE_READ_END: begin
			// latch data to correct registers based on stage
			if (cycle >= TIME_WAIT) begin // bliss box holds the line low for about 3us after reply
				if (stage == READ_STATUS) begin // de-analog the dpad on controllers without analog
					if (lljs_modes[7]) begin
						lljs_buttons[27] <= lljs_buttons[27] | (lljs_analog[15:8] < 'd50);
						lljs_buttons[26] <= lljs_buttons[26] | (lljs_analog[15:8] > 'd200);
						lljs_buttons[25] <= lljs_buttons[25] | (lljs_analog[7:0]  < 'd50);
						lljs_buttons[24] <= lljs_buttons[24] | (lljs_analog[7:0]  > 'd200);
					end
					stage <= READ_IDLE;
				end else begin
					stage <= READ_IDLE;
				end
				cycle <= 0;
				state <= STATE_IDLE;
			end
		end

		default: begin
			cycle <= 0;
			count <= 0;
			stage <= READ_IDLE;
			state <= STATE_IDLE;
		end
	endcase
	end else begin
		latch <= 1'b0;
		enable <= 1'b0;
		lljs_analog <= 0;
		lljs_buttons <= 0;
		lljs_modes <= 0;
		lljs_type <= 0;
		state <= STATE_IDLE;
		stage <= READ_IDLE;
	end
end

endmodule
