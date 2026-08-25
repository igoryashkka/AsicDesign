interface axi_if #(
  parameter ADDR_BW = 32,
  parameter DATA_BW = 32,
  parameter ID_BW = 4,
  parameter STRB_BW = DATA_BW/8
)(
  input logic aclk, arstn
);

  initial begin
    if (!(DATA_BW inside {8, 16, 32, 64, 128, 256, 512, 1024}))
      $fatal (1, "axi_if: DATA_BW=%0d invalid for AXI4", DATA_BW);
  end
  
  //aw
  logic [ID_BW-1:0] awid;
  logic awvalid;
  logic [7:0] awlen;
  logic [2:0] awsize;
  logic [1:0] awburst;
  logic [ADDR_BW-1:0] awaddr;
  logic awlock;
  logic [3:0] awcache;
  logic [3:0] awqos;
  logic [2:0] awprot;
  logic awready;
  //w
  logic wvalid;
  logic wlast;
  logic [DATA_BW-1:0] wdata;
  logic [STRB_BW-1:0] wstrb;
  logic wready;
  //b
  logic [ID_BW-1:0] bid;
  logic bvalid;
  logic [1:0] bresp;
  logic bready;
  //ar
  logic [ID_BW-1:0] arid;
  logic arvalid;
  logic [7:0] arlen;
  logic [2:0] arsize;
  logic [1:0] arburst;
  logic [ADDR_BW-1:0] araddr;
  logic arlock;
  logic [3:0] arcache;
  logic [3:0] arqos;
  logic [2:0] arprot;
  logic arready;
  //r
  logic [ID_BW-1:0] rid;
  logic rvalid;
  logic rlast;
  logic [DATA_BW-1:0] rdata;
  logic [1:0] rresp;
  logic rready; 

  modport write_mst (
    //aw
    output awid,
    output awvalid,
    output awlen,
    output awsize,
    output awburst,
    output awaddr,
    output awlock,
    output awcache,
    output awqos,
    output awprot,
    input awready,
    //w
    output wvalid,
    output wdata,
    output wstrb,
    output wlast,
    input wready,
    //b
    input bid,
    input bresp,
    input bvalid,
    output bready,

    input aclk, arstn
  );

  modport write_slv (
    //aw
    input awid,
    input awvalid,
    input awlen,
    input awsize,
    input awburst,
    input awaddr,
    input awlock,
    input awcache,
    input awqos,
    input awprot,
    output awready,
    //w
    input wvalid,
    input wdata,
    input wstrb,
    input wlast,
    output wready,
    //b
    output bid,
    output bresp,
    output bvalid,
    input bready,

    input aclk, arstn
  );

  modport read_mst (
    //ar
    output arid,
    output arvalid,
    output arlen,
    output arsize,
    output arburst,
    output araddr,
    output arlock,
    output arcache,
    output arqos,
    output arprot,
    input arready,
    //r
    input rid,
    input rvalid,
    input rdata,
    input rresp,
    input rlast,
    output rready,
    
    input aclk, arstn
  );

  modport read_slv (
    //ar
    input arid,
    input arvalid,
    input arlen,
    input arsize,
    input arburst,
    input araddr,
    input arlock,
    input arcache,
    input arqos,
    input arprot,
    output arready,
    //r
    output rid,
    output rvalid,
    output rdata,
    output rresp,
    output rlast,
    input rready,

    input aclk, arstn
  );
endinterface 