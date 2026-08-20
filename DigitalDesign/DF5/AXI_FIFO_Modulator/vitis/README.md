# DF5 Vitis — мінімальна тестова аплікуха

`app_component/src/main.c` — мінімальний тест кастомного AXI-периферійного блоку
`axi_fifo_regs` (DATA/STATUS/CTRL/FREQ регістри), написаний за тим самим патерном прямого
доступу до регістрів (`Xil_Out32`/`Xil_In32`), що й у `DF4/AXI_Slave_example` main.c для
кастомного `top_gpio`.

## Як це реально запустити (порядок дій)

1. Довести до кінця RTL (`sources/rtl/axi_fifo_regs.vhd`, `sync_fifo.vhd`, `fsk_modulator.vhd`, `top.vhd`) — див. `task_readme.md`.
2. У Vivado: **Tools -> Create and Package New IP -> Package your current project** (IP Packager,
   він же "пакетайзер") для `top.vhd`/`axi_fifo_regs.vhd`, щоб отримати AXI4-Lite IP-ядро.
3. Додати це IP-ядро в MicroBlaze block design поруч з AXI Interconnect/SmartConnect, підключити,
   згенерувати bitstream, експортувати `.xsa` (`build.bat -xsa`).
4. У Vitis: створити Platform Component з цього `.xsa`, потім Application Component з доменом
   `standalone_microblaze_0` — Vitis сам згенерує реальні `lscript.ld`,
   `Empty_applicationExample.cmake` (memory map) та `xparameters.h` під фактичне залізо.
5. Замінити `src/main.c` цим файлом (або скопіювати в згенерований `app_component`), у макросі
   `FIFO_MOD_BASE` підставити реальне ім'я з `xparameters.h` (буде щось на кшталт
   `XPAR_AXI_FIFO_REGS_0_S_AXI_BASEADDR` — точне ім'я залежить від імені інстансу IP в BD).

## Чому тут немає `lscript.ld` і `Empty_applicationExample.cmake`

Ці файли описують реальну карту памʼяті (BRAM/розмір, адреси) конкретного block design і
генеруються Vitis автоматично з фактичного `.xsa`. Поки немає зібраного заліза (крок 1-3 вище не
пройдено), будь-які значення в них були б вигаданими і вводили б в оману — тому тут навмисно
лишений тільки `main.c` + генеричні (не апаратно-залежні) `CMakeLists.txt`/`UserConfig.cmake`,
скопійовані з такого ж шаблону в `DF3/vitis/app_component`.
