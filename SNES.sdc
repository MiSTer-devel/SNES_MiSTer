derive_pll_clocks

create_generated_clock -name GSU_CASHE_CLK -source [get_pins -compatibility_mode {*|pll|pll_inst|altera_pll_i|*[3].*|divclk}] \
							  -invert [get_pins {emu|main|GSUMap|GSU|CACHE|ram|altsyncram_component|auto_generated|*|clk0}]

create_generated_clock -name CX4_MEM_CLK -source [get_pins -compatibility_mode {*|pll|pll_inst|altera_pll_i|*[3].*|divclk}] \
							  -invert [get_pins {emu|main|CX4Map|CX4|DATA_RAM|altsyncram_component|auto_generated|*|clk0 \
														emu|main|CX4Map|CX4|DATA_ROM|spram_sz|altsyncram_component|auto_generated|altsyncram1|*|clk0 }]

create_generated_clock -source [get_pins -compatibility_mode {*|pll|pll_inst|altera_pll_i|*[1].*|divclk}] \
                       -name SDRAM_CLK [get_ports {SDRAM_CLK}]

derive_clock_uncertainty

set_clock_groups -asynchronous -group [get_clocks { GSU_CASHE_CLK CX4_MEM_CLK }] 

set_input_delay -max -clock SDRAM_CLK 6.4ns [get_ports SDRAM_DQ[*]]
set_input_delay -min -clock SDRAM_CLK 3.7ns [get_ports SDRAM_DQ[*]]
set_output_delay -max -clock SDRAM_CLK 1.6ns [get_ports {SDRAM_D* SDRAM_A* SDRAM_BA* SDRAM_n* SDRAM_CKE}]
set_output_delay -min -clock SDRAM_CLK -0.9ns [get_ports {SDRAM_D* SDRAM_A* SDRAM_BA* SDRAM_n* SDRAM_CKE}]

set_max_delay 23 -from [get_registers { emu:emu|hps_io:hps_io|* \
													 emu:emu|main:main|* \
													 emu:emu|rom_mask[*] \
													 emu:emu|rom_type[*] }] \
					  -to   [get_registers { emu:emu|sdram:sdram|a[*] \
													 emu:emu|sdram:sdram|ram_req \
													 emu:emu|sdram:sdram|we \
													 emu:emu|sdram:sdram|state[*] \
													 emu:emu|sdram:sdram|old_* \
													 emu:emu|sdram:sdram|busy \
													 emu:emu|sdram:sdram|SDRAM_nCAS \
													 emu:emu|sdram:sdram|SDRAM_A[*] \
													 emu:emu|sdram:sdram|SDRAM_BA[*] }] 

set_max_delay 23 -from [get_registers { emu:emu|sdram:sdram|* }] \
						-to  [get_registers { emu:emu|main:main|* }] 

set_false_path -to [get_registers { emu:emu|sdram:sdram|ds emu:emu|sdram:sdram|data[*]}]