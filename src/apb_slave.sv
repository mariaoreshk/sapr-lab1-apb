module apb_slave
(
    input  logic        pclk,      // синхросигнал
    input  logic        presetn,   // сброс, активный уровень 0

    input  logic [31:0] paddr,     // адрес обращения
    input  logic [31:0] pwdata,    // данные для записи

    input  logic        psel,      // выбор slave
    input  logic        penable,   // активная фаза APB-транзакции
    input  logic        pwrite,    // 1 - запись, 0 - чтение

    output logic        pready,    // slave готов завершить транзакцию
    output logic        pslverr,   // ошибка обращения
    output logic [31:0] prdata     // данные при чтении
);


// ------------------------------------------------------------
// Регистры slave
// ------------------------------------------------------------

// Регистр по адресу 0x00.
// Для него действует специальная логика из пункта 8 задания:
// pwdata[0] = 0 -> AAAA_AAAA
// pwdata[0] = 1 -> 5555_5555
logic [31:0] register_with_some_name;


// Регистр по адресу 0x04.
// Здесь будет храниться дата.
logic [31:0] register_date;


// Регистр по адресу 0x08.
// Здесь будут храниться первые 4 буквы фамилии в ASCII.
logic [31:0] register_surname;


// Регистр по адресу 0x0C.
// Здесь будут храниться первые 4 буквы имени в ASCII.
logic [31:0] register_name;


// ------------------------------------------------------------
// Состояния конечного автомата APB slave
// ------------------------------------------------------------

typedef enum logic [1:0]
{
    APB_SETUP,
    APB_W_ENABLE,
    APB_R_ENABLE
} apb_state_t;

apb_state_t apb_st;


// ------------------------------------------------------------
// Основная последовательная логика
// ------------------------------------------------------------

