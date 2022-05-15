
module msu_audio_fifo
(
	input	        aclr,
	input	 [31:0] data,
	input	        rdclk,
	input	        rdreq,
	input	        wrclk,
	input	        wrreq,
	output [31:0] q,
	output        rdempty,
	output        wrfull,
	output  [9:0] wrusedw
);

dcfifo dcfifo_component
(
	.aclr (aclr),
	.data (data),
	.rdclk (rdclk),
	.rdreq (rdreq),
	.wrclk (wrclk),
	.wrreq (wrreq),
	.q (q),
	.rdempty (rdempty),
	.wrfull (wrfull),
	.wrusedw (wrusedw),
	.eccstatus (),
	.rdfull (),
	.rdusedw (),
	.wrempty ()
);
defparam
	dcfifo_component.intended_device_family = "Cyclone V",
	dcfifo_component.lpm_numwords = 1024,
	dcfifo_component.lpm_showahead = "ON",
	dcfifo_component.lpm_type = "dcfifo",
	dcfifo_component.lpm_width = 32,
	dcfifo_component.lpm_widthu = 10,
	dcfifo_component.overflow_checking = "ON",
	dcfifo_component.rdsync_delaypipe = 4,
	dcfifo_component.read_aclr_synch = "OFF",
	dcfifo_component.underflow_checking = "ON",
	dcfifo_component.use_eab = "ON",
	dcfifo_component.write_aclr_synch = "OFF",
	dcfifo_component.wrsync_delaypipe = 4;

endmodule
