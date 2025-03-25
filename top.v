module top (
    input wire clk,
    input wire rx,
    output reg [7:0] leds
);
    wire [7:0] received_data;
    wire data_valid;

    // Parameters
    parameter CLK_FREQ = 50_000_000;  // 50 MHz
    parameter FLASH_PERIOD = 2;       // Flash period in seconds
    parameter FLASH_CYCLES = CLK_FREQ * FLASH_PERIOD; // Number of cycles for 2 seconds

    // State machine states
    typedef enum reg [1:0] {
        IDLE,
        FLASH_ON,
        FLASH_OFF
    } state_t;

    state_t current_state = IDLE;
    reg [26:0] flash_counter = 0; // 27-bit counter to count up to 100,000,000
    reg [2:0] flash_count = 0;    // Counter for number of flashes

    // UART receiver instance
    uart_rx uart (
        .clk(clk),
        .rst(0),
        .rx(rx),
        .data(received_data),
        .data_valid(data_valid)
    );

    // Main LED control logic
    always @(posedge clk) begin
        case (current_state)
            IDLE: begin
                if (data_valid) begin
                    if ((received_data >= "0" && received_data <= "7")) begin
                        // Directly light up corresponding LED
                        leds <= 1 << (received_data - "0");
                    end else begin
                        // Start flashing sequence for non-numeric or '8'/'9'
                        current_state <= FLASH_ON;
                        flash_counter <= 0;
                        flash_count <= 0;
                        leds <= 8'b1111_1111; // Turn on all LEDs
                    end
                end
            end

            FLASH_ON: begin
                if (flash_counter < FLASH_CYCLES) begin
                    flash_counter <= flash_counter + 1;
                end else begin
                    flash_counter <= 0;
                    leds <= 8'b0000_0000; // Turn off all LEDs
                    current_state <= FLASH_OFF;
                end
            end

            FLASH_OFF: begin
                if (flash_counter < FLASH_CYCLES) begin
                    flash_counter <= flash_counter + 1;
                end else begin
                    flash_counter <= 0;
                    flash_count <= flash_count + 1;
                    if (flash_count < 3) begin
                        leds <= 8'b1111_1111; // Turn on all LEDs
                        current_state <= FLASH_ON;
                    end else begin
                        current_state <= IDLE; // End flashing sequence
                    end
                end
            end
        endcase
    end
endmodule