module savestates_regs
(
	input reset_n,
	input clk,

	input ss_busy,
	input save_en,

	input ss_reg_sel,

	input sysclkf_ce,
	input sysclkr_ce,

	input romsel_n,

	input [23:0] ca,
	input cpurd_ce,
	input cpurd_ce_n,
	input cpuwr_ce,

	input [7:0] pa,
	input pard_ce,
	input pawr_ce,

	input [7:0] di,
	output reg [7:0] ssr_do,
	output reg ssr_oe
);

wire mmio_sel = (ca[15:10] == 6'b010000);
wire io_sel = ~ca[22] & mmio_sel; // $00-$3F/$80-$BF:$4000-$43FF
wire ss_io_sel = ss_reg_sel & mmio_sel; // $C0:$4000-$43FF

wire ppu_sel = (ca[15:8] == 8'h21) & (ca[7:6] == 2'b00);
wire wram_sel = (ca[15:8] == 8'h21) & (ca[7:2] == 6'b100000);

reg  ppu_word_reg, ppu_word_reg_read;

reg [16:0] wmadd;
reg        nmitimen_j;
reg  [1:0] nmitimen_hv;
reg        nmitimen_n;
reg [ 7:0] wrmpya;
reg [ 7:0] wrmpyb;
reg [15:0] wrdiv;
reg [ 7:0] wrdivb;
reg        wrdivb_last;
reg [ 8:0] htime;
reg [ 8:0] vtime;
reg [ 7:0] hdmaen;
reg        memsel;

reg [ 7:0] dma0[0:6];

reg        ppu_inidisp_fb;
reg [ 3:0] ppu_inidisp_br;
reg [ 7:0] ppu_objsel;
reg        ppu_oamadd_prio;
reg [ 8:0] ppu_oamadd;
reg [ 7:0] ppu_bgmode;
reg [ 7:0] ppu_mosaic;
reg [ 7:0] ppu_bg1sc;
reg [ 7:0] ppu_bg2sc;
reg [ 7:0] ppu_bg3sc;
reg [ 7:0] ppu_bg4sc;
reg [ 7:0] ppu_bg12nba;
reg [ 7:0] ppu_bg34nba;
reg [ 9:0] ppu_bg1_hofs;
reg [ 9:0] ppu_bg1_vofs;
reg [12:0] ppu_m7_hofs;
reg [12:0] ppu_m7_vofs;
reg [ 7:0] ppu_m7_latch;
reg [ 9:0] ppu_bg2_hofs;
reg [ 9:0] ppu_bg2_vofs;
reg [ 9:0] ppu_bg3_hofs;
reg [ 9:0] ppu_bg3_vofs;
reg [ 9:0] ppu_bg4_hofs;
reg [ 9:0] ppu_bg4_vofs;
reg [ 7:0] ppu_ofs_latch;
reg [ 2:0] ppu_hofs_latch;
reg        ppu_vmain_inc;
reg [ 3:0] ppu_vmain;
reg  [7:0] ppu_vmain_inc_cnt;
reg [15:0] ppu_vmadd;
reg [ 7:6] ppu_m7sel_rf;
reg [ 1:0] ppu_m7sel_yx;
reg [15:0] ppu_m7a;
reg [15:0] ppu_m7b;
reg [15:0] ppu_m7c;
reg [15:0] ppu_m7d;
reg [12:0] ppu_m7x;
reg [12:0] ppu_m7y;
reg [ 8:0] ppu_cgadd;
reg [ 7:0] ppu_cglatch;
reg [ 7:0] ppu_w12sel;
reg [ 7:0] ppu_w34sel;
reg [ 7:0] ppu_wobjsel;
reg [ 7:0] ppu_wh0;
reg [ 7:0] ppu_wh1;
reg [ 7:0] ppu_wh2;
reg [ 7:0] ppu_wh3;
reg [ 7:0] ppu_wbglog;
reg [ 3:0] ppu_wobjlog;
reg [ 4:0] ppu_tm;
reg [ 4:0] ppu_ts;
reg [ 4:0] ppu_tmw;
reg [ 4:0] ppu_tsw;
reg [ 7:4] ppu_cgwsel_mss;
reg [ 1:0] ppu_cgwsel_ad;
reg [ 7:0] ppu_cgadsub;
reg [ 7:0] ppu_coldata;
reg [ 7:6] ppu_setini_ex;
reg [ 3:0] ppu_setini;

reg read_hb;
always @(posedge clk or negedge reset_n) begin
	 if (~reset_n) begin
		dma0[0] <= 8'hFF;
		dma0[1] <= 8'hFF;
		dma0[2] <= 8'hFF;
		dma0[3] <= 8'hFF;
		dma0[4] <= 8'hFF;
		dma0[5] <= 8'hFF;
		dma0[6] <= 8'hFF;
		read_hb <= 0;
		ppu_word_reg_read <= 0;
		wmadd <= 0;
		nmitimen_j <= 0;
		nmitimen_hv <= 0;
		nmitimen_n <= 0;
		wrmpya <= 0;
		wrmpyb <= 0;
		wrdiv <= 0;
		wrdivb <= 8'h01;
		wrdivb_last <= 0;
		htime <= 9'h1FF;
		vtime <= 9'h1FF;
		hdmaen <= 0;
		memsel <= 0;
	 end else begin

		if (cpuwr_ce) begin
			if (ss_busy & ss_io_sel & (ca[9:8] == 2'd3)) begin
				case(ca[7:0])
					// Temp storage for DMA registers during save state
					8'h00: dma0[0] <= di;
					8'h01: dma0[1] <= di;
					8'h02: dma0[2] <= di;
					8'h03: dma0[3] <= di;
					8'h04: dma0[4] <= di;
					8'h05: dma0[5] <= di;
					8'h06: dma0[6] <= di;
					default: ;
				endcase
			end

			// For only writing to the shadow register
			if (ss_busy) begin
				if (ss_reg_sel & ppu_sel & (ca[5:0] == 6'h00)) begin
					ppu_inidisp_fb <= di[7];
					ppu_inidisp_br <= di[3:0];
				end

				if (ss_io_sel) begin
					if (ca[9:8] == 2'd2) begin
						case(ca[7:0])
							8'h00: begin
								nmitimen_j  <= di[0];
								nmitimen_hv <= di[5:4];
								nmitimen_n  <= di[7];
							end
							8'h03: wrmpyb <= di;
							8'h06: wrdivb <= di;
							8'h0C: hdmaen <= di;
							default: ;
						endcase
					end
				end
			end
		end

		if (cpuwr_ce & ~(ss_busy & save_en)) begin
			if (io_sel & (ca[9:8] == 2'd2)) begin
				case(ca[7:0])
					8'h00: begin
						nmitimen_j  <= di[0];
						nmitimen_hv <= di[5:4];
						nmitimen_n  <= di[7];
					end
					8'h02: wrmpya <= di;
					8'h03: begin
						wrmpyb <= di;
						wrdivb_last <= 0;
					end
					8'h04: wrdiv[7:0]  <= di;
					8'h05: wrdiv[15:8] <= di;
					8'h06: begin
						wrdivb <= di;
						wrdivb_last <= 1;
					end
					8'h07: htime[7:0] <= di;
					8'h08: htime[8]   <= di[0];
					8'h09: vtime[7:0] <= di;
					8'h0A: vtime[8]   <= di[0];
					8'h0C: hdmaen     <= di;
					8'h0D: memsel     <= di[0];
					default: ;
				endcase
			end
		end

		if (pawr_ce & ~(ss_busy & save_en)) begin
			if (pa[7:2] == 6'b100000) begin // $80-$83
				case(pa[1:0])
					2'd1: wmadd[ 7: 0] <= di;
					2'd2: wmadd[15: 8] <= di;
					2'd3: wmadd[   16] <= di[0];
					default: ;
				endcase
			end
		end

		if (pawr_ce & ~(ss_busy & (save_en | ca[16]))) begin
			if (pa[7:6] == 2'b00) begin
				case(pa[5:0])
					6'h00: begin
						ppu_inidisp_fb     <= di[7];
						ppu_inidisp_br     <= di[3:0];
					end
					6'h01: ppu_objsel      <= di;
					6'h02: ppu_oamadd[7:0] <= di;
					6'h03: begin
						ppu_oamadd_prio    <= di[7];
						ppu_oamadd[8]      <= di[0];
					end
					6'h04: ;// OAMDATA
					6'h05: ppu_bgmode      <= di;
					6'h06: ppu_mosaic      <= di;
					6'h07: ppu_bg1sc       <= di;
					6'h08: ppu_bg2sc       <= di;
					6'h09: ppu_bg3sc       <= di;
					6'h0A: ppu_bg4sc       <= di;
					6'h0B: ppu_bg12nba     <= di;
					6'h0C: ppu_bg34nba     <= di;
					6'h0D: begin
						ppu_bg1_hofs       <= { di[1:0], ppu_ofs_latch[7:3], ppu_hofs_latch };
						ppu_ofs_latch      <= di;
						ppu_hofs_latch     <= di[2:0];

						ppu_m7_hofs        <= { di[4:0], ppu_m7_latch };
						ppu_m7_latch       <= di;
					end
					6'h0E: begin
						ppu_bg1_vofs       <= { di[1:0], ppu_ofs_latch[7:0] };
						ppu_ofs_latch      <= di;

						ppu_m7_vofs        <= { di[4:0], ppu_m7_latch };
						ppu_m7_latch       <= di;
					end
					6'h0F: begin
						ppu_bg2_hofs       <= { di[1:0], ppu_ofs_latch[7:3], ppu_hofs_latch };
						ppu_ofs_latch      <= di;
						ppu_hofs_latch     <= di[2:0];
					end
					6'h10: begin
						ppu_bg2_vofs       <= { di[1:0], ppu_ofs_latch[7:0] };
						ppu_ofs_latch      <= di;
					end
					6'h11: begin
						ppu_bg3_hofs       <= { di[1:0], ppu_ofs_latch[7:3], ppu_hofs_latch };
						ppu_ofs_latch      <= di;
						ppu_hofs_latch     <= di[2:0];
					end
					6'h12: begin
						ppu_bg3_vofs       <= { di[1:0], ppu_ofs_latch[7:0] };
						ppu_ofs_latch      <= di;
					end
					6'h13: begin
						ppu_bg4_hofs       <= { di[1:0], ppu_ofs_latch[7:3], ppu_hofs_latch };
						ppu_ofs_latch      <= di;
						ppu_hofs_latch     <= di[2:0];
					end
					6'h14: begin
						ppu_bg4_vofs       <= { di[1:0], ppu_ofs_latch[7:0] };
						ppu_ofs_latch      <= di;
					end

					6'h15: begin
						ppu_vmain_inc      <= di[7];
						ppu_vmain          <= di[3:0];
						case(di[1:0])
							2'b00:   ppu_vmain_inc_cnt <= 8'h01;
							2'b01:   ppu_vmain_inc_cnt <= 8'h20;
							default: ppu_vmain_inc_cnt <= 8'h80;
						endcase
					end
					6'h16: ppu_vmadd[ 7:0] <= di;
					6'h17: ppu_vmadd[15:8] <= di;
					6'h18, 6'h19: begin
						if (pa[0] == ppu_vmain_inc) begin
							ppu_vmadd <= ppu_vmadd + ppu_vmain_inc_cnt;
						end
					end
					6'h1A: begin
						ppu_m7sel_rf <= di[7:6];
						ppu_m7sel_yx <= di[1:0];
					end
					6'h1B: begin
						ppu_m7a            <= { di, ppu_m7_latch };
						ppu_m7_latch       <= di;
					end
					6'h1C: begin
						ppu_m7b            <= { di, ppu_m7_latch };
						ppu_m7_latch       <= di;
					end
					6'h1D: begin
						ppu_m7c            <= { di, ppu_m7_latch };
						ppu_m7_latch       <= di;
					end
					6'h1E: begin
						ppu_m7d            <= { di, ppu_m7_latch };
						ppu_m7_latch       <= di;
					end
					6'h1F: begin
						ppu_m7x            <= { di[4:0], ppu_m7_latch };
						ppu_m7_latch       <= di;
					end
					6'h20: begin
						ppu_m7y            <= { di[4:0], ppu_m7_latch };
						ppu_m7_latch       <= di;
					end
					6'h21: ppu_cgadd       <= { di, 1'b0 };
					6'h22: begin
							if (~ppu_cgadd[0]) begin
								ppu_cglatch <= di;
							end
							ppu_cgadd       <= ppu_cgadd + 1'b1; // CGDATA write
					end
					6'h23: ppu_w12sel      <= di;
					6'h24: ppu_w34sel      <= di;
					6'h25: ppu_wobjsel     <= di;
					6'h26: ppu_wh0         <= di;
					6'h27: ppu_wh1         <= di;
					6'h28: ppu_wh2         <= di;
					6'h29: ppu_wh3         <= di;
					6'h2A: ppu_wbglog      <= di;
					6'h2B: ppu_wobjlog     <= di[3:0];
					6'h2C: ppu_tm          <= di[4:0];
					6'h2D: ppu_ts          <= di[4:0];
					6'h2E: ppu_tmw         <= di[4:0];
					6'h2F: ppu_tsw         <= di[4:0];
					6'h30: begin
						ppu_cgwsel_mss     <= di[7:4];
						ppu_cgwsel_ad      <= di[1:0];
					end
					6'h31: ppu_cgadsub     <= di;
					6'h32: ppu_coldata     <= di;
					6'h33: begin
						ppu_setini_ex      <= di[7:6];
						ppu_setini         <= di[3:0];
					end
					default: ;
				endcase
			end
		end

		if (~ss_busy) begin
			if (pard_ce) begin
				if ((pa[7:0] == 8'h39) | (pa[7:0] == 8'h3A)) begin
					if (~pa[0] == ppu_vmain_inc) begin
						ppu_vmadd <= ppu_vmadd + ppu_vmain_inc_cnt;
					end
				end
			end

			if (pard_ce | pawr_ce) begin
				if (pa[7:0] == 8'h80) begin
					wmadd <= wmadd + 1'b1;
				end
			end
		end

		if (ss_busy) begin
			if (cpurd_ce) begin
				ppu_word_reg_read <= ppu_word_reg;
			end

			if (cpurd_ce_n) begin
				if (ppu_word_reg_read) begin
					ppu_word_reg_read <= 0;
					read_hb <= ~read_hb;
				end
			end
		end

	 end
end


always @(*) begin
	ppu_word_reg = 0;
	if (ss_reg_sel & ppu_sel) begin
		case(ca[5:0])
			6'h0D,6'h0E,6'h0F,6'h10,6'h11,6'h12,6'h13,6'h14,
			6'h1B,6'h1C,6'h1D,6'h1E,6'h1F,6'h20,6'h21:
			begin
				ppu_word_reg = 1;
			end
			default: ;
		endcase
	end
end

reg [7:0] ppu_dout;
always @(*) begin
	ppu_dout = 8'h00;
	case(ca[5:0])
		6'h00: begin
			ppu_dout[7]         = ppu_inidisp_fb;
			ppu_dout[3:0]       = ppu_inidisp_br;
		end
		6'h01: ppu_dout         = ppu_objsel;
		6'h02: ppu_dout         = ppu_oamadd[7:0];
		6'h03: begin
			ppu_dout[7]         = ppu_oamadd_prio;
			ppu_dout[0]         = ppu_oamadd[8];
		end
		6'h04: ;// OAMDATA
		6'h05: ppu_dout         = ppu_bgmode;
		6'h06: ppu_dout         = ppu_mosaic;
		6'h07: ppu_dout         = ppu_bg1sc;
		6'h08: ppu_dout         = ppu_bg2sc;
		6'h09: ppu_dout         = ppu_bg3sc;
		6'h0A: ppu_dout         = ppu_bg4sc;
		6'h0B: ppu_dout         = ppu_bg12nba;
		6'h0C: ppu_dout         = ppu_bg34nba;
		6'h0D: begin
			if (ppu_bgmode[2:0] == 3'd7) begin
				if (read_hb) begin
					ppu_dout[4:0] = ppu_m7_hofs[12:8];
				end else begin
					ppu_dout      = ppu_m7_hofs[7:0];
				end
			end else begin
				if (read_hb) begin
					ppu_dout[1:0]   = ppu_bg1_hofs[9:8];
				end else begin
					ppu_dout        = ppu_bg1_hofs[7:0];
				end
			end
		end
		6'h0E: begin
			if (ppu_bgmode[2:0] == 3'd7) begin
				if (read_hb) begin
					ppu_dout[4:0] = ppu_m7_vofs[12:8];
				end else begin
					ppu_dout      = ppu_m7_vofs[7:0];
				end
			end else begin
				if (read_hb) begin
					ppu_dout[1:0]   = ppu_bg1_vofs[9:8];
				end else begin
					ppu_dout        = ppu_bg1_vofs[7:0];
				end
			end
		end
		6'h0F: begin
			if (read_hb) begin
				ppu_dout[1:0]   = ppu_bg2_hofs[9:8];
			end else begin
				ppu_dout        = ppu_bg2_hofs[7:0];
			end
		end
		6'h10: begin
			if (read_hb) begin
				ppu_dout[1:0]   = ppu_bg2_vofs[9:8];
			end else begin
				ppu_dout        = ppu_bg2_vofs[7:0];
			end
		end
		6'h11: begin
			if (read_hb) begin
				ppu_dout[1:0]   = ppu_bg3_hofs[9:8];
			end else begin
				ppu_dout        = ppu_bg3_hofs[7:0];
			end
		end
		6'h12: begin
			if (read_hb) begin
				ppu_dout[1:0]   = ppu_bg3_vofs[9:8];
			end else begin
				ppu_dout        = ppu_bg3_vofs[7:0];
			end
		end
		6'h13: begin
			if (read_hb) begin
				ppu_dout[1:0]   = ppu_bg4_hofs[9:8];
			end else begin
				ppu_dout        = ppu_bg4_hofs[7:0];
			end
		end
		6'h14: begin
			if (read_hb) begin
				ppu_dout[1:0]   = ppu_bg4_vofs[9:8];
			end else begin
				ppu_dout        = ppu_bg4_vofs[7:0];
			end
		end

		6'h15: begin
			ppu_dout[7]        = ppu_vmain_inc;
			ppu_dout[3:0]      = ppu_vmain;
		end
		6'h16: ppu_dout        = ppu_vmadd[ 7:0];
		6'h17: ppu_dout        = ppu_vmadd[15:8];
		6'h18, 6'h19: ; //VRAM data write
		6'h1A: begin
			ppu_dout[7:6]      = ppu_m7sel_rf;
			ppu_dout[1:0]      = ppu_m7sel_yx;
		end
		6'h1B: ppu_dout        = (read_hb) ? ppu_m7a[15:8] : ppu_m7a[7:0];
		6'h1C: ppu_dout        = (read_hb) ? ppu_m7b[15:8] : ppu_m7b[7:0];
		6'h1D: ppu_dout        = (read_hb) ? ppu_m7c[15:8] : ppu_m7c[7:0];
		6'h1E: ppu_dout        = (read_hb) ? ppu_m7d[15:8] : ppu_m7d[7:0];
		6'h1F: begin
			if (read_hb) begin
				ppu_dout[4:0]   = ppu_m7x[12:8];
			end else begin
				ppu_dout        = ppu_m7x[7:0];
			end
		end
		6'h20: begin
			if (read_hb) begin
				ppu_dout[4:0]   = ppu_m7y[12:8];
			end else begin
				ppu_dout        = ppu_m7y[7:0];
			end
		end
		6'h21: begin
			if (read_hb) begin
				ppu_dout[0]     = ppu_cgadd[0]; // Write cglatch to CGDATA if 1
			end else begin
				ppu_dout        = ppu_cgadd[8:1];
			end
		end
		6'h22: ppu_dout         = ppu_cglatch;
		6'h23: ppu_dout         = ppu_w12sel;
		6'h24: ppu_dout         = ppu_w34sel;
		6'h25: ppu_dout         = ppu_wobjsel;
		6'h26: ppu_dout         = ppu_wh0;
		6'h27: ppu_dout         = ppu_wh1;
		6'h28: ppu_dout         = ppu_wh2;
		6'h29: ppu_dout         = ppu_wh3;
		6'h2A: ppu_dout         = ppu_wbglog;
		6'h2B: ppu_dout[3:0]    = ppu_wobjlog;
		6'h2C: ppu_dout[4:0]    = ppu_tm;
		6'h2D: ppu_dout[4:0]    = ppu_ts;
		6'h2E: ppu_dout[4:0]    = ppu_tmw;
		6'h2F: ppu_dout[4:0]    = ppu_tsw;
		6'h30: begin
			ppu_dout[7:4]       = ppu_cgwsel_mss;
			ppu_dout[1:0]       = ppu_cgwsel_ad;
		end
		6'h31: ppu_dout         = ppu_cgadsub;
		6'h32: ppu_dout         = ppu_coldata;
		6'h33: begin
			ppu_dout[7:6]       = ppu_setini_ex;
			ppu_dout[3:0]       = ppu_setini;
		end
		default: ;

	endcase
end


always @(posedge clk) begin
	ssr_oe <= ss_reg_sel & (mmio_sel | ppu_sel | wram_sel);
	ssr_do <= 8'h00;
	case(ca[7:0])
		8'h00: ssr_do <= dma0[0];
		8'h01: ssr_do <= dma0[1];
		8'h02: ssr_do <= dma0[2];
		8'h03: ssr_do <= dma0[3];
		8'h04: ssr_do <= dma0[4];
		8'h05: ssr_do <= dma0[5];
		8'h06: ssr_do <= dma0[6];
		default: ;
	endcase

	if (mmio_sel & (ca[9:8] == 2'd2)) begin
		case(ca[7:0])
			8'h00: begin
				ssr_do[0]   <= nmitimen_j;
				ssr_do[5:4] <= nmitimen_hv;
				ssr_do[7]   <= nmitimen_n;
			end
			8'h02: ssr_do <= wrmpya;
			8'h03: ssr_do <= wrmpyb;
			8'h04: ssr_do <= wrdiv[ 7:0];
			8'h05: ssr_do <= wrdiv[15:8];
			8'h06: ssr_do <= wrdivb;
			8'h07: ssr_do <= htime[7:0];
			8'h08: ssr_do[0] <= htime[8];
			8'h09: ssr_do <= vtime[7:0];
			8'h0A: ssr_do[0] <= vtime[8];
			8'h0C: ssr_do <= hdmaen;
			8'h0D: ssr_do[0] <= memsel;
			8'h0F: ssr_do[0] <= wrdivb_last;
			default: ;
		endcase
	end

	if (ppu_sel) begin
		ssr_do <= ppu_dout;
	end

	if (wram_sel) begin
		case(ca[1:0])
			2'd1: ssr_do <= wmadd[ 7: 0];
			2'd2: ssr_do <= wmadd[15: 8];
			2'd3: ssr_do <= wmadd[   16];
			default: ;
		endcase
	end
end


endmodule
