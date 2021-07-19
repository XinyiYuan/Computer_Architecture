`ifndef MYCPU_H
    `define MYCPU_H
    `define BR_BUS_WD 34 // 32->33|->34
    `define FS_TO_DS_BUS_WD 64
    `define DS_TO_ES_BUS_WD 144 //136->144
    `define ES_TO_MS_BUS_WD 71 //135
    `define MS_TO_WS_BUS_WD 70
    `define WS_TO_RF_BUS_WD 38
    // new
    `define ES_TO_DS_BUS_WD 38 // 5->5+32+1
    `define MS_TO_DS_BUS_WD 37 // 5->5+32
`endif
