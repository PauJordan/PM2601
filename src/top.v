

module top(
input wire clk,
input wire rst,
input wire enable,
input wire echo,
input wire start_stop,
input wire sw_aux,
output wire trig,
output wire echo_copia,
output wire [3:0] xif,
output wire [3:0] xif_copia,
output wire [7:0] sseg,
output wire [10:0] distancia,
input wire spi_sclk,
input wire spi_csn,
output wire spi_miso,
output wire spi_miso_en
);




//components
// senyals
wire clk_petit; wire trig_s; wire enable_s; wire refresh_s; wire polsador_s; wire c_rst; wire c_e;
wire [11:0] hex_num;
wire [11:0] bcd_num;
wire [1:0] error_s;
wire [15:0] disp_s;  // signal test_num : std_logic_vector(15 downto 0);

  // test_num (11 downto 0) <= bcd_num;
  // test_num (15 downto 12) <= "0000";
  // passtrough
  assign echo_copia = echo;
  assign trig = trig_s;
  assign distancia = disp_s[10:0];
  // mapeig blocs
  trigger_gen trigger_gen_1(
    //10mhz ok
    .rst(rst),
    .clk(clk),
    .enable_trig(enable_s),
    .trig_out(trig_s));

  enable_ctl enable_ctl_1(
    //10mhz ok
    .clk(clk),
    .e_out(enable_s),
    .trig(trig_s),
    .echo(echo),
    .sw_e(enable),
    .polsador(start_stop),
    .clk_10k(clk_petit),
    .rst(rst),
    .c_dst_rst(c_rst),
    .c_dst_e(c_e),
    .err(error_s),
    .refresh_d(refresh_s));

  c999 c999_1(
    .clk(clk),
    .rst(c_rst),
    .e(c_e),
    .bcddist(bcd_num),
    .hexdist(hex_num));

  clk_10k clk_10k_1(
    .clk(clk),
    .rst(rst),
    .clk_out(clk_petit));

  display display_1(
    .sw(disp_s),
    .e(1'b0),
    .rst(rst),
    .clk(clk_petit),
    .sseg(sseg),
    .xif(xif),
    .xifra_test(xif_copia),
    .actiu(enable_s),
    .err(error_s));

  display_ctrl display_ctrl_1(
    .clk(clk),
    .rst(rst),
    .sw_dx(sw_aux),
    .refresh(refresh_s),
    .bcddist(bcd_num),
    .hexdist(hex_num),
    .disp_out(disp_s));

  spi_out spi_out_1(
    .clk(clk),
    .rst(rst),
    .trigger(refresh_s),
    .data(disp_s[10:0]),
    .sclk(spi_sclk),
    .miso(spi_miso),
    .miso_en(spi_miso_en),
    .csn(spi_csn));


endmodule
// components
// triger_gen

module trigger_gen(
input wire clk,
input wire rst,
input wire enable_trig,
output wire trig_out
);




reg trig_s;

  assign trig_out = trig_s;
  reg [31:0] count_up = 0;
  //-comptarem els flancs de clk de 10mhz que tindrem trig='1'
  reg [31:0] count_t = 0;
  always @(posedge clk) begin : p1

  //-comptarem els flancs de clk de 10mhz per controlar el període total del trigger

    if((rst == 1'b1)) begin
      trig_s <= 1'b0;
      count_up = 0;
      count_t = 249899;
    end
    else if((enable_trig == 1'b1)) begin
      if((trig_s == 1'b0)) begin
        count_t = count_t + 1;
        if((count_t >= 249900)) begin
          count_t = 0;
          trig_s <= 1'b1;
        end
      end
      else begin
        count_up = count_up + 1;
        if((count_up >= 100)) begin
          count_up = 0;
          trig_s <= 1'b0;
        end
      end
    end
  end


endmodule
// /triger gen
// enable_ctl

module enable_ctl(
input wire clk,
input wire clk_10k,
input wire rst,
input wire sw_e,
input wire trig,
input wire echo,
input wire polsador,
output wire e_out,
output reg c_dst_rst,
output reg c_dst_e,
output wire refresh_d,
output reg [1:0] err,
output reg [3:0] estat
);

//-rst
//-enable
//-trig_s
//-echo
//-start_stop
//-enable_s
//-c_rst
//-c_e
//-refresh_s



parameter [2:0]
  s0 = 0,
  s1 = 1,
  s2 = 2,
  s3 = 3,
  s4 = 4,
  s5 = 5;

reg [2:0] state;
reg [3:0] ct_oor;
reg oor_flank;
reg ct_err_enable;
reg ct_err_rst;
reg refresh_d_s;
reg a; reg b; reg echo_petit;
wire e_out_s; wire on_out_s;

  assign e_out = e_out_s;
  assign refresh_d = refresh_d_s;
  assign e_out_s = on_out_s & sw_e;
  on_off onoff(
    .polsador(polsador),
    .on_out(on_out_s),
    .rst(rst),
    .clk(clk));

  always @(posedge clk_10k, posedge ct_err_rst) begin
    if((ct_err_rst == 1'b1)) begin
      oor_flank <= 1'b0;
      ct_oor <= 4'b0000;
    end else begin
      if((ct_err_enable == 1'b1)) begin
        if((ct_oor == 4'b1111)) begin
          ct_oor <= 4'b0000;
          oor_flank <= 1'b1;
          //-out of range
        end
        else begin
          ct_oor <= ct_oor + 1;
        end
      end
    end
  end

  always @(posedge clk) begin
    echo_petit <= b;
    b <= a;
    a <= echo;
  end

  always @(posedge clk) begin
    if((rst == 1'b1)) begin
      state <= s0;
      c_dst_rst <= 1'b1;
      ct_err_rst <= 1'b1;
      err <= 2'b00;
    end else if((e_out_s == 1'b1)) begin
      case(state)
      s0 : begin
        estat <= 4'h0;
        c_dst_e <= 1'b0;
        c_dst_rst <= 1'b0;
        ct_err_rst <= 1'b0;
        ct_err_enable <= 1'b0;
        refresh_d_s <= 1'b0;
        if((trig == 1'b1 && e_out_s == 1'b1)) begin
          state <= s1;
        end
      end
      s1 : begin
        estat <= 4'h1;
        ct_err_rst <= 1'b1;
        if((trig == 1'b0)) begin
          state <= s2;
        end
      end
      s2 : begin
        estat <= 4'h2;
        ct_err_enable <= 1'b1;
        c_dst_rst <= 1'b1;
        ct_err_rst <= 1'b0;
        if((echo_petit == 1'b1)) begin
          state <= s3;
        end
        if((oor_flank == 1'b1)) begin
          state <= s4;
        end
      end
      s3 : begin
        estat <= 4'h3;
        c_dst_rst <= 1'b0;
        c_dst_e <= 1'b1;
        ct_err_enable <= 1'b0;
        if((trig == 1'b1)) begin
          state <= s5;
        end
        if((echo_petit == 1'b0)) begin
          state <= s0;
          refresh_d_s <= 1'b1;
          err <= 2'b00;
        end
      end
      s4 : begin
        estat <= 4'h4;
        err <= 2'b01;
        state <= s0;
      end
      s5 : begin
        estat <= 4'h5;
        err <= 2'b10;
        if((echo_petit == 1'b0)) begin
          state <= s0;
        end
      end
      default : begin
        state <= s0;
      end
      endcase
    end
  end


endmodule
//- component on_off

module on_off(
input wire clk,
input wire rst,
input wire polsador,
output wire on_out
);




parameter [1:0]
  np = 0,
  p0 = 1,
  p1 = 2;

reg [1:0] estat;
reg on_out_s;

  assign on_out = on_out_s;
  always @(posedge clk) begin
    if((rst == 1'b1)) begin
      estat <= np;
      on_out_s <= 1'b0;
    end else
    case(estat)
    np : begin
      if((polsador == 1'b1)) begin
        estat <= p0;
        on_out_s <=  ~(on_out_s);
      end
    end
    p0 : begin
      estat <= p1;
    end
    p1 : begin
      if((polsador == 1'b0)) begin
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
// definicio entitats

module c999(
input wire e,
input wire clk,
input wire rst,
output wire [11:0] bcddist,
output wire [11:0] hexdist
);




reg [12:0] s;
reg [3:0] u; reg [3:0] d; reg [3:0] c;
reg [11:0] hex;

  assign hexdist = hex;
  assign bcddist[3:0] = u;
  assign bcddist[7:4] = d;
  assign bcddist[11:8] = c;
  always @(posedge clk) begin
    if((rst == 1'b1)) begin
      s <= 13'b0000000000000;
      hex <= 12'h000;
      u <= 4'h0;
      d <= 4'h0;
      c <= 4'h0;
    end
    else if((e == 1'b1)) begin
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
// definicio entitats

module clk_10k(
input wire clk,
input wire rst,
output wire clk_out
);




reg [12:0] s;
reg clk_out_s;

  assign clk_out = clk_out_s;
  always @(posedge clk) begin
    if((rst == 1'b1)) begin
      s <= 13'b0000000000000;
      clk_out_s <= 1'b0;
    end
    else if((s == 499)) begin
      s <= 13'b0000000000000;
      clk_out_s <=  ~(clk_out_s);
    end
    else begin
      s <= s + 1;
    end
  end


endmodule
// /clk_10k
// display_ctrl

module display_ctrl(
input wire clk,
input wire rst,
input wire sw_dx,
input wire refresh,
input wire [11:0] bcddist,
input wire [11:0] hexdist,
output reg [15:0] disp_out
);




reg [11:0] lastbcd; reg [11:0] lasthex;

  always @(posedge clk) begin
    if((refresh == 1'b1)) begin
      lastbcd <= bcddist;
      lasthex <= hexdist;
    end
  end

  always @(*) begin
    disp_out[15:12] = 4'b0000;
    case(sw_dx)
      1'b1 : disp_out[11:0] = lasthex;
      default : disp_out[11:0] = lastbcd;
    endcase
  end

endmodule
// /display_ctrl
// display

module display(
input wire clk,
input wire rst,
input wire e,
input wire actiu,
input wire [1:0] err,
input wire [15:0] sw,
output wire [3:0] xif,
output wire [3:0] xifra_test,
output wire [7:0] sseg,
output wire clk_test,
output wire presc_test,
output wire [1:0] sseg_test
);




// delcaracio blocs:
// senyals interconectadores de blocs
wire [3:0] xif_act_bcd; wire [3:0] xif_sel; wire [3:0] b4_c10_out;
wire [7:0] xif_act_seg;
wire [1:0] xif_act_num; wire [1:0] aux_s;
wire enable; wire b5_d9_out; wire b6_c4_enable;

  assign clk_test = clk;
  // clock pass-trough
  assign presc_test = b6_c4_enable;
  assign sseg = xif_act_seg;
  assign sseg_test = xif_act_seg[7:6];
  assign xif = xif_sel;
  assign xifra_test = xif_sel;
  assign enable =  ~(e);
  assign b6_c4_enable = enable & b5_d9_out;
  // connexionat blocs
  m16x4 b1(
    .actiu(actiu),
    .err(err),
    .daux(aux_s),
    .din(sw),
    .dcontrol(xif_act_num),
    .dout(xif_act_bcd));

  bcdto7seg b2(
    .data_in(xif_act_bcd),
    .sseg(xif_act_seg),
    .aux_in(aux_s));

  d2x4 b3(
    .din(xif_act_num),
    .dout(xif_sel));

  c10 b4(
    .clk(clk),
    .e(enable),
    .rst(rst),
    .dout(b4_c10_out));

  d9 b5(
    .din(b4_c10_out),
    .dout(b5_d9_out));

  c4 b6(
    .clk(clk),
    .e(b6_c4_enable),
    .rst(rst),
    .dout(xif_act_num));


endmodule
//components------------------------------
//m4x4to4
// mux 4x4 to 4

module m16x4(
input wire actiu,
input wire [15:0] din,
input wire [1:0] dcontrol,
input wire [1:0] err,
output reg [3:0] dout,
output reg [1:0] daux
);




wire [23:0] data;

  always @(*) begin
    case(dcontrol)
      2'b00 : dout <= data[3:0];
      2'b01 : dout <= data[7:4];
      2'b10 : dout <= data[11:8];
      2'b11 : dout <= data[15:12];
      default : dout <= 4'b0000;
    endcase
  end

  always @(*) begin
    case(dcontrol)
      2'b00 : daux <= data[17:16];
      2'b01 : daux <= data[19:18];
      2'b10 : daux <= data[21:20];
      2'b11 : daux <= data[23:22];
      default : daux <= 2'b00;
    endcase
  end

  // normal axxx, -xxx
  // err x eo, x es
  assign data[15:12] = (actiu == 1'b1) ? 4'b1010 : din[15:12];
  //xifra 3 a quan actiu, din
  assign data[11:0] = (err == 2) ? 12'h0e0 : (err == 1) ? 12'h0e5 : (err == 0) ? din[11:0] : 12'h0e0;
  //xifra 2 sempre din, xifra 1, e quan err, xifra 0 5 quan err 1 sino normal
  assign data[23:22] = (actiu == 1'b0) ? 2'b01 : 2'b00;
  //xifra 3 aux - quan inactiu, desactivat
  assign data[21:20] = (err == 0) ? 2'b00 : 2'b11;
  // xifra 2 aux blanc quan err, blanc
  assign data[19:18] = 2'b00;
  // xifra 1 aux sempre desactivat
  assign data[17:16] = (err == 2) ? 2'b10 : (err == 3) ? 2'b11 : 2'b00;
    //xifra 0 aux o quan err 2

endmodule
// /m4x4to4
// bcto7seg
// definicio entitats
// decoder bcd a 7 segments

module bcdto7seg(
input wire [3:0] data_in,
input wire [1:0] aux_in,
output wire [7:0] sseg
);




reg [7:0] s;

  always @(*) begin
    case(data_in)
      4'd0:  s = 8'b01111110;
      4'd1:  s = 8'b00110000;
      4'd2:  s = 8'b01101101;
      4'd3:  s = 8'b01111001;
      4'd4:  s = 8'b00110011;
      4'd5:  s = 8'b01011011;
      4'd6:  s = 8'b01011111;
      4'd7:  s = 8'b01110000;
      4'd8:  s = 8'b01111111;
      4'd9:  s = 8'b01111011;
      4'd10: s = 8'b01110111;
      4'd11: s = 8'b00011111;
      4'd12: s = 8'b01001110;
      4'd13: s = 8'b00111101;
      4'd14: s = 8'b01001111;
      4'd15: s = 8'b01000111;
      default: s = 8'b00000000;
    endcase
  end
  assign sseg = aux_in == 0 ?  ~(s) : (aux_in == 1) ? 8'b11111101 : (aux_in == 2) ? 8'b11000101 : 8'b11111111;

endmodule
// /bcdto7seg
// d2x4
// decoder 2x4

module d2x4(
input wire [1:0] din,
output wire [3:0] dout
);





  assign dout = (din == 2'b00) ? 4'b1110 : (din == 2'b01) ? 4'b1101 : (din == 2'b10) ? 4'b1011 : (din == 2'b11) ? 4'b0111 : 4'b1111;

endmodule
///d2x4
// c10
// definicio entitats

module c10(
input wire e,
input wire clk,
input wire rst,
output wire [3:0] dout
);




reg [3:0] s;

  always @(posedge clk, posedge rst) begin
    if((rst == 1'b1)) begin
      s <= 4'b0000;
    end else begin
      if((e == 1'b1)) begin
        if((s == 4'b1001)) begin
          s <= 4'b0000;
        end
        else begin
          s <= s + 1;
        end
      end
    end
  end

  assign dout = s;

endmodule
// /c10
// c4
// definicio entitats

module c4(
input wire e,
input wire rst,
input wire clk,
output wire [1:0] dout
);




reg [1:0] s;

  always @(posedge clk, posedge rst) begin
    if((rst == 1'b1)) begin
      s <= 2'b00;
    end else begin
      if((e == 1'b1)) begin
        s <= s + 1;
      end
    end
  end

  assign dout = s;

endmodule
// /c4
// d9
// decoder 9

module d9(
input wire [3:0] din,
output wire dout
);





  assign dout = (din == 4'b1001) ? 1'b1 : 1'b0;

endmodule
// /d9
///display

// spi_out
// serialises an 11-bit distance value over spi (mode 0, msb first) whenever
// trigger pulses. data is padded to 16 bits (5 leading zeros).
// spi clock = 10 mhz / 8 = 1.25 mhz.

module spi_out(
input  wire        clk,
input  wire        rst,
input  wire        trigger,
input  wire [10:0] data,
input wire         sclk,
input wire         csn,
output wire        miso,
output wire        miso_en
);

reg [15:0] shreg;
reg last_sclk;

always @(posedge clk) begin
  if (rst) begin
    shreg <= 16'd0;

  end else if (csn) begin
    if (trigger) begin
      shreg <= {5'b00000, data};
    end
  end else if (sclk && ~last_sclk) begin
      shreg <= {shreg[14:0], 1'b0};
  end
  last_sclk <= sclk;
  
end
assign miso_en =  ~csn;
assign miso = shreg[15];

endmodule
// /spi_out
