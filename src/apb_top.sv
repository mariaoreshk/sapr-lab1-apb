module apb_top
(
    input  logic pclk,
    input  logic presetn,

    // Сигнал для testbench:
    // master закончил все четыре операции
    output logic done
);


// ------------------------------------------------------------
// Внутренние APB-сигналы между master и slave
// ------------------------------------------------------------

logic [31:0] paddr;
logic [31:0] pwdata;

logic        psel;
logic        penable;
logic        pwrite;

logic [31:0] prdata;
logic        pready;
logic        pslverr;


// ------------------------------------------------------------
// APB MASTER
// ------------------------------------------------------------

apb_master u_master
(
    .pclk    (pclk),
    .presetn (presetn),

    // Ответы от slave
    .pready  (pready),
    .pslverr (pslverr),

    // Сигналы к slave
    .paddr   (paddr),
    .pwdata  (pwdata),
    .psel    (psel),
    .penable (penable),
    .pwrite  (pwrite),

    // Все четыре операции завершены
    .done    (done)
);


// ------------------------------------------------------------
// APB SLAVE
// ------------------------------------------------------------

apb_slave u_slave
(
    .pclk    (pclk),
    .presetn (presetn),

    // Сигналы от master
    .paddr   (paddr),
    .pwdata  (pwdata),
    .psel    (psel),
    .penable (penable),
    .pwrite  (pwrite),

    // Ответы slave
    .pready  (pready),
    .pslverr (pslverr),
    .prdata  (prdata)
);


endmodule