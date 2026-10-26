`timescale 1ns/1ps

module TB;


logic pclk;
logic presetn;

logic psel;
logic penable;
logic pwrite;

logic [31:0] paddr;
logic [31:0] pwdata;

wire [31:0] prdata;
wire pready;
wire pslverr;


parameter p_device_offset = 32'h7000_0000;


logic [31:0] address;
logic [31:0] data_to_device;
logic [31:0] data_from_device;


// Подключаем тестируемый APB slave
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


// -------------------------------------------------
// Задача записи по APB
// -------------------------------------------------
task apb_write(
    input logic [31:0] addr,
    input logic [31:0] data
);

    wait ((penable == 0) && (pready == 0));

    @(posedge pclk);

    psel   <= 1'b1;
    paddr  <= addr;
    pwdata <= data;
    pwrite <= 1'b1;

    @(posedge pclk);

    penable <= 1'b1;

    @(posedge pclk);

    wait (pready == 1'b1);

    @(posedge pclk);

    psel    <= 1'b0;
    penable <= 1'b0;
    pwrite  <= 1'b0;

    @(posedge pclk);

endtask


// -------------------------------------------------
// Задача чтения по APB
// -------------------------------------------------
task apb_read(
    input  logic [31:0] addr,
    output logic [31:0] data
);

    wait ((penable == 0) && (pready == 0));

    @(posedge pclk);

    psel   <= 1'b1;
    pwrite <= 1'b0;
    paddr  <= addr;

    @(posedge pclk);

    penable <= 1'b1;

    @(posedge pclk);

    wait (pready == 1'b1);

    @(posedge pclk);

    data = prdata;

    psel    <= 1'b0;
    penable <= 1'b0;

    @(posedge pclk);

endtask


// Тактовый сигнал.
// Период = 20 нс.
always
    #10 pclk = ~pclk;


// Основной сценарий тестирования
initial
begin

    pclk    = 1'b0;
    presetn = 1'b1;

    psel    = 1'b0;
    penable = 1'b0;
    pwrite  = 1'b0;

    paddr   = '0;
    pwdata  = '0;


    // Ждём несколько тактов
    repeat (5)
        @(posedge pclk);


    // Сброс
    presetn = 1'b0;

    repeat (5)
        @(posedge pclk);

    presetn = 1'b1;

    repeat (5)
        @(posedge pclk);


    // ----------------------------
    // Тест №1
    // ----------------------------

    address = p_device_offset + 32'h0;

    data_to_device = 32'h1234_5678;

    apb_write(address, data_to_device);

    apb_read(address, data_from_device);

    $display(
        "Addr=0x%h, write data=0x%h, read data=0x%h",
        address,
        data_to_device,
        data_from_device
    );


    // ----------------------------
    // Тест №2
    // ----------------------------

    data_to_device = 32'h0000_0001;

    apb_write(address, data_to_device);

    apb_read(address, data_from_device);

    $display(
        "Addr=0x%h, write data=0x%h, read data=0x%h",
        address,
        data_to_device,
        data_from_device
    );


    repeat (10)
        @(posedge pclk);


    $stop;

end


// Вывод изменения сигналов в консоль
initial
begin

    $monitor(
        "APB: PENABLE=%b PREADY=%b PADDR=0x%h PWDATA=0x%h PRDATA=0x%h",
        penable,
        pready,
        paddr,
        pwdata,
        prdata
    );

end


endmodule