module uart_rx #(
    parameter CLK_FREQ  = 100_000_000,  // 100 MHz FPGA clock
    parameter BAUD_RATE = 115200
) (
    input  wire       clk,        // FPGA clock
    input  wire       rst,        // Reset signal
    input  wire       rx,         // UART receive line
    output reg  [7:0] data,       // Received data
    output reg        data_valid  // High when new data is received
);
    // States
    localparam IDLE     = 2'd0;
    localparam START    = 2'd1;    
    localparam DATA     = 2'd2;   
    localparam STOP     = 2'd3;    
    // Calculate baud rate divider
    localparam BAUD_TICK = CLK_FREQ / BAUD_RATE;
    
    // Registers
    reg [15:0] counter;
    reg [ 1:0] state;
    reg [ 2:0] bit_index; 
    reg [ 7:0] shift_reg;
    
    // [CHANGE] Added input synchronization to prevent metastability
    reg rx_sync1, rx_sync2;
    wire rx_in;
    
    always @(posedge clk) begin
        rx_sync1 <= rx;
        rx_sync2 <= rx_sync1;
    end
    
    assign rx_in = rx_sync2;  // [CHANGE] Use synchronized rx input
    // Main state machine
    always @(posedge clk) begin  // [CHANGE] Removed sensitivity to posedge rst for consistency
        if (rst) begin
            counter <= 0;
            state <= IDLE;
            bit_index <= 0; 
            shift_reg <= 0;
            data <= 0;
            data_valid <= 0;
        end else begin
            // Default state for data_valid (auto-clear after one cycle)
            data_valid <= 0;  // [CHANGE] Moved outside case statement for clarity
            
            case (state)
                IDLE: begin
                    if (rx_in == 0) begin  // Using synchronized rx_in
                        counter <= 0;
                        state <= START;    //  Go to START state instead of DATA
                    end
                end
                
                START: begin
                    // Sample in the middle of the start bit to confirm
                    if (counter < BAUD_TICK/2 - 1) begin
                        counter <= counter + 1;
                    end else begin
                        counter <= 0;
                        // Verify start bit is still low
                        if (rx_in == 0) begin
                            state <= DATA;
                            bit_index <= 0;
                        end else begin
                            // False start bit, return to IDLE
                            state <= IDLE;
                        end
                    end
                end
                
                DATA: begin
                    if (counter < BAUD_TICK - 1) begin
                        counter <= counter + 1;
                    end else begin
                        counter <= 0;
                        shift_reg[bit_index] <= rx_in;  // LSB first
                        
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            state <= STOP;
                        end
                    end
                end
                
                STOP: begin
                    if (counter < BAUD_TICK - 1) begin
                        counter <= counter + 1;
                    end else begin
                        counter <= 0;
                        // Check for valid stop bit
                        if (rx_in == 1) begin
                            data <= shift_reg;  // Update output data
                            data_valid <= 1;    // Set data_valid directly here
                        end
                        // Always return to IDLE after stop bit
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule