#include <stdio.h>
#include "liba.h"

void liba_cleanup(void) {
    printf("liba cleanup done\n");
}

void liba_dump_info(void) {
    printf("=== liba Info ===\n");
    printf("Version: %s\n", liba_version());
    printf("Build: CMake+Ninja\n");
    printf("==================\n");
}
