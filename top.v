
// 
// Module: impl_top
// 
// Notes:
// - Top level module to be used in an implementation.
// - To be used in conjunction with the constraints/defaults.xdc file.
// - Ports can be (un)commented depending on whether they are being used.
// - The constraints file contains a complete list of the available ports
module top (
    input        clk,        // System clock
    input        rst,        // Active high reset
    input        uart_rx,    // UART receive input from the USB-UART bridge
    output [7:0] leds        // 8 LEDs on the board
);

  // Internal signals for UART data and valid pulse
  wire [7:0] rx_data;
  wire       rx_valid;
  wire       uart_rx_en = 1;
  wire       uart_rx_break;

  uart_rx uart_inst (
    .clk(clk),
    .resetn(rst),
    .uart_rxd(uart_rx),
    .uart_rx_en(uart_rx_en),
    .uart_rx_break(uart_rx_break),
    .uart_rx_valid(rx_valid),
    .uart_rx_data(rx_data)
  )

  // Register to hold the last received byte, which drives the LEDs.
  reg [7:0] led_reg;
  
  // On reset, clear the register. Otherwise, when a new byte is received,
  // update the LED register. The value remains until the next byte is received.
  always @(posedge clk or posedge rst) begin
    if (rst)
      led_reg <= 8'b0;
    else if (rx_valid)
      led_reg <= rx_data;
  end

  // Drive the board's LEDs with the register value.
  assign leds = led_reg;

endmodule

