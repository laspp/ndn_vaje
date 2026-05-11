




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



