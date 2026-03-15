#include <stdio.h>
#include "liba.h"

void liba_print_name(void) {
    printf("Library A - liba\n");
}

void liba_init(void) {
    printf("liba initialized\n");
}

const char* liba_version(void) {
    return "1.0.0";
}
// Modified for testing
