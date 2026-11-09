#include "system.h"
#include "altera_avalon_pio_regs.h"
#include "altera_avalon_timer_regs.h"

#ifdef LAB3_FAST_SIMULATION
#define TICKS_PER_SECOND 1u
#else
#define TICKS_PER_SECOND 1000u
#endif

/* Вариант 6. Две равнозначные дороги, по три полосы на каждой. */
enum {
    A_RED    = 1u << 0,
    A_YELLOW = 1u << 1,
    A_GREEN  = 1u << 2,
    B_RED    = 1u << 3,
    B_YELLOW = 1u << 4,
    B_GREEN  = 1u << 5
};

/* На плате таймер даёт 1000 отсчётов в секунду. */
static void show_lights(unsigned int lights, unsigned int ticks)
{
    IOWR_ALTERA_AVALON_PIO_DATA(LEDS_BASE, lights);
    while (ticks > 0) {
        while (!(IORD_ALTERA_AVALON_TIMER_STATUS(TIMER_BASE) &
                 ALTERA_AVALON_TIMER_STATUS_TO_MSK)) {
        }
        IOWR_ALTERA_AVALON_TIMER_STATUS(TIMER_BASE, 0);
        --ticks;
    }
}

int main(void)
{
    IOWR_ALTERA_AVALON_TIMER_STATUS(TIMER_BASE, 0);
    IOWR_ALTERA_AVALON_TIMER_CONTROL(TIMER_BASE,
        ALTERA_AVALON_TIMER_CONTROL_CONT_MSK |
        ALTERA_AVALON_TIMER_CONTROL_START_MSK);

    show_lights(A_RED | B_RED, TICKS_PER_SECOND);
    for (;;) {
        show_lights(A_GREEN  | B_RED,    10u * TICKS_PER_SECOND);
        show_lights(A_YELLOW | B_RED,     3u * TICKS_PER_SECOND);
        show_lights(A_RED    | B_RED,          TICKS_PER_SECOND);
        show_lights(A_RED    | B_GREEN,  10u * TICKS_PER_SECOND);
        show_lights(A_RED    | B_YELLOW,  3u * TICKS_PER_SECOND);
        show_lights(A_RED    | B_RED,          TICKS_PER_SECOND);
    }
}
