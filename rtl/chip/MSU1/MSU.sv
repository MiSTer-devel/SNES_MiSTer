// This module is responsible for exposing MSU registers to the SNES for it to control

module MSU(
    input CLK,

    input ENABLE,
    input RD_N,
    input WR_N,
    input RST_N,

    input      [23:0] ADDR,
    input       [7:0] DIN,
    output reg  [7:0] DOUT,
	 
	 output            MSU_SEL,

    output reg  [15:0] track_out,
    output            track_request,
    input  reg        track_mounting,
    input             track_finished,

    // Audio player control
    output reg  [7:0] volume_out,

    // Wired into the status reg later
    output reg msu_status_audio_busy,
    output reg msu_status_audio_repeat,
    // If the msu_audio instance is currently playing
    input      msu_status_audio_playing_in,
    // Play/stop coming from game code poking MSU_CONTROL
    output reg msu_status_audio_playing_out,
    // Track missing will be pulsed from ext messages
    input      msu_status_track_missing_in,
    output reg msu_status_track_missing,

    output reg [31:0] msu_data_addr = 0,
    input [7:0] msu_data_in,
    input msu_status_data_busy,
    output reg msu_data_seek,
    output reg msu_data_req
);

initial begin
    msu_status_audio_busy = 0;
    msu_status_audio_repeat = 0;
    msu_status_audio_playing_out = 0;
    msu_status_track_missing = 0;
    track_out = 0;

    //track_mounting_falling = 0;
    track_mounting_old = 0;
    //track_mounting_falling_old = 0;
    //track_mounting_falling_rising = 0;

    msu_data_addr = 0;
    msu_data_req <= 0;
    msu_data_seek <= 0;
    msu_status_data_busy_out <= 0;
end

assign volume_out = MSU_VOLUME;

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

initial msu_data_addr = 32'h00000000;

// MSU_ID - $2002 to $2007
// 'S-MSU1' identity string is at MSU_ID during reading of $2002 to $2007
wire [7:0] MSU_ID [0:5];
assign MSU_ID[0] = "S";
assign MSU_ID[1] = "-";
assign MSU_ID[2] = "M";
assign MSU_ID[3] = "S";
assign MSU_ID[4] = "U";
// Can be updated at a later stage should MSU-2 become available
assign MSU_ID[5] = "1";

// Write registers
reg [31:0] MSU_SEEK;                      // $2000 - $2003
reg [15:0] MSU_TRACK;                     // $2004 - $2005
reg  [7:0] MSU_VOLUME;                    // $2006
// Just here to keep track of what was put into the MSU_CONTROL register
//(*keep*) reg  [7:0] MSU_CONTROL;          // $2007
reg [31:0] MSU_ADDR;

