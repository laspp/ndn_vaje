module top (
    // Clock and Reset
    input logic clock,
    input logic resetn, 
    // leds and switches
    output logic [15:0] leds,
    input logic [15:0] switches,
    // UART
    output logic tx
);



// Parameters
localparam AW = 32;
localparam DW = 32;
localparam NUM_PERIPHERALS = 64;
localparam NUM_REG_PERIPHERAL = 32;
// Derived Parameters
localparam CW = 1 + DW + AW;
localparam RW = 1 + DW;

// IO bus signals
logic [31:0] io_address;
logic io_addr_strobe;
logic [31:0] io_write_data;
logic io_write_strobe;
logic [3:0] io_byte_enable;
logic [31:0] io_read_data;
logic io_read_strobe;
logic io_ready;


logic reset;

assign reset = ~resetn;

microblaze_mcs_0 your_instance_name (
  .Clk(clock),                          // input wire Clk
  .Reset(reset),                      // input wire Reset
  .IO_addr_strobe(io_addr_strobe),    // output wire IO_addr_strobe
  .IO_address(io_address),            // output wire [31 : 0] IO_address
  .IO_byte_enable(io_byte_enable),    // output wire [3 : 0] IO_byte_enable
  .IO_read_data(io_read_data),        // input wire [31 : 0] IO_read_data
  .IO_read_strobe(io_read_strobe),    // output wire IO_read_strobe
  .IO_ready(io_ready),                // input wire IO_ready
  .IO_write_data(io_write_data),      // output wire [31 : 0] IO_write_data
  .IO_write_strobe(io_write_strobe)  // output wire IO_write_strobe
);


// OBI master-side signals between bridge and interconnect
logic                        master_obi_req;
logic                        master_obi_gnt;
logic [AW-1:0]               master_obi_addr;
logic                        master_obi_we;
logic [3:0]                  master_obi_be;
logic [DW-1:0]               master_obi_wdata;
logic                        master_obi_rvalid;
logic                        master_obi_rready;
logic [DW-1:0]               master_obi_rdata;
logic                        master_obi_err;


// Instantiate OBI bridge
OBI_Bridge #(
    .DW(DW),
    .AW(AW),
    .BRG_BASE(32'hC0000000)
) obi_bridge_inst (
    .CLK(clock),
    .RESETn(resetn),
    // IO bus
    .io_address(io_address),
    .io_addr_strobe(io_addr_strobe),
    .io_write_data(io_write_data),
    .io_write_strobe(io_write_strobe),
    .io_byte_enable(io_byte_enable),
    .io_read_data(io_read_data),
    .io_read_strobe(io_read_strobe),
    .io_ready(io_ready),
    // OBI master side
    // A channel
    .obi_req_o   (master_obi_req),
    .obi_gnt_i   (master_obi_gnt),
    .obi_addr_o  (master_obi_addr),
    .obi_we_o    (master_obi_we),
    .obi_be_o    (master_obi_be),
    .obi_wdata_o (master_obi_wdata),
    // R channel
    .obi_rvalid_i(master_obi_rvalid),
    .obi_rready_o(master_obi_rready),
    .obi_rdata_i (master_obi_rdata),
    .obi_err_i   (master_obi_err)
);

// Instantiate OBI interconnect

// OBI slave-side arrayed signals between interconnect and peripherals
logic [NUM_PERIPHERALS-1:0]  slave_obi_req;
logic [NUM_PERIPHERALS-1:0]  slave_obi_gnt;
logic [AW-1:0]               slave_obi_addr [NUM_PERIPHERALS-1:0];
logic [NUM_PERIPHERALS-1:0]  slave_obi_we;
logic [DW-1:0]               slave_obi_wdata [NUM_PERIPHERALS-1:0];
logic [3:0]                  slave_obi_be [NUM_PERIPHERALS-1:0];
logic [NUM_PERIPHERALS-1:0]  slave_obi_rvalid;
logic [NUM_PERIPHERALS-1:0]  slave_obi_rready;
logic [DW-1:0]               slave_obi_rdata [NUM_PERIPHERALS-1:0];
logic [NUM_PERIPHERALS-1:0]  slave_obi_err;



OBI_interconnect #(
    .DW(DW),
    .AW(AW),
    .NUM_PERIPHERALS(NUM_PERIPHERALS),
    .NUM_REG_PERIPHERAL(NUM_REG_PERIPHERAL)
) u_obi_interconnect (
// MASTER A channel
    .master_obi_req_o    (master_obi_req),
    .master_obi_gnt_i    (master_obi_gnt),
    .master_obi_addr_o   (master_obi_addr),
    .master_obi_we_o     (master_obi_we),
    .master_obi_be_o     (master_obi_be),
    .master_obi_wdata_o (master_obi_wdata),
// MASTER B channel
    .master_obi_rvalid_i(master_obi_rvalid),
    .master_obi_rready_o(master_obi_rready),
    .master_obi_rdata_i (master_obi_rdata),
    .master_obi_err_i    (master_obi_err),
 // SLAVE A channel
    .slave_obi_req_i     (slave_obi_req),
    .slave_obi_gnt_o     (slave_obi_gnt),
    .slave_obi_addr_i    (slave_obi_addr),
    .slave_obi_we_i      (slave_obi_we),
    .slave_obi_be_i      (slave_obi_be),
    .slave_obi_wdata_i  (slave_obi_wdata),
//  SLAVE R channel 
    .slave_obi_rvalid_o (slave_obi_rvalid),
    .slave_obi_rready_i (slave_obi_rready),
    .slave_obi_rdata_o  (slave_obi_rdata),
    .slave_obi_err_o     (slave_obi_err)
);


// instantiate a gpio device.
// the base address will be 0 

// 0xC000_0000 + 0x00
obi_gpio #(
    .OBI_ADDR_WIDTH(AW),
    .OBI_DATA_WIDTH(DW)
) u_obi_gpio (
    .switches      (switches),
    .leds          (leds),
    .obi_clk_i     (clock),
    .obi_rstn_i    (resetn),
    .obi_req_i     (slave_obi_req[0]),
    .obi_gnt_o     (slave_obi_gnt[0]),
    .obi_addr_i    (slave_obi_addr[0]),
    .obi_we_i      (slave_obi_we[0]),
    .obi_wdata_i  (slave_obi_wdata[0]),
    .obi_be_i      (slave_obi_be[0]),
    .obi_rready_i (slave_obi_rready[0]), // always ready to accept data
    .obi_rvalid_o (slave_obi_rvalid[0]),
    .obi_rdata_o  (slave_obi_rdata[0]),
    .obi_err_o     (slave_obi_err[0])
);

// 0xC000_0000 + 0x80
obi_timer #(
    .OBI_ADDR_WIDTH(AW),
    .OBI_DATA_WIDTH(DW)
) u_obi_timer (
    .obi_clk_i     (clock),
    .obi_rstn_i    (resetn),
    .obi_req_i     (slave_obi_req[1]),
    .obi_gnt_o     (slave_obi_gnt[1]),
    .obi_addr_i    (slave_obi_addr[1]),
    .obi_we_i      (slave_obi_we[1]),
    .obi_wdata_i  (slave_obi_wdata[1]),
    .obi_be_i      (slave_obi_be[1]),
    .obi_rready_i (1), // always ready to accept data
    .obi_rvalid_o (slave_obi_rvalid[1]),
    .obi_rdata_o  (slave_obi_rdata[1]),
    .obi_err_o     (slave_obi_err[1])

);

obi_uart #(
    .OBI_ADDR_WIDTH(AW),
    .OBI_DATA_WIDTH(DW)
) u_obi_uart (
    .obi_clk_i     (clock),
    .obi_rstn_i    (resetn),
    .obi_req_i     (slave_obi_req[2]),
    .obi_gnt_o     (slave_obi_gnt[2]),
    .obi_addr_i    (slave_obi_addr[2]),
    .obi_we_i      (slave_obi_we[2]),
    .obi_wdata_i  (slave_obi_wdata[2]),
    .obi_be_i      (slave_obi_be[2]),
    .obi_rready_i (1), // always ready to accept data
    .obi_rvalid_o (slave_obi_rvalid[2]),
    .obi_rdata_o  (slave_obi_rdata[2]),
    .obi_err_o     (slave_obi_err[2]),
    .tx       (tx)
);

// the "rest" of peripherals
genvar i;
for (i = 3; i < NUM_PERIPHERALS; i++) begin : gen_addr
    assign slave_obi_gnt[i] = 1'b0;
    assign slave_obi_rvalid[i] = slave_obi_req[i];
    assign slave_obi_rdata[i] = 32'hFFFF_FFFF;
    assign slave_obi_err[i] = 1'b1;
end


endmodule