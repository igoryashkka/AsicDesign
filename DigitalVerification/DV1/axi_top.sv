module axi_filter_top #(
  parameter int PIX_BW = 8
)(
  input  logic                      aclk,
  input  logic                      arstn,

  axi_if.write_slv                  s_wbus,    // вхідна шина, запис
  axi_if.read_slv                   s_rbus,    // вхідна шина, читання (заглушка)
  axi_if.write_mst                  m_wbus,    // вихідна шина, запис
  axi_if.read_mst                   m_rbus,    // вихідна шина, читання (заглушка)

  input  logic [1:0]                cfg_select,
  input  logic [m_wbus.ADDR_BW-1:0] dst_addr,
  output logic                      busy,
  output logic                      done,
  output logic                      err
);

  logic [PIX_BW-1:0] win [0:8];
  logic              win_valid, win_ready;
  logic [PIX_BW-1:0] filt_pix;

  axi_slv #(.PIX_BW(PIX_BW)) u_slv (
    .aclk        (aclk),
    .arstn       (arstn),
    .sw_bus      (s_wbus),
    .sr_bus      (s_rbus),
    .o_win       (win),
    .o_win_valid (win_valid),
    .i_win_ready (win_ready)
  );

  axi_cl #(.PIX_BW(PIX_BW)) u_cl (
    .i_win (win),
    .i_cfg (cfg_select),
    .o_pix (filt_pix)
  );

  axi_mst #(.PIX_BW(PIX_BW)) u_mst (
    .aclk        (aclk),
    .arstn       (arstn),
    .mw_bus      (m_wbus),
    .mr_bus      (m_rbus),
    .i_pix       (filt_pix),
    .i_pix_valid (win_valid),
    .o_pix_ready (win_ready),
    .dst_addr    (dst_addr),
    .busy        (busy),
    .done        (done),
    .err         (err)
  );

endmodule