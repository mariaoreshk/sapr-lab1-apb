#include "traffic_light.h"

/* Timing assumptions: green 10 s, yellow 3 s, all-red interval 1 s. */
static const uint32_t phase_duration_ms[TRAFFIC_PHASE_COUNT] = {
    1000u, 10000u, 3000u, 1000u, 10000u, 3000u, 1000u
};

void traffic_light_init(struct traffic_light *light)
{
    light->phase = TRAFFIC_STARTUP;
    light->elapsed_ms = 0u;
}

void traffic_light_tick(struct traffic_light *light)
{
    /* При недопустимой фазе восстанавливается начальное состояние. */
    if ((unsigned int)light->phase >= TRAFFIC_PHASE_COUNT) {
        traffic_light_init(light);
        return;
    }

    light->elapsed_ms++;
    /* Переход выполняется после окончания текущей фазы. */
    if (light->elapsed_ms >= phase_duration_ms[light->phase]) {
        light->elapsed_ms = 0u;
        /* После завершающей паузы цикл повторяется без стартовой фазы. */
        if (light->phase == TRAFFIC_CLEAR_B_TO_A) {
            light->phase = TRAFFIC_A_GO;
        } else {
            light->phase = (enum traffic_phase)(light->phase + 1);
        }
    }
}

uint8_t traffic_light_output(const struct traffic_light *light)
{
    switch (light->phase) {
    case TRAFFIC_A_GO:
        return TRAFFIC_A_GREEN | TRAFFIC_B_RED;
    case TRAFFIC_A_WAIT:
        return TRAFFIC_A_YELLOW | TRAFFIC_B_RED;
    case TRAFFIC_B_GO:
        return TRAFFIC_A_RED | TRAFFIC_B_GREEN;
    case TRAFFIC_B_WAIT:
        return TRAFFIC_A_RED | TRAFFIC_B_YELLOW;
    default:
        /* Startup, clearance intervals and invalid phases all show red. */
        return TRAFFIC_A_RED | TRAFFIC_B_RED;
    }
}
