`timescale 1ns/1ps

//==============================================================================
package tb_pkg;

  parameter int ADDR_BW = 32;
  parameter int DATA_BW = 32;
  parameter int ID_BW   = 4;
  parameter int PIX_BW  = 8;

  parameter logic [1:0] F_MIN = 2'b00, F_MAX = 2'b01,
                        F_MED = 2'b10, F_SOBEL = 2'b11;

  parameter logic [ADDR_BW-1:0] SRC_ADDR = 32'h0000_1000;
  parameter logic [ADDR_BW-1:0] DST_ADDR = 32'h0000_2000;

  parameter logic [7:0] WIN_LEN = 8'd8;   // 9 beat'ів
  parameter logic [2:0] BEAT_SZ = 3'd2;   // 4 байти за beat

  typedef logic [PIX_BW-1:0] pix_t;

  //--------------------------------------------------------------------------
  // Референсна модель -- те саме, що має порахувати axi_cl
  //--------------------------------------------------------------------------
  function automatic pix_t ref_filter (input pix_t w [9], input logic [1:0] cfg);
    pix_t sorted [9];
    pix_t tmp;
    int   gxp, gxn, gyp, gyn, mag;

    case (cfg)
      F_MIN, F_MAX, F_MED: begin
        for (int i = 0; i < 9; i++) sorted[i] = w[i];
        for (int i = 0; i < 8; i++)
          for (int j = 0; j < 8-i; j++)
            if (sorted[j] > sorted[j+1]) begin
              tmp = sorted[j]; sorted[j] = sorted[j+1]; sorted[j+1] = tmp;
            end
        if      (cfg == F_MIN) ref_filter = sorted[0];
        else if (cfg == F_MAX) ref_filter = sorted[8];
        else                   ref_filter = sorted[4];
      end
      default: begin   // SOBEL: |Gx| + |Gy| з насиченням
        gxp = w[2] + 2*w[5] + w[8];
        gxn = w[0] + 2*w[3] + w[6];
        gyp = w[6] + 2*w[7] + w[8];
        gyn = w[0] + 2*w[1] + w[2];
        mag = ((gxp > gxn) ? gxp-gxn : gxn-gxp)
            + ((gyp > gyn) ? gyp-gyn : gyn-gyp);
        ref_filter = (mag > 255) ? pix_t'(255) : pix_t'(mag);
      end
    endcase
  endfunction

  function automatic string cfg_name (input logic [1:0] c);
    case (c)
      F_MIN:   cfg_name = "MIN";
      F_MAX:   cfg_name = "MAX";
      F_MED:   cfg_name = "MEDIAN";
      default: cfg_name = "SOBEL";
    endcase
  endfunction

endpackage : tb_pkg

import tb_pkg::*;

//==============================================================================
// Інтерфейс конфігурації
//==============================================================================
interface cfg_if (input logic clk);
  logic [1:0]         cfg_select;
  logic [ADDR_BW-1:0] dst_addr;
endinterface

//==============================================================================
// TRANSACTION -- одне вікно 3x3, режим фільтра, затримки
//==============================================================================
class axi_transaction;
  rand pix_t        pix [9];     // 9 пікселів вікна
  rand logic [1:0]  cfg;         // режим фільтра
  rand int unsigned aw_delay;    // затримка перед AW
  rand int unsigned w_gap;       // пауза між W-beat'ами
  rand bit          use_gap;

  int unsigned delay_max = 3;
  int unsigned dist_gap  = 3;    // 0..10 -- ймовірність пауз

  constraint c_gap_prob {
    use_gap dist {1 := dist_gap, 0 := 10 - dist_gap};
  }
  constraint c_delays {
    aw_delay inside {[0:delay_max]};
    if (use_gap) w_gap inside {[1:delay_max]};
    else         w_gap == 0;
  }

  function string convert2str();
    return $sformatf("cfg=%s aw_delay=%0d w_gap=%0d",
                     cfg_name(cfg), aw_delay, w_gap);
  endfunction
endclass

//==============================================================================
// MASTER AGENT -- драйвер + монітор вхідної шини
//==============================================================================
class axi_mst_agent;
  virtual axi_if #(ADDR_BW, DATA_BW, ID_BW) vif;
  virtual cfg_if                            cvif;

  function new(virtual axi_if #(ADDR_BW, DATA_BW, ID_BW) vif,
               virtual cfg_if                            cvif);
    this.vif  = vif;
    this.cvif = cvif;
  endfunction

  task automatic init();
    vif.awvalid <= 1'b0;
    vif.wvalid  <= 1'b0;
    vif.wlast   <= 1'b0;
    vif.bready  <= 1'b0;
    vif.arvalid <= 1'b0;          // канал читання не задіяний
    vif.rready  <= 1'b0;
    vif.arid    <= '0;
    vif.araddr  <= '0;
    vif.arlen   <= '0;
    vif.arsize  <= BEAT_SZ;
    vif.arburst <= 2'b01;
    vif.arlock  <= 1'b0;
    vif.arcache <= '0;
    vif.arprot  <= '0;
    vif.arqos   <= '0;
  endtask

  //-------------------------------------------------------------------- DRIVER
  task automatic drive(input axi_transaction tr);
    cvif.cfg_select <= tr.cfg;
    cvif.dst_addr   <= DST_ADDR;
    @(posedge vif.aclk);

    fork
      drive_aw(tr);
      drive_w(tr);
      drive_b();
    join
  endtask

  task automatic drive_aw(input axi_transaction tr);
    repeat (tr.aw_delay) @(posedge vif.aclk);
    vif.awid    <= 4'h1;
    vif.awaddr  <= SRC_ADDR;
    vif.awlen   <= WIN_LEN;
    vif.awsize  <= BEAT_SZ;
    vif.awburst <= 2'b01;         // INCR
    vif.awlock  <= 1'b0;
    vif.awcache <= '0;
    vif.awprot  <= '0;
    vif.awqos   <= '0;
    vif.awvalid <= 1'b1;
    do @(posedge vif.aclk); while (!vif.awready);
    vif.awvalid <= 1'b0;
    vif.awaddr  <= 'x;
  endtask

  task automatic drive_w(input axi_transaction tr);
    for (int i = 0; i < 9; i++) begin
      if (tr.w_gap > 0 && i > 0) begin
        vif.wvalid <= 1'b0;
        vif.wdata  <= 'x;
        repeat (tr.w_gap) @(posedge vif.aclk);
      end
      vif.wdata  <= DATA_BW'(tr.pix[i]);
      vif.wstrb  <= '1;
      vif.wlast  <= (i == 8);
      vif.wvalid <= 1'b1;
      do @(posedge vif.aclk); while (!vif.wready);
    end
    vif.wvalid <= 1'b0;
    vif.wlast  <= 1'b0;
    vif.wdata  <= 'x;
    vif.wstrb  <= 'x;
  endtask

  task automatic drive_b();
    vif.bready <= 1'b1;
    do @(posedge vif.aclk); while (!vif.bvalid);
    if (vif.bresp !== 2'b00)
      $display("[MST-DRV] @%0t BRESP=%b", $time, vif.bresp);
    vif.bready <= 1'b0;
  endtask

  //------------------------------------------------------------------- MONITOR
  // Збирає 9 beat'ів бурста, фіксує режим фільтра на першому beat'і.
  task automatic monitor(output pix_t win [9], output logic [1:0] cfg);
    int idx = 0;
    forever begin
      @(posedge vif.aclk);
      if (vif.wvalid && vif.wready) begin
        win[idx] = vif.wdata[PIX_BW-1:0];
        if (idx == 0) cfg = cvif.cfg_select;
        idx++;
        if (vif.wlast) begin
          $display("[MON-IN ] @%0t cfg=%s", $time, cfg_name(cfg));
          break;
        end
      end
    end
  endtask
endclass

//==============================================================================
// SLAVE AGENT -- респондер + монітор вихідної шини
//==============================================================================
class axi_slv_agent;
  virtual axi_if #(ADDR_BW, DATA_BW, ID_BW) vif;
  int unsigned bp_max;          // максимальний backpressure, 0 = без пауз

  function new(virtual axi_if #(ADDR_BW, DATA_BW, ID_BW) vif,
               input int unsigned bp_max = 0);
    this.vif    = vif;
    this.bp_max = bp_max;
  endfunction

  task automatic init();
    vif.awready <= 1'b0;
    vif.wready  <= 1'b0;
    vif.bvalid  <= 1'b0;
    vif.bresp   <= 2'b00;
    vif.bid     <= '0;
    vif.arready <= 1'b0;          // канал читання не задіяний
    vif.rvalid  <= 1'b0;
    vif.rdata   <= '0;
    vif.rresp   <= 2'b00;
    vif.rlast   <= 1'b0;
    vif.rid     <= '0;
  endtask

  //-------------------------------------------------------------------- DRIVER
  task automatic run_responder();
    logic [ID_BW-1:0]   id;
    logic [ADDR_BW-1:0] addr;
    forever begin
      // AW
      vif.awready <= 1'b1;
      do @(posedge vif.aclk); while (!vif.awvalid);
      id   = vif.awid;
      addr = vif.awaddr;
      vif.awready <= 1'b0;

      if (addr !== DST_ADDR)
        $display("[SLV-DRV] @%0t невірна адреса 0x%08h", $time, addr);

      // W
      if (bp_max > 0) repeat ($urandom_range(1, bp_max)) @(posedge vif.aclk);
      vif.wready <= 1'b1;
      do @(posedge vif.aclk); while (!vif.wvalid);
      vif.wready <= 1'b0;

      // B
      if (bp_max > 0) repeat ($urandom_range(0, bp_max)) @(posedge vif.aclk);
      vif.bid    <= id;
      vif.bresp  <= 2'b00;
      vif.bvalid <= 1'b1;
      do @(posedge vif.aclk); while (!vif.bready);
      vif.bvalid <= 1'b0;
    end
  endtask

  //------------------------------------------------------------------- MONITOR
  task automatic monitor(output pix_t dout);
    forever begin
      @(posedge vif.aclk);
      if (vif.wvalid && vif.wready) begin
        dout = vif.wdata[PIX_BW-1:0];
        $display("[MON-OUT] @%0t pix=%02h", $time, dout);
        break;
      end
    end
  endtask
endclass

//==============================================================================
// CHECKER / SCOREBOARD
//==============================================================================
class checker_scoreboard;
  axi_mst_agent mst_ag;
  axi_slv_agent slv_ag;

  mailbox #(pix_t) mb_gold;
  mailbox #(pix_t) mb_out;

  int unsigned n_compared;
  int unsigned n_errors;

  function new(axi_mst_agent mst_ag, axi_slv_agent slv_ag);
    this.mst_ag = mst_ag;
    this.slv_ag = slv_ag;
    mb_gold     = new();
    mb_out      = new();
    n_compared  = 0;
    n_errors    = 0;
  endfunction

  task automatic collect_in();
    pix_t       win [9];
    logic [1:0] cfg;
    forever begin
      mst_ag.monitor(win, cfg);
      mb_gold.put(ref_filter(win, cfg));
    end
  endtask

  task automatic collect_out();
    pix_t dout;
    forever begin
      slv_ag.monitor(dout);
      mb_out.put(dout);
    end
  endtask

  task automatic compare();
    pix_t gld, out;
    forever begin
      mb_gold.get(gld);
      mb_out.get(out);
      n_compared++;
      if (out !== gld) begin
        n_errors++;
        $display("[SCB] @%0t MISMATCH #%0d: exp=%02h got=%02h",
                 $time, n_compared, gld, out);
      end
      else
        $display("[SCB] @%0t MATCH    #%0d: %02h", $time, n_compared, out);
    end
  endtask

  task automatic run();
    fork
      collect_in();
      collect_out();
      compare();
    join_none
  endtask

  function void report(input int expected);
    $display("\n----------------------------------------");
    $display("Порівняно: %0d / %0d, помилок: %0d",
             n_compared, expected, n_errors);
    $display((n_errors == 0 && n_compared == expected)
             ? "РЕЗУЛЬТАТ: PASS" : "РЕЗУЛЬТАТ: FAIL");
    $display("----------------------------------------\n");
  endfunction
endclass

//==============================================================================
// TEST CASE
//==============================================================================
class filter_test;
  virtual axi_if #(ADDR_BW, DATA_BW, ID_BW) vif_in, vif_out;
  virtual cfg_if                            cvif;

  axi_mst_agent      mst_ag;
  axi_slv_agent      slv_ag;
  checker_scoreboard scb;

  int n_random = 30;
  int n_sent   = 0;

  function new(virtual axi_if #(ADDR_BW, DATA_BW, ID_BW) vif_in,
               virtual axi_if #(ADDR_BW, DATA_BW, ID_BW) vif_out,
               virtual cfg_if                            cvif);
    this.vif_in  = vif_in;
    this.vif_out = vif_out;
    this.cvif    = cvif;
  endfunction

  //--------------------------------------------------------------------- BUILD
  task automatic build();
    mst_ag = new(vif_in, cvif);
    slv_ag = new(vif_out, 3);      // backpressure до 3 тактів
    scb    = new(mst_ag, slv_ag);
    mst_ag.init();
    slv_ag.init();
    cvif.cfg_select <= F_MIN;
    cvif.dst_addr   <= DST_ADDR;
  endtask

  //------------------------------------------------------------------- ХЕЛПЕР
  task automatic send_directed(input pix_t p [9], input logic [1:0] cfg);
    axi_transaction tr = new();
    tr.pix      = p;
    tr.cfg      = cfg;
    tr.aw_delay = 0;
    tr.w_gap    = 0;
    n_sent++;
    mst_ag.drive(tr);
  endtask

  //----------------------------------------------------------------- СЦЕНАРІЙ
  task automatic run_testcase();
    pix_t ramp  [9] = '{10, 20, 30, 40, 50, 60, 70, 80, 90};
    pix_t flat  [9] = '{77, 77, 77, 77, 77, 77, 77, 77, 77};
    pix_t spike [9] = '{0, 0, 0, 0, 255, 0, 0, 0, 0};
    pix_t vedge [9] = '{0, 0, 255, 0, 0, 255, 0, 0, 255};

    $display("\n=== Направлені: базове вікно, усі режими ===");
    send_directed(ramp, F_MIN);      // 10
    send_directed(ramp, F_MAX);      // 90
    send_directed(ramp, F_MED);      // 50
    send_directed(ramp, F_SOBEL);    // 320 -> насичення 255

    $display("\n=== Виродження та межі ===");
    send_directed(flat,  F_MED);     // 77
    send_directed(flat,  F_SOBEL);   // 0 -- градієнта немає
    send_directed(spike, F_MED);     // 0 -- викид не зміщує медіану
    send_directed(spike, F_MAX);     // 255
    send_directed(vedge, F_SOBEL);   // вертикальний край -> 255

    $display("\n=== Випадкові вікна ===");
    repeat (n_random) begin
      axi_transaction tr = new();
      assert (tr.randomize()) else $fatal(1, "randomize failed");
      n_sent++;
      mst_ag.drive(tr);
    end
  endtask

  //----------------------------------------------------------------------- RUN
  task automatic run();
    build();
    fork
      slv_ag.run_responder();
      scb.run();
    join_none

    run_testcase();

    wait (scb.n_compared == n_sent);
    repeat (10) @(posedge vif_in.aclk);
    scb.report(n_sent);
  endtask
endclass

//==============================================================================
// TOP MODULE
//==============================================================================
module tb_axi_filter;

  localparam time CLK_P = 10ns;

  logic aclk = 1'b0;
  logic arstn;
  always #(CLK_P/2) aclk = ~aclk;

  axi_if #(ADDR_BW, DATA_BW, ID_BW) bus_in  (.aclk(aclk), .arstn(arstn));
  axi_if #(ADDR_BW, DATA_BW, ID_BW) bus_out (.aclk(aclk), .arstn(arstn));
  cfg_if                            cfg     (.clk(aclk));

  logic busy, done, err;

  axi_filter_top #(.PIX_BW(PIX_BW)) u_dut (
    .aclk       (aclk),
    .arstn      (arstn),
    .s_wbus     (bus_in.write_slv),
    .s_rbus     (bus_in.read_slv),
    .m_wbus     (bus_out.write_mst),
    .m_rbus     (bus_out.read_mst),
    .cfg_select (cfg.cfg_select),
    .dst_addr   (cfg.dst_addr),
    .busy       (busy),
    .done       (done),
    .err        (err)
  );

  filter_test test;

  initial begin
    arstn = 1'b0;
    repeat (5) @(posedge aclk);
    arstn = 1'b1;
    repeat (2) @(posedge aclk);

    test = new(bus_in, bus_out, cfg);
    test.run();

    $finish;
  end

endmodule