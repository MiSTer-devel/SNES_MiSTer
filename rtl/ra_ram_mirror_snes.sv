// RetroAchievements RAM Mirror for SNES — Option C + RTQuery (Tier 1)
//
// Each VBlank, reads a list of specific addresses from DDRAM (written by ARM),
// fetches the byte values from SDRAM (WRAM) or BSRAM, and writes them back
// to DDRAM for the ARM to read via rcheevos.
//
// Typically ~185 addresses for a game like Super Mario World, taking ~30µs
// per frame. This is frame-accurate with zero visual impact.
//
// DDRAM Layout (at DDRAM_BASE, ARM phys 0x3D000000):
//   [0x00000] Header:   magic(32) + 0(8) + flags(8) + 0(16)
//   [0x00008] Frame:    frame_counter(32) + bsram_size(32)
//
//   [0x40000] AddrReq:  addr_count(32) + request_id(32)       (ARM → FPGA)
//   [0x40008] Addrs:    addr[0](32) + addr[1](32), ...        (2 per 64-bit word)
//
//   [0x48000] ValResp:  response_id(32) + response_frame(32)  (FPGA → ARM)
//   [0x48008] Values:   val[0..7](8b each), val[8..15], ...   (8 per 64-bit word)

module ra_ram_mirror_snes #(
	parameter [28:0] DDRAM_BASE = 29'h07A00000,  // ARM phys 0x3D000000 >> 3
	// Debug: bypass SNI/BSRAM reads, write addr-based pattern instead
	// Set to 1 to test DDRAM pipeline without relying on SDRAM reads
	// Expected value for each address = addr[7:0] ^ 8'hA5
	parameter BYPASS_SNI = 0
)(
	input             clk,           // clk_sys (~21.477 MHz)
	input             reset,
	input             vblank,

	// SDRAM SNI read interface (for WRAM)
	output reg [24:0] sni_addr,
	output reg        sni_rd_req,
	input      [15:0] sni_dout,
	input             sni_ready,
	output reg        sni_word,

	// BSRAM read interface
	output reg [17:0] bsram_addr,
	input       [7:0] bsram_dout,

	// BSRAM actual size (bytes, from cart header ram_mask+1)
	input      [17:0] bsram_size,

	// DDRAM write interface (toggle req/ack)
	output reg [28:0] ddram_wr_addr,
	output reg [63:0] ddram_wr_din,
	output reg  [7:0] ddram_wr_be,
	output reg        ddram_wr_req,
	input             ddram_wr_ack,

	// DDRAM read interface (toggle req/ack)
	output reg [28:0] ddram_rd_addr,
	output reg        ddram_rd_req,
	input             ddram_rd_ack,
	input      [63:0] ddram_rd_dout,

	// Status
	output reg        active,
	output reg [31:0] dbg_frame_counter
);

// ======================================================================
// Constants
// ======================================================================
localparam [28:0] ADDRLIST_BASE = DDRAM_BASE + 29'h8000;  // byte offset 0x40000 / 8
localparam [28:0] VALCACHE_BASE = DDRAM_BASE + 29'h9000;  // byte offset 0x48000 / 8
localparam [31:0] WRAM_LIMIT    = 32'h20000;              // 128KB boundary
localparam [12:0] MAX_ADDRS     = 13'd4096;

// Realtime query mailbox (Tier 1 smart cache)
localparam [28:0] QUERY_CTRL_ADDR = DDRAM_BASE + 29'hA000;  // byte offset 0x50000 / 8
localparam [28:0] QUERY_REQ_BASE  = DDRAM_BASE + 29'hA001;  // byte offset 0x50008 / 8
localparam [28:0] QUERY_RESP_BASE = DDRAM_BASE + 29'hA011;  // byte offset 0x50088 / 8
localparam [28:0] ARM_CFG_ADDR    = DDRAM_BASE + 29'd8;        // byte offset 0x40: ARM-written config
localparam [3:0]  MAX_RT_QUERIES  = 4'd16;

