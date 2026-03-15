#include <stdio.h>
#include "libb.h"

void libb_print_name(void) {
    printf("Library B - libb\n");
}

void libb_start(void) {
    printf("libb started\n");
    liba_init();  // Use liba's initialization
}

int libb_get_id(void) {
    return 42;
}
