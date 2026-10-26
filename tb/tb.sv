`timescale 1ns/1ps

module TB;


// ------------------------------------------------------------
// APB-сигналы
// ------------------------------------------------------------

logic pclk;
logic presetn;

logic psel;
logic penable;
logic pwrite;

logic [31:0] paddr;
logic [31:0] pwdata;

wire [31:0] prdata;
wire        pready;
wire        pslverr;


// ------------------------------------------------------------
// Базовый адрес нашего устройства
// ------------------------------------------------------------

localparam logic [31:0] DEVICE_BASE = 32'h7000_0000;


// ------------------------------------------------------------
// Персональные данные
// ------------------------------------------------------------

// Номер в списке
localparam logic [31:0] STUDENT_NUMBER = 32'd6;


// Дата выполнения лабораторной: 26.10.2026
//
// Точки физически не помещаются вместе со всеми цифрами
// в один 32-битный регистр,
// поэтому дата записана как 8 hex-цифр: DDMMYYYY.
localparam logic [31:0] DATE_VALUE = 32'h2610_2026;


// "Ores" в ASCII:
//
// O = 4F
// r = 72
// e = 65
// s = 73
localparam logic [31:0] SURNAME_VALUE = 32'h4F72_6573;


// "Mari" в ASCII:
//
// M = 4D
// a = 61
// r = 72
// i = 69
localparam logic [31:0] NAME_VALUE = 32'h4D61_7269;


// Переменная для результата чтения
logic [31:0] read_data;


// ------------------------------------------------------------
// Подключение DUT
// ------------------------------------------------------------

apb_slave DUT
(
    .pclk    (pclk),
    .presetn (presetn),

    .paddr   (paddr),
    .pwdata  (pwdata),

    .psel    (psel),
    .penable (penable),
    .pwrite  (pwrite),

    .pready  (pready),
    .pslverr (pslverr),
    .prdata  (prdata)
);


// ------------------------------------------------------------
// Генерация тактового сигнала
//
// Полупериод = 10 нс
// Период = 20 нс
// ------------------------------------------------------------

always
begin
    #10 pclk = ~pclk;
end


// ------------------------------------------------------------
// APB WRITE
// ------------------------------------------------------------

task automatic apb_write
(
    input logic [31:0] addr,
    input logic [31:0] data
);

begin

    // Ждём свободный интерфейс
    wait ((penable == 1'b0) && (pready == 1'b0));


    // ----------------------------
    // SETUP
    // ----------------------------

    @(posedge pclk);

    psel    <= 1'b1;
    penable <= 1'b0;

    pwrite  <= 1'b1;

    paddr   <= addr;
    pwdata  <= data;


    // ----------------------------
    // ACCESS
    // ----------------------------

    @(posedge pclk);

    penable <= 1'b1;


    // Ждём готовность slave
    wait (pready == 1'b1);


    @(posedge pclk);

    // Завершаем транзакцию
    psel    <= 1'b0;
    penable <= 1'b0;
    pwrite  <= 1'b0;


    @(posedge pclk);

end

endtask


// ------------------------------------------------------------
// APB READ
// ------------------------------------------------------------

task automatic apb_read
(
    input  logic [31:0] addr,
    output logic [31:0] data
);

begin

    wait ((penable == 1'b0) && (pready == 1'b0));


    // ----------------------------
    // SETUP
    // ----------------------------

    @(posedge pclk);

    psel    <= 1'b1;
    penable <= 1'b0;

    pwrite  <= 1'b0;

    paddr   <= addr;


    // ----------------------------
    // ACCESS
    // ----------------------------

    @(posedge pclk);

    penable <= 1'b1;


    wait (pready == 1'b1);


    // PRDATA уже выставлены slave.
    data = prdata;


    @(posedge pclk);

    // Завершаем транзакцию
    psel    <= 1'b0;
    penable <= 1'b0;


    @(posedge pclk);

end

endtask


// ------------------------------------------------------------
// Основной тест
// ------------------------------------------------------------

initial
begin

    // Начальные значения
    pclk    = 1'b0;
    presetn = 1'b1;

    psel    = 1'b0;
    penable = 1'b0;
    pwrite  = 1'b0;

    paddr   = 32'h0;
    pwdata  = 32'h0;

    read_data = 32'h0;


    // --------------------------------------------------------
    // Сброс
    // --------------------------------------------------------

    repeat (5)
        @(posedge pclk);

    presetn = 1'b0;

    repeat (5)
        @(posedge pclk);

    presetn = 1'b1;

    repeat (5)
        @(posedge pclk);


    $display("");
    $display("============================================");
    $display("START APB TEST");
    $display("============================================");


    // ========================================================
    // 1. Адрес 0x00
    // Номер в списке = 6
    // ========================================================

    $display("");
    $display("TEST 1: student number");

    apb_write(
        DEVICE_BASE + 32'h00,
        STUDENT_NUMBER
    );

    apb_read(
        DEVICE_BASE + 32'h00,
        read_data
    );

    $display(
        "RESULT 0x00: write=0x%h read=0x%h",
        STUDENT_NUMBER,
        read_data
    );

    // Поскольку 6 имеет младший бит 0,
    // по пункту 8 ожидаем AAAA_AAAA.
    if (read_data == 32'hAAAA_AAAA)
        $display("TEST 1 PASSED");
    else
        $display("TEST 1 FAILED");


    // ========================================================
    // 2. Адрес 0x04
    // Дата
    // ========================================================

    $display("");
    $display("TEST 2: date");

    apb_write(
        DEVICE_BASE + 32'h04,
        DATE_VALUE
    );

    apb_read(
        DEVICE_BASE + 32'h04,
        read_data
    );

    $display(
        "RESULT 0x04: write=0x%h read=0x%h",
        DATE_VALUE,
        read_data
    );

    if (read_data == DATE_VALUE)
        $display("TEST 2 PASSED");
    else
        $display("TEST 2 FAILED");


    // ========================================================
    // 3. Адрес 0x08
    // Ores
    // ========================================================

    $display("");
    $display("TEST 3: surname Ores");

    apb_write(
        DEVICE_BASE + 32'h08,
        SURNAME_VALUE
    );

    apb_read(
        DEVICE_BASE + 32'h08,
        read_data
    );

    $display(
        "RESULT 0x08: write=0x%h read=0x%h",
        SURNAME_VALUE,
        read_data
    );

    if (read_data == SURNAME_VALUE)
        $display("TEST 3 PASSED");
    else
        $display("TEST 3 FAILED");


    // ========================================================
    // 4. Адрес 0x0C
    // Mari
    // ========================================================

    $display("");
    $display("TEST 4: name Mari");

    apb_write(
        DEVICE_BASE + 32'h0C,
        NAME_VALUE
    );

    apb_read(
        DEVICE_BASE + 32'h0C,
        read_data
    );

    $display(
        "RESULT 0x0C: write=0x%h read=0x%h",
        NAME_VALUE,
        read_data
    );

    if (read_data == NAME_VALUE)
        $display("TEST 4 PASSED");
    else
        $display("TEST 4 FAILED");


    // ========================================================
    // Конец
    // ========================================================

    $display("");
    $display("============================================");
    $display("END APB TEST");
    $display("============================================");


    repeat (5)
        @(posedge pclk);


    $stop;

end


endmodule