#include <stdio.h>
#include "libb.h"

void libb_compute(int a, int b) {
    printf("libb compute: %d + %d = %d\n", a, b, a + b);
    // Use liba's data processing
    liba_process_data("data from libb");
}

char libb_get_char(void) {
    return 'X';
}
