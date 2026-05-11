# Eight exercise: Adding a 7-segment display core to the FPROv3 system

## 7-segment display core

In this exercise we will add a 7-segment display core to the FPROv3 system. Start from the FPROv3 system that we have developed in the lectures.

### Register map

The 7-segment display core has the following register map:

| Address Offset | Register Name | Description                                  |
|----------------|---------------|----------------------------------------------|
| 0x00           | Config_reg    | Bit 0: Enables/disables the display          |
| 0x04           | Digit0        | Bits 0-7: Hex value of the first digit       |
| 0x08           | Digit1        | Bits 0-7: Hex value of the second digit      |
| 0x0C           | Digit2        | Bits 0-7: Hex value of the third digit       |
| 0x10           | Digit3        | Bits 0-7: Hex value of the fourth digit      |
| 0x14           | Digit4        | Bits 0-7: Hex value of the fifth digit       |
| 0x18           | Digit5        | Bits 0-7: Hex value of the sixth digit       |
| 0x1C           | Digit6        | Bits 0-7: Hex value of the seventh digit     |
| 0x20           | Digit7        | Bits 0-7: Hex value of the eighth digit      |

---

## Tasks

### 1. Implement the OBI slave wrapper for the 7-segment display core

Create a new file `OBI_seg7_display.sv` that implements the OBI slave interface for the 7-segment display core. Use the provided `obi_slave_template.sv` as your starting point.

Instantiate the 7-segment display core inside `OBI_seg7_display.sv`:

```verilog
logic [7:0] digit0, digit1, digit2, digit3, digit4, digit5, digit6, digit7;
logic enable_7seg;

SevSegDisplay SevSegDisplay_inst (
    .clock        (obi_clk_i),
    .reset        (!obi_rstn_i),
    .enable_7seg  (enable_7seg),
    .digit1       (digit0),
    .digit2       (digit1),
    .digit3       (digit2),
    .digit4       (digit3),
    .digit5       (digit4),
    .digit6       (digit5),
    .digit7       (digit6),
    .digit8       (digit7),
    .anode_select (anode_select),
    .segs         (segs)
);
```

### 2. Write the OBI interface logic

Use the OBI slave template structure to connect the bus to your internal registers. The skeleton below shows the write logic pattern — complete the `case` statement and add the read logic and error logic following the same approach used in the lectures.

```verilog
// Write enable: asserted during the response phase for write transactions
logic wr_en;
assign wr_en = (state == RESP) & latched_we;

always_ff @(posedge obi_clk_i) begin : write_logic
    if (!obi_rstn_i) begin
        enable_7seg <= 1'b0;
        digit0 <= 8'b0;
        // ... reset all digit registers
    end else begin
        if (wr_en) begin
            case (latched_addr[6:0])
                // TODO: fill in a case entry for each register offset
            endcase
        end
    end
end
```

Since the 7-segment display core is write-only from the bus perspective:
- The `obi_rdata_o` signal should return `32'b0` for all addresses.
- The `obi_err_o` signal should be asserted when a **read** is attempted on any register, or when any access targets an undefined address.

### 3. Register the peripheral in the FPROv3 top-level module

Instantiate `OBI_seg7_display` in the FPROv3 top-level module and connect the OBI signals. The peripheral index for the 7-segment display is **2**.

```verilog
OBI_seg7_display #(
    .OBI_ADDR_WIDTH (AW),
    .OBI_DATA_WIDTH (DW)
) u_obi_seg7 (
    .obi_clk_i     (clock),
    .obi_rstn_i    (resetn),
    .obi_req_i     (slave_obi_req[3]),
    .obi_gnt_o     (slave_obi_gnt[3]),
    .obi_addr_i    (slave_obi_addr[3]),
    .obi_we_i      (slave_obi_we[3]),
    .obi_wdata_i  (slave_obi_wdata[3]),
    .obi_be_i      (slave_obi_be[3]),
    .obi_rready_i (1), // always ready to accept data
    .obi_rvalid_o (slave_obi_rvalid[3]),
    .obi_rdata_o  (slave_obi_rdata[3]),
    .obi_err_o     (slave_obi_err[3])
    // External signals
    .anode_select (anode_select),
    .segs         (segs)
);
```


Do not forget to update the genvar loop starting index to **4** in the FPROv3 top-level module, and ensure the default error assignments cover the remaining unused slots:

```verilog
genvar i;
for (i = 4; i < NUM_PERIPHERALS; i++) begin : gen_unused
    assign S_obi_err[i]    = 1'b1;
    assign S_obi_rvalid[i] = 1'b0;
    assign S_obi_rdata[i]  = 32'hFFFFFFFF;
    assign S_obi_gnt[i]    = 1'b0;
end
```

### 4. Write a C application

Write a bare-metal C application that reads the current timer value and displays the elapsed seconds on the 7-segment display.

#### Determining the base address

In FPROv3 the base address of each peripheral is calculated as:

```
base_address = (0xC0 << 24) + (peripheral_index × 0x80)
```

For the 7-segment display (peripheral index 3):

```
base_address = 0xC0000000 + (3 × 0x80) = 0xC0000180
```

To access a specific register, add its offset to the base address.

#### Example code

```c
volatile uint32_t* seg7_base = (volatile uint32_t*)0xC0000180;

// Enable the display (Config_reg at offset 0x00)
*(seg7_base + 0) = 0x1;

// Write digit values (offsets 0x04 – 0x20, i.e. word indices 1 – 8)
*(seg7_base + 1) = digit0_value;  // Digit0
*(seg7_base + 2) = digit1_value;  // Digit1
// ... and so on for the remaining digits
```

Read the timer peripheral as shown in the lectures, and whenever the timer value changes by one second, decompose the new count into individual decimal digits and write each one to the corresponding `DigitN` register.
