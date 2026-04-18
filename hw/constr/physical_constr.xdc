# Clock

#create_clock -period 20.000 -name clk [get_ports clk]
#set_property IOSTANDARD LVCMOS33 [get_ports clk]
#set_property PACKAGE_PIN N18 [get_ports clk]


# i2c

set_property PACKAGE_PIN J19 [get_ports i2c_sda]
set_property IOSTANDARD LVCMOS33 [get_ports i2c_sda]
set_property PULLTYPE PULLUP [get_ports i2c_sda]

set_property PACKAGE_PIN K18 [get_ports i2c_scl]
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


# i2s

set_property IOSTANDARD LVCMOS33 [get_ports i2s_mclk]
set_property IOSTANDARD LVCMOS33 [get_ports i2s_bclk]
set_property IOSTANDARD LVCMOS33 [get_ports i2s_lrck]
set_property IOSTANDARD LVCMOS33 [get_ports i2s_din]

set_property PACKAGE_PIN K19 [get_ports i2s_mclk]
set_property PACKAGE_PIN L16 [get_ports i2s_lrck]
set_property PACKAGE_PIN M18 [get_ports i2s_din]
set_property PACKAGE_PIN M20 [get_ports i2s_bclk]

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


set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets i2s_bclk_IBUF]










set_property IOSTANDARD LVCMOS33 [get_ports {emio_tri_io[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {emio_tri_io[0]}]

set_property PACKAGE_PIN W13 [get_ports {emio_tri_io[0]}]
set_property PACKAGE_PIN W14 [get_ports {emio_tri_io[1]}]

set_property DRIVE 12 [get_ports {emio_tri_io[1]}]
set_property DRIVE 12 [get_ports {emio_tri_io[0]}]

# ENET0 MII via EMIO
set_property IOSTANDARD LVCMOS33 [get_ports enet0_mdio_mdc]
set_property IOSTANDARD LVCMOS33 [get_ports enet0_mdio_mdio_io]

set_property IOSTANDARD LVCMOS33 [get_ports enet0_mii_rx_clk]
set_property IOSTANDARD LVCMOS33 [get_ports enet0_mii_rx_dv]
set_property IOSTANDARD LVCMOS33 [get_ports {enet0_mii_rxd[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {enet0_mii_rxd[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {enet0_mii_rxd[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {enet0_mii_rxd[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports enet0_mii_tx_clk]
set_property IOSTANDARD LVCMOS33 [get_ports {enet0_mii_tx_en[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {enet0_mii_txd[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {enet0_mii_txd[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {enet0_mii_txd[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {enet0_mii_txd[0]}]

set_property PACKAGE_PIN W15 [get_ports enet0_mdio_mdc]
set_property PACKAGE_PIN Y14 [get_ports enet0_mdio_mdio_io]

set_property PACKAGE_PIN U14 [get_ports enet0_mii_rx_clk]
set_property PACKAGE_PIN W16 [get_ports enet0_mii_rx_dv]
set_property PACKAGE_PIN Y17 [get_ports {enet0_mii_rxd[3]}]
set_property PACKAGE_PIN V17 [get_ports {enet0_mii_rxd[2]}]
set_property PACKAGE_PIN V16 [get_ports {enet0_mii_rxd[1]}]
set_property PACKAGE_PIN Y16 [get_ports {enet0_mii_rxd[0]}]

set_property PACKAGE_PIN U15 [get_ports enet0_mii_tx_clk]
set_property PACKAGE_PIN W19 [get_ports {enet0_mii_tx_en[0]}]
set_property PACKAGE_PIN Y19 [get_ports {enet0_mii_txd[3]}]
set_property PACKAGE_PIN V18 [get_ports {enet0_mii_txd[2]}]
set_property PACKAGE_PIN Y18 [get_ports {enet0_mii_txd[1]}]
set_property PACKAGE_PIN W18 [get_ports {enet0_mii_txd[0]}]

set_property DRIVE 8 [get_ports enet0_mdio_mdc]
set_property DRIVE 8 [get_ports enet0_mdio_mdio_io]

set_property DRIVE 8 [get_ports {enet0_mii_tx_en[0]}]
set_property DRIVE 8 [get_ports {enet0_mii_txd[3]}]
set_property DRIVE 8 [get_ports {enet0_mii_txd[2]}]
set_property DRIVE 8 [get_ports {enet0_mii_txd[1]}]
set_property DRIVE 8 [get_ports {enet0_mii_txd[0]}]


