#ifndef LIBA_H
#define LIBA_H

void liba_print_name(void);
void liba_init(void);
const char* liba_version(void);
void liba_process_data(const char* data);
int liba_validate(int value);
void liba_cleanup(void);
void liba_dump_info(void);

#endif /* LIBA_H */
