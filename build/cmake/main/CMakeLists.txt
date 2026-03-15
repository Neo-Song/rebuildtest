# main 主程序 CMake 配置

set(MAIN_SOURCES
    ${PROJECT_ROOT}/code/main/main.c
)

add_executable(main ${MAIN_SOURCES})

set_target_properties(main PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${PROJECT_ROOT}/tar
)

target_include_directories(main PRIVATE
    ${PROJECT_ROOT}/code/liba
    ${PROJECT_ROOT}/code/libb
)

target_link_libraries(main 
    ${PROJECT_ROOT}/tar/liba.a
    ${PROJECT_ROOT}/tar/libb.a
)
