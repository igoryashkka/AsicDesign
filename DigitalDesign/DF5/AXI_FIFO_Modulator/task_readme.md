# DF5 / AXI FIFO Modulator Task

## Що треба зробити
Підняти систему на MicroBlaze. Interconnect між MicroBlaze
і периферією — **готовий IP-блок Vivado** (AXI Interconnect / AXI SmartConnect з IP Integrator), свій
RTL для interconnect писати НЕ треба. Через цей interconnect підключити новий AXI4-Lite слейв з чергою (FIFO), у яку
MicroBlaze пише семпли/байти через софт. Вихід FIFO апаратно йде у спрощений модулятор сигналу —
FSK (Frequency-Shift Keying), який перетворює потік бітів з FIFO на вихідний сигнал. Додатково: кожна прийнята по AXI транзакція запису у
FIFO має відображатись на світлодіоді плати.

Мета — пройти повний ланцюжок: CPU (MicroBlaze) → IP interconnect Vivado → свій AXI-периферійний блок
(FIFO) → чисто апаратний DSP-блок (FSK-модулятор), і мати візуальну індикацію (LED) кожної транзакції.

## Архітектура (recomended)
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

Модулятор має бути  простим: **FSK** дивись док. DF5/DOC/FSK.md

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
