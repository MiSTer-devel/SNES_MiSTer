// This module is responsible for exposing MSU registers to the SNES for it to control

module MSU
(
	input             CLK,
	input             RST_N,
	input             ENABLE,

	input             RD_N,
	input             WR_N,
	input             SYSCLKF_CE,

	input      [23:0] ADDR,
	input       [7:0] DIN,
	output reg  [7:0] DOUT,
	output            MSU_SEL,

	output reg [15:0] track_out,
	output            track_request,
	input  reg        track_mounting,
	input             track_finished,

	// Audio player control
	output reg  [7:0] msu_volume,
	output reg        msu_status_audio_repeat,
	input             msu_status_audio_playing_in,  // If the msu_audio instance is currently playing
	output reg        msu_status_audio_playing_out, // Play/stop coming from game code poking MSU_CONTROL
	input             msu_status_track_missing,

	// Data track read
	output reg [31:0] msu_data_addr,
	input       [7:0] msu_data_in,
	input             msu_data_ack,
	output reg        msu_data_seek,
	output reg        msu_data_req
);

initial begin
	msu_status_audio_busy = 0;
	msu_status_audio_repeat = 0;
	msu_status_audio_playing_out = 0;
	msu_data_addr = 0;
	msu_data_req = 0;
	msu_data_seek = 0;
	msu_status_data_busy_out <= 0;
	track_out = 0;
	track_mounting_old = 0;
end

// Read 'registers'
// MSU_STATUS - $2000
// Status bits
localparam [2:0] msu_status_revision = 3'b001;
wire [7:0] MSU_STATUS = {
	msu_status_data_busy_out,
	msu_status_audio_busy,
	msu_status_audio_repeat,
	msu_status_audio_playing_out,
	msu_status_track_missing,
	msu_status_revision
};

// Write registers
reg [31:0] MSU_SEEK;   // $2000 - $2003
reg [15:0] MSU_TRACK;  // $2004 - $2005

// Make sure we are aware of which bank ADDR is currently in
wire IO_BANK_SEL = (ADDR[23:16]>=8'h00 && ADDR[23:16]<=8'h3F) || (ADDR[23:16]>=8'h80 && ADDR[23:16]<=8'hBF);
assign MSU_SEL = ENABLE && IO_BANK_SEL && (ADDR[15:4] == 'h200) && !ADDR[3];

reg msu_status_audio_busy = 0;

// Rising and falling edge detection
reg msu_status_audio_playing_in_old = 0;

reg msu_data_ack_1 = 1'b0;
reg msu_status_data_busy_out = 1'b0;
reg track_mounting_old = 0;

reg  data_rd_old;
wire data_rd = MSU_SEL && !RD_N && ADDR[3:0] == 1 && !msu_status_data_busy_out;

always @(posedge CLK or negedge RST_N) begin
	if (~RST_N) begin
		MSU_SEEK <= 0;
		msu_data_addr <= 0;
		MSU_TRACK <= 0;
		track_out <= 0;
		track_request <= 0;
		msu_volume <= 8'hff; // MSU volume at full after a reset
		msu_status_audio_playing_out <= 0;
		msu_status_audio_playing_in_old <= 0;
		msu_status_audio_repeat <= 0;
		msu_status_data_busy_out <= 0;
		msu_status_audio_busy <= 0;
		track_mounting_old <= 0;
		msu_data_req <= 0;
		msu_data_seek <= 0;
	end else begin
		// Reset our request trigger for pulsing
		msu_data_req <= 0;

		// Falling edge of data busy
		msu_data_ack_1 <= msu_data_ack;
		if (!msu_data_ack_1 && msu_data_ack) begin
			msu_status_data_busy_out <= 0;
			msu_data_seek <= 0;
		end

		// Falling edge of track mounting
		track_mounting_old <= track_mounting;
		if (track_mounting_old && !track_mounting) begin
			msu_status_audio_busy <= 0;
			track_request <= 0;
			msu_status_audio_playing_out <= 0;
		end

		// Falling edge of the audio players "playing" status
		msu_status_audio_playing_in_old <= msu_status_audio_playing_in;
		if (msu_status_audio_playing_in_old && !msu_status_audio_playing_in) msu_status_audio_playing_out <= 0;

		// Register writes
		if (MSU_SEL & SYSCLKF_CE & ~WR_N) begin
			case (ADDR[2:0])
				0: MSU_SEEK[7:0]   <= DIN; // Data seek address. MSU_SEEK, LSB byte
				1: MSU_SEEK[15:8]  <= DIN; // Data seek address. MSU_SEEK.
				2: MSU_SEEK[23:16] <= DIN; // Data seek address. MSU_SEEK.
				3: begin 
						MSU_SEEK[31:24] <= DIN; // Data seek address. MSU_SEEK, MSB byte
						msu_data_addr <= {DIN, MSU_SEEK[23:0]};
						msu_data_seek <= 1;
						msu_status_data_busy_out <= 1;
					end

				4: MSU_TRACK[7:0] <= DIN; // MSU_Track LSB
				5: begin
						MSU_TRACK[15:8] <= DIN; // MSU_Track MSB
						track_out <= {DIN, MSU_TRACK[7:0]};
						track_request <= 1;
						msu_status_audio_busy <= 1;
						// TODO check this against the spec - Setting volume to full on track selection
						msu_volume <= 8'hff;
					end

				6: msu_volume <= DIN; // MSU Audio Volume. (MSU_VOLUME).

				// MSU Audio state control. (MSU_CONTROL).
				7: if (!msu_status_audio_busy) begin
						msu_status_audio_repeat <= DIN[1];
						// We can only play/pause a track that has been set and mounted. Not on missing track either
						if (!msu_status_track_missing) begin
							msu_status_audio_playing_out <= DIN[0];
						end
					end
			endcase
		end

		// Advance data pointer after read
		data_rd_old <= data_rd;
		if (data_rd_old & ~data_rd) begin
			msu_data_addr <= msu_data_addr + 1;
			msu_data_req <= 1'b1;
		end
		
		case (ADDR[2:0])
			0: DOUT <= MSU_STATUS;
			1: DOUT <= msu_data_in;
			2: DOUT <= "S";
			3: DOUT <= "-";
			4: DOUT <= "M";
			5: DOUT <= "S";
			6: DOUT <= "U";
			7: DOUT <= "1";
		endcase
	end
end

endmodule
