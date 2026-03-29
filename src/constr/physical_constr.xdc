# Clock

create_clock -period 20.000 -name clk [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property PACKAGE_PIN N18 [get_ports clk]


# i2c

set_property PACKAGE_PIN M17 [get_ports i2c_sda]
set_property IOSTANDARD LVCMOS33 [get_ports i2c_sda]
set_property PULLTYPE PULLUP [get_ports i2c_sda]

set_property PACKAGE_PIN P18 [get_ports i2c_scl]
set_property IOSTANDARD LVCMOS33 [get_ports i2c_scl]
set_property PULLTYPE PULLUP [get_ports i2c_scl]


# SPI

set_property IOSTANDARD LVCMOS33 [get_ports DC]
set_property IOSTANDARD LVCMOS33 [get_ports SCL]
set_property IOSTANDARD LVCMOS33 [get_ports SDA]
set_property IOSTANDARD LVCMOS33 [get_ports nRES]

set_property PACKAGE_PIN R18 [get_ports DC]
set_property PACKAGE_PIN R19 [get_ports SCL]
set_property PACKAGE_PIN P20 [get_ports SDA]
set_property PACKAGE_PIN N17 [get_ports nRES]


# reset

set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
set_property PACKAGE_PIN P19 [get_ports rst_n]


# buttons

set_property IOSTANDARD LVCMOS33 [get_ports start]
set_property PACKAGE_PIN U20 [get_ports start]

set_property IOSTANDARD LVCMOS33 [get_ports search_en_btn]
set_property PACKAGE_PIN T19 [get_ports search_en_btn]


#set_property IOSTANDARD LVCMOS33 [get_ports btn_search_up]
#set_property IOSTANDARD LVCMOS33 [get_ports btn_search_down]

#set_property PACKAGE_PIN T19 [get_ports btn_search_up]
#set_property PACKAGE_PIN U19 [get_ports btn_search_down]

## LED

set_property PACKAGE_PIN E19 [get_ports busy_led]
set_property IOSTANDARD LVCMOS33 [get_ports busy_led]

set_property PACKAGE_PIN H18 [get_ports search_en_led]
set_property IOSTANDARD LVCMOS33 [get_ports search_en_led]

set_property PACKAGE_PIN K17 [get_ports error_led]
set_property IOSTANDARD LVCMOS33 [get_ports error_led]

