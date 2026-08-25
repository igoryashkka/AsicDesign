module axi_slv #(
  parameter int PIX_BW = 8
)(
  input logic aclk,
  input logic arstn,
  axi_if.read_slv sr_bus,
  axi_if.write_slv sw_bus,

  output logic [PIX_BW-1:0] o_win [0:8],
  output logic o_win_valid,
  input logic i_win_ready
);
  
  localparam ID_BW = sr_bus.ID_BW;

  localparam logic [1:0] RESP_OKAY = 2'b00;
  localparam logic [1:0] RESP_SLVERR = 2'b10;
  localparam logic [7:0] WIN_LEN = 8'd8; //9 beats
  
  wire aw_hs = sw_bus.awvalid && sw_bus.awready;
  wire w_hs = sw_bus.wvalid && sw_bus.wready;
  wire b_hs = sw_bus.bvalid && sw_bus.bready;

  typedef enum logic [1:0] {
    W_ADDR,
    W_DATA,
    W_OUT,
    W_RESP
  } state_t;

  state_t state, next_state;

  always_ff @(posedge aclk or negedge arstn) begin
    if (!arstn) state <= W_ADDR;
    else state <= next_state;
  end

  always_comb begin
    next_state = state;
    case (state)
      W_ADDR: if (aw_hs) next_state = W_DATA;
      W_DATA: if (w_hs && sw_bus.wlast) next_state = W_OUT;
      W_OUT: if (i_win_ready) next_state = W_RESP;
      W_RESP: if (b_hs) next_state = W_ADDR;
      default: next_state = W_ADDR;
    endcase
  end

  logic [ID_BW-1:0] aw_id;
  logic [7:0] aw_len;
  logic [3:0] w_cnt;
  logic len_err;

  always_ff @(posedge aclk or negedge arstn) begin
    if (!arstn) begin
      w_cnt <= '0;
      len_err <= 1'b0;
    end
    else if (aw_hs) begin
      aw_id <= sw_bus.awid;
      aw_len <= sw_bus.awlen;
      w_cnt <= '0;
      len_err <= (sw_bus.awlen != WIN_LEN);
    end
    else if (w_hs) begin
      w_cnt <= w_cnt + 4'b1;
      if (sw_bus.wlast && (w_cnt != 4'b0)) len_err <= 1'b1;
    end
  end

  //window packing
  always_ff @(posedge aclk) begin
    if (w_hs && (w_cnt < 4'd9))
      o_win[w_cnt] <= sw_bus.wdata[PIX_BW-1:0];
  end

  assign sw_bus.awready = (state == W_ADDR);
  assign sw_bus.wready = (state == W_DATA);
  assign sw_bus.bvalid = (state == W_RESP);
  assign sw_bus.bresp = len_err ? RESP_SLVERR : RESP_OKAY;
  assign sw_bus.bid = aw_id;

  assign o_win_valid = (state == W_OUT);

endmodule