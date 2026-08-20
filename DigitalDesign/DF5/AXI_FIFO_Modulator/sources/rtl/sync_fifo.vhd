library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Звичайний синхронний FIFO. Записується з боку AXI-регістрів (axi_fifo_regs),
-- читається апаратним модулятором (simple_ook_modulator).
entity sync_fifo is
  generic (
    DATA_WIDTH : positive := 8;
    DEPTH      : positive := 16
  );
  port (
    clk   : in  std_logic;
    rst_n : in  std_logic;

    wr_en : in  std_logic;
    din   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    full  : out std_logic;

    rd_en : in  std_logic;
    dout  : out std_logic_vector(DATA_WIDTH-1 downto 0);
    empty : out std_logic
  );
end entity sync_fifo;

architecture rtl of sync_fifo is
begin

  -- TODO: реалізувати кільцевий буфер (memory array + wr_ptr/rd_ptr + count),
  -- коректно формувати full/empty, не втрачати дані при одночасному wr_en/rd_en.

end architecture rtl;
