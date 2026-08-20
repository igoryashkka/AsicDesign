# DF5 / AXI FIFO Modulator Task

## Що треба зробити
Підняти систему на MicroBlaze (block design, як у `DF4/AXI_Slave_example`). Interconnect між MicroBlaze
і периферією — **готовий IP-блок Vivado** (AXI Interconnect / AXI SmartConnect з IP Integrator), свій
RTL для interconnect писати НЕ треба (на відміну від DF4/AXI_Interconnect — там саме interconnect був
завданням, тут ні). Через цей interconnect підключити новий AXI4-Lite слейв з чергою (FIFO), у яку
MicroBlaze пише семпли/байти через софт. Вихід FIFO апаратно йде у **дуже спрощений модулятор сигналу —
FSK (Frequency-Shift Keying)**, який перетворює потік бітів з FIFO на вихідний сигнал з двома несучими
частотами (одна для біта '0', інша для біта '1'). Додатково: кожна прийнята по AXI транзакція запису у
FIFO має відображатись на світлодіоді плати.

Мета — пройти повний ланцюжок: CPU (MicroBlaze) → IP interconnect Vivado → свій AXI-периферійний блок
(FIFO) → чисто апаратний DSP-блок (FSK-модулятор), і мати візуальну індикацію (LED) кожної транзакції.

## Архітектура 
```
MicroBlaze (BD)
     |  AXI4-Lite (master, з BD)
     v
AXI Interconnect / AXI SmartConnect   (готовий IP-блок Vivado, з IP Integrator, НЕ власний RTL)
     |
     v
axi_fifo_regs  (новий AXI4-Lite slave: control/status/data регістри навколо FIFO)
     |  запис даних у fifo_din/fifo_wr_en (з боку AXI)
     |  кожна транзакція запису -> axi_rx_led_o (розтягнутий імпульс на LED)
     v
sync_fifo  (звичайний синхронний FIFO, generic DATA_WIDTH/DEPTH)
     |  fifo_dout/fifo_rd_en (апаратна сторона, читає модулятор)
     v
fsk_modulator  (дві несучі частоти, перемикання за поточним бітом з FIFO) -> modulated_out (пін)
```

Модулятор має бути  простим: **FSK** — коли поточний біт з FIFO = '0', на вихід подається
несуча з дільником `freq_div0`, коли '1' — несуча з дільником `freq_div1`. Ніяких фазових зсувів,
амплітудних рівнів чи QPSK — саме "дуже спрощений" варіант: два дільники частоти + мультиплексор.

## LED на прийом AXI-транзакції
Кожен успішний запис по AXI у регістр DATA (тобто кожен байт, покладений софтом у FIFO) має бути видно
на світлодіоді плати. Сирий `fifo_wr_en` триває лише 1 такт clk (десятки наносекунд) — оком це не
побачити, тому імпульс потрібно **розтягнути** (наприклад лічильником на ~0.1-0.5 с при робочій частоті
clk) або просто **тоглити** LED на кожній транзакції (тоді LED буде блимати рідше при повільних записах
і світитиметься суцільно при швидких — теж прийнятно для перевірки, що транзакції взагалі доходять).
Реалізувати як окремий маленький блок (наприклад `led_stretch.vhd`) або прямо всередині `axi_fifo_regs`.

## Піни / порти
- `axi_fifo_regs.vhd` (новий AXI4-Lite slave, за зразком `DF4/AXI_Slave_example/sources/rtl/axi_gpio/axi_gpio.vhd`)
  - `s_axi_aclk`, `s_axi_aresetn`
  - write address/data/response channel: `s_axi_awaddr`, `s_axi_awvalid`, `s_axi_awready`, `s_axi_wdata`, `s_axi_wstrb`, `s_axi_wvalid`, `s_axi_wready`, `s_axi_bresp`, `s_axi_bvalid`, `s_axi_bready`
  - read address/data channel: `s_axi_araddr`, `s_axi_arvalid`, `s_axi_arready`, `s_axi_rdata`, `s_axi_rresp`, `s_axi_rvalid`, `s_axi_rready`
  - FIFO-сторона: `fifo_full`, `fifo_empty`, `fifo_wr_en`, `fifo_din`
  - модулятор-сторона: `modulator_en`, `freq_div0`, `freq_div1`
  - індикація: `axi_rx_led_o` - розтягнутий/тоглений сигнал на кожну транзакцію запису
