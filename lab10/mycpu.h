`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD 35

    `define FS_TO_DS_BUS_WD 97
    `define DS_TO_ES_BUS_WD 199
    `define ES_TO_MS_BUS_WD 162
    `define MS_TO_WS_BUS_WD 121

    `define WS_TO_RF_BUS_WD 38
    `define ES_TO_DS_BUS_WD 38
    `define MS_TO_DS_BUS_WD 38

    // CRs
    `define CR_COMPARE 8'h0b
    `define CR_STATUS 8'h0c
    `define CR_CAUSE 8'h0d
    `define CR_EPC 8'h0e
    `define CR_COUNT 8'h09
    `define CR_BADVADDR 8'h08

    // EXcode
    `define EX_INTR 5'h00
    `define EX_ADEL 5'h04
    `define EX_ADES 5'h05
    `define EX_OV 5'h0c
    `define EX_SYS 5'h08
    `define EX_BP 5'h09
    `define EX_RI 5'h0a
`endif
