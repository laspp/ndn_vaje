// ============================================================
//  OBI Slave Template
//  
//  Students: Search for "TODO" to find all sections you need
//  to implement or customize for your peripheral.
// ============================================================

// ------------------------------------------------------------
//  TODO (1): Define your register address offsets here.
//  Use 7-bit offsets (bits [6:0] of the address bus).
//  Example:
//    `define MY_REG_A_OFF  7'h00
//    `define MY_REG_B_OFF  7'h04
// ------------------------------------------------------------
// `define REG_A_OFF  7'h00
// `define REG_B_OFF  7'h04


module obi_slave_template #(
    parameter OBI_ADDR_WIDTH = 32,
    parameter OBI_DATA_WIDTH = 32

) (
    // --------------------------------------------------------
    //  TODO (2): Add your peripheral-specific ports here.
    //  Examples:
    //    input  logic [15:0] data_in,
    //    output logic [15:0] data_out,
    // --------------------------------------------------------

    // OBI SLAVE INTERFACE (do not modify)
    //***************************************
    input  logic                          obi_clk_i,
    input  logic                          obi_rstn_i,

    // ADDRESS CHANNEL
    input  logic                          obi_req_i,
    output logic                          obi_gnt_o,
    input  logic [OBI_ADDR_WIDTH-1:0]     obi_addr_i,
    input  logic                          obi_we_i,
    input  logic [OBI_DATA_WIDTH-1:0]     obi_wdata_i,
    input  logic [3:0]                    obi_be_i,

    // RESPONSE CHANNEL
    input  logic                          obi_rready_i,
    output logic                          obi_rvalid_o,
    output logic [OBI_DATA_WIDTH-1:0]     obi_rdata_o,
    output logic                          obi_err_o
);

    // ============================================================
    //  OBI FSM
    //  Two-state FSM: ADDR phase -> RESP phase.
    //  Do not modify this section.
    // ============================================================

    logic latch_addr;

    typedef enum logic {
        ADDR,
        RESP
    } state_t;
    state_t state, next_state;

    // State register
    always_ff @(posedge obi_clk_i) begin
        if (!obi_rstn_i) begin
            state <= ADDR;
        end else begin
            state <= next_state;
        end
    end

    // Next-state logic
    always_comb begin : OBI_SLAVE_next_state
        next_state = state;
        latch_addr = 1'b0;
        case (state)
            ADDR: begin
                if (obi_gnt_o & obi_req_i) begin
                    next_state = RESP;
                    latch_addr = 1'b1;
                end
            end
            RESP: begin
                if (obi_rvalid_o & obi_rready_i) begin
                    next_state = ADDR;
                end
            end
        endcase
    end

    // OBI handshake signals — do not modify
    assign obi_gnt_o    = 1'b1 & !(state == RESP);
    assign obi_rvalid_o = 1'b1 &  (state == RESP);

    // ============================================================
    //  Address / Data Latching
    //  Captures the transaction details at the end of the address
    //  phase so they are stable during the response phase.
    //  Do not modify this section.
    // ============================================================

    logic [OBI_ADDR_WIDTH-1:0] latched_addr;
    logic [OBI_DATA_WIDTH-1:0] latched_wdata;
    logic                      latched_we;

    always_ff @(posedge obi_clk_i) begin
        if (!obi_rstn_i) begin
            latched_addr  <= '0;
            latched_wdata <= '0;
            latched_we    <= 1'b0;
        end else if (latch_addr) begin
            latched_addr  <= obi_addr_i;
            latched_wdata <= obi_wdata_i;
            latched_we    <= obi_we_i;
        end
    end

    // ============================================================
    //  TODO (3): Write Logic
    //
    //  For each writable register, create a write-enable signal
    //  and an always_ff block that updates the register.
    //
    //  A write is valid when ALL of the following are true:
    //    - The FSM is in the RESP phase           (state == RESP)
    //    - The transaction is a write             (latched_we)
    //    - The address matches the register       (latched_addr[6:0] == `YOUR_REG_OFF)
    //
    //  Template for one register:
    //
    //    logic wr_en_reg_a;
    //    assign wr_en_reg_a = (state == RESP)
    //                       & latched_we
    //                       & (latched_addr[6:0] == `REG_A_OFF);
    //
    //    logic [OBI_DATA_WIDTH-1:0] reg_a;
    //    always_ff @(posedge obi_clk_i) begin
    //        if (!obi_rstn_i) begin
    //            reg_a <= '0;            // reset value
    //        end else if (wr_en_reg_a) begin
    //            reg_a <= latched_wdata; // or a slice, e.g. latched_wdata[15:0]
    //        end
    //    end
    // ============================================================


    // ============================================================
    //  TODO (4): Read Logic
    //
    //  Drive obi_rdata_o based on latched_addr during the RESP
    //  phase for read transactions.
    //
    //  - Always output 32'b0 when not in RESP phase.
    //  - For invalid read addresses, also return 32'b0.
    //
    //  Template:
    //
    //    always_comb begin
    //        obi_rdata_o = 32'b0; // default
    //        if (state == RESP && !latched_we) begin
    //            case (latched_addr[6:0])
    //                `REG_A_OFF: obi_rdata_o = {16'b0, reg_a[15:0]};
    //                `REG_B_OFF: obi_rdata_o = reg_b;
    //                default:    obi_rdata_o = 32'b0;
    //            endcase
    //        end
    //    end
    // ============================================================

    assign obi_rdata_o = 32'b0; // TODO: replace with your read logic above


    // ============================================================
    //  TODO (5): Error Logic
    //
    //  Assert obi_err_o when a request targets an address that
    //  does not exist in your peripheral.
    //
    //  Check for invalid accesses during the ADDRESS phase
    //  (when obi_gnt_o & obi_req_i is true), using the
    //  non-latched obi_addr_i and obi_we_i signals.
    //
    //  Template:
    //
    //    logic valid_addr;
    //    assign valid_addr = (obi_addr_i[6:0] == `REG_A_OFF)
    //                      | (obi_addr_i[6:0] == `REG_B_OFF);
    //
    //    logic invalid_access;
    //    assign invalid_access = (obi_gnt_o & obi_req_i) & !valid_addr;
    //
    //    assign obi_err_o = invalid_access;
    // ============================================================

    assign obi_err_o = 1'b0; // TODO: replace with your error logic above

endmodule
