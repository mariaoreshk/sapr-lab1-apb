module apb_slave
(
    input  logic        pclk,      // синхросигнал
    input  logic        presetn,   // сигнал сброса, активный 0
    input  logic [31:0] paddr,     // адрес обращения
    input  logic [31:0] pwdata,    // данные для записи
    input  logic        psel,      // выбор устройства
    input  logic        penable,   // активная фаза транзакции
    input  logic        pwrite,    // 1 - запись, 0 - чтение

    output logic        pready,    // устройство готово
    output logic        pslverr,   // ошибка обращения
    output logic [31:0] prdata     // данные при чтении
);


logic [31:0] register_with_some_name;


// Состояния конечного автомата APB
enum logic [1:0]
{
    APB_SETUP,
    APB_W_ENABLE,
    APB_R_ENABLE
} apb_st;


// Основная последовательная логика
always @(posedge pclk)
begin

    // Сброс
    if (!presetn)
    begin
        prdata                  <= '0;
        pslverr                 <= 1'b0;
        pready                  <= 1'b0;
        register_with_some_name <= 32'h0;
        apb_st                  <= APB_SETUP;
    end

    else
    begin

        case (apb_st)

            // -----------------------------
            // SETUP
            // -----------------------------
            APB_SETUP:
            begin : apb_setup_st

                prdata  <= '0;
                pready  <= 1'b0;
                pslverr <= 1'b0;

                // Если устройство выбрано и ещё не началась ENABLE-фаза
                if (psel && !penable)
                begin

                    // Запись
                    if (pwrite == 1'b1)
                    begin
                        apb_st <= APB_W_ENABLE;
                    end

                    // Чтение
                    else
                    begin
                        apb_st <= APB_R_ENABLE;
                    end

                end
            end


            // -----------------------------
            // WRITE ENABLE
            // -----------------------------
            APB_W_ENABLE:
            begin : apb_w_en_st

                if (psel && penable && pwrite)
                begin

                    pready <= 1'b1;

                    case (paddr[7:0])

                        8'h00:
                        begin
                            // Если младший бит записываемого значения равен 0,
                            // сохраняем AAAA_AAAA.
                            // Если равен 1 — сохраняем 5555_5555.

                            if (pwdata[0] == 1'b0)
                            begin
                                register_with_some_name <= 32'hAAAA_AAAA;
                            end
                            else
                            begin
                                register_with_some_name <= 32'h5555_5555;
                            end
                        end


                        8'h04:
                        begin
                            // Регистр пока не реализован
                        end


                        8'h08:
                        begin
                            // Регистр пока не реализован
                        end


                        default:
                        begin
                            pslverr <= 1'b1;
                        end

                    endcase

                    apb_st <= APB_SETUP;

                end
            end


            // -----------------------------
            // READ ENABLE
            // -----------------------------
            APB_R_ENABLE:
            begin : apb_r_en_st

                if (psel && penable && !pwrite)
                begin

                    pready <= 1'b1;

                    case (paddr[7:0])

                        8'h00:
                        begin
                            prdata <= register_with_some_name;
                        end


                        8'h04:
                        begin
                            // Чтение пока не реализовано
                        end


                        8'h08:
                        begin
                            // Чтение пока не реализовано
                        end


                        default:
                        begin
                            pslverr <= 1'b1;
                        end

                    endcase

                    apb_st <= APB_SETUP;

                end
            end


            default:
            begin
                pslverr <= 1'b1;
                apb_st  <= APB_SETUP;
            end

        endcase

    end
end


endmodule