module axi_mst #(
  parameter int PIX_BW = 8
)(
  input logic aclk,
  input logic arstn,
  axi_if.write_mst mw_bus,
  axi_if.read_mst mr_bus,

  input logic [PIX_BW-1:0] i_pix,
  input logic i_pix_valid,
  output logic o_pix_ready,

  input logic [mw_bus.ADDR_BW-1:0] dst_addr,
  output logic busy,
  output logic done,
  output logic err
);

  localparam ADDR_BW = mr_bus.ADDR_BW;
  localparam DATA_BW = mr_bus.DATA_BW;
  localparam STRB_BW = DATA_BW/8;

  localparam logic [1:0] BURST_INCR = 2'b01;
  localparam logic [2:0] BEAT_SIZE = 3'($clog2(STRB_BW));
  
  //handshake
  wire aw_hs = mw_bus.awvalid && mw_bus.awready; 
  wire w_hs = mw_bus.wvalid && mw_bus.wready; 
  wire b_hs = mw_bus.bvalid && mw_bus.bready; 

  wire pix_hs = i_pix_valid && o_pix_ready;

  //fsm
  typedef enum logic [1:0] {
    IDLE,
    W_XFER,
    W_RESP,
    DONE
  } state_t;

  state_t state, next_state;

  logic aw_sent, w_sent;   
  
  always_ff @(posedge aclk or negedge arstn) begin
    if (!arstn) state <= IDLE;
    else state <= next_state;
  end
  
  always_comb begin
    next_state = state;
    case (state)
      IDLE: if (pix_hs) next_state = W_XFER;
      W_XFER: if ((aw_sent || aw_hs) && (w_sent || w_hs)) next_state = W_RESP;
      W_RESP: if (b_hs) next_state = DONE;
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end
  
  logic [PIX_BW-1:0] pix_reg;
  logic [ADDR_BW-1:0] dst_reg;

  always_ff @(posedge aclk) begin
    if (pix_hs) begin
      pix_reg <= i_pix;
      dst_reg <= dst_addr;
    end
  end

  always_ff @(posedge aclk or negedge arstn) begin
    if (!arstn) begin
      aw_sent <= 1'b0;
      w_sent <= 1'b0;
    end
    else if (state == IDLE) begin
      aw_sent <= 1'b0;
      w_sent <= 1'b0;
    end
    else begin
      if (aw_hs) aw_sent <= 1'b1;
      if (w_hs) w_sent <= 1'b1;
    end
  end

  //error
  always_ff @(posedge aclk or negedge arstn) begin
    if (!arstn) err <= 1'b0;
    else if (pix_hs) err <= 1'b0;
    else if (b_hs && (mw_bus.bresp != 2'b00)) err <= 1'b1;
  end

  //outputs
  assign o_pix_ready = (state == IDLE);
  assign busy = (state != IDLE);
  assign done = (state == DONE);

  assign mw_bus.awvalid = (state == W_XFER) && !aw_sent;
  assign mw_bus.awid = '0;
  assign mw_bus.awaddr = dst_reg;
  assign mw_bus.awlen = 8'b0;
  assign mw_bus.awsize = BEAT_SIZE;
  assign mw_bus.awburst = BURST_INCR;
  assign mw_bus.awlock = 1'b0;
  assign mw_bus.awcache = 4'b0000;
  assign mw_bus.awprot = 3'b000;
  assign mw_bus.awqos = 4'b0000;

  assign mw_bus.wvalid = (state == W_XFER) && !w_sent;
  assign mw_bus.wdata = DATA_BW'(pix_reg);
  assign mw_bus.wstrb = '1;
  assign mw_bus.wlast = 1'b1;

  assign mw_bus.bready = (state == W_RESP);
endmodule