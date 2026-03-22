// TinyTapeout wrapper for ultrasonic distance sensor
//
// Pin mapping:
//   ui_in[0]   -> ENABLE       (enable measurement)
//   ui_in[1]   -> ECHO         (ultrasonic echo input)
//   ui_in[2]   -> START_STOP   (debounced toggle button)
//   ui_in[3]   -> SW_aux       (BCD/HEX display mode select)
//   ui_in[7:4] -> unused
//
//   uo_out[7:0] -> SSEG[7:0]   (7-segment display byte, active-low)
//
//   uio_out[3:0] -> XIF[3:0]   (digit select, one-hot active-low)
//   uio_out[4]   -> TRIG       (ultrasonic trigger pulse output)
//   uio_out[5]   -> ECHO_COPIA (echo passthrough for debug)
//   uio_out[6]   -> SPI_SCLK  (SPI clock, 1.25 MHz)
//   uio_out[7]   -> SPI_MOSI  (SPI data, MSB first, 16-bit frame: 5'b0 + DISTANCIA[10:0])
//   uio_oe[7:0]  -> 8'hFF     (all bidir pins configured as outputs)

`default_nettype none

module tt_um_ultrasonic_sensor (
    input  wire [7:0] ui_in,    // dedicated inputs
    output wire [7:0] uo_out,   // dedicated outputs
    input  wire [7:0] uio_in,   // bidirectional: input path (unused)
    output wire [7:0] uio_out,  // bidirectional: output path
    output wire [7:0] uio_oe,   // bidirectional: output enable (1=output)
    input  wire       ena,      // design enable (unused, always on)
    input  wire       clk,      // clock (10 MHz)
    input  wire       rst_n     // active-low reset
);

    // Internal wires from the core
    wire        trig_w;
    wire        echo_copia_w;
    wire [3:0]  xif_w;
    wire [3:0]  xif_copia_w;
    wire [7:0]  sseg_w;
    wire [10:0] distancia_w;
    wire        spi_sclk_w;
    wire        spi_mosi_w;

    // Instantiate the converted core
    top core (
        .CLK        (clk),
        .RST        (~rst_n),       // TT reset is active-low; core expects active-high
        .ENABLE     (ui_in[0]),
        .ECHO       (ui_in[1]),
        .START_STOP (ui_in[2]),
        .SW_aux     (ui_in[3]),
        .TRIG       (trig_w),
        .ECHO_COPIA (echo_copia_w),
        .XIF        (xif_w),
        .XIF_COPIA  (xif_copia_w),
        .SSEG       (sseg_w),
        .DISTANCIA  (distancia_w),
        .SPI_SCLK   (spi_sclk_w),
        .SPI_MOSI   (spi_mosi_w)
    );

    // Output assignments
    assign uo_out  = sseg_w;

    assign uio_out = {spi_mosi_w, spi_sclk_w, echo_copia_w, trig_w, xif_w};
    assign uio_oe  = 8'hFF;

    // Suppress unused signal warnings
    wire _unused = &{ena, uio_in, xif_copia_w, distancia_w[10], 1'b0};

endmodule