// ======================================================================
// Clock domain crossing synchronizers
// Note: sni_ready does NOT need a synchronizer because clk_sys and
// clk_mem come from the same PLL with a 4:1 ratio (synchronous clocks).
// The original sni.sv module also reads sni_ready directly.
// ======================================================================
reg dwr_ack_s1, dwr_ack_s2;
reg drd_ack_s1, drd_ack_s2;
always @(posedge clk) begin
	dwr_ack_s1 <= ddram_wr_ack; dwr_ack_s2 <= dwr_ack_s1;
	drd_ack_s1 <= ddram_rd_ack; drd_ack_s2 <= drd_ack_s1;
end

// ======================================================================
// VBlank edge detection
// ======================================================================
reg vblank_prev;
wire vblank_rising = vblank & ~vblank_prev;
always @(posedge clk) vblank_prev <= vblank;

// Sticky vblank flag — captures edge; consumed in S_IDLE without triggering scan
reg vblank_pending;
always @(posedge clk) begin
	if (reset)
		vblank_pending <= 1'b0;
	else if (vblank_rising)
		vblank_pending <= 1'b1;
	else if (state == S_IDLE && vblank_pending)
		vblank_pending <= 1'b0;
end

// Pre-VBlank scan trigger — fires at ~line 215 (pre-NMI, end of active display).
// WRAM is scanned BEFORE the SNES NMI handler writes 0x1FFC=160,
// matching the timing used by RASnes9x for achievement evaluation.
// SDRAM arbitration (can_start_sni in sdram.sv) handles contention safely.
//
// Two-counter design (line + sub-line) avoids large 19-bit constants that
// trigger a known Quartus 17.0 SGN_EXTRACTOR crash.
// Line period: 1364 clk_sys cycles (NTSC). Trigger at start of line 215.
localparam [10:0] CYCLES_PER_LINE = 11'd1363;   // 0..1363 = 1364 cycles
localparam [8:0]  PRE_VBL_LINE    = 9'd222;

reg [10:0] subline_cnt;   // 0..1363, cycle within current scanline
reg [8:0]  line_cnt;      // 0..261, current scanline since vblank fell

always @(posedge clk) begin
	if (reset || vblank) begin
		subline_cnt <= 11'd0;
		line_cnt    <= 9'd0;
	end else if (subline_cnt == CYCLES_PER_LINE) begin
		subline_cnt <= 11'd0;
		line_cnt    <= line_cnt + 9'd1;
	end else begin
		subline_cnt <= subline_cnt + 11'd1;
	end
end

