module spi_master #(
  parameter N = 4 
)(
  input logic clk, reset, start, miso,
  input logic [N-1:0] data,
  output logic mosi, done, sck, cs
);
  typedef enum logic [3:0] {
    IDLE = 4'b0001,
    RECORD = 4'b0010,
    SHIFT = 4'b0100,
    CHECK = 4'b1000 
  } state_t;

  state_t current_state, next_state;

  logic [N-1:0] shift_reg;
  int bit_index;

  always_ff @(posedge clk, posedge reset) begin
    if (reset) 
      current_state <= IDLE;
    else
      current_state <= next_state;
  end

  always_comb begin
    next_state = current_state;


    case(current_state)
      IDLE: begin
        mosi = 0;
        done = 0;
        sck = 0;
        cs = 1;
        bit_index = 0;
        shift_reg = data;
        if (start) next_state = RECORD;
        else next_state = IDLE;
      end
      RECORD: begin
        bit_index = N;
        next_state = SHIFT;
      end
      SHIFT: begin
        cs = 0;
        sck = 1;
        mosi = shift_reg[0];
        shift_reg = shift_reg >> 1;
        bit_index--;
        next_state = CHECK;
      end
      CHECK: begin
        sck = 0;
        if (bit_index == 0) begin
          done = 1;
          next_state = IDLE;
        end
        else begin
          next_state = SHIFT;
        end
    
      end
    endcase
  end

endmodule