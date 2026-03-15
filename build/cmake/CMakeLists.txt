cmake_minimum_required(VERSION 3.15)
project(rebuildtest C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# 编译类型
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# 项目根目录
set(PROJECT_ROOT $ENV{PROJECT_ROOT})

# 输出目录 - libraries to libs/, executables to tar/
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${PROJECT_ROOT}/libs)
set(LIBRARY_OUTPUT_DIRECTORY ${PROJECT_ROOT}/libs)
set(RUNTIME_OUTPUT_DIRECTORY ${PROJECT_ROOT}/tar)

# 包含各子目录的 CMake 配置
add_subdirectory(${PROJECT_ROOT}/build/cmake/liba)
add_subdirectory(${PROJECT_ROOT}/build/cmake/libb)
add_subdirectory(${PROJECT_ROOT}/build/cmake/main)
