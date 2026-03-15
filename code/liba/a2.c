#include <stdio.h>
#include "liba.h"

void liba_process_data(const char* data) {
    printf("liba processing: %s\n", data);
}

int liba_validate(int value) {
    return value > 0 ? 1 : 0;
}
