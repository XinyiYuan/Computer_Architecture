`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD 34

    //65->66
    `define FS_TO_DS_BUS_WD 98
    //164->168
    `define DS_TO_ES_BUS_WD 200
    //125->161
    `define ES_TO_MS_BUS_WD 163
    //84->121
    `define MS_TO_WS_BUS_WD 122

    `define WS_TO_RF_BUS_WD 38
    `define ES_TO_DS_BUS_WD 38
    `define MS_TO_DS_BUS_WD 38

    // CRs
    `define CR_COMPARE 8'h0b // 000, 01011
    `define CR_STATUS 8'h0c // 000, 01100
    `define CR_CAUSE 8'h0d // 000, 01101
    `define CR_EPC 8'h0e // 000, 01110
    `define CR_COUNT 8'h09 // 000, 01001
    `define CR_BADVADDR 8'h08 // 000,01000

    // EXcode
    `define EX_INTR 5'h00
    `define EX_ADEL 5'h04 // fetch_inst/read_data
    `define EX_ADES 5'h05 // write_data
    `define EX_OV 5'h0c
    `define EX_SYS 5'h08
    `define EX_BP 5'h09
    `define EX_RI 5'h0a
`endif
