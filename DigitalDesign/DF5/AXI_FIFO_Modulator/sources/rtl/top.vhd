library ieee;
use ieee.std_logic_1164.all;

-- Верхній рівень поза MicroBlaze block design: обгортає axi_fifo_regs, sync_fifo
-- та fsk_modulator в один RTL-периферійний блок. Interconnect до MicroBlaze -
-- готовий Vivado IP (AXI Interconnect / AXI SmartConnect), доданий в IP Integrator,
-- НЕ частина цього файлу. В BD цей блок підключається як RTL-периферія поруч з
-- MicroBlaze (аналогічно axi_gpio у DF4/AXI_Slave_example).
entity top is
  port (
    clk           : in  std_logic;
    rst_n         : in  std_logic;
    modulated_out : out std_logic;
    axi_rx_led_o  : out std_logic
  );
end entity top;

architecture rtl of top is
begin

  -- TODO: інстанціювати axi_fifo_regs <-> sync_fifo <-> fsk_modulator,
  -- вивести modulated_out та axi_rx_led_o на піни плати.

end architecture rtl;
