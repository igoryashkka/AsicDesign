#include <stdio.h>
#include "xil_printf.h"
#include "xil_io.h"
#include "xil_types.h"
#include "sleep.h"

/*
 * Мінімальний тест кастомного AXI-периферійного блоку axi_fifo_regs
 * (упакованого через IP Packager і доданого в MicroBlaze block design).
 *
 * TODO: після Package IP + генерації xparameters.h заміни
 * XPAR_AXI_FIFO_REGS_0_S_AXI_BASEADDR на реальне ім'я макросу з
 * xparameters.h (залежить від імені інстансу IP у block design).
 */
#define FIFO_MOD_BASE   XPAR_AXI_FIFO_REGS_0_S_AXI_BASEADDR

#define REG_DATA_OFF    0x00u
#define REG_STATUS_OFF  0x04u
#define REG_CTRL_OFF    0x08u
#define REG_FREQ_OFF    0x0Cu

#define STATUS_EMPTY_BIT (1u << 0)
#define STATUS_FULL_BIT  (1u << 1)
#define CTRL_MOD_EN_BIT  (1u << 0)

static inline void fifo_mod_write_data(u8 byte)
{
    Xil_Out32(FIFO_MOD_BASE + REG_DATA_OFF, (u32)byte);
}

static inline u32 fifo_mod_read_status(void)
{
    return Xil_In32(FIFO_MOD_BASE + REG_STATUS_OFF);
}

static inline void fifo_mod_set_ctrl(int modulator_en)
{
    Xil_Out32(FIFO_MOD_BASE + REG_CTRL_OFF, modulator_en ? CTRL_MOD_EN_BIT : 0u);
}

static inline void fifo_mod_set_freq(u8 freq_div0, u8 freq_div1)
{
    u32 v = ((u32)freq_div1 << 8) | (u32)freq_div0;
    Xil_Out32(FIFO_MOD_BASE + REG_FREQ_OFF, v);
}

int main(void)
{
    xil_printf("DF5 AXI FIFO Modulator - minimal test app\r\n");

    /* дві різні несучі частоти для FSK: біт '0' -> div=50, біт '1' -> div=100 */
    fifo_mod_set_freq(50u, 100u);
    fifo_mod_set_ctrl(1);

    static const u8 pattern[] = { 0xAAu, 0x55u, 0xF0u, 0x0Fu };

    while (1) {
        for (unsigned i = 0; i < sizeof(pattern); i++) {
            u32 status;

            do {
                status = fifo_mod_read_status();
            } while (status & STATUS_FULL_BIT);

            fifo_mod_write_data(pattern[i]);
            xil_printf("wrote 0x%02x, status=0x%08x\r\n", pattern[i], status);

            usleep(200000u);
        }
    }
}
