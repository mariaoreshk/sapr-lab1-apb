module apb_master
(
    input  logic        pclk,
    input  logic        presetn,

    // Ответные сигналы от APB slave
    input  logic        pready,
    input  logic        pslverr,

    // Управляющие сигналы APB
    output logic [31:0] paddr,
    output logic [31:0] pwdata,
    output logic        psel,
    output logic        penable,
    output logic        pwrite,

    // Признак завершения всех операций
    output logic        done
);


// ------------------------------------------------------------
// Базовый адрес APB slave
// ------------------------------------------------------------

localparam logic [31:0] DEVICE_BASE = 32'h7000_0000;


// ------------------------------------------------------------
// Персональные данные
// ------------------------------------------------------------

// Номер в списке = 6
localparam logic [31:0] STUDENT_NUMBER = 32'd6;


// Дата выполнения лабораторной = 26.10.2026
// Представление DDMMYYYY
localparam logic [31:0] DATE_VALUE = 32'h2610_2026;


// "Ores" в ASCII:
// O = 4F
// r = 72
// e = 65
// s = 73
localparam logic [31:0] SURNAME_VALUE = 32'h4F72_6573;


// "Mari" в ASCII:
// M = 4D
// a = 61
// r = 72
// i = 69
localparam logic [31:0] NAME_VALUE = 32'h4D61_7269;


// ------------------------------------------------------------
// Состояния автомата APB master
// ------------------------------------------------------------

typedef enum logic [1:0]
{
    MASTER_IDLE,
    MASTER_SETUP,
    MASTER_ACCESS,
    MASTER_DONE
} master_state_t;

master_state_t state;


// ------------------------------------------------------------
// Номер текущей транзакции
//
// 0 -> номер в списке
// 1 -> дата
// 2 -> фамилия
// 3 -> имя
// ------------------------------------------------------------

logic [1:0] transaction_number;


// ------------------------------------------------------------
// Формирование адреса и данных
// ------------------------------------------------------------

always_comb
begin

    // Значения по умолчанию
    paddr  = 32'h0000_0000;
    pwdata = 32'h0000_0000;


    case (transaction_number)


        // ----------------------------------------------------
        // Транзакция 0:
        // номер в списке
        // ----------------------------------------------------

        2'd0:
        begin

            paddr  = DEVICE_BASE + 32'h00;
            pwdata = STUDENT_NUMBER;

        end


        // ----------------------------------------------------
        // Транзакция 1:
        // дата
        // ----------------------------------------------------

        2'd1:
        begin

            paddr  = DEVICE_BASE + 32'h04;
            pwdata = DATE_VALUE;

        end


        // ----------------------------------------------------
        // Транзакция 2:
        // фамилия
        // ----------------------------------------------------

        2'd2:
        begin

            paddr  = DEVICE_BASE + 32'h08;
            pwdata = SURNAME_VALUE;

        end


        // ----------------------------------------------------
        // Транзакция 3:
        // имя
        // ----------------------------------------------------

        2'd3:
        begin

            paddr  = DEVICE_BASE + 32'h0C;
            pwdata = NAME_VALUE;

        end


        default:
        begin

            paddr  = 32'h0000_0000;
            pwdata = 32'h0000_0000;

        end


    endcase

end


// ------------------------------------------------------------
// Конечный автомат APB master
// ------------------------------------------------------------

always_ff @(posedge pclk)
begin

    // --------------------------------------------------------
    // Сброс
    // --------------------------------------------------------

    if (!presetn)
    begin

        state <= MASTER_IDLE;

        transaction_number <= 2'd0;

        psel    <= 1'b0;
        penable <= 1'b0;
        pwrite  <= 1'b0;

        done <= 1'b0;

    end

    else
    begin

        case (state)


            // ====================================================
            // IDLE
            // ====================================================

            MASTER_IDLE:
            begin

                psel    <= 1'b0;
                penable <= 1'b0;
                pwrite  <= 1'b0;

                done <= 1'b0;

                transaction_number <= 2'd0;

                // Начинаем первую транзакцию
                state <= MASTER_SETUP;

            end


            // ====================================================
            // SETUP
            // ====================================================

            MASTER_SETUP:
            begin

                // APB SETUP:
                //
                // PSEL = 1
                // PENABLE = 0

                psel    <= 1'b1;
                penable <= 1'b0;

                // Выполняем запись
                pwrite <= 1'b1;

                state <= MASTER_ACCESS;

            end


            // ====================================================
            // ACCESS
            // ====================================================

            MASTER_ACCESS:
            begin

                // APB ACCESS:
                //
                // PSEL = 1
                // PENABLE = 1

                psel    <= 1'b1;
                penable <= 1'b1;
                pwrite  <= 1'b1;


                // Ждём ответ slave
                if (pready)
                begin

                    // --------------------------------------------
                    // Проверяем ошибку slave
                    // --------------------------------------------

                    if (pslverr)
                    begin

`ifndef SYNTHESIS
                        $display(
                            "MASTER ERROR: address=0x%h data=0x%h",
                            paddr,
                            pwdata
                        );
`endif

                    end

                    else
                    begin

`ifndef SYNTHESIS
                        $display(
                            "MASTER WRITE: address=0x%h data=0x%h",
                            paddr,
                            pwdata
                        );
`endif

                    end


                    // --------------------------------------------
                    // Последняя транзакция?
                    // --------------------------------------------

                    if (transaction_number == 2'd3)
                    begin

                        // Все четыре операции выполнены
                        psel    <= 1'b0;
                        penable <= 1'b0;
                        pwrite  <= 1'b0;

                        state <= MASTER_DONE;

                    end

                    else
                    begin

                        // Переходим к следующей операции
                        transaction_number
                            <= transaction_number + 1'b1;

                        psel    <= 1'b0;
                        penable <= 1'b0;

                        state <= MASTER_SETUP;

                    end

                end

            end


            // ====================================================
            // DONE
            // ====================================================

            MASTER_DONE:
            begin

                psel    <= 1'b0;
                penable <= 1'b0;
                pwrite  <= 1'b0;

                done <= 1'b1;

            end


            // ====================================================
            // Защита
            // ====================================================

            default:
            begin

                state <= MASTER_IDLE;

                psel    <= 1'b0;
                penable <= 1'b0;
                pwrite  <= 1'b0;

                done <= 1'b0;

            end


        endcase

    end

end


endmodule