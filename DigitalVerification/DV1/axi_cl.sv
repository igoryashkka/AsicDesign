module axi_cl #(
  parameter int PIX_BW = 8
)(
  input  logic [PIX_BW-1:0] i_win [0:8],
  input  logic [1:0]        i_cfg,
  output logic [PIX_BW-1:0] o_pix
);

  localparam logic [1:0] F_MIN = 2'b00, F_MAX = 2'b01,
                         F_MED = 2'b10, F_SOBEL = 2'b11;
  localparam logic [PIX_BW-1:0] PIX_MAX = '1;

  logic [PIX_BW-1:0] min_pix, max_pix;

  always_comb begin
    min_pix = i_win[0];
    max_pix = i_win[0];
    for (int i = 1; i < 9; i++) begin
      if (i_win[i] < min_pix) min_pix = i_win[i];
      if (i_win[i] > max_pix) max_pix = i_win[i];
    end
  end

  function automatic logic [2*PIX_BW-1:0] cas (
    input logic [PIX_BW-1:0] a, b
  );
    cas = (a <= b) ? {a, b} : {b, a};   // {менше, більше}
  endfunction

  logic [PIX_BW-1:0] s [0:8];
  logic [PIX_BW-1:0] med_pix;

  always_comb begin
    for (int i = 0; i < 9; i++) s[i] = i_win[i];

    {s[1],s[2]} = cas(s[1],s[2]);
    {s[4],s[5]} = cas(s[4],s[5]);
    {s[7],s[8]} = cas(s[7],s[8]);

    {s[0],s[1]} = cas(s[0],s[1]);
    {s[3],s[4]} = cas(s[3],s[4]);
    {s[6],s[7]} = cas(s[6],s[7]);

    {s[1],s[2]} = cas(s[1],s[2]);
    {s[4],s[5]} = cas(s[4],s[5]);
    {s[7],s[8]} = cas(s[7],s[8]);

    {s[0],s[3]} = cas(s[0],s[3]);
    {s[5],s[8]} = cas(s[5],s[8]);
    {s[4],s[7]} = cas(s[4],s[7]);

    {s[3],s[6]} = cas(s[3],s[6]);
    {s[1],s[4]} = cas(s[1],s[4]);
    {s[2],s[5]} = cas(s[2],s[5]);

    {s[4],s[7]} = cas(s[4],s[7]);
    {s[4],s[2]} = cas(s[4],s[2]);
    {s[6],s[4]} = cas(s[6],s[4]);
    {s[4],s[2]} = cas(s[4],s[2]);

    med_pix = s[4];
  end

  localparam int PBW = PIX_BW + 3;   // часткова сума <= 4*(2^PIX_BW - 1)
  localparam int MBW = PIX_BW + 4;   // |Gx| + |Gy| <= 8*(2^PIX_BW - 1)

  logic [PBW-1:0]    gx_pos, gx_neg, gy_pos, gy_neg, abs_gx, abs_gy;
  logic [MBW-1:0]    mag;
  logic [PIX_BW-1:0] sobel_pix;

  always_comb begin
    gx_pos = PBW'(i_win[2]) + PBW'({i_win[5], 1'b0}) + PBW'(i_win[8]);
    gx_neg = PBW'(i_win[0]) + PBW'({i_win[3], 1'b0}) + PBW'(i_win[6]);
    gy_pos = PBW'(i_win[6]) + PBW'({i_win[7], 1'b0}) + PBW'(i_win[8]);
    gy_neg = PBW'(i_win[0]) + PBW'({i_win[1], 1'b0}) + PBW'(i_win[2]);

    abs_gx = (gx_pos >= gx_neg) ? (gx_pos - gx_neg) : (gx_neg - gx_pos);
    abs_gy = (gy_pos >= gy_neg) ? (gy_pos - gy_neg) : (gy_neg - gy_pos);

    mag = MBW'(abs_gx) + MBW'(abs_gy);

    sobel_pix = (mag > MBW'(PIX_MAX)) ? PIX_MAX : mag[PIX_BW-1:0];
  end

  always_comb begin
    unique case (i_cfg)
      F_MIN   : o_pix = min_pix;
      F_MAX   : o_pix = max_pix;
      F_MED   : o_pix = med_pix;
      F_SOBEL : o_pix = sobel_pix;
      default : o_pix = '0;
    endcase
  end

endmodule