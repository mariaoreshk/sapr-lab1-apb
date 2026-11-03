#include <stdio.h>
#include <stdlib.h>
#include "traffic_light.h"

static unsigned long checks;

#define CHECK(condition) do { \
    checks++; \
    if (!(condition)) { \
        fprintf(stderr, "FAIL at line %d: %s\n", __LINE__, #condition); \
        exit(EXIT_FAILURE); \
    } \
} while (0)

/* Expected signals and durations come from the phase specification. */
static const struct {
    enum traffic_phase phase;
    uint8_t signals;
    unsigned int duration_ms;
} schedule[] = {
    { TRAFFIC_STARTUP,      0x09u,  1000u },
    { TRAFFIC_A_GO,         0x0cu, 10000u },
    { TRAFFIC_A_WAIT,       0x0au,  3000u },
    { TRAFFIC_CLEAR_A_TO_B, 0x09u,  1000u },
    { TRAFFIC_B_GO,         0x21u, 10000u },
    { TRAFFIC_B_WAIT,       0x11u,  3000u },
    { TRAFFIC_CLEAR_B_TO_A, 0x09u,  1000u }
};

static void check_boundaries(void)
{
    struct traffic_light light;
    unsigned int phase, ms;

    traffic_light_init(&light);
    for (phase = 0u; phase < sizeof(schedule) / sizeof(schedule[0]); phase++) {
        CHECK(light.phase == schedule[phase].phase);
        CHECK(light.elapsed_ms == 0u);
        for (ms = 0u; ms < schedule[phase].duration_ms; ms++) {
            CHECK(light.phase == schedule[phase].phase);
            CHECK(traffic_light_output(&light) == schedule[phase].signals);
            traffic_light_tick(&light);
        }
    }
    CHECK(light.phase == TRAFFIC_A_GO);
    CHECK(light.elapsed_ms == 0u);
    puts("PASS: startup, phase order, exact durations and output bits");
}

static void check_repeated_cycles(void)
{
    struct traffic_light light;
    unsigned long ms, green_a = 0u, green_b = 0u;
    const unsigned long cycles = 30u;

    traffic_light_init(&light);
    for (ms = 0u; ms < 1000u + cycles * 28000u; ms++) {
        uint8_t signals = traffic_light_output(&light);
        unsigned int a = signals & 7u;
        unsigned int b = (signals >> 3) & 7u;

        /* Exactly one colour per group; reserved bits stay clear. */
        CHECK(a == 1u || a == 2u || a == 4u);
        CHECK(b == 1u || b == 2u || b == 4u);
        CHECK((signals & 0xc0u) == 0u);
        CHECK(a == 1u || b == 1u);
        if (a == 4u) green_a++;
        if (b == 4u) green_b++;
        traffic_light_tick(&light);
    }
    CHECK(green_a == cycles * 10000u);
    CHECK(green_b == cycles * 10000u);
    CHECK(light.phase == TRAFFIC_A_GO);
    CHECK(light.elapsed_ms == 0u);
    puts("PASS: 30 cycles, conflicting signals excluded, equal green times");
}

static void check_reset(void)
{
    struct traffic_light light;
    unsigned int target, phase, ms;

    for (target = 0u; target < sizeof(schedule) / sizeof(schedule[0]); target++) {
        traffic_light_init(&light);
        for (phase = 0u; phase < target; phase++) {
            for (ms = 0u; ms < schedule[phase].duration_ms; ms++) {
                traffic_light_tick(&light);
            }
        }
        for (ms = 0u; ms < 123u; ms++) traffic_light_tick(&light);
        CHECK(light.phase == schedule[target].phase);
        traffic_light_init(&light);
        CHECK(light.phase == TRAFFIC_STARTUP);
        CHECK(light.elapsed_ms == 0u);
        CHECK(traffic_light_output(&light) == 0x09u);
        for (ms = 0u; ms < 999u; ms++) traffic_light_tick(&light);
        CHECK(light.phase == TRAFFIC_STARTUP);
        traffic_light_tick(&light);
        CHECK(light.phase == TRAFFIC_A_GO);
    }
    puts("PASS: reset from every phase restarts the 1-second all-red interval");
}

static void check_invalid_phase(void)
{
    struct traffic_light light;
    const int invalid[] = { -1, TRAFFIC_PHASE_COUNT, 100 };
    unsigned int i;

    for (i = 0u; i < sizeof(invalid) / sizeof(invalid[0]); i++) {
        light.phase = (enum traffic_phase)invalid[i];
        light.elapsed_ms = 500u;
        CHECK(traffic_light_output(&light) == 0x09u);
        traffic_light_tick(&light);
        CHECK(light.phase == TRAFFIC_STARTUP);
        CHECK(light.elapsed_ms == 0u);
    }
    puts("PASS: invalid phases show all red and restart safely");
}

int main(void)
{
    check_boundaries();
    check_repeated_cycles();
    check_reset();
    check_invalid_phase();
    printf("PASS: %lu checks\n", checks);
    return EXIT_SUCCESS;
}
