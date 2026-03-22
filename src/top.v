

module top(
input wire CLK,
input wire RST,
input wire ENABLE,
input wire ECHO,
input wire START_STOP,
input wire SW_aux,
output wire TRIG,
output wire ECHO_COPIA,
output wire [3:0] XIF,
output wire [3:0] XIF_COPIA,
output wire [7:0] SSEG,
output wire [10:0] DISTANCIA,
output wire SPI_SCLK,
output wire SPI_MOSI
);




//Components
// Senyals
wire CLK_petit; wire trig_s; wire enable_s; wire refresh_s; wire polsador_s; wire c_rst; wire c_e;
wire [11:0] hex_num;
wire [11:0] bcd_num;
wire [1:0] error_s;
wire [15:0] disp_s;  // signal test_num : std_logic_vector(15 downto 0);

  // test_num (11 downto 0) <= bcd_num;
  // test_num (15 downto 12) <= "0000";
  // passtrough
  assign ECHO_COPIA = ECHO;
  assign TRIG = trig_s;
  assign DISTANCIA = disp_s[10:0];
  // Mapeig blocs
  trigger_gen TRIGGER_GEN_1(
    //10MHz ok
    .RST(RST),
    .CLK(CLK),
    .ENABLE_TRIG(enable_s),
    .TRIG_OUT(trig_s));

  ENABLE_CTL ENABLE_CTL_1(
    //10MHz ok
    .CLK(CLK),
    .E_OUT(enable_s),
    .TRIG(trig_s),
    .ECHO(ECHO),
    .SW_E(ENABLE),
    .POLSADOR(START_STOP),
    .CLK_10k(CLK_petit),
    .RST(RST),
    .C_DST_RST(c_rst),
    .C_DST_E(c_e),
    .ERR(error_s),
    .REFRESH_D(refresh_s));

  c999 C999_1(
    .CLK(CLK),
    .RST(c_rst),
    .E(c_e),
    .bcdDIST(bcd_num),
    .hexDIST(hex_num));

  clk_10k clk_10k_1(
    .CLK(CLK),
    .RST(RST),
    .CLK_OUT(CLK_petit));

  display display_1(
    .SW(disp_s),
    .E(1'b0),
    .RST(RST),
    .CLK(CLK_petit),
    .SSEG(SSEG),
    .XIF(XIF),
    .XIFRA_TEST(XIF_COPIA),
    .ACTIU(enable_s),
    .ERR(error_s));

  display_ctrl display_ctrl_1(
    .CLK(CLK),
    .RST(RST),
    .SW_DX(SW_aux),
    .REFRESH(refresh_s),
    .bcdDIST(bcd_num),
    .hexDIST(hex_num),
    .DISP_OUT(disp_s));

  spi_out spi_out_1(
    .CLK(CLK),
    .RST(RST),
    .TRIGGER(refresh_s),
    .DATA(disp_s[10:0]),
    .SCLK(SPI_SCLK),
    .MOSI(SPI_MOSI));


endmodule
// COMPONENTS
// triger_gen

module TRIGGER_GEN(
input wire CLK,
input wire RST,
input wire ENABLE_TRIG,
output wire TRIG_OUT
);




reg TRIG_s;

  assign TRIG_OUT = TRIG_s;
  always @(posedge CLK) begin : P1
    reg [31:0] COUNT_UP = 0;
  //-Comptarem els flancs de CLK de 10MHz que tindrem TRIG='1'
    reg [31:0] COUNT_T = 0;
  //-Comptarem els flancs de CLK de 10MHz per controlar el període total del trigger

    if((RST == 1'b1)) begin
      TRIG_s <= 1'b0;
      COUNT_UP = 0;
      COUNT_T = 249899;
    end
    else if((ENABLE_TRIG == 1'b1)) begin
      if((TRIG_s == 1'b0)) begin
        COUNT_T = COUNT_T + 1;
        if((COUNT_T >= 249900)) begin
          COUNT_T = 0;
          TRIG_s <= 1'b1;
        end
      end
      else begin
        COUNT_UP = COUNT_UP + 1;
        if((COUNT_UP >= 100)) begin
          COUNT_UP = 0;
          TRIG_s <= 1'b0;
        end
      end
    end
  end


endmodule
// /triger gen
// enable_ctl

module ENABLE_CTL(
input wire CLK,
input wire CLK_10k,
input wire RST,
input wire SW_E,
input wire TRIG,
input wire ECHO,
input wire POLSADOR,
output wire E_OUT,
output reg C_DST_RST,
output reg C_DST_E,
output wire REFRESH_D,
output reg [1:0] ERR,
output reg [3:0] ESTAT
);

//-RST
//-ENABLE
//-TRIG_s
//-ECHO
//-START_STOP
//-ENABLE_S
//-C_RST
//-C_E
//-REFRESH_S



parameter [2:0]
  S0 = 0,
  S1 = 1,
  S2 = 2,
  S3 = 3,
  S4 = 4,
  S5 = 5;

reg [2:0] STATE;
reg [3:0] CT_OOR;
reg OOR_FLANK;
reg CT_ERR_ENABLE;
reg CT_ERR_RST;
reg REFRESH_D_S;
reg a; reg b; reg echo_petit;
wire e_out_s; wire on_out_s;

  assign E_OUT = e_out_s;
  assign REFRESH_D = REFRESH_D_S;
  assign e_out_s = on_out_s & SW_E;
  on_off onoff(
    .POLSADOR(POLSADOR),
    .on_out(on_out_s),
    .RST(RST),
    .CLK(CLK));

  always @(posedge CLK_10k, posedge CT_ERR_RST) begin
    if((CT_ERR_RST == 1'b1)) begin
      OOR_FLANK <= 1'b0;
      CT_OOR <= 4'b0000;
    end else begin
      if((CT_ERR_ENABLE == 1'b1)) begin
        if((CT_OOR == 4'b1111)) begin
          CT_OOR <= 4'b0000;
          OOR_FLANK <= 1'b1;
          //-Out of range
        end
        else begin
          CT_OOR <= CT_OOR + 1;
        end
      end
    end
  end

  always @(posedge CLK) begin
    echo_petit <= b;
    b <= a;
    a <= ECHO;
  end

  always @(posedge CLK) begin
    if((RST == 1'b1)) begin
      STATE <= S0;
      C_DST_RST <= 1'b1;
      CT_ERR_RST <= 1'b1;
      ERR <= 2'b00;
    end else if((e_out_s == 1'b1)) begin
      case(STATE)
      S0 : begin
        ESTAT <= 4'h0;
        C_DST_E <= 1'b0;
        C_DST_RST <= 1'b0;
        CT_ERR_RST <= 1'b0;
        CT_ERR_ENABLE <= 1'b0;
        REFRESH_D_S <= 1'b0;
        if((TRIG == 1'b1 && e_out_s == 1'b1)) begin
          STATE <= S1;
        end
      end
      S1 : begin
        ESTAT <= 4'h1;
        CT_ERR_RST <= 1'b1;
        if((TRIG == 1'b0)) begin
          STATE <= S2;
        end
      end
      S2 : begin
        ESTAT <= 4'h2;
        CT_ERR_ENABLE <= 1'b1;
        C_DST_RST <= 1'b1;
        CT_ERR_RST <= 1'b0;
        if((echo_petit == 1'b1)) begin
          STATE <= S3;
        end
        if((OOR_FLANK == 1'b1)) begin
          STATE <= S4;
        end
      end
      S3 : begin
        ESTAT <= 4'h3;
        C_DST_RST <= 1'b0;
        C_DST_E <= 1'b1;
        CT_ERR_ENABLE <= 1'b0;
        if((TRIG == 1'b1)) begin
          STATE <= S5;
        end
        if((echo_petit == 1'b0)) begin
          STATE <= S0;
          REFRESH_D_S <= 1'b1;
          ERR <= 2'b00;
        end
      end
      S4 : begin
        ESTAT <= 4'h4;
        ERR <= 2'b01;
        STATE <= S0;
      end
      S5 : begin
        ESTAT <= 4'h5;
        ERR <= 2'b10;
        if((echo_petit == 1'b0)) begin
          STATE <= S0;
        end
      end
      default : begin
        STATE <= S0;
      end
      endcase
    end
  end


endmodule
//- component on_off

module on_off(
input wire CLK,
input wire RST,
input wire POLSADOR,
output wire ON_out
);




parameter [1:0]
  np = 0,
  p0 = 1,
  p1 = 2;

reg [1:0] estat;
reg on_out_s;

  assign ON_out = on_out_s;
  always @(posedge CLK) begin
    if((RST == 1'b1)) begin
      estat <= np;
      on_out_s <= 1'b0;
    end else
    case(estat)
    np : begin
      if((POLSADOR == 1'b1)) begin
        estat <= p0;
        on_out_s <=  ~(on_out_s);
      end
    end
    p0 : begin
      estat <= p1;
    end
    p1 : begin
      if((POLSADOR == 1'b0)) begin
        estat <= np;
      end
    end
    default : begin
      estat <= np;
    end
    endcase
  end


endmodule
// /on_off
// /enable_ctl
// c999
// Definicio entitats

module c999(
input wire E,
input wire CLK,
input wire RST,
output wire [11:0] bcdDIST,
output wire [11:0] hexDIST
);




reg [12:0] s;
reg [3:0] u; reg [3:0] d; reg [3:0] c;
reg [11:0] hex;

  assign hexDIST = hex;
  assign bcdDIST[3:0] = u;
  assign bcdDIST[7:4] = d;
  assign bcdDIST[11:8] = c;
  always @(posedge CLK) begin
    if((RST == 1'b1)) begin
      s <= 13'b0000000000000;
      hex <= 12'h000;
      u <= 4'h0;
      d <= 4'h0;
      c <= 4'h0;
    end
    else if((E == 1'b1)) begin
      if((s >= 579)) begin
        s <= 13'b0000000000000;
        hex <= hex + 1;
        u <= u + 1;
        if((u >= 9)) begin
          d <= d + 1;
          u <= 4'h0;
          if((d >= 9)) begin
            c <= c + 1;
            d <= 4'h0;
          end
        end
      end
      else begin
        s <= s + 1;
      end
    end
  end


endmodule
// /c999
// clk_10k
// Definicio entitats

module clk_10k(
input wire CLK,
input wire RST,
output wire CLK_OUT
);




reg [12:0] S;
reg CLK_out_s;

  assign CLK_OUT = CLK_out_s;
  always @(posedge CLK) begin
    if((RST == 1'b1)) begin
      S <= 13'b0000000000000;
      CLK_out_s <= 1'b0;
    end
    else if((S == 499)) begin
      S <= 13'b0000000000000;
      CLK_out_s <=  ~(CLK_out_s);
    end
    else begin
      S <= S + 1;
    end
  end


endmodule
// /clk_10k
// display_ctrl

module display_ctrl(
input wire CLK,
input wire RST,
input wire SW_DX,
input wire REFRESH,
input wire [11:0] bcdDIST,
input wire [11:0] hexDIST,
output reg [15:0] DISP_OUT
);




reg [11:0] lastBCD; reg [11:0] lastHEX;

  always @(posedge CLK) begin
    if((REFRESH == 1'b1)) begin
      lastBCD <= bcdDIST;
      lastHEX <= hexDIST;
    end
  end

  always @(*) begin
    DISP_OUT[15:12] = 4'b0000;
    case(SW_DX)
      1'b1 : DISP_OUT[11:0] = lastHEX;
      default : DISP_OUT[11:0] = lastBCD;
    endcase
  end

endmodule
// /display_ctrl
// display

module display(
input wire CLK,
input wire RST,
input wire E,
input wire ACTIU,
input wire [1:0] ERR,
input wire [15:0] SW,
output wire [3:0] XIF,
output wire [3:0] XIFRA_TEST,
output wire [7:0] SSEG,
output wire CLK_TEST,
output wire PRESC_TEST,
output wire [1:0] SSEG_TEST
);




// delcaracio blocs:
// Senyals interconectadores de blocs
wire [3:0] xif_act_bcd; wire [3:0] xif_sel; wire [3:0] B4_c10_out;
wire [7:0] xif_act_seg;
wire [1:0] xif_act_num; wire [1:0] aux_s;
wire enable; wire B5_d9_out; wire B6_c4_enable;

  assign CLK_TEST = CLK;
  // clock pass-trough
  assign PRESC_TEST = B6_c4_enable;
  assign SSEG = xif_act_seg;
  assign SSEG_TEST = xif_act_seg[7:6];
  assign XIF = xif_sel;
  assign XIFRA_TEST = xif_sel;
  assign enable =  ~(E);
  assign B6_c4_enable = enable & B5_d9_out;
  // connexionat blocs
  m16x4 B1(
    .actiu(ACTIU),
    .err(ERR),
    .dAux(aux_s),
    .dIn(SW),
    .dControl(xif_act_num),
    .dOut(xif_act_bcd));

  bcdto7seg B2(
    .DATA_IN(xif_act_bcd),
    .SSEG(xif_act_seg),
    .AUX_IN(aux_s));

  d2x4 B3(
    .dIn(xif_act_num),
    .dOut(xif_sel));

  c10 B4(
    .CLK(CLK),
    .E(enable),
    .RST(RST),
    .DOUT(B4_c10_out));

  d9 B5(
    .dIn(B4_c10_out),
    .dOut(B5_d9_out));

  c4 B6(
    .CLK(CLK),
    .E(B6_c4_enable),
    .RST(RST),
    .DOUT(xif_act_num));


endmodule
//COMPONENTS------------------------------
//m4x4to4
// mux 4x4 to 4

module m16x4(
input wire actiu,
input wire [15:0] dIn,
input wire [1:0] dControl,
input wire [1:0] err,
output reg [3:0] dOut,
output reg [1:0] dAux
);




wire [23:0] data;

  always @(*) begin
    case(dControl)
      2'b00 : dOut <= data[3:0];
      2'b01 : dOut <= data[7:4];
      2'b10 : dOut <= data[11:8];
      2'b11 : dOut <= data[15:12];
      default : dOut <= 4'b0000;
    endcase
  end

  always @(*) begin
    case(dControl)
      2'b00 : dAux <= data[17:16];
      2'b01 : dAux <= data[19:18];
      2'b10 : dAux <= data[21:20];
      2'b11 : dAux <= data[23:22];
      default : dAux <= 2'b00;
    endcase
  end

  // normal Axxx, -xxx
  // err X Eo, X Es
  assign data[15:12] = (actiu == 1'b1) ? 4'b1010 : dIn[15:12];
  //Xifra 3 A quan actiu, din
  assign data[11:0] = (err == 2) ? 12'h0E0 : (err == 1) ? 12'h0E5 : (err == 0) ? dIn[11:0] : 12'h0E0;
  //Xifra 2 sempre dIn, Xifra 1, e quan err, XIfra 0 5 quan err 1 sino normal
  assign data[23:22] = (actiu == 1'b0) ? 2'b01 : 2'b00;
  //Xifra 3 aux - quan inactiu, desactivat
  assign data[21:20] = (err == 0) ? 2'b00 : 2'b11;
  // Xifra 2 aux blanc quan err, blanc
  assign data[19:18] = 2'b00;
  // Xifra 1 aux sempre desactivat
  assign data[17:16] = (err == 2) ? 2'b10 : (err == 3) ? 2'b11 : 2'b00;
    //Xifra 0 aux o quan err 2

endmodule
// /m4x4to4
// bcto7seg
// Definicio entitats
// decoder bcd a 7 segments

module bcdto7seg(
input wire [3:0] DATA_IN,
input wire [1:0] AUX_IN,
output wire [7:0] SSEG
);




reg [7:0] S;

  always @(*) begin
    case(DATA_IN)
      4'd0:  S = 8'b01111110;
      4'd1:  S = 8'b00110000;
      4'd2:  S = 8'b01101101;
      4'd3:  S = 8'b01111001;
      4'd4:  S = 8'b00110011;
      4'd5:  S = 8'b01011011;
      4'd6:  S = 8'b01011111;
      4'd7:  S = 8'b01110000;
      4'd8:  S = 8'b01111111;
      4'd9:  S = 8'b01111011;
      4'd10: S = 8'b01110111;
      4'd11: S = 8'b00011111;
      4'd12: S = 8'b01001110;
      4'd13: S = 8'b00111101;
      4'd14: S = 8'b01001111;
      4'd15: S = 8'b01000111;
      default: S = 8'b00000000;
    endcase
  end
  assign SSEG = AUX_IN == 0 ?  ~(S) : (AUX_IN == 1) ? 8'b11111101 : (AUX_IN == 2) ? 8'b11000101 : 8'b11111111;

endmodule
// /bcdto7seg
// d2x4
// decoder 2x4

module d2x4(
input wire [1:0] dIn,
output wire [3:0] dOut
);





  assign dOut = (dIn == 2'b00) ? 4'b1110 : (dIn == 2'b01) ? 4'b1101 : (dIn == 2'b10) ? 4'b1011 : (dIn == 2'b11) ? 4'b0111 : 4'b1111;

endmodule
///d2x4
// c10
// Definicio entitats

module c10(
input wire E,
input wire CLK,
input wire RST,
output wire [3:0] DOUT
);




reg [3:0] S;

  always @(posedge CLK, posedge RST) begin
    if((RST == 1'b1)) begin
      S <= 4'b0000;
    end else begin
      if((E == 1'b1)) begin
        if((S == 4'b1001)) begin
          S <= 4'b0000;
        end
        else begin
          S <= S + 1;
        end
      end
    end
  end

  assign DOUT = S;

endmodule
// /c10
// c4
// Definicio entitats

module c4(
input wire E,
input wire RST,
input wire CLK,
output wire [1:0] DOUT
);




reg [1:0] S;

  always @(posedge CLK, posedge RST) begin
    if((RST == 1'b1)) begin
      S <= 2'b00;
    end else begin
      if((E == 1'b1)) begin
        S <= S + 1;
      end
    end
  end

  assign DOUT = S;

endmodule
// /c4
// d9
// decoder 9

module d9(
input wire [3:0] dIn,
output wire dOut
);





  assign dOut = (dIn == 4'b1001) ? 1'b1 : 1'b0;

endmodule
// /d9
///display

// spi_out
// Serialises an 11-bit distance value over SPI (mode 0, MSB first) whenever
// TRIGGER pulses. Data is padded to 16 bits (5 leading zeros).
// SPI clock = 10 MHz / 8 = 1.25 MHz.

module spi_out(
input  wire        CLK,
input  wire        RST,
input  wire        TRIGGER,
input  wire [10:0] DATA,
output reg         SCLK,
output wire        MOSI
);

reg [2:0]  div;
reg [15:0] shreg;
reg [4:0]  cnt;     // counts SCLK edges: 32 edges = 16 bits
reg        busy;

assign MOSI = shreg[15];

always @(posedge CLK) begin
  if (RST) begin
    div   <= 3'd0;
    SCLK  <= 1'b0;
    shreg <= 16'd0;
    cnt   <= 5'd0;
    busy  <= 1'b0;
  end else if (!busy) begin
    SCLK <= 1'b0;
    if (TRIGGER) begin
      shreg <= {5'b00000, DATA};
      div   <= 3'd0;
      cnt   <= 5'd0;
      busy  <= 1'b1;
    end
  end else begin
    if (div == 3'd3) begin
      div  <= 3'd0;
      SCLK <= ~SCLK;
      cnt  <= cnt + 1'd1;
      if (SCLK) begin
        // falling edge: shift next bit onto MOSI
        shreg <= {shreg[14:0], 1'b0};
      end
      if (cnt == 5'd31) begin
        busy <= 1'b0;
      end
    end else begin
      div <= div + 1'd1;
    end
  end
end

endmodule
// /spi_out
