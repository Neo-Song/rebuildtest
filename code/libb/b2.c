#include <stdio.h>
#include "libb.h"

void libb_compute(int a, int b) {
    printf("libb compute: %d + %d = %d\n", a, b, a + b);
}

char libb_get_char(void) {
    return 'X';
}
