#include <stdio.h>
#include "libb.h"

void libb_status(void) {
    printf("libb status: OK\n");
}

void libb_summary(void) {
    printf("=== libb Summary ===\n");
    printf("ID: %d\n", libb_get_id());
    printf("Char: %c\n", libb_get_char());
    printf("===================\n");
}
