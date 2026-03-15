#ifndef LIBB_H
#define LIBB_H

#include "liba.h"  // libb depends on liba

void libb_print_name(void);
void libb_start(void);
int libb_get_id(void);
void libb_compute(int a, int b);
char libb_get_char(void);
void libb_status(void);
void libb_summary(void);

// New: Use liba's functions
int libb_with_liba_validation(int value);

#endif /* LIBB_H */