// Make sure we are aware of which bank ADDR is currently in
wire IO_BANK_SEL = (ADDR[23:16]>=8'h00 && ADDR[23:16]<=8'h3F) || (ADDR[23:16]>=8'h80 && ADDR[23:16]<=8'hBF);
assign MSU_SEL = ENABLE && IO_BANK_SEL && (ADDR[15:4] == 'h200);

// Rising and falling edge detection
reg RD_N_1 = 1'b1;
reg WR_N_1 = 1'b1;
reg RD_N_falling = 0;
reg WR_N_falling = 0;

reg msu_status_track_missing_in_old = 0;
reg msu_status_audio_playing_in_old = 0;

reg msu_status_busy_1 = 1'b0;
reg msu_status_data_busy_out = 1'b0;

// track mounting with respect to audio busy
//reg track_mounting_falling = 0;
reg track_mounting_old = 0;
//reg track_mounting_falling_old = 0;
//reg track_mounting_falling_rising = 0;

always @(posedge CLK or negedge RST_N) begin
    if (~RST_N) begin
        RD_N_1 = 1;
        WR_N_1 = 1;
        DOUT <= 0;

        MSU_SEEK <= 0;
        MSU_TRACK <= 16'h0000;
        track_out <= 16'h0000;
        track_request <= 0;
        // MSU volume at full after a reset
        MSU_VOLUME <= 8'hff;
        //MSU_CONTROL <= 0;
        msu_status_audio_playing_out <= 0;
        msu_status_audio_playing_in_old <= 0;
        msu_status_audio_repeat <= 0;
        msu_status_track_missing <= 0;
        msu_status_track_missing_in_old <= 0;
        msu_status_data_busy_out <= 0;
        msu_status_audio_busy <= 0;
        track_mounting_old <= 0;
        //track_mounting_falling_old <= 0;

        msu_data_req <= 0;
        msu_data_seek <= 0;
        msu_data_addr <= 32'h00000000;
    end else begin
        // Reset our request trigger for pulsing
        track_request <= 0;
        // Pulses for data
        msu_data_seek <= 0;
        msu_data_req <= 0;

        // Rising and falling edge detection stuff
        RD_N_1 <= RD_N;
        WR_N_1 <= WR_N;
        msu_status_track_missing_in_old <= msu_status_track_missing_in;
        track_mounting_old <= track_mounting;
        msu_status_audio_playing_in_old <= msu_status_audio_playing_in;

        // Falling edge of data busy
        msu_status_busy_1 <= msu_status_data_busy;
        if (msu_status_busy_1 & !msu_status_data_busy) begin
            msu_status_data_busy_out <= 0;
        end

        // Falling edge of track mounting
        if (track_mounting_old && !track_mounting) begin
            msu_status_track_missing <= msu_status_track_missing_in;
            msu_status_audio_busy <= 0;
        end

        if (!track_mounting_old && track_mounting) begin
            //track_change_audio_busy <= 1;
            msu_status_audio_busy <= 1;
        end

        // FALLING edge of WR_N.
        // 0x2003 = MSU SEEK Port
        // if (ENABLE && IO_BANK_SEL && ADDR[15:0]==16'h2003 && (WR_N_1 && !WR_N)) begin
        //     // A write to 0x2003 triggers the update of msu_data_addr...
        //     msu_data_addr <= {DIN, MSU_SEEK[23:0]};
        //     // And a SINGLE clock pulse of msu_data_seek
        //     msu_data_seek <= 1'b1;
        // end

        // Track missing is rising
        if (!msu_status_track_missing_in_old && msu_status_track_missing_in) begin
            // Status bit set (see $2005 for where it gets unset)
            msu_status_track_missing <= 1;
            msu_status_audio_busy <= 0;
        end

        // Falling edge of the audio players "playing" status
        if (msu_status_audio_playing_in_old && !msu_status_audio_playing_in) begin
            // Update our status register flag to indicate that the player has stopped playing
            msu_status_audio_playing_out <= 0;
            msu_status_audio_busy <= 0;
        end

        // Register writes
        //if (ENABLE & IO_BANK_SEL & ~WR_N) begin
        if (ENABLE & IO_BANK_SEL & WR_N_falling) begin
            case (ADDR[15:0])
                // Data seek address. MSU_SEEK, LSB byte
                16'h2000: begin
                    MSU_SEEK[7:0] <= DIN;
                end
                // Data seek address. MSU_SEEK.
                16'h2001: begin
                    MSU_SEEK[15:8] <= DIN;
                end
                // Data seek address. MSU_SEEK.
                16'h2002: begin
                    MSU_SEEK[23:16] <= DIN;
                end
                // Data seek address. MSU_SEEK, MSB byte
                16'h2003: begin
                    MSU_SEEK[31:24] <= DIN;
                    // A write to 0x2003 triggers the update of msu_data_addr...
                    msu_data_addr <= {DIN, MSU_SEEK[23:0]};
                    // And a pulse of msu_data_seek
                    msu_data_seek <= 1;
                    // TODO this needs to send out a status that the data is busy seeking
                    //msu_status_data_busy_out <= 1;
                end
                // MSU_Track LSB
                16'h2004: begin
                    MSU_TRACK[7:0] <= DIN;
                end
                // MSU_Track MSB
                16'h2005: begin
                    MSU_TRACK[15:8] <= DIN;
                    // Only update track_out when both (upper and lower) bytes arrive
                    track_out <= {DIN, MSU_TRACK[7:0]};
                    // Pulse the track_request
                    track_request <= 1;
                    msu_status_track_missing <= 0;
                    // TODO check this against the spec - Setting volume to full on track selection
                    MSU_VOLUME <= 8'hff;
                end
                // MSU Audio Volume. (MSU_VOLUME).
                16'h2006: begin
                    MSU_VOLUME <= DIN;
                end
                // MSU Audio state control. (MSU_CONTROL).
                16'h2007: begin
                    if (!msu_status_audio_busy) begin
                        //MSU_CONTROL <= DIN;
                        msu_status_audio_repeat <= DIN[1];
                        // We can only play/pause a track that has been set and mounted. Not on missing track either
                        if (!msu_status_track_missing) begin
                            msu_status_audio_playing_out <= DIN[0];
                        end
                    end
                end
                default:;
            endcase
        end

        if (ENABLE & IO_BANK_SEL & RD_N_falling) begin
            // Register reads
            case (ADDR[15:0])
                 // MSU_STATUS
                16'h2000: begin
                    DOUT <= MSU_STATUS;
                end
                // MSU_READ data
                16'h2001: begin
                    if (!msu_status_data_busy) begin
                        // Data reads increase the memory address by 1
                        msu_data_addr <= msu_data_addr + 1;
                        msu_data_req <= 1'b1;
                    end
                    DOUT <= msu_data_in;
                end
                 // MSU_ID
                16'h2002: begin
                    DOUT <= MSU_ID[0];
                end
                16'h2003: begin
                    DOUT <= MSU_ID[1];
                end
                16'h2004: begin
                    DOUT <= MSU_ID[2];
                end
                16'h2005: begin
                    DOUT <= MSU_ID[3];
                end
                16'h2006: begin
                    DOUT <= MSU_ID[4];
                end
                16'h2007: begin
                    DOUT <= MSU_ID[5];
                end
                default:;
            endcase
        end

        // TODO Data file stuff
        // RISING edge of RD_N, when it goes to idle
        // So the address increments AFTER the SNES has read the data from the CURRENT address
        // 0x2001 = MSU DATA Port
        // if (ENABLE && IO_BANK_SEL && ADDR[15:0]==16'h2001 && (!RD_N_1 && RD_N) ) begin
        //     msu_data_addr <= msu_data_addr + 1;
        //     msu_data_req <= 1'b1;
        // end
    end
end

assign WR_N_falling = WR_N_1 && !WR_N;
assign RD_N_falling = RD_N_1 && !RD_N;
endmodule