derive_pll_clocks

create_generated_clock -name GSU_CASHE_CLK -source [get_pins -compatibility_mode {*|pll|pll_inst|altera_pll_i|*[2].*|divclk}] \
							  -invert [get_pins {emu|main|GSUMap|GSU|CACHE|ram|altsyncram_component|auto_generated|*|clk0}]

create_generated_clock -name CX4_MEM_CLK -source [get_pins -compatibility_mode {*|pll|pll_inst|altera_pll_i|*[2].*|divclk}] \
							  -invert [get_pins {emu|main|CX4Map|CX4|DATA_RAM|altsyncram_component|auto_generated|*|clk0 \
														emu|main|CX4Map|CX4|DATA_ROM|spram_sz|altsyncram_component|auto_generated|altsyncram1|*|clk0 }]

derive_clock_uncertainty

set_clock_groups -asynchronous -group [get_clocks { GSU_CASHE_CLK CX4_MEM_CLK }] 


set_max_delay 23 -from [get_registers { emu|hps_io|* \
													 emu|main|* \
													 emu|rom_mask[*] \
													 emu|rom_type[*] }] \
					  -to   [get_registers { emu|sdram|a[*] \
													 emu|sdram|ram_req* \
													 emu|sdram|we* \
													 emu|sdram|state[*] \
													 emu|sdram|old_* \
													 emu|sdram|busy* \
													 emu|sdram|SDRAM_nCAS \
													 emu|sdram|SDRAM_A[*] \
													 emu|sdram|SDRAM_BA[*] }] 

set_max_delay 23 -from [get_registers { emu|sdram|* }] \
					  -to   [get_registers { emu|main|* \
													 emu|bsram|* \
													 emu|wram|* \
													 emu|vram*|* }] 

set_false_path -to [get_registers { emu|sdram|ds emu|sdram|data[*]}]