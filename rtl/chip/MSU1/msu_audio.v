// This module is responsible for handling sectors, including loop point and partial end sector.
// Pausing/resuming also handled here

module msu_audio(
    input             clk,
    input             reset,
    input             ext_ack,
    // Ext_dout here is the PCM file stream
    input      [31:0] ext_dout,
    input       [7:0] ext_count,
    input             ext_wr,
    input       [9:0] audio_fifo_usedw,
    input             audio_fifo_full,
    input             repeat_in,
    input             play_in,
    input             trackmounting,
    input      [31:0] track_size,

    output reg        ext_req,
    output reg        ext_jump_sector,
    output reg [21:0] ext_sector,
    output reg        audio_play,
    output reg        audio_fifo_write
);

localparam WAITING_FOR_PLAY_STATE = 0;
localparam WAITING_ACK_STATE      = 1;
localparam PLAYING_STATE          = 2;
localparam PLAYING_CHECKS_STATE   = 3;
localparam END_SECTOR_STATE       = 5;

reg [31:0] loop_index = 0;
reg  [7:0] state = WAITING_FOR_PLAY_STATE;
reg partial_sector_state = 0;
reg trackmounting_old = 0;
reg play_in_old = 0;
reg looping;

always @(posedge clk) begin

	play_in_old <= play_in;

	if (reset) begin
		audio_play <= 0;
		state <= WAITING_FOR_PLAY_STATE;
		ext_sector <= 0;
		ext_jump_sector <= 0;
		audio_fifo_write <= 0;
		ext_req <= 0;
	end
	else begin

		audio_play <= play_in;

		// Loop sector handling - also need to take into account the 4 words for file header (msu1 and loop index = 8 bytes)
		if (ext_sector == 0 && ext_count == 1 && ext_wr && ext_ack) loop_index <= ext_dout + 2;

		case (state)
			WAITING_FOR_PLAY_STATE:
				begin
					ext_sector <= 0;
					ext_jump_sector <= 0;
					partial_sector_state <= 0;
					audio_fifo_write <= 0;
					looping <= 0;
					audio_play <= 0;
					ext_req <= 0;
					if (~play_in_old & play_in) begin
						audio_play <= 1;
						ext_jump_sector <= 1;
						state <= WAITING_ACK_STATE;
					end
				end

			WAITING_ACK_STATE:
				begin
					if (ext_ack) begin
						ext_req <= 0;
						ext_jump_sector <= 0;
						state <= PLAYING_STATE;
					end
				end

			PLAYING_STATE:
				begin
					if (partial_sector_state) begin
						// Handling the last sector here
						if (ext_count >= track_size[9:2]) begin
							audio_fifo_write <= 0;
							state <= END_SECTOR_STATE;
						end
					end
					else begin
						// Keep collecting samples until we hit the buffer limit and while ext_ack is still high
						if (looping) begin
							// We may need to deal with some remainder samples after the loop sector boundary
							if (ext_count < loop_index[7:0]) begin
								// Disable writing to the fifo, skipping to the correct sample in the loop sector
								audio_fifo_write <= 0;
							end else begin
								looping <= 0;
								audio_fifo_write <= 1;
							end
						end
						else begin
							audio_fifo_write <= (ext_sector || ext_count[7:1]);
						end
						 
						if (!ext_ack && audio_fifo_usedw < 768) begin
							// We've received a full sector
							// Only add new sectors if we haven't filled the buffer
							// 1024 dwords in the fifo - sector size of 256 dwords
							state <= PLAYING_CHECKS_STATE;
						end
					end
				end

			PLAYING_CHECKS_STATE:
				begin
					// Check if we've reached end_sector yet
					if (ext_sector < track_size[31:10]-1'd1) begin
						// Nope, Fetch another sector, keeping track of where we are
						ext_sector <= ext_sector + 1'd1;
						ext_req <= 1;
						state <= WAITING_ACK_STATE;
					end else begin
						state <= END_SECTOR_STATE;
					end
				end

			END_SECTOR_STATE:
				begin
					// Depending on the last sector and looping, we need to handle things differently
					if (!track_size[9:2] || partial_sector_state) begin
						partial_sector_state <= 0;
						// Handle a full last sector
						if (!repeat_in) begin
							// Stop, no loop
							state <= WAITING_FOR_PLAY_STATE;
						end else begin
							// Loop, jump back to the loop sector
							ext_sector <= loop_index[29:8];
							ext_jump_sector <= 1;
							state <= WAITING_ACK_STATE;
							looping <= 1;
						end
					end else begin
						// Handle partial end sector - The last sector of the PCM file does NOT end on an exact
						// Sector boundary. We need to keep reading until we reach the end sample.
						// Move to the partial sector
						partial_sector_state <= 1;
						ext_sector <= ext_sector + 1'd1;
						ext_req <= 1;
						state <= WAITING_ACK_STATE;
					end
				end
		endcase
		
		trackmounting_old <= trackmounting;
		if (!trackmounting_old && trackmounting) state <= WAITING_FOR_PLAY_STATE;
  end // Ends else
end // Ends clocked block

endmodule
