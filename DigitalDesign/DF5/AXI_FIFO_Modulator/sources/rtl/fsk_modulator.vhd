library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- ДУЖЕ спрощений модулятор сигналу: FSK (Frequency-Shift Keying).
-- Читає байти з FIFO, побітово зсуває їх, і залежно від поточного біта
-- перемикає вихідну частоту між двома несучими: freq_div0 (для біта '0')
-- і freq_div1 (для біта '1'). Ніяких фаз/амплітуд - лише два дільники + мультиплексор.
entity fsk_modulator is
  port (
    clk   : in  std_logic;
    rst_n : in  std_logic;

    enable    : in  std_logic;
    freq_div0 : in  std_logic_vector(7 downto 0); -- дільник для біта '0'
    freq_div1 : in  std_logic_vector(7 downto 0); -- дільник для біта '1'

    -- зі сторони FIFO (апаратне читання)
    fifo_dout  : in  std_logic_vector(7 downto 0);
    fifo_empty : in  std_logic;
    fifo_rd_en : out std_logic;

    modulated_out : out std_logic
  );
end entity fsk_modulator;

architecture rtl of fsk_modulator is
begin

  -- TODO:
  -- 1) Коли FIFO не пустий і enable='1' - забрати байт (fifo_rd_en на 1 такт),
  --    завантажити у зсувний регістр і послідовно видавати біти на символьній швидкості.
  -- 2) Два лічильники-дільники (за freq_div0 / freq_div1), кожен генерує square wave
  --    зі своєю частотою.
  -- 3) Мультиплексор: modulated_out <= вихід дільника freq_div1, якщо current_bit='1',
  --    інакше вихід дільника freq_div0. Перемикати дільник ТІЛЬКИ по завершенню періоду
  --    поточної несучої (щоб не було розривів фази посеред періоду).

end architecture rtl;
