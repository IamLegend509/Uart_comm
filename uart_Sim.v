`timescale 1ns/1ps

module uart_rx_tb;
    // Parameters
    parameter CLK_FREQ = 50_000_000;  // 50 MHz clock for easier timing
    parameter BAUD_RATE = 115200;
    parameter CLK_PERIOD = 20;        // 50MHz = 20ns period
    parameter BIT_PERIOD = CLK_FREQ / BAUD_RATE;  // Clock cycles per bit

    // Signals
    reg        clk;
    reg        rst;
    reg        rx;
    wire [7:0] data;
    wire       data_valid;
    
    // Test data (ASCII values for '0' through '7')
    reg [7:0] test_data;
    
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
        integer i;
        begin
            // Send start bit (low)
            rx = 0;
            repeat (BIT_PERIOD) @(posedge clk);
            
            // Send data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                rx = byte_to_send[i];
                repeat (BIT_PERIOD) @(posedge clk);
            end
            
            // Send stop bit (high)
            rx = 1;
            repeat (BIT_PERIOD) @(posedge clk);
            
            // Wait a bit between bytes
            repeat (BIT_PERIOD/2) @(posedge clk);
        end
    endtask
    
    // Task to send a byte with framing error (no stop bit)
    task send_byte_with_framing_error;
        input [7:0] byte_to_send;
        integer i;
        begin
            // Send start bit (low)
            rx = 0;
            repeat (BIT_PERIOD) @(posedge clk);
            
            // Send data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                rx = byte_to_send[i];
                repeat (BIT_PERIOD) @(posedge clk);
            end
            
            // Send invalid stop bit (low instead of high)
            rx = 0;
            repeat (BIT_PERIOD) @(posedge clk);
            
            // Restore line to idle state
            rx = 1;
            repeat (BIT_PERIOD/2) @(posedge clk);
        end
    endtask
    
    // Monitor for received data
    always @(posedge clk) begin
        if (data_valid) begin
            $display("Time %0t: Received data: 0x%h (ASCII '%c')", $time, data, data);
        end
    end
    
    // For Vivado simulation
    initial begin
        // Use $vcdpluson for Vivado, equivalent to $dumpvars
        $vcdpluson;
    end
    
    // Test sequence
    initial begin
        // Initialize
        rx = 1;      // Idle state is high
        rst = 1;     // Start with reset
        test_data = 8'h00;
        
        // Reset sequence
        #100;
        rst = 0;
        #100;
        
        // Test Case 1-8: Send numbers '0' through '7'
        for (integer i = 0; i <= 7; i = i + 1) begin
            test_data = 8'h30 + i;  // ASCII '0' starts at 0x30
            $display("\nTest Case %0d: Sending character '%c' (0x%h)", i+1, test_data, test_data);
            send_byte(test_data);
            #(BIT_PERIOD * 2);
        end
        
        // Test Case 9: Send byte with framing error
        $display("\nTest Case 9: Sending '3' with framing error");
        test_data = 8'h33;  // ASCII '3'
        send_byte_with_framing_error(test_data);
        #(BIT_PERIOD * 2);
        
        // Test Case 10: Send another valid byte to verify recovery
        $display("\nTest Case 10: Sending '5' to verify recovery");
        test_data = 8'h35;  // ASCII '5'
        send_byte(test_data);
        #(BIT_PERIOD * 2);
        
        // End simulation
        $display("\nSimulation complete");
        #1000;
        $finish;
    end
    
endmodule