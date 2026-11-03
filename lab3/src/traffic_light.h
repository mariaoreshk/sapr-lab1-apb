#ifndef TRAFFIC_LIGHT_H
#define TRAFFIC_LIGHT_H

#include <stdint.h>

/* Two equal roads, three lanes per road; each road has one signal group. */
enum traffic_signal {
    TRAFFIC_A_RED    = 1u << 0,
    TRAFFIC_A_YELLOW = 1u << 1,
    TRAFFIC_A_GREEN  = 1u << 2,
    TRAFFIC_B_RED    = 1u << 3,
    TRAFFIC_B_YELLOW = 1u << 4,
    TRAFFIC_B_GREEN  = 1u << 5
};

enum traffic_phase {
    TRAFFIC_STARTUP,
    TRAFFIC_A_GO,
    TRAFFIC_A_WAIT,
    TRAFFIC_CLEAR_A_TO_B,
    TRAFFIC_B_GO,
    TRAFFIC_B_WAIT,
    TRAFFIC_CLEAR_B_TO_A,
    TRAFFIC_PHASE_COUNT
};

struct traffic_light {
    enum traffic_phase phase;
    uint32_t elapsed_ms;
};

void traffic_light_init(struct traffic_light *light);

/* Call once per elapsed millisecond. This function never waits or accesses PIO. */
void traffic_light_tick(struct traffic_light *light);

/* Bits 0..5 are active high; reserved bits 6..7 are always zero. */
uint8_t traffic_light_output(const struct traffic_light *light);

#endif
