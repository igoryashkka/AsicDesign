library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- AXI4-Lite слейв: DATA/STATUS/CTRL/FREQ регістри навколо sync_fifo.
-- За зразком DF4/AXI_Slave_example/sources/rtl/axi_gpio/axi_gpio.vhd.
-- Регістрова карта:
--   0x00 DATA   (WO) - запис байта у FIFO
--   0x04 STATUS (RO) - [0]=fifo_empty, [1]=fifo_full
--   0x08 CTRL   (RW) - [0]=modulator_en
--   0x0C FREQ   (RW) - [7:0]=freq_div0, [15:8]=freq_div1
-- Кожна успішна транзакція запису в DATA додатково формує axi_rx_led_o -
-- розтягнутий/тогльований імпульс, щоб транзакцію було видно на світлодіоді плати
-- (сирий fifo_wr_en триває 1 такт clk і оком не помітний).
entity axi_fifo_regs is
  generic (
    ADDR_WIDTH    : positive := 32;
    DATA_WIDTH    : positive := 32;
    LED_STRETCH_W : positive := 26 -- розрядність лічильника розтягування LED (підібрати під частоту clk)
  );
  port (
    s_axi_aclk    : in  std_logic;
    s_axi_aresetn : in  std_logic;

    s_axi_awaddr  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    s_axi_awvalid : in  std_logic;
    s_axi_awready : out std_logic;

    s_axi_wdata   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    s_axi_wstrb   : in  std_logic_vector(DATA_WIDTH/8-1 downto 0);
    s_axi_wvalid  : in  std_logic;
    s_axi_wready  : out std_logic;

    s_axi_bresp   : out std_logic_vector(1 downto 0);
    s_axi_bvalid  : out std_logic;
    s_axi_bready  : in  std_logic;

    s_axi_araddr  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    s_axi_arvalid : in  std_logic;
    s_axi_arready : out std_logic;

    s_axi_rdata   : out std_logic_vector(DATA_WIDTH-1 downto 0);
    s_axi_rresp   : out std_logic_vector(1 downto 0);
    s_axi_rvalid  : out std_logic;
    s_axi_rready  : in  std_logic;

    -- FIFO-сторона (до sync_fifo)
    fifo_full  : in  std_logic;
    fifo_empty : in  std_logic;
    fifo_wr_en : out std_logic;
    fifo_din   : out std_logic_vector(7 downto 0);

    -- сторона модулятора (fsk_modulator)
    modulator_en : out std_logic;
    freq_div0    : out std_logic_vector(7 downto 0);
    freq_div1    : out std_logic_vector(7 downto 0);

    -- індикація прийому AXI-транзакції запису в FIFO
    axi_rx_led_o : out std_logic
  );
end entity axi_fifo_regs;

architecture rtl of axi_fifo_regs is
begin

  -- TODO:
  -- 1) Handshake запису (aw/w -> fifo_wr_en на 1 такт, fifo_din <= wdata),
  --    handshake читання (ar -> rdata = STATUS/CTRL/FREQ залежно від araddr).
  -- 2) Не дозволяти запис у DATA, коли fifo_full = '1'.
  -- 3) На кожен успішний запис у DATA (fifo_wr_en='1') - розтягнути/тогльнути
  --    axi_rx_led_o лічильником LED_STRETCH_W біт, щоб імпульс було видно оком.

end architecture rtl;
