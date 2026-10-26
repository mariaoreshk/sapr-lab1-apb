`timescale 1ns/1ps

module TB_TOP;


// ------------------------------------------------------------
// Сигналы верхнего уровня
// ------------------------------------------------------------

logic pclk;
logic presetn;

wire done;


// ------------------------------------------------------------
// Подключаем всю систему
// ------------------------------------------------------------

apb_top DUT
(
    .pclk    (pclk),
    .presetn (presetn),
    .done    (done)
);


// ------------------------------------------------------------
// Генератор тактового сигнала
//
// Период = 20 нс
// ------------------------------------------------------------

always
begin
    #10 pclk = ~pclk;
end


// ------------------------------------------------------------
// Основной тест
// ------------------------------------------------------------

initial
begin

    pclk    = 1'b0;
    presetn = 1'b1;


    // --------------------------------------------------------
    // Сброс
    // --------------------------------------------------------

    repeat (5)
        @(posedge pclk);

    presetn = 1'b0;

    repeat (5)
        @(posedge pclk);

    presetn = 1'b1;


    $display("");
    $display("============================================");
    $display("START MASTER + SLAVE TEST");
    $display("============================================");


    // --------------------------------------------------------
    // Ждём, пока master выполнит все четыре записи
    // --------------------------------------------------------

    wait (done == 1'b1);

    @(posedge pclk);


    $display("");
    $display("All APB master transactions completed.");
    $display("");


    // --------------------------------------------------------
    // Проверяем внутренние регистры slave
    // --------------------------------------------------------


    // 0x00:
    // master записал 6.
    //
    // 6 имеет младший бит 0,
    // поэтому slave должен сохранить AAAA_AAAA.

    $display(
        "REGISTER 0x00 = 0x%h",
        DUT.u_slave.register_with_some_name
    );

    if (DUT.u_slave.register_with_some_name == 32'hAAAA_AAAA)
        $display("REGISTER 0x00 TEST PASSED");
    else
        $display("REGISTER 0x00 TEST FAILED");


    // --------------------------------------------------------
    // 0x04 - дата
    // --------------------------------------------------------

    $display(
        "REGISTER 0x04 = 0x%h",
        DUT.u_slave.register_date
    );

    if (DUT.u_slave.register_date == 32'h2610_2026)
        $display("REGISTER 0x04 TEST PASSED");
    else
        $display("REGISTER 0x04 TEST FAILED");


    // --------------------------------------------------------
    // 0x08 - Ores
    // --------------------------------------------------------

    $display(
        "REGISTER 0x08 = 0x%h",
        DUT.u_slave.register_surname
    );

    if (DUT.u_slave.register_surname == 32'h4F72_6573)
        $display("REGISTER 0x08 TEST PASSED");
    else
        $display("REGISTER 0x08 TEST FAILED");


    // --------------------------------------------------------
    // 0x0C - Mari
    // --------------------------------------------------------

    $display(
        "REGISTER 0x0C = 0x%h",
        DUT.u_slave.register_name
    );

    if (DUT.u_slave.register_name == 32'h4D61_7269)
        $display("REGISTER 0x0C TEST PASSED");
    else
        $display("REGISTER 0x0C TEST FAILED");


    $display("");
    $display("============================================");
    $display("END MASTER + SLAVE TEST");
    $display("============================================");


    repeat (5)
        @(posedge pclk);

    $stop;

end


endmodule