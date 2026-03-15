cmake_minimum_required(VERSION 3.15)
project(rebuildtest C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Output directories
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/libs)
set(LIBRARY_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/libs)

# Include directories
include_directories(${CMAKE_SOURCE_DIR}/code/liba)
include_directories(${CMAKE_SOURCE_DIR}/code/libb)

# Build liba
add_library(liba STATIC
    ${CMAKE_SOURCE_DIR}/code/liba/a1.c
    ${CMAKE_SOURCE_DIR}/code/liba/a2.c
    ${CMAKE_SOURCE_DIR}/code/liba/a3.c
)
set_target_properties(liba PROPERTIES OUTPUT_NAME "a")

# Build libb
add_library(libb STATIC
    ${CMAKE_SOURCE_DIR}/code/libb/b1.c
    ${CMAKE_SOURCE_DIR}/code/libb/b2.c
    ${CMAKE_SOURCE_DIR}/code/libb/b3.c
)
set_target_properties(libb PROPERTIES OUTPUT_NAME "b")

# Build main executable
add_executable(main ${CMAKE_SOURCE_DIR}/code/main/main.c)

# Link libraries
target_link_libraries(main liba libb)
