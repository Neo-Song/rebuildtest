# libb 静态库 CMake 配置

set(LIBB_SOURCES
    ${PROJECT_ROOT}/code/libb/b1.c
    ${PROJECT_ROOT}/code/libb/b2.c
    ${PROJECT_ROOT}/code/libb/b3.c
)

add_library(libb STATIC ${LIBB_SOURCES})
set_target_properties(libb PROPERTIES
    OUTPUT_NAME "b"
    ARCHIVE_OUTPUT_DIRECTORY ${PROJECT_ROOT}/libs
)

target_include_directories(libb PUBLIC
    ${PROJECT_ROOT}/code/libb
    ${PROJECT_ROOT}/code/liba
)

target_link_libraries(libb liba)
