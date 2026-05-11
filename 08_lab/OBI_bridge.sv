
module OBI_Bridge  #(
    // Configurable Parameters
    parameter DW = 32 ,  // Data width
    parameter AW = 32  ,  // Address width
    parameter BRG_BASE = 32'hc000_0000 // 0xC0FFFFFF
)(
    input logic CLK,
    input logic RESETn,
    // IO bus
    // uBLAZE MCS I/O bus
    input logic [31:0] io_address,
    input logic io_addr_strobe,
    input logic [31:0] io_write_data,
    input logic io_write_strobe,
    input logic [3:0] io_byte_enable,
    output logic [31:0] io_read_data,
    input logic io_read_strobe,
    output logic io_ready,
    // OBI master side (driving the slave)
    // A channel 
    output logic        obi_req_o,
    input  logic        obi_gnt_i,
    output logic [31:0] obi_addr_o,
    output logic        obi_we_o,
    output logic [3:0]  obi_be_o,
    output logic [31:0] obi_wdata_o,
    // R channel
    input  logic        obi_rvalid_i,
    output logic        obi_rready_o,
    input  logic [31:0] obi_rdata_i,
    input  logic        obi_err_i
);
    

    // The OBI subsystem acts as slave on I/O bus. It starting address is 0xC000_0000
    logic mcs_bridge_enable;
    assign mcs_bridge_enable = (io_address[31:24] == BRG_BASE[31:24]);

    // We will use a address_strobe to generate the valid signal. 
    // regardless of read or write, address_strobe is always asserted when there is a valid address
    logic valid;
    assign valid = io_addr_strobe & mcs_bridge_enable; // do not generate any request if we did not select our system

    logic write_req, write, delay_write;
        
    assign write = io_write_strobe & ~io_read_strobe;
    
    always_ff @(posedge CLK) begin
        if (!RESETn) begin
            delay_write <= 0;
        end else begin
            if(valid) begin
                delay_write <= write;
            end
        end
    end

    assign write_req = (valid == 1) ? write : delay_write;

    // -----------------------------------------------------------
    // State machine
    // IDLE     : no transaction
    // ADDR     : req sent, waiting for gnt
    // WAIT_RSP : gnt received, waiting for rvalid
    // DONE     : rvalid received, assert IO_Ready for one cycle
    // -----------------------------------------------------------
    typedef enum logic [1:0] {
        IDLE     = 2'd0,
        ADDR     = 2'd1,
        WAIT_RSP = 2'd2,
        DONE     = 2'd3
    } state_e;

    state_e state_q, state_d;

    always_ff @(posedge CLK)
        if (!RESETn)
            state_q <= IDLE;
        else         
            state_q <= state_d;

    // -----------------------------------------------------------
    // Next-state logic
    // -----------------------------------------------------------
    always_comb begin
        state_d = state_q;
        case (state_q)

            IDLE:
                if (valid)
                    state_d = ADDR;

            ADDR:
                // gnt and rvalid may arrive same cycle (zero-latency slave)
                if (obi_gnt_i && obi_req_o)
                    state_d = WAIT_RSP;
    

            WAIT_RSP:
                if (obi_rvalid_i)
                    state_d = DONE;

            DONE:
                // IO_Ready pulses for exactly one cycle, then back to IDLE
                // If valid is already high again (back-to-back),
                // go straight to ADDR
                if (valid)
                    state_d = ADDR;
                else
                    state_d = IDLE;
        endcase
    end


    // -----------------------------------------------------------
    // OBI request — hold req and address stable until gnt
    // -----------------------------------------------------------
    assign obi_req_o   = (state_q == ADDR);
    assign obi_addr_o  = io_address;
    assign obi_we_o    = write_req;
    assign obi_be_o    = io_byte_enable;
    assign obi_wdata_o = io_write_data;
    assign obi_rready_o = 1'b1;   // we always accept responses immediately


    // -----------------------------------------------------------
    // Response capture — latch rdata when rvalid arrives
    // -----------------------------------------------------------
    logic [31:0] rdata_q;

    always_ff @(posedge CLK) begin
        if (!RESETn)
            rdata_q <= '0;
        else if (obi_rvalid_i)
            rdata_q <= obi_rdata_i;
    end

    // -----------------------------------------------------------
    // IO bus response — IO_Ready pulses one cycle in DONE
    // -----------------------------------------------------------
    assign io_ready     = (state_q == DONE)  & mcs_bridge_enable ;
    assign io_read_data = rdata_q;

endmodule
