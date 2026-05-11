module OBI_interconnect #(
    // Configurable Parameters
    parameter DW = 32 ,  // Data width
    parameter AW = 32  ,  // Address width
    parameter NUM_PERIPHERALS = 64,
    parameter NUM_REG_PERIPHERAL = 32
)(
    // OBI master-side interface
    // A channel
    input  logic                        master_obi_req_o,
    output logic                       master_obi_gnt_i,
    input logic [AW-1:0]              master_obi_addr_o,
    input logic                        master_obi_we_o,
    input logic [3:0]                  master_obi_be_o,
    input logic [DW-1:0]               master_obi_wdata_o,
    // R channel
    output logic                       master_obi_rvalid_i,
    input logic                        master_obi_rready_o,
    output logic [DW-1:0]              master_obi_rdata_i,
    output logic                       master_obi_err_i,
    // OBI slave-side interface (arrayed per peripheral)
    // A channel
    output logic [NUM_PERIPHERALS-1:0] slave_obi_req_i,
    input logic [NUM_PERIPHERALS-1:0]  slave_obi_gnt_o,
    output logic [AW-1:0]              slave_obi_addr_i [NUM_PERIPHERALS-1:0],
    output logic [NUM_PERIPHERALS-1:0] slave_obi_we_i,
    output logic [3:0]                 slave_obi_be_i [NUM_PERIPHERALS-1:0],
    output logic [DW-1:0]              slave_obi_wdata_i [NUM_PERIPHERALS-1:0],
    // R channel
    input logic [NUM_PERIPHERALS-1:0]  slave_obi_rvalid_o,
    output logic [NUM_PERIPHERALS-1:0] slave_obi_rready_i,
    input logic [DW-1:0]               slave_obi_rdata_o [NUM_PERIPHERALS-1:0],
    input logic [NUM_PERIPHERALS-1:0]  slave_obi_err_o
);

    // Addressing
    // Extracting base address from master_obi_addr_i
    
    // the bits for addressing are: (log2(NUM_PERIPHERALS) + log2(NUM_REG_PERIPHERAL) + 2 -1): log2(NUM_REG_PERIPHERAL) + 2
    // log2(NUM_PERIPHERALS) is number of bits to address each slave - base address 
    // log2(NUM_REG_PERIPHERAL) + 2 bits are needed to address every byte in the address space of each peripheral device - offset
    // +2 goes because every register is 32-bit or 4 bytes 
    
    // Write interface 
    // 1. Calculate the base address bits and offset bits based on the number of peripherals and number of registers per peripheral
    localparam baseAddr_MSB = ($clog2(NUM_PERIPHERALS) + $clog2(NUM_REG_PERIPHERAL) + 2) - 1; // evalutesto 6+5+2-1=12 for 64 peripherals with 32 registers each
    localparam baseAddr_LSB = $clog2(NUM_REG_PERIPHERAL) + 2; // evaluates to 5+2=7 for 32 registers per peripheral
    
    localparam MSB = $clog2(NUM_PERIPHERALS);
    logic [MSB - 1 : 0] baseAddr;
    logic [NUM_PERIPHERALS-1:0] onehot_sel;

    assign baseAddr = master_obi_addr_o[baseAddr_MSB : baseAddr_LSB];
    assign onehot_sel = ({ {(NUM_PERIPHERALS-1){1'b0}}, 1'b1 } << baseAddr);
    

    // Decoder: one-hot request routing to the selected peripheral.
    assign slave_obi_req_i =  master_obi_req_o ? (1 << baseAddr) : 0;
    
    // Forward shared OBI address channel signals to all peripherals.
    genvar i;
    for (i = 0; i < NUM_PERIPHERALS; i++) begin : gen_addr
        assign slave_obi_addr_i[i] = master_obi_addr_o;
        assign slave_obi_we_i[i] = master_obi_we_o;
        assign slave_obi_wdata_i[i] = master_obi_wdata_o;
        assign slave_obi_be_i[i] = master_obi_be_o;
        assign slave_obi_rready_i[i] = 1; 
    end
    

    // Read interface
    
    
    // Read data muxing: route the read data from the selected peripheral to the master, and route the gnt, rvalid and err signals from the selected peripheral to the master as well
    always_comb begin : default_assign
        // Default assignments to avoid latches
        master_obi_rdata_i = slave_obi_rdata_o[baseAddr];
    end
    
    
    // Muxing grant, rvalid and err signals from the selected peripheral to the master
    always_comb begin : readData
        master_obi_gnt_i = slave_obi_gnt_o[baseAddr]; // Dynamic address when multiplexing grant signals from the selected peripheral to the master 
        master_obi_rvalid_i = slave_obi_rvalid_o[baseAddr];
        master_obi_err_i = slave_obi_err_o[baseAddr];
    end

   


endmodule