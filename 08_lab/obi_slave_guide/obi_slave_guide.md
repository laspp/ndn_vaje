# OBI Slave Peripheral — Student Guide

This guide walks you through implementing a memory-mapped peripheral using the **OBI (Open Bus Interface)** protocol. You will fill in a provided SystemVerilog template (`obi_slave_template.sv`) to create your own peripheral.

---

## 1. What Is OBI?

OBI is a simple, handshake-based bus protocol used to connect peripherals (slaves) to a processor (master). Every transaction has two phases:

| Phase | Description |
|-------|-------------|
| **Address phase** | The master sends an address, write-enable flag, and optional write data. The slave asserts `gnt` to accept the request. |
| **Response phase** | The slave puts read data (or an error) on the bus and asserts `rvalid`. The master asserts `rready` to consume the response. |

A transaction completes only when **both** sides of a handshake occur simultaneously (e.g., `req & gnt` in the address phase, `rvalid & rready` in the response phase).

---

## 2. Signal Reference

### Address Channel (master → slave)

| Signal | Width | Description |
|--------|-------|-------------|
| `obi_req_i` | 1 | Master requests a transaction |
| `obi_addr_i` | 32 | Target byte address |
| `obi_we_i` | 1 | `1` = write, `0` = read |
| `obi_wdata_i` | 32 | Write data |
| `obi_be_i` | 4 | Byte enables (one bit per byte lane) |

### Address Channel (slave → master)

| Signal | Width | Description |
|--------|-------|-------------|
| `obi_gnt_o` | 1 | Slave accepts the request this cycle |

### Response Channel (master → slave)

| Signal | Width | Description |
|--------|-------|-------------|
| `obi_rready_i` | 1 | Master is ready to consume the response |

### Response Channel (slave → master)

| Signal | Width | Description |
|--------|-------|-------------|
| `obi_rvalid_o` | 1 | Response is valid this cycle |
| `obi_rdata_o` | 32 | Read data |
| `obi_err_o` | 1 | Error flag (e.g., invalid address) |

---

## 3. FSM Overview

The template implements a two-state FSM. **Do not modify it.**

```
         req & gnt
  ADDR ─────────────► RESP
   ◄────────────────
      rvalid & rready
```

- In **ADDR**: the slave is ready to accept a new request (`gnt = 1`).  
  When `req & gnt`, the address/data/we signals are latched and the FSM moves to RESP.
- In **RESP**: the slave drives `rvalid = 1` and holds `gnt = 0` (no new requests accepted).  
  When `rvalid & rready`, the response is consumed and the FSM returns to ADDR.

> **Key rule:** always use the *latched* signals (`latched_addr`, `latched_wdata`, `latched_we`) in the RESP phase — the original input signals may have changed by then.

---

## 4. Register Map

Peripherals expose their internal state through a set of memory-mapped registers. Each register sits at a fixed **byte offset** from the peripheral's base address. The template uses bits `[6:0]` of the address (a 7-bit window) to select registers, giving you 32 possible 32-bit register slots (offsets `0x00`, `0x04`, `0x08`, …, `0x7C`). Choose offsets that are multiples of 4 (word-aligned). (every 32-bit register occupies 4 bytes, so word-alignment is required to avoid overlapping registers).

---

## 5. Step-by-Step: What You Need to Fill In

The template contains five `TODO` markers. Work through them in order.

### TODO 1 — Define register offsets

```systemverilog
`define MY_OUTPUT_REG_OFF  7'h00
`define MY_INPUT_REG_OFF   7'h04
```

### TODO 2 — Add peripheral ports

Declare the I/O signals your peripheral needs to talk to the outside world (switches, LEDs, sensors, etc.).

```systemverilog
input  logic [7:0]  sensor_data_i,
output logic [7:0]  actuator_ctrl_o,
```

### TODO 3 — Write logic

For each **writable** register:
1. Declare a write-enable signal.
2. Assert it when in RESP phase **and** `latched_we` is set **and** the address matches.
3. Register the write data in an `always_ff` block.

```systemverilog
logic wr_en_output;
assign wr_en_output = (state == RESP)
                    & latched_we
                    & (latched_addr[6:0] == `MY_OUTPUT_REG_OFF);

logic [7:0] output_reg;
always_ff @(posedge obi_clk_i) begin
    if (!obi_rstn_i)        output_reg <= 8'b0;
    else if (wr_en_output)  output_reg <= latched_wdata[7:0];
end

assign actuator_ctrl_o = output_reg;
```

### TODO 4 — Read logic

Drive `obi_rdata_o` based on `latched_addr` during the RESP phase for read transactions. Return `32'b0` for all other cases.

```systemverilog
always_comb begin
    obi_rdata_o = 32'b0;
    if (state == RESP && !latched_we) begin
        case (latched_addr[6:0])
            `MY_INPUT_REG_OFF:  obi_rdata_o = {24'b0, sensor_data_i};
            `MY_OUTPUT_REG_OFF: obi_rdata_o = {24'b0, output_reg};
            default:            obi_rdata_o = 32'b0;
        endcase
    end
end
```

> You can also make a write-only register un-readable by simply not listing it in the `case` statement (it will return `32'b0`).

### TODO 5 — Error logic

Signal an error when the master accesses an address that does not exist in your peripheral. Evaluate this during the **address phase** using the non-latched signals.

```systemverilog
logic valid_addr;
assign valid_addr = (obi_addr_i[6:0] == `MY_INPUT_REG_OFF)
                  | (obi_addr_i[6:0] == `MY_OUTPUT_REG_OFF);

assign obi_err_o = (obi_gnt_o & obi_req_i) & !valid_addr;
```

---



## 6. Checklist Before Simulation

- [ ] All register offsets are defined and word-aligned.
- [ ] All peripheral ports are declared.
- [ ] Every writable register has a dedicated write-enable and `always_ff` block.
- [ ] Every readable register appears in the read `case` statement.
- [ ] `obi_err_o` covers all invalid addresses (write and read).
- [ ] All `always_ff` blocks have a reset branch.
- [ ] `obi_rdata_o` is zero when not in RESP phase or when the request is a write.

---

## 7. Timing Diagram Example

```
          ┌─┐   ┌─┐   ┌─┐
clk   ────┘ └───┘ └───┘ └───
          ┌─────┐
req   ────┘     └───────────       master requests
                    ┌─────┐
gnt   ──────────────┘     └───     slave accepts (not in RESP)
      ─────────────────┬───────
addr                   │ 0x04      address is stable during req+gnt
                       ┌─────┐
rvalid ────────────────┘     └─    slave drives response next cycle
          ┌─────────────────┐
rready ───┘                 └──    master ready to consume
```

> The address is sampled (latched) on the rising clock edge where `req & gnt` is true. The response appears one cycle later when `rvalid` goes high.

---

## 8. Further Reading

- [OBI Protocol Specification v1.6](https://github.com/openhwgroup/obi/blob/main/OBI-v1.6.0.pdf)
- Course lecture slides on memory-mapped I/O
- Reference implementation: `obi_gpio.sv` (provided separately)