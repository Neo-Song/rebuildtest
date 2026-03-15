# liba 静态库 CMake 配置

set(LIBA_SOURCES
    ${PROJECT_ROOT}/code/liba/a1.c
    ${PROJECT_ROOT}/code/liba/a2.c
    ${PROJECT_ROOT}/code/liba/a3.c
)

add_library(liba STATIC ${LIBA_SOURCES})
set_target_properties(liba PROPERTIES
    OUTPUT_NAME "a"
    ARCHIVE_OUTPUT_DIRECTORY ${PROJECT_ROOT}/libs
)

target_include_directories(liba PUBLIC
    ${PROJECT_ROOT}/code/liba
)
