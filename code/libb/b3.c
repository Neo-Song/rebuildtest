#include <stdio.h>
#include "libb.h"

void libb_status(void) {
    printf("libb status: OK\n");
}

void libb_summary(void) {
    printf("=== libb Summary ===\n");
    printf("ID: %d\n", libb_get_id());
    printf("Char: %c\n", libb_get_char());
    liba_dump_info();  // Use liba's info dump
    printf("===================\n");
}

// New function that uses liba's validation
int libb_with_liba_validation(int value) {
    printf("libb: validating value using liba...\n");
    return liba_validate(value);
}
