
`define CONFIG_REG 7'h00
`define DIGIT0_REG 7'h04
`define DIGIT1_REG 7'h08
`define DIGIT2_REG 7'h0C
`define DIGIT3_REG 7'h10
`define DIGIT4_REG 7'h14
`define DIGIT5_REG 7'h18
`define DIGIT6_REG 7'h1C
`define DIGIT7_REG 7'h20



module OBI_7seg #(
    parameter OBI_ADDR_WIDTH = 32,
    parameter OBI_DATA_WIDTH = 32

) (
    // 7 seg interface


    // OBI SLAVE INTERFACE
    //***************************************
    input logic obi_clk_i,
    input logic obi_rstn_i,

    // ADDRESS CHANNEL
    input logic                         obi_req_i,
    output  logic                       obi_gnt_o,
    input logic [OBI_ADDR_WIDTH-1:0]    obi_addr_i,
    input logic                         obi_we_i,
    input logic [OBI_DATA_WIDTH-1:0]    obi_wdata_i,
    input logic [               3:0]    obi_be_i,

    // RESPONSE CHANNEL
    input logic      obi_rready_i,
    output logic    obi_rvalid_o,
    output logic    [OBI_DATA_WIDTH-1:0] obi_rdata_o,
    output logic                       obi_err_o
);


endmodule



module SevSegDisplay (
    input logic clock,
    input logic reset,
    input logic enable_7seg,
    input logic [3:0] digit1,
    input logic [3:0] digit2,
    input logic [3:0] digit3,
    input logic [3:0] digit4,
    input logic [3:0] digit5,
    input logic [3:0] digit6,
    input logic [3:0] digit7,
    input logic [3:0] digit8,
    output logic [7:0] anode_select,
    output logic [6:0] segs
);

    // prescaler for anode
    localparam PRESCALER_ANODE_WIDTH = 16;
    localparam PRESCALER_ANODE_LIMIT = 40000; // achieve   delay
    logic anode_clock_enable;


    // define the prescaler module for anode as GP_counter
    GP_counter #(
        .PRESCALER_WIDTH(PRESCALER_ANODE_WIDTH),
        .LIMIT(PRESCALER_ANODE_LIMIT)
    ) anode_prescaler (
        .clock(clock),
        .reset(reset),
        .start(enable_7seg),
        .sample_tick(anode_clock_enable)
    );

    // define the anode_assert module
    anode_assert anode_assert_inst (
        .clock(clock),
        .reset(reset),
        .clock_enable(anode_clock_enable),
        .enable_7seg(enable_7seg),
        .anode_select(anode_select)
    );

    // define the value_to_digit module
    logic [31:0] digit_all;
    assign digit_all = {digit8, digit7, digit6, digit5, digit4, digit3, digit2, digit1};
    logic [3:0] digit_select;

    value_to_digit value_to_digit_inst (
        .value(digit_all),
        .anode_select(anode_select),
        .digit(digit_select)
    );

    digit_to_segments digit_to_segments_inst (
        .digit(digit_select),
        .segs(segs)
    );
    
    
endmodule




 module GP_counter // General Purpose counter        
    #(parameter PRESCALER_WIDTH = 14,
      parameter LIMIT = 10000)
    (
        input logic clock,
        input logic reset,
        input start,
        output logic sample_tick
    );

    logic [PRESCALER_WIDTH-1:0] count;

    always_ff @( posedge clock) begin 
        if (reset) begin
            count <= 0;
            sample_tick <= 0;
        end
        else begin
            if (start) begin
                count <= count + 1;
                if (count == LIMIT-1) begin
                    count <= 0;
                    sample_tick <= 1;
                end
                else begin
                    sample_tick <= 0;
                end
            end 
        end
    end

    
endmodule



// Components for 7-segment display

module anode_assert (
    input logic clock,
    input logic reset,
    input logic clock_enable,
    input logic enable_7seg,
    output logic [7:0] anode_select
    
);

    // counter that counts from 0 to 7
    logic [2:0] count;

    always_ff @(posedge clock) begin
        if (reset) begin
            count <= 0;
        end
        else begin
            if (clock_enable) begin
                count <= count + 1;
            end
        end
    end

    // assert anode_select
    assign anode_select = enable_7seg ? ~(1 << count) : ~0  ;
    
endmodule


module value_to_digit(
    input logic [31:0] value,
    input logic [7:0] anode_select,
    output logic [3:0] digit
);

    always_comb begin : value_to_digit
        case (~anode_select)
            8'H01: digit = value[3:0];
            8'H02: digit = value[7:4];
            8'H04: digit = value[11:8];
            8'H08: digit = value[15:12];
            8'H10: digit = value[19:16];
            8'H20: digit = value[23:20];
            8'H40: digit = value[27:24];
            8'H80: digit = value[31:28];
            default: digit = 4'b1111;
        endcase
    end

endmodule

// purely comb module 

module digit_to_segments (
    input logic [3:0] digit,
    output logic [6:0] segs
);
    
    always_comb begin : segDecoder
        case (digit)
            4'b0000: segs = 7'b1000000; // 0
            4'b0001: segs = 7'b1111001; // 1
            4'b0010: segs = 7'b0100100; // 2
            4'b0011: segs = 7'b0110000; // 3
            4'b0100: segs = 7'b0011001; // 4
            4'b0101: segs = 7'b0010010; // 5
            4'b0110: segs = 7'b0000010; // 6
            4'b0111: segs = 7'b1111000; // 7
            4'b1000: segs = 7'b0000000; // 8
            4'b1001: segs = 7'b0010000; // 9
            4'b1010: segs = 7'b0001000; // A
            4'b1011: segs = 7'b0000011; // b
            4'b1100: segs = 7'b1000110; // C
            4'b1101: segs = 7'b0100001; // d
            4'b1110: segs = 7'b0000110; // E
            4'b1111: segs = 7'b0001110; // F
            default: segs = 7'b1111111; // off
        endcase
    end

endmodule




