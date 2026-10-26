# Лабораторная работа по САПР

## Автор

ФИО: Орешкина Мария

Группа: М3О-409Б-23

## Описание проекта

В рамках лабораторной работы реализована система обмена данными по интерфейсу APB на языке SystemVerilog.

Проект содержит:

- APB Master;
- APB Slave;
- модуль верхнего уровня;
- testbench для проверки APB Slave;
- testbench для проверки совместной работы APB Master и APB Slave.

Проект был проверен с помощью ModelSim и синтезирован в Quartus II.

## Структура проекта

```text
src/
    apb_master.sv
    apb_slave.sv
    apb_top.sv

tb/
    tb.sv
    tb_top.sv