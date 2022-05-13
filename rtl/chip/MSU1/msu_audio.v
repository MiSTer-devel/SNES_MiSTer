// This module is responsible for handling sectors, including loop point and partial end sector.
// Pausing/resuming also handled here

module msu_audio(
    input             clk,
    input             reset,
    input             ext_ack,
    // Ext_dout here is the PCM file stream
    input      [15:0] ext_dout,
    input      [10:0] ext_count,
    input             ext_wr,
    input             trig_play_in,
    input             trig_pause_in,
    input      [10:0] audio_fifo_usedw,
    input             audio_fifo_full,
    input             repeat_in,
    input             trackmounting,
    input             trackmissing,
    input             trackfinished,
    input             trackstopped,
    input      [31:0] img_size,

    output reg        ext_req,
    output reg        ext_jump_sector,
    output reg [21:0] ext_sector,
    output reg        audio_play,
    output reg        audio_fifo_write,
    output reg        looping,
    output reg        trackmissing_reset
);

    reg  [31:0] loop_index = 0;
    reg   [7:0] state;
    reg  [10:0] loop_sector_sample_offset;
    // Loop calculation helpers
    // Sector size of 1024 bytes
    reg  [31:0] loop_index_in_sectors_full = 0;
    wire [31:0] img_size_sectors = img_size >> 10;
    reg  [21:0] end_sector = 0;
    reg  [10:0] end_sector_sample_offset = 0;
    reg  [21:0] loop_sector = 0;

    localparam WAITING_FOR_PLAY_STATE = 8'd0;
    localparam WAITING_ACK_STATE = 8'd1;
    localparam PLAYING_STATE = 8'd2;
    localparam PLAYING_CHECKS_STATE = 8'd3;
    localparam END_SECTOR_STATE = 8'd5;
    localparam PAUSED_STATE = 8'd6;
    localparam SECTOR_SIZE_WORDS = 11'd511;

    reg  [7:0] partial_sector_state = 8'd0;
    reg just_reset = 0;
    reg trackmissing_old = 0;
    reg trackmounting_old = 0;
    reg trackstopped_old = 0;
    reg trig_play = 0;
    reg trig_pause = 0;
    reg trig_play_in_old = 0;
    reg trig_pause_in_old = 0;
    reg force_reset = 0;

    initial begin
        looping = 0;
        audio_play = 0;
        state = WAITING_FOR_PLAY_STATE;
        loop_index = 0;
        loop_sector = 0;
        trackmissing_reset = 0;
        force_reset = 0;
        audio_fifo_write = 0;
        ext_jump_sector = 0;
        just_reset = 0;
        trig_play = 0;
        trig_play_in_old = 0;
        trig_pause = 0;
        trig_pause_in_old = 0;
    end

    always @(posedge clk) begin
        if (reset || force_reset) begin
            // Stop any existing audio playback
            audio_play <= 0;
            state <= WAITING_FOR_PLAY_STATE;
            ext_sector <= 0;
            ext_jump_sector <= 0;
            loop_index <= 0;
            loop_sector <= 0;
            looping <= 0;
            trackmissing_old <= 0;
            trackmissing_reset <= 0;
            trig_play <= 0;
            trig_play_in_old <= 0;
            trig_pause <= 0;
            trig_pause_in_old <= 0;
            partial_sector_state <= 0;
            audio_fifo_write <= 0;
            // Pulse just_reset
            just_reset <= 1;
            force_reset <= 0;
            ext_req <= 0;
        end else begin
            just_reset <= 0;

            // Trackmissing handling
            trackmissing_old <= trackmissing;
            if (!trackmissing_old && trackmissing && !just_reset) begin
                // We need to reset audio file playing on trackmissing, but only once
                trackmissing_reset <= 1;
                force_reset <= 1;
            end

            trackmounting_old <= trackmounting;
            if (!trackmounting_old && trackmounting && !just_reset) begin
                force_reset <= 1;
            end

            trackstopped_old <= trackstopped;
            if (!trackstopped_old && trackstopped && !just_reset) begin
                force_reset <= 1;
            end

            trig_play_in_old <= trig_play_in;
            if (!trig_play_in_old && trig_play_in) begin
                trig_play <= 1;
                trig_pause <= 0;
            end

            trig_pause_in_old <= trig_pause_in;
            if (!trig_pause_in_old && trig_pause_in) begin
                trig_play <= 0;
                trig_pause <= 1;
            end

            // Loop sector handling
            if (ext_sector == 0 && ext_count == 2 && ext_wr && ext_ack) begin
                loop_index[15:0] <= ext_dout;
            end
            if (ext_sector == 0 && ext_count == 3 && ext_wr && ext_ack) begin
                loop_index[31:16] <= ext_dout;
            end

            // loop sector - also need to take into account the 4 words for file header (msu1 and loop index = 8 bytes)
            loop_index_in_sectors_full <= loop_index >> 8;
            loop_sector <= loop_index_in_sectors_full[21:0];
            loop_sector_sample_offset[10:0] <= loop_index[10:0] - {loop_sector[2:0],8'h00} + 11'd2; //((loop_index[10:0] * 4) - (loop_sector[10:0] * 11'd1024) + 8) / 4;

            // End sector handling
            end_sector <= img_size_sectors[21:0];
            end_sector_sample_offset[10:0] <= {img_size[2:0], 8'h00}; //(img_size[10:0] * 11'd1024) / 4;

            case (state)
                WAITING_FOR_PLAY_STATE: begin
                    ext_sector <= 0;
                    ext_jump_sector <= 0;
                    partial_sector_state <= 0;
                    audio_fifo_write <= 0;
                    looping <= 0;
                    audio_play <= 0;
                    ext_req <= 0;
                    if (trig_play) begin
                        trig_play <= 0;
                        trackmissing_reset <= 0;
                        // Go! (requests a sector via EXT bus)
                        audio_play <= 1;
                        audio_fifo_write <= 1;
                        ext_req <= 1;
                        state <= WAITING_ACK_STATE;
                    end
                end
                WAITING_ACK_STATE: begin
                    // Wait for ACK to go high, meaning we are receiving a new sector and can start playing samples
                    // We can still pause audio in this state
                    if (trig_pause) begin
                        audio_play <= 0;
                        state <= PAUSED_STATE;
                    end else if (ext_ack) begin
                        ext_req <= 0;
                        audio_play <= 1;
                        // ext_ack goes high at the start of a sector transfer (and during)
                        ext_jump_sector <= 0;
                        state <= PLAYING_STATE;
                        // We still could be looping <= 1 at this point
                    end else if (trackmissing) begin
                        ext_req <= 0;
                        audio_play <= 0;
                        ext_sector <= 0;
                        ext_jump_sector <= 0;
                        trackmissing_reset <= 1;
                        loop_index <= 0;
                        state <= WAITING_FOR_PLAY_STATE;
                    end
                end
                PLAYING_STATE: begin
                    if (trig_pause) begin
                        audio_play <= 0;
                        state <= PAUSED_STATE;
                    end else begin
                        if (partial_sector_state == 8'd1) begin
                            // Handling the last sector here
                            if (ext_count > end_sector_sample_offset) begin
                                partial_sector_state <= 8'd2;
                                state <= END_SECTOR_STATE;
                            end
                        end else begin
                            // Keep collecting samples until we hit the buffer limit and while ext_ack is still high
                            if (looping) begin
                                audio_fifo_write <= 0;
                                // We may need to deal with some remainder samples after the loop sector boundary
                                if (ext_count < loop_sector_sample_offset) begin
                                    // Disable writing to the fifo, skipping to the correct sample in the loop sector
                                    audio_fifo_write <= 0;
                                end else begin
                                    looping <= 0;
                                    audio_fifo_write <= 1;
                                end
                            end
                            if (!ext_ack && audio_fifo_usedw < 11'd1536) begin
                                // We've received a full sector
                                // Only add new sectors if we haven't filled the buffer
                                // 2048 words in the fifo - sector size of 512 words
                                state <= PLAYING_CHECKS_STATE;
                            end
                        end
                    end
                end
                PLAYING_CHECKS_STATE: begin
                    // Check if we've reached end_sector yet
                    if ((ext_sector < (end_sector - 1)) && audio_play) begin
                        // Nope, Fetch another sector, keeping track of where we are
                        ext_sector <= ext_sector + 1'd1;
                        ext_req <= 1;
                        state <= WAITING_ACK_STATE;
                    end else begin
                        state <= END_SECTOR_STATE;
                    end
                end
                END_SECTOR_STATE: begin
                    // Depending on the last sector and looping, we need to handle things differently
                    if (audio_play && end_sector_sample_offset == 0) begin
                        // Handle a full last sector
                        if (!repeat_in) begin
                            // Stop, no loop
                            audio_play <= 0;
                            state <= WAITING_FOR_PLAY_STATE;
                            ext_sector <= 0;
                            ext_req <= 0;
                        end else begin
                            // Loop, jump back to the loop sector
                            ext_sector <= loop_sector;
                            ext_jump_sector <= 1;
                            ext_req <= 1;
                            state <= WAITING_ACK_STATE;
                            looping <= 1;
                        end
                    end else begin
                        // Handle partial end sector - The last sector of the PCM file does NOT end on an exact
                        // Sector boundary. We need to keep reading until we reach the end sample.
                        case (partial_sector_state)
                            0: begin
                                // Move to the partial sector
                                partial_sector_state <= 8'd1;
                                ext_sector <= ext_sector + 1'd1;
                                ext_req <= 1;
                            end
                            1: begin
                                // Keep reading samples for the partial sector
                                state <= WAITING_ACK_STATE;
                            end
                            2: begin
                                // We've reached the end of the partial sector now.. handle stopping/looping
                                if (!repeat_in) begin
                                    // Stopping
                                    audio_play <= 0;
                                    ext_sector <= 0;
                                    ext_jump_sector <= 0;
                                    state <= WAITING_FOR_PLAY_STATE;
                                    audio_fifo_write <= 0;
                                    partial_sector_state <= 8'd0;
                                    looping <= 0;
                                end else begin
                                    // We need to repeat/loop
                                    looping <= 1;
                                    partial_sector_state <= 8'd0;
                                    if (loop_sector == 0) begin
                                        // Loop sector is zero
                                        ext_sector <= 0;
                                        ext_jump_sector <= 1;
                                    end else begin
                                        // Loop sector is a non-zero one
                                        ext_sector <= loop_sector;
                                        ext_jump_sector <= 1;
                                        // We will deal with loop sector word offsets above
                                        audio_fifo_write <= 0;
                                    end
                                    audio_play <= 1;
                                    state <= WAITING_ACK_STATE;
                                    ext_req <= 1;
                                end
                            end
                        endcase
                    end
                end
                PAUSED_STATE: begin
                    if (trig_play) begin
                        audio_play <= 1;
                        state <= PLAYING_STATE;
                    end
                end
                default:; // Do nothing but wait
            endcase
        end // Ends else
    end // Ends clocked block
endmodule