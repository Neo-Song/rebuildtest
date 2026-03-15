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
    
    // Call libb functions (libb now depends on liba)
    printf("--- Calling libb functions (libb depends on liba) ---\n");
    libb_print_name();
    libb_start();
    libb_compute(10, 20);
    libb_summary();
    
    // Test new function that uses liba's validation
    printf("--- Testing libb with liba dependency ---\n");
    int result = libb_with_liba_validation(100);
    printf("Validation result: %d\n", result);
    printf("\n");
    
    printf("=== Program completed successfully ===\n");
    return 0;
}
