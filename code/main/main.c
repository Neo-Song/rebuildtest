#include <stdio.h>
#include "liba.h"
#include "libb.h"

int main(int argc, char* argv[]) {
    printf("=== rebuildtest Main Program ===\n\n");
    
    // Call liba functions
    printf("--- Calling liba functions ---\n");
    liba_print_name();
    liba_init();
    liba_process_data("test data");
    liba_dump_info();
    printf("\n");
    
    // Call libb functions
    printf("--- Calling libb functions ---\n");
    libb_print_name();
    libb_start();
    libb_compute(10, 20);
    libb_summary();
    printf("\n");
    
    printf("=== Program completed successfully ===\n");
    return 0;
}
