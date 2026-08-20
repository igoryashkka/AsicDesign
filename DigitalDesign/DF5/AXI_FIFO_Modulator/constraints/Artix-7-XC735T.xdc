# Загальні параметри конфігурації
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE Yes [current_design]

# Підключення зовнішніх сигналів та клоку (як у DF4/AXI_Slave_example, та сама плата)
set_property -dict {PACKAGE_PIN R4 IOSTANDARD DIFF_SSTL15} [get_ports diff_clock_rtl_0_clk_p ]

# Reset
set_property -dict {PACKAGE_PIN W21 IOSTANDARD LVCMOS33 } [get_ports reset_rtl_0]
set_property -dict {PACKAGE_PIN R14 IOSTANDARD LVCMOS33} [get_ports rst_n_0]

# TODO: вивід модульованого сигналу на пін плати (обрати вільний пін, узгодити зі схемою)
#set_property -dict {PACKAGE_PIN W22 IOSTANDARD LVCMOS33} [get_ports {modulated_out}]

# TODO: світлодіод індикації прийому AXI-транзакції в FIFO (обрати вільний LED на платі)
#set_property -dict {PACKAGE_PIN Y22 IOSTANDARD LVCMOS33} [get_ports {axi_rx_led_o}]