reg pre_vbl_pending;
always @(posedge clk) begin
	if (reset)
		pre_vbl_pending <= 1'b0;
	else if (~vblank && line_cnt == PRE_VBL_LINE && subline_cnt == 11'd0)
		pre_vbl_pending <= 1'b1;
	else if (state == S_IDLE && pre_vbl_pending)
		pre_vbl_pending <= 1'b0;
end

// ======================================================================
// State machine
// ======================================================================
localparam S_IDLE        = 5'd0;
localparam S_DD_WR_WAIT  = 5'd1;   // Generic: wait DDRAM write ack
localparam S_DD_RD_WAIT  = 5'd2;   // Generic: wait DDRAM read ack
localparam S_READ_HDR    = 5'd3;   // Issue DDRAM read: addr list header
localparam S_PARSE_HDR   = 5'd4;   // Parse addr_count + request_id
localparam S_READ_PAIR   = 5'd5;   // Issue DDRAM read: address pair
localparam S_PARSE_ADDR  = 5'd6;   // Extract address from cached word
localparam S_DISPATCH    = 5'd7;   // Route to WRAM or BSRAM fetch
localparam S_FETCH_WRAM  = 5'd8;   // Issue SDRAM SNI read
localparam S_WRAM_WAIT   = 5'd9;   // Wait for SDRAM ready
localparam S_FETCH_BSRAM = 5'd10;  // Issue BSRAM read
localparam S_BSRAM_WAIT  = 5'd11;  // 1st wait: present address to altsyncram
localparam S_STORE_VAL   = 5'd12;  // Store byte in collect buffer
localparam S_FLUSH_BUF   = 5'd13;  // Write collect buffer to DDRAM
localparam S_WRITE_RESP  = 5'd14;  // Write response header
localparam S_WR_HDR0     = 5'd15;  // Write main header word 0 (busy=0)
localparam S_WR_HDR1     = 5'd16;  // Write main header word 1 (frame+bsram)
localparam S_WR_DBG      = 5'd17;  // Write debug counters word 1
localparam S_WR_DBG2     = 5'd18;  // Write debug counters word 2
// Realtime query states
localparam S_QRY_PARSE   = 5'd19;
localparam S_QRY_RD_REQ  = 5'd20;
localparam S_QRY_FETCH   = 5'd21;
localparam S_QRY_WAIT_W  = 5'd22;  // WRAM query wait
localparam S_QRY_WAIT_B  = 5'd23;  // BSRAM query wait
localparam S_QRY_WR_RESP = 5'd24;
localparam S_QRY_WR_CTRL = 5'd25;
localparam S_RD_ARMCFG    = 5'd26;  // initiate read of ARM config word
localparam S_PARSE_ARMCFG = 5'd27;  // latch rtquery_armed from rd_data[0]
localparam S_BSRAM_WAIT2  = 5'd28;  // 2nd wait: BSRAM data valid (altsyncram registers addr at edge N, output valid after edge N)
localparam S_QRY_LATCH_B  = 5'd29;  // extra wait for BSRAM data valid (rtquery path)

reg [4:0]  state;
reg [4:0]  return_state;

reg [31:0] frame_counter;
always @(posedge clk) dbg_frame_counter <= frame_counter;

reg [63:0] rd_data;         // Captured DDRAM read data
reg [31:0] req_count;       // Number of addresses in request
reg [31:0] req_id;          // Request ID from ARM
reg [12:0] addr_idx;        // Current address index (0..req_count-1)
reg [63:0] addr_word;       // Cached DDRAM word containing 2 addresses
reg [31:0] cur_addr;        // Current address being fetched
reg        cur_addr_lsb;    // LSB of WRAM address (byte within word)
reg [63:0] collect_buf;
reg  [3:0] collect_cnt;     // 0-8 bytes in buffer
reg [12:0] val_word_idx;    // DDRAM word index for value writes

reg        sni_phase;       // 0=pulse sent (skip first cycle), 1=polling sni_ready
reg [15:0] timeout;
reg  [7:0] fetch_byte;

// Debug counters (reset each frame)
reg [15:0] dbg_ok_cnt;       // SNI reads completed normally
reg [15:0] dbg_timeout_cnt;  // SNI reads that timed out
reg [15:0] dbg_first_dout;   // raw sni_dout from first good read
reg        dbg_first_cap;    // first good read captured flag
reg [15:0] dbg_max_timeout;  // max timeout value seen in a good read
reg  [7:0] dbg_dispatch_cnt; // entries to S_DISPATCH
reg [15:0] dbg_wram_cnt;     // entries to S_FETCH_WRAM
reg [15:0] dbg_bsram_cnt;    // entries to S_FETCH_BSRAM
reg [15:0] dbg_first_addr;   // first cur_addr from S_DISPATCH

// Realtime query registers
reg  [7:0] qry_request_seq;
reg  [7:0] qry_last_seen_seq;
reg  [7:0] qry_num;
reg  [3:0] qry_idx;
reg [31:0] qry_addr;
reg  [7:0] qry_num_bytes;
reg [31:0] qry_value;
reg  [2:0] qry_byte_idx;
reg        qry_sni_phase;
reg  [10:0] qry_poll_timer;
reg        rtquery_armed = 1'b0;  // set by ARM via RA_ARM_CFG_RTQUERY bit

// DDRAM wait timeout (prevents permanent stall)
reg [19:0] ddram_wait_timeout;

// ======================================================================
// Main state machine
// ======================================================================
always @(posedge clk) begin

	if (reset) begin
		state        <= S_IDLE;
		active       <= 1'b0;
		frame_counter <= 32'd0;
		sni_rd_req   <= 1'b0;
		sni_word     <= 1'b0;
		ddram_wr_req <= dwr_ack_s2;
		ddram_rd_req <= drd_ack_s2;
		qry_last_seen_seq <= 8'd0;
		qry_poll_timer <= 11'd0;
	end
	else begin
		case (state)

		// =============================================================
		// IDLE: wait for pre-VBlank trigger (~line 215)
		// =============================================================
		S_IDLE: begin
			active   <= 1'b0;
			sni_word <= 1'b0;
			// pre_vbl_pending fires at ~line 215 so WRAM is captured pre-NMI.
			// vblank_pending is still cleared by its own always block; no scan here.
			if (pre_vbl_pending) begin
				active <= 1'b1;
				qry_poll_timer   <= 10'd0;
				// Reset debug counters for this frame
				dbg_ok_cnt      <= 16'd0;
				dbg_timeout_cnt <= 16'd0;
				dbg_first_cap   <= 1'b0;
				dbg_first_dout  <= 16'd0;
				dbg_max_timeout <= 16'd0;
				dbg_dispatch_cnt <= 8'd0;
				dbg_wram_cnt    <= 16'd0;
				dbg_bsram_cnt   <= 16'd0;
				dbg_first_addr  <= 16'd0;
				// Write header with busy=1
				ddram_wr_addr <= DDRAM_BASE;
				ddram_wr_din  <= {16'h0300, 8'h01, 8'd0, 32'h52414348};
				ddram_wr_be   <= 8'hFF;
				ddram_wr_req  <= ~ddram_wr_req;
				return_state  <= S_READ_HDR;
				state         <= S_DD_WR_WAIT;
			end
			else if (qry_poll_timer < 11'd2000) begin
				qry_poll_timer <= qry_poll_timer + 11'd1;
			end
			else if (rtquery_armed) begin
				// Poll realtime query mailbox
				qry_poll_timer <= 11'd0;
				ddram_rd_addr <= QUERY_CTRL_ADDR;
				ddram_rd_req  <= ~ddram_rd_req;
				return_state  <= S_QRY_PARSE;
				state         <= S_DD_RD_WAIT;
			end
			else begin
				qry_poll_timer <= 11'd0;  // no rtquery active, skip poll
			end
		end

		// =============================================================
		// Generic DDRAM write wait
		// =============================================================
		S_DD_WR_WAIT: begin
			ddram_wait_timeout <= ddram_wait_timeout + 20'd1;
			if (ddram_wr_req == dwr_ack_s2) begin
				ddram_wait_timeout <= 20'd0;
				state <= return_state;
			end else if (ddram_wait_timeout >= 20'hFFFFF) begin
				ddram_wait_timeout <= 20'd0;
				state <= S_IDLE;
			end
		end

		// =============================================================
		// Generic DDRAM read wait — capture data
		// =============================================================
		S_DD_RD_WAIT: begin
			ddram_wait_timeout <= ddram_wait_timeout + 20'd1;
			if (ddram_rd_req == drd_ack_s2) begin
				ddram_wait_timeout <= 20'd0;
				rd_data <= ddram_rd_dout;
				state   <= return_state;
			end else if (ddram_wait_timeout >= 20'hFFFFF) begin
				ddram_wait_timeout <= 20'd0;
				state <= S_IDLE;
			end
		end

		// =============================================================
		// Read address list header from DDRAM
		// =============================================================
		S_READ_HDR: begin
			ddram_rd_addr <= ADDRLIST_BASE;
			ddram_rd_req  <= ~ddram_rd_req;
			return_state  <= S_PARSE_HDR;
			state         <= S_DD_RD_WAIT;
		end

		// =============================================================
		// Parse header: extract addr_count and request_id
		// =============================================================
		S_PARSE_HDR: begin
			req_id <= rd_data[63:32];
			if (rd_data[31:0] == 32'd0) begin
				// No addresses — skip to response
				req_count <= 32'd0;
				state     <= S_WRITE_RESP;
			end else begin
				req_count    <= (rd_data[31:0] > {19'd0, MAX_ADDRS}) ?
				                {19'd0, MAX_ADDRS} : rd_data[31:0];
				addr_idx     <= 13'd0;
				collect_cnt  <= 4'd0;
				collect_buf  <= 64'd0;
				val_word_idx <= 13'd0;
				state        <= S_READ_PAIR;
			end
		end

		// =============================================================
		// Read address pair from DDRAM (2 addrs per 64-bit word)
		// =============================================================
		S_READ_PAIR: begin
			ddram_rd_addr <= ADDRLIST_BASE + 29'd1 + {16'd0, addr_idx[12:1]};
			ddram_rd_req  <= ~ddram_rd_req;
			return_state  <= S_PARSE_ADDR;
			state         <= S_DD_RD_WAIT;
		end

		// =============================================================
		// Extract current address from cached word
		// =============================================================
		S_PARSE_ADDR: begin
			if (!addr_idx[0]) begin
				// Even index: save word, use low 32 bits
				addr_word <= rd_data;
				cur_addr  <= rd_data[31:0];
			end else begin
				// Odd index: use high 32 bits from saved word
				cur_addr <= addr_word[63:32];
			end
			state <= S_DISPATCH;
		end

		// =============================================================
		// Route to WRAM (SDRAM) or BSRAM based on address
		// =============================================================
		S_DISPATCH: begin
			dbg_dispatch_cnt <= dbg_dispatch_cnt + 8'd1;
			if (!dbg_dispatch_cnt)
				dbg_first_addr <= cur_addr[15:0];
			if (BYPASS_SNI) begin
				// Debug bypass: write addr-based pattern, skip SDRAM/BSRAM
				fetch_byte <= cur_addr[7:0] ^ 8'hA5;
				state      <= S_STORE_VAL;
			end
			else if (cur_addr < WRAM_LIMIT) begin
				dbg_wram_cnt <= dbg_wram_cnt + 16'd1;
				state <= S_FETCH_WRAM;
			end
			else begin
				dbg_bsram_cnt <= dbg_bsram_cnt + 16'd1;
				state <= S_FETCH_BSRAM;
			end
		end

		// =============================================================
		// WRAM: byte-mode SDRAM SNI read (matches sni.sv protocol exactly)
		// Uses sni_word=0 (byte read) so sdram.sv handles byte selection.
		// No vblank gate: scan starts pre-NMI (~line 215) so we capture
		// active-display WRAM values before the NMI handler runs.
		// can_start_sni in sdram.sv serializes with CPU/PPU safely.
		// =============================================================
		S_FETCH_WRAM: begin
			// Read immediately — SDRAM arbitration handles contention
			sni_addr     <= {1'b1, 7'd0, cur_addr[16:0]};
			sni_word     <= 1'b0;     // byte mode (matches sni.sv)
			sni_rd_req   <= 1'b1;     // ONE cycle pulse
			sni_phase    <= 1'b0;
			timeout      <= 16'd0;
			state        <= S_WRAM_WAIT;
		end

		S_WRAM_WAIT: begin
			sni_rd_req <= 1'b0;      // deassert immediately → one-cycle pulse
			timeout    <= timeout + 16'd1;
			if (!sni_phase) begin
				// First cycle: pulse just deasserted, sdram is clearing
				// sni_ready. Skip this cycle to avoid seeing stale HIGH.
				sni_phase <= 1'b1;
			end else begin
				// Poll sni_ready directly (synchronous clocks, no CDC needed)
				if (sni_ready) begin
					// Byte mode: sdram.sv returns selected byte in sni_dout[7:0]
					fetch_byte <= sni_dout[7:0];
					dbg_ok_cnt <= dbg_ok_cnt + 16'd1;
					if (!dbg_first_cap) begin
						dbg_first_dout <= sni_dout;
						dbg_first_cap  <= 1'b1;
					end
					if (timeout > dbg_max_timeout)
						dbg_max_timeout <= timeout;
					state <= S_STORE_VAL;
				end
			end
			// Timeout safety (~3ms)
			if (timeout >= 16'hFFFF) begin
				fetch_byte <= 8'd0;
				dbg_timeout_cnt <= dbg_timeout_cnt + 16'd1;
				state      <= S_STORE_VAL;
			end
		end

		// =============================================================
		// BSRAM: 2-cycle block RAM read
		// altsyncram (outdata_reg_a=UNREGISTERED): address registered at edge N,
		// bsram_dout (q_a) valid after edge N => capture in S_BSRAM_WAIT2 at edge N+2.
		// =============================================================
		S_FETCH_BSRAM: begin
			// VBlank gate: keep BSRAM in same VBlank window as WRAM
			// to prevent delta-condition frame skew on SA-1 games.
			if (vblank) begin
				bsram_addr <= cur_addr - 32'h20000;
				state      <= S_BSRAM_WAIT;
			end
			// else: stay here until vblank returns (same as S_FETCH_WRAM)
		end

		S_BSRAM_WAIT: begin
			// Address presented to altsyncram this edge; wait one more cycle for data.
			state <= S_BSRAM_WAIT2;
		end

		S_BSRAM_WAIT2: begin
			fetch_byte <= bsram_dout;  // valid now
			state      <= S_STORE_VAL;
		end

		// =============================================================
		// Store fetched byte in collect buffer, advance index
		// =============================================================
		S_STORE_VAL: begin
			case (collect_cnt[2:0])
				3'd0: collect_buf[ 7: 0] <= fetch_byte;
				3'd1: collect_buf[15: 8] <= fetch_byte;
				3'd2: collect_buf[23:16] <= fetch_byte;
				3'd3: collect_buf[31:24] <= fetch_byte;
				3'd4: collect_buf[39:32] <= fetch_byte;
				3'd5: collect_buf[47:40] <= fetch_byte;
				3'd6: collect_buf[55:48] <= fetch_byte;
				3'd7: collect_buf[63:56] <= fetch_byte;
			endcase
			collect_cnt <= collect_cnt + 4'd1;
			addr_idx    <= addr_idx + 13'd1;

			// Flush when buffer full (8 bytes) or last address
			if (collect_cnt == 4'd7 || (addr_idx + 13'd1 >= req_count[12:0])) begin
				state <= S_FLUSH_BUF;
			end
			// Next address routing
			else if (addr_idx[0]) begin
				// Was odd index → next is even → need new pair
				state <= S_READ_PAIR;
			end else begin
				// Was even index → next is odd → use cached high half
				state <= S_PARSE_ADDR;
			end
		end

		// =============================================================
		// Flush collect buffer to DDRAM value cache
		// =============================================================
		S_FLUSH_BUF: begin
			ddram_wr_addr <= VALCACHE_BASE + 29'd1 + {16'd0, val_word_idx};
			ddram_wr_din  <= collect_buf;
			ddram_wr_be   <= (collect_cnt == 4'd8) ? 8'hFF
			                 : ((8'd1 << collect_cnt[2:0]) - 8'd1);
			ddram_wr_req  <= ~ddram_wr_req;
			val_word_idx  <= val_word_idx + 13'd1;
			collect_cnt   <= 4'd0;
			collect_buf   <= 64'd0;

			if (addr_idx >= req_count[12:0]) begin
				return_state <= S_WRITE_RESP;
			end else if (!addr_idx[0]) begin
				// Even → need new DDRAM pair read
				return_state <= S_READ_PAIR;
			end else begin
				// Odd → use cached high half
				return_state <= S_PARSE_ADDR;
			end
			state <= S_DD_WR_WAIT;
		end

		// =============================================================
		// Write response header: {response_frame, response_id}
		// =============================================================
		S_WRITE_RESP: begin
			ddram_wr_addr <= VALCACHE_BASE;
			ddram_wr_din  <= {frame_counter + 32'd1, req_id};
			ddram_wr_be   <= 8'hFF;
			ddram_wr_req  <= ~ddram_wr_req;
			return_state  <= S_WR_HDR0;
			state         <= S_DD_WR_WAIT;
		end

		// =============================================================
		// Write main header word 0: magic + flags=0 (not busy)
		// =============================================================
		S_WR_HDR0: begin
			ddram_wr_addr <= DDRAM_BASE;
			ddram_wr_din  <= {16'h0300, 8'h00, 8'd0, 32'h52414348};
			ddram_wr_be   <= 8'hFF;
			ddram_wr_req  <= ~ddram_wr_req;
			return_state  <= S_WR_HDR1;
			state         <= S_DD_WR_WAIT;
		end

		// =============================================================
		// Write main header word 1: frame_counter + bsram_size
		// =============================================================
		S_WR_HDR1: begin
			ddram_wr_addr <= DDRAM_BASE + 29'd1;
			ddram_wr_din  <= {{14'd0, bsram_size}, frame_counter + 32'd1};
			ddram_wr_be   <= 8'hFF;
			ddram_wr_req  <= ~ddram_wr_req;
			frame_counter <= frame_counter + 32'd1;
			return_state  <= S_WR_DBG;
			state         <= S_DD_WR_WAIT;
		end

		// =============================================================
		// Write debug word 1: {ver(8), dispatch(8), first_dout(16), timeout(16), ok(16)}
		// =============================================================
		S_WR_DBG: begin
			ddram_wr_addr <= DDRAM_BASE + 29'd2;
			ddram_wr_din  <= {8'h0E, dbg_dispatch_cnt, dbg_first_dout, dbg_timeout_cnt, dbg_ok_cnt};
			ddram_wr_be   <= 8'hFF;
			ddram_wr_req  <= ~ddram_wr_req;
			return_state  <= S_WR_DBG2;
			state         <= S_DD_WR_WAIT;
		end

		// =============================================================
		// Write debug word 2: {first_addr(16), wram_cnt(16), bsram_cnt(16), max_timeout(16)}
		// =============================================================
		S_WR_DBG2: begin
			ddram_wr_addr <= DDRAM_BASE + 29'd3;
			ddram_wr_din  <= {dbg_first_addr, dbg_wram_cnt, dbg_bsram_cnt, dbg_max_timeout};
			ddram_wr_be   <= 8'hFF;
			ddram_wr_req  <= ~ddram_wr_req;
			return_state  <= S_RD_ARMCFG;  // read ARM config before returning to idle
			state         <= S_DD_WR_WAIT;
		end

		// Read ARM-written config byte once per VBlank.
		// ARM sets RA_ARM_CFG_RTQUERY (bit 0) when rtquery is active.
		// FPGA latches it to gate inter-VBlank query mailbox polling.
		S_RD_ARMCFG: begin
			ddram_rd_addr <= ARM_CFG_ADDR;
			ddram_rd_req  <= ~ddram_rd_req;
			return_state  <= S_PARSE_ARMCFG;
			state         <= S_DD_RD_WAIT;
		end

		S_PARSE_ARMCFG: begin
			rtquery_armed <= rd_data[0];
			state <= S_IDLE;
		end

		// =============================================================
		// Realtime Query States
		// =============================================================
		S_QRY_PARSE: begin
			if (rd_data[7:0] != qry_last_seen_seq && rd_data[15:8] != 8'd0) begin
				qry_request_seq <= rd_data[7:0];
				qry_num         <= (rd_data[15:8] > {4'd0, MAX_RT_QUERIES}) ?
				                   {4'd0, MAX_RT_QUERIES} : rd_data[15:8];
				qry_idx         <= 4'd0;
				state           <= S_QRY_RD_REQ;
			end else begin
				state <= S_IDLE;
			end
		end

		S_QRY_RD_REQ: begin
			ddram_rd_addr <= QUERY_REQ_BASE + {25'd0, qry_idx};
			ddram_rd_req  <= ~ddram_rd_req;
			return_state  <= S_QRY_FETCH;
			state         <= S_DD_RD_WAIT;
		end

		S_QRY_FETCH: begin
			qry_addr      <= rd_data[31:0];
			qry_num_bytes <= (rd_data[39:32] == 8'd0) ? 8'd1 : rd_data[39:32];
			qry_value     <= 32'd0;
			qry_byte_idx  <= 3'd0;
			// Route: WRAM (< 0x20000) or BSRAM
			if (rd_data[31:0] < WRAM_LIMIT) begin
				sni_addr      <= {1'b1, 7'd0, rd_data[16:0]};
				sni_word      <= 1'b0;
				sni_rd_req    <= 1'b1;
				qry_sni_phase <= 1'b0;
				timeout       <= 16'd0;
				state         <= S_QRY_WAIT_W;
			end else begin
				bsram_addr <= rd_data[31:0] - 32'h20000;
				state      <= S_QRY_LATCH_B;  // extra cycle for altsyncram latency
			end
		end

		S_QRY_WAIT_W: begin
			sni_rd_req <= 1'b0;
			timeout    <= timeout + 16'd1;
			if (!qry_sni_phase) begin
				qry_sni_phase <= 1'b1;
			end else if (sni_ready) begin
				qry_value    <= qry_value | ({24'd0, sni_dout[7:0]} << (qry_byte_idx * 8));
				qry_byte_idx <= qry_byte_idx + 3'd1;
				if (qry_byte_idx + 3'd1 >= qry_num_bytes[2:0]) begin
					state <= S_QRY_WR_RESP;
				end else begin
					qry_addr      <= qry_addr + 32'd1;
					sni_addr      <= {1'b1, 7'd0, qry_addr[16:0] + 17'd1};
					sni_rd_req    <= 1'b1;
					qry_sni_phase <= 1'b0;
					timeout       <= 16'd0;
				end
			end
			if (timeout >= 16'hFFFF) begin
				qry_byte_idx <= qry_byte_idx + 3'd1;
				if (qry_byte_idx + 3'd1 >= qry_num_bytes[2:0])
					state <= S_QRY_WR_RESP;
				else begin
					qry_addr      <= qry_addr + 32'd1;
					sni_addr      <= {1'b1, 7'd0, qry_addr[16:0] + 17'd1};
					sni_rd_req    <= 1'b1;
					qry_sni_phase <= 1'b0;
					timeout       <= 16'd0;
				end
			end
		end

		S_QRY_LATCH_B: begin
			// altsyncram registered address at previous edge; bsram_dout valid now.
			state <= S_QRY_WAIT_B;
		end

		S_QRY_WAIT_B: begin
			// Capture BSRAM byte (valid after 2-cycle altsyncram latency)
			qry_value    <= qry_value | ({24'd0, bsram_dout} << (qry_byte_idx * 8));
			qry_byte_idx <= qry_byte_idx + 3'd1;
			if (qry_byte_idx + 3'd1 >= qry_num_bytes[2:0]) begin
				state <= S_QRY_WR_RESP;
			end else begin
				qry_addr   <= qry_addr + 32'd1;
				bsram_addr <= qry_addr + 32'd1 - 32'h20000;
				state      <= S_QRY_LATCH_B;  // wait again for next byte
			end
		end

		S_QRY_WR_RESP: begin
			ddram_wr_addr <= QUERY_RESP_BASE + {25'd0, qry_idx};
			ddram_wr_din  <= {32'd0, qry_value};
			ddram_wr_be   <= 8'hFF;
			ddram_wr_req  <= ~ddram_wr_req;
			qry_idx       <= qry_idx + 4'd1;
			if (qry_idx + 4'd1 >= qry_num[3:0]) begin
				return_state <= S_QRY_WR_CTRL;
			end else begin
				return_state <= S_QRY_RD_REQ;
			end
			state <= S_DD_WR_WAIT;
		end

		S_QRY_WR_CTRL: begin
			qry_last_seen_seq <= qry_request_seq;
			ddram_wr_addr     <= QUERY_CTRL_ADDR;
			ddram_wr_din      <= {24'd0, qry_request_seq, 16'd0, qry_num[7:0], qry_request_seq};
			ddram_wr_be       <= 8'hFF;
			ddram_wr_req      <= ~ddram_wr_req;
			return_state      <= S_IDLE;
			state             <= S_DD_WR_WAIT;
		end

		default: state <= S_IDLE;
		endcase
	end
end

endmodule
