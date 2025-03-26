`timescale 1ns/1ps

module uart_rx_tb;
    // Parameters
    parameter CLK_FREQ = 50_000_000;  // 50 MHz clock
    parameter BAUD_RATE = 115200;
    parameter CLK_PERIOD = 20;        // 50MHz = 20ns period
    parameter BIT_PERIOD = CLK_FREQ / BAUD_RATE;  // Clock cycles per bit

    // Signals
    reg        clk;
    reg        rst;
    reg        rx;
    wire [7:0] data;
    wire       data_valid;
    integer    i;  // [FIX] Declared integer i outside loops
    
    // DUT instantiation
    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .data(data),
        .data_valid(data_valid)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Task to send a byte over UART
    task send_byte;
        input [7:0] byte_to_send;
        begin
            // Send start bit (low)
            rx = 0;
            #(BIT_PERIOD * CLK_PERIOD);  // [FIX] Ensured correct cycle count
            
            // Send data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                rx = byte_to_send[i];
                #(BIT_PERIOD * CLK_PERIOD);  // [FIX] Consistent timing
            end
            
            // Send stop bit (high)
            rx = 1;
            #(BIT_PERIOD * CLK_PERIOD);
        end
    endtask
    
    // Task to send a byte with framing error (missing stop bit)
    task send_byte_with_framing_error;
        input [7:0] byte_to_send;
        begin
            rx = 0;
            #(BIT_PERIOD * CLK_PERIOD);
            
            for (i = 0; i < 8; i = i + 1) begin
                rx = byte_to_send[i];
                #(BIT_PERIOD * CLK_PERIOD);
            end
            
            // Incorrect stop bit (low instead of high)
            rx = 0;
            #(BIT_PERIOD * CLK_PERIOD);
            
            // Restore to idle state
            rx = 1;
            #(BIT_PERIOD * CLK_PERIOD);
        end
    endtask
    
    // Monitor for received data
    always @(posedge clk) begin
        if (data_valid) begin
            $display("Time %0t: Received data: 0x%h (ASCII '%c')", $time, data, data);
        end
    end
    
    // Dump waveform for debugging
    initial begin
        $dumpfile("uart_rx_tb.vcd");  // [NEW] Added waveform dumping
        $dumpvars(0, uart_rx_tb);
    end
    
    // Test sequence
    initial begin
        rx = 1;      // Idle state is high
        rst = 1;     // Assert reset
        #200;        // [FIX] Added delay for reset assertion
        rst = 0;     // Deassert reset
        #200;
        
        // Send ASCII '0' to '7'
        for (i = 0; i <= 7; i = i + 1) begin
            send_byte(8'h30 + i);  // ASCII '0' starts at 0x30
            #(BIT_PERIOD * 2 * CLK_PERIOD);
        end
        
        // Send framing error
        send_byte_with_framing_error(8'h33);
        #(BIT_PERIOD * 2 * CLK_PERIOD);
        
        // Send valid data to check recovery
        send_byte(8'h35);
        #(BIT_PERIOD * 2 * CLK_PERIOD);
        
        // End simulation
        $display("\nSimulation complete");
        #1000;
        $finish;  // [FIX] Ensured simulation exits cleanly
    end
    
endmodule