always_ff @(posedge pclk)
begin

    // --------------------------------------------------------
    // Сброс
    // --------------------------------------------------------

    if (!presetn)
    begin

        prdata  <= 32'h0000_0000;
        pready  <= 1'b0;
        pslverr <= 1'b0;

        register_with_some_name <= 32'h0000_0000;
        register_date           <= 32'h0000_0000;
        register_surname        <= 32'h0000_0000;
        register_name           <= 32'h0000_0000;

        apb_st <= APB_SETUP;

    end

    else
    begin

        case (apb_st)


            // ====================================================
            // SETUP
            // ====================================================

            APB_SETUP:
            begin

                // По умолчанию slave ещё не завершает транзакцию
                pready <= 1'b0;

                // Очищаем ошибку предыдущего обращения
                pslverr <= 1'b0;

                // По умолчанию данные чтения очищаем
                prdata <= 32'h0000_0000;


                // Если master выбрал устройство
                // и находится в SETUP-фазе
                if (psel && !penable)
                begin

                    // pwrite = 1 -> операция записи
                    if (pwrite)
                    begin
                        apb_st <= APB_W_ENABLE;
                    end

                    // pwrite = 0 -> операция чтения
                    else
                    begin
                        apb_st <= APB_R_ENABLE;
                    end

                end

            end


            // ====================================================
            // WRITE ENABLE
            // ====================================================

            APB_W_ENABLE:
            begin

                // Проверяем, что действительно выполняется
                // ACCESS-фаза операции записи
                if (psel && penable && pwrite)
                begin

                    // Slave готов завершить транзакцию
                    pready <= 1'b1;


                    // Используем младшие 8 бит адреса,
                    // потому что нас интересуют смещения
                    // 0x00, 0x04, 0x08 и 0x0C.
                    case (paddr[7:0])


                        // ----------------------------------------
                        // Адрес 0x00
                        // ----------------------------------------

                        8'h00:
                        begin

                            // Специальная логика из пункта 8.
                            //
                            // ВАЖНО:
                            // проверяем непосредственно pwdata[0],
                            // то есть младший бит ЗАПИСЫВАЕМЫХ данных.

                            if (pwdata[0] == 1'b0)
                            begin
                                register_with_some_name
                                    <= 32'hAAAA_AAAA;
                            end

                            else
                            begin
                                register_with_some_name
                                    <= 32'h5555_5555;
                            end


`ifndef SYNTHESIS
                            $display(
                                "SLAVE WRITE: addr=0x%h data=0x%h -> special register",
                                paddr,
                                pwdata
                            );
`endif

                        end


                        // ----------------------------------------
                        // Адрес 0x04
                        // ----------------------------------------

                        8'h04:
                        begin

                            register_date <= pwdata;

`ifndef SYNTHESIS
                            $display(
                                "SLAVE WRITE: addr=0x%h date=0x%h",
                                paddr,
                                pwdata
                            );
`endif

                        end


                        // ----------------------------------------
                        // Адрес 0x08
                        // ----------------------------------------

                        8'h08:
                        begin

                            register_surname <= pwdata;

`ifndef SYNTHESIS
                            $display(
                                "SLAVE WRITE: addr=0x%h surname=0x%h",
                                paddr,
                                pwdata
                            );
`endif

                        end


                        // ----------------------------------------
                        // Адрес 0x0C
                        // ----------------------------------------

                        8'h0C:
                        begin

                            register_name <= pwdata;

`ifndef SYNTHESIS
                            $display(
                                "SLAVE WRITE: addr=0x%h name=0x%h",
                                paddr,
                                pwdata
                            );
`endif

                        end


                        // ----------------------------------------
                        // Неизвестный адрес
                        // ----------------------------------------

                        default:
                        begin

                            pslverr <= 1'b1;

`ifndef SYNTHESIS
                            $display(
                                "SLAVE ERROR: invalid write address 0x%h",
                                paddr
                            );
`endif

                        end

                    endcase


                    // После окончания ACCESS-фазы
                    // возвращаемся в SETUP.
                    apb_st <= APB_SETUP;

                end

            end


            // ====================================================
            // READ ENABLE
            // ====================================================

            APB_R_ENABLE:
            begin

                // ACCESS-фаза операции чтения
                if (psel && penable && !pwrite)
                begin

                    pready <= 1'b1;


                    case (paddr[7:0])


                        // ----------------------------------------
                        // Чтение 0x00
                        // ----------------------------------------

                        8'h00:
                        begin

                            prdata <= register_with_some_name;

`ifndef SYNTHESIS
                            $display(
                                "SLAVE READ: addr=0x%h special register=0x%h",
                                paddr,
                                register_with_some_name
                            );
`endif

                        end


                        // ----------------------------------------
                        // Чтение 0x04
                        // ----------------------------------------

                        8'h04:
                        begin

                            prdata <= register_date;

`ifndef SYNTHESIS
                            $display(
                                "SLAVE READ: addr=0x%h date=0x%h",
                                paddr,
                                register_date
                            );
`endif

                        end


                        // ----------------------------------------
                        // Чтение 0x08
                        // ----------------------------------------

                        8'h08:
                        begin

                            prdata <= register_surname;

`ifndef SYNTHESIS
                            $display(
                                "SLAVE READ: addr=0x%h surname=0x%h",
                                paddr,
                                register_surname
                            );
`endif

                        end


                        // ----------------------------------------
                        // Чтение 0x0C
                        // ----------------------------------------

                        8'h0C:
                        begin

                            prdata <= register_name;

`ifndef SYNTHESIS
                            $display(
                                "SLAVE READ: addr=0x%h name=0x%h",
                                paddr,
                                register_name
                            );
`endif

                        end


                        // ----------------------------------------
                        // Неизвестный адрес
                        // ----------------------------------------

                        default:
                        begin

                            prdata  <= 32'h0000_0000;
                            pslverr <= 1'b1;

`ifndef SYNTHESIS
                            $display(
                                "SLAVE ERROR: invalid read address 0x%h",
                                paddr
                            );
`endif

                        end

                    endcase


                    apb_st <= APB_SETUP;

                end

            end


            // ====================================================
            // Защита от некорректного состояния автомата
            // ====================================================

            default:
            begin

                apb_st  <= APB_SETUP;
                pslverr <= 1'b1;

            end


        endcase

    end

end


endmodule