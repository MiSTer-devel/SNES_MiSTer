//
// hps_ext for Mega CD
//
// Copyright (c) 2020 Alexey Melnikov
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
///////////////////////////////////////////////////////////////////////

module hps_ext
(
	input             clk_sys,
	inout      [35:0] EXT_BUS,

	input             reset,

	output reg        msu_enable,

	output reg        msu_trackmounting,
	output reg        msu_trackmissing,
	input      [15:0] msu_trackout,
	input             msu_trackrequest,
	
	output reg        msu_audio_ack,
	input             msu_audio_req,
	input             msu_audio_jump_sector,
	input      [31:0] msu_audio_sector,
	input             msu_audio_download	
);

assign EXT_BUS[15:0] = io_dout;
wire [15:0] io_din = EXT_BUS[31:16];
assign EXT_BUS[32] = dout_en;
wire io_strobe = EXT_BUS[33];
wire io_enable = EXT_BUS[34];

localparam EXT_CMD_MIN = CD_GET;
localparam EXT_CMD_MAX = CD_SET;

localparam CD_GET = 'h34;
localparam CD_SET = 'h35;

reg [15:0] io_dout;
reg        dout_en = 0;
reg  [9:0] byte_cnt;

always@(posedge clk_sys) begin
	reg [15:0] cmd;
	reg  [7:0] cd_req = 0;
	reg        old_cd = 0;

	old_cd <= cd_in[48];
	if(old_cd ^ cd_in[48]) cd_req <= cd_req + 1'd1;

	if(~io_enable) begin
		dout_en <= 0;
		io_dout <= 0;
		byte_cnt <= 0;
		if(cmd == 'h35) cd_out[48] <= ~cd_out[48];
	end
	else if(io_strobe) begin

		io_dout <= 0;
		if(~&byte_cnt) byte_cnt <= byte_cnt + 1'd1;

		if(byte_cnt == 0) begin
			cmd <= io_din;
			dout_en <= (io_din >= EXT_CMD_MIN && io_din <= EXT_CMD_MAX);
			if(io_din == CD_GET) io_dout <= cd_req;
		end else begin
			case(cmd)
				CD_GET:
					if(!byte_cnt[9:3]) begin
						case(byte_cnt[2:0])
							1: io_dout <= cd_in[15:0];
							2: io_dout <= cd_in[31:16];
							3: io_dout <= cd_in[47:32];
						endcase
					end

				CD_SET:
					if(!byte_cnt[9:3]) begin
						case(byte_cnt[2:0])
							1: cd_out[15:0]  <= io_din;
							2: cd_out[31:16] <= io_din;
							3: cd_out[47:32] <= io_din;
						endcase
					end
			endcase
		end
	end
end

reg [48:0] cd_in;
reg [48:0] cd_out;

always @(posedge clk_sys) begin
	reg         send = 0;
	reg  [47:0] command = 0;

	reg         cd_out48_last = 1;
	reg         send_old = 0;
	reg         reset_old = 0;
	reg         msu_audio_req_old = 0;
	reg         msu_audio_jump_sector_old = 0;
	reg         msu_trackrequest_old = 0;
	reg         msu_audio_download_old = 0;

	if (reset) begin
		msu_trackmissing <= 0;
		msu_trackmounting <= 0;
		send <= 0;
		command <= 0;
		msu_audio_ack <= 0;
		msu_audio_download_old <= 0;
	end
	
	msu_audio_download_old <= msu_audio_download;
	if (!msu_audio_download && msu_audio_download_old) begin
		msu_audio_ack <= 0;
	end
	if (msu_audio_download && !msu_audio_download_old) begin
		msu_audio_ack <= 1;
	end
	
	// Outgoing messaging
	// Sectors
	msu_audio_req_old <= msu_audio_req;
	if (!msu_audio_req_old && msu_audio_req && !msu_trackrequest) begin
		// Request for next sector has come from MSU1
		command <= 'h34;
		send <= 1;
	end
	
	// Jump to a sector
	msu_audio_jump_sector_old <= msu_audio_jump_sector;
	if (!msu_audio_jump_sector_old && msu_audio_jump_sector) begin
		command <= { msu_audio_sector, 16'h36 };
		send <= 1;
	end
	
	// Track requests
	msu_trackrequest_old <= msu_trackrequest;
	if (!msu_trackrequest_old && msu_trackrequest) begin
		command <= { 16'h0, msu_trackout, 16'h35 };
		msu_trackmounting <= 1;
		send <= 1;
	end

	// Send and reset
	send_old <= send;
	if (send && !send_old) begin
		cd_in[47:0] <= command;
		cd_in[48] <= ~cd_in[48];
		send <= 0;
		command <= 0;
	end
	else begin
		reset_old <= reset;
		if (!reset_old && reset) begin
			cd_in[47:0] <= 8'hFF;
			cd_in[48] <= ~cd_in[48];
		end
	end

	cd_out48_last <= cd_out[48];
	if (cd_out[48] != cd_out48_last) begin
		if(cd_out == 'h001) begin
			msu_enable <= 1;
		end
		else if(cd_out == 'h002) begin
			msu_enable <= 0;
		end
		else if(cd_out == 'h101) begin
			//    // Handle ack to go low
			//    msu_trackmissing <= 0;
			//    msu_trackmounting <= 0;
			//    //ext_ack <= 0;
		end
		else if(cd_out == 'h201) begin
			// Track has finished mounting
			msu_trackmissing <= 0;
			msu_trackmounting <= 0;
			msu_audio_ack <= 0;
		end
		else if(cd_out == 'h301) begin
			//    // Handle beginning of sector
			//    msu_trackmissing <= 0;
			//    msu_trackmounting <= 0;
		end
		else if(cd_out == 'h401) begin
			// Handle track missing
			msu_trackmissing <= 1;
			msu_trackmounting <= 0;
			msu_audio_ack <= 0;
		end
	end
end

endmodule