- `sync_fifo.vhd`
  - `clk`, `rst_n`
  - `wr_en`, `din`, `full`
  - `rd_en`, `dout`, `empty`
  - `generic DATA_WIDTH`, `generic DEPTH`
- `fsk_modulator.vhd`
  - `clk`, `rst_n`, `enable`
  - `freq_div0`, `freq_div1` - дільники для несучої на біт '0' і біт '1'
  - `fifo_dout`, `fifo_empty`, `fifo_rd_en` - читання байтів з FIFO, побітове видавання
  - `modulated_out` - вихідний промодульований сигнал (на пін плати)
- `top.vhd`
  - обгортає `axi_fifo_regs`, `sync_fifo`, `fsk_modulator` в один RTL-периферійний блок, який в
    IP Integrator підключається до Vivado AXI Interconnect поруч з MicroBlaze BD (аналогічно `axi_gpio`
    у `DF4/AXI_Slave_example`)
  - `clk`, `rst_n`, `modulated_out`, `axi_rx_led_o` - назовні на плату

## Софт (Vitis)
Мінімальна тестова С-аплікуха лежить у `vitis/app_component/src/main.c` — пише байти в DATA,
виставляє FREQ/CTRL, читає STATUS. Щоб вона стала реально збірною:
1. Запакувати `top.vhd`/`axi_fifo_regs.vhd` через Vivado IP Packager ("Tools -> Create and
   Package New IP") в AXI4-Lite IP-ядро.
2. Додати це IP-ядро в block design, зібрати bitstream, експортувати `.xsa`.
3. У Vitis створити Platform + Application Component на основі цього `.xsa` (Vitis сам згенерує
   `xparameters.h`, `lscript.ld` тощо) і підставити туди `main.c`.
4. У `main.c` замінити плейсхолдер `FIFO_MOD_BASE` на реальний макрос базової адреси з
   згенерованого `xparameters.h`.

Детальніше — `vitis/README.md`.

## Регістрова карта (пропозиція, offset від base адреси AXI-слейва)
- `0x00` DATA (WO) - запис байта/семпла у FIFO (побічний ефект: `fifo_wr_en` на 1 такт + імпульс на LED)
- `0x04` STATUS (RO) - біт 0 = `fifo_empty`, біт 1 = `fifo_full`
- `0x08` CTRL (RW) - біт 0 = enable модулятора
- `0x0C` FREQ (RW) - `[7:0]` = `freq_div0` (дільник для біта '0'), `[15:8]` = `freq_div1` (дільник для біта '1')

## Що перевірити
- MicroBlaze ходить через AXI Interconnect IP з IP Integrator (перевірити в block design, що це
  стандартний Vivado IP, а не власний RTL).
- Запис у DATA регістр з софту коректно потрапляє у FIFO (`fifo_wr_en` формується на один такт, без
  повторного запису при утриманні `wvalid`).
- STATUS.full не дає переповнити FIFO (перевірити поведінку при записі в повний FIFO).
- `axi_rx_led_o` реагує на кожну транзакцію запису в DATA — перевірити на платі/симуляції, що LED
  реально видно (імпульс достатньо розтягнутий).
- `fsk_modulator` перемикає частоту виходу відповідно до поточного біта (біт '0' -> `freq_div0`,
  біт '1' -> `freq_div1`) — перевірити на симуляції та на `modulated_out` осцилографом/ChipScope.
- Наскрізний тест: софт кладе у FIFO відому послідовність байтів (наприклад патерн 0xAA), на
  `modulated_out` має бути видно відповідну FSK-послідовність з двома періодами, а `axi_rx_led_o`
  реагує на кожен байт.
