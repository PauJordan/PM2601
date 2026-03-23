// tinytapeout wrapper for ultrasonic distance sensor
//
// pin mapping:
//   ui_in[0]   -> enable       (enable measurement)
//   ui_in[1]   -> echo         (ultrasonic echo input)
//   ui_in[2]   -> start_stop   (debounced toggle button)
//   ui_in[3]   -> sw_aux       (bcd/hex display mode select)
//   ui_in[7:4] -> unused
//
//   uo_out[7:0] -> sseg[7:0]   (7-segment display byte, active-low)
//
//   uio_out[3:0] -> xif[3:0]   (digit select, one-hot active-low)
//   uio_out[4]   -> trig       (ultrasonic trigger pulse output)
//   uio_in[5]    <- spi_csn   (spi chip select, active-low, from master)
//   uio_in[6]    <- spi_sclk  (spi clock from master)
//   uio_out[7]   -> spi_miso  (spi data out, tristated when csn high)
//   uio_oe[7]    -> spi_miso_en (1 when csn low)
//   uio_oe[6:5]  -> 0 (inputs)
//   uio_oe[4:0]  -> 1 (outputs: trig + xif[3:0])

`default_nettype none

module tt_um_pm2601 (
    input  wire [7:0] ui_in,    // dedicated inputs
    output wire [7:0] uo_out,   // dedicated outputs
    input  wire [7:0] uio_in,   // bidirectional: input path (unused)
    output wire [7:0] uio_out,  // bidirectional: output path
    output wire [7:0] uio_oe,   // bidirectional: output enable (1=output)
    input  wire       ena,      // design enable (unused, always on)
    input  wire       clk,      // clock (10 mhz)
    input  wire       rst_n     // active-low reset
);

    // internal wires from the core
    wire        trig_w;
    wire        echo_copia_w;
    wire [3:0]  xif_w;
    wire [3:0]  xif_copia_w;
    wire [7:0]  sseg_w;
    wire [10:0] distancia_w;
    wire        spi_sclk_w;
    wire        spi_miso_w;
    wire        spi_miso_en_w;
    wire        spi_csn_w;

    // instantiate the converted core
    top core (
        .clk        (clk),
        .rst        (~rst_n),       // tt reset is active-low; core expects active-high
        .enable     (ui_in[0]),
        .echo       (ui_in[1]),
        .start_stop (ui_in[2]),
        .sw_aux     (ui_in[3]),
        .trig       (trig_w),
        .echo_copia (echo_copia_w),
        .xif        (xif_w),
        .xif_copia  (xif_copia_w),
        .sseg       (sseg_w),
        .distancia  (distancia_w),
        .spi_sclk   (spi_sclk_w),
        .spi_miso   (spi_miso_w),
        .spi_miso_en (spi_miso_en_w),
        .spi_csn    (spi_csn_w)
    );

    // output assignments
    assign uo_out  = sseg_w;
    assign spi_csn_w = uio_in[5];
    assign spi_sclk_w = uio_in[6];
    assign uio_out = {spi_miso_w, 2'b0, trig_w, xif_w};
    assign uio_oe  = {spi_miso_en_w, 2'b00, 5'b11111};

    // suppress unused signal warnings
    wire _unused = &{ena, xif_copia_w, distancia_w[10], echo_copia_w, 1'b0};

endmodule
