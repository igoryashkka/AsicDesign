//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2025.2 (win64) Build 6299465 Fri Nov 14 19:35:11 GMT 2025
//Date        : Mon Aug 24 20:02:17 2026
//Host        : AX-192715 running 64-bit major release  (build 9200)
//Command     : generate_target microblaze_wrapper.bd
//Design      : microblaze_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module microblaze_wrapper
   (diff_clock_rtl_0_clk_n,
    diff_clock_rtl_0_clk_p,
    pwm_r_o_0,
    pwm_r_o_1,
    reset_rtl_0,
    rst_n_0);
  input diff_clock_rtl_0_clk_n;
  input diff_clock_rtl_0_clk_p;
  output pwm_r_o_0;
  output pwm_r_o_1;
  input reset_rtl_0;
  input rst_n_0;

  wire diff_clock_rtl_0_clk_n;
  wire diff_clock_rtl_0_clk_p;
  wire pwm_r_o_0;
  wire pwm_r_o_1;
  wire reset_rtl_0;
  wire rst_n_0;

  microblaze microblaze_i
       (.diff_clock_rtl_0_clk_n(diff_clock_rtl_0_clk_n),
        .diff_clock_rtl_0_clk_p(diff_clock_rtl_0_clk_p),
        .pwm_r_o_0(pwm_r_o_0),
        .pwm_r_o_1(pwm_r_o_1),
        .reset_rtl_0(reset_rtl_0),
        .rst_n_0(rst_n_0));
endmodule
