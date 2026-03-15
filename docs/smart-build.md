# Smart Build - 智能增量编译指南

本文档详细介绍如何使用 CMake + Ninja 实现智能增量编译，包括依赖链追踪和自动重新编译功能。

## 目录

1. [项目概述](#项目概述)
2. [构建系统](#构建系统)
3. [智能增量编译原理](#智能增量编译原理)
4. [依赖链追踪](#依赖链追踪)
5. [使用指南](#使用指南)
6. [Ninja 进阶](#ninja-进阶)

---

## 项目概述

### 项目结构

```
rebuildtest/
├── CMakeLists.txt          # CMake 主配置
├── code/
│   ├── main/main.c         # 主程序
│   ├── liba/               # 静态库 A (无依赖)
│   │   ├── a1.c, a2.c, a3.c
│   │   └── liba.h
│   └── libb/               # 静态库 B (依赖 liba)
│       ├── b1.c, b2.c, b3.c
│       └── libb.h
├── build/
│   └── rebuild.sh          # 智能增量编译脚本
└── libs/                   # 编译输出的静态库
    ├── liba.a
    └── libb.a
```

### 依赖关系

```
main
├── liba (无依赖)
└── libb (依赖 liba)
```

---

## 构建系统

### CMake 配置

```cmake
cmake_minimum_required(VERSION 3.15)
project(rebuildtest C)

# 输出目录
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/libs)

# 头文件目录
include_directories(${CMAKE_SOURCE_DIR}/code/liba)
include_directories(${CMAKE_SOURCE_DIR}/code/libb)

# 构建 liba (无依赖)
add_library(liba STATIC
    ${CMAKE_SOURCE_DIR}/code/liba/a1.c
    ${CMAKE_SOURCE_DIR}/code/liba/a2.c
    ${CMAKE_SOURCE_DIR}/code/liba/a3.c
)

# 构建 libb (依赖 liba)
add_library(libb STATIC
    ${CMAKE_SOURCE_DIR}/code/libb/b1.c
    ${CMAKE_SOURCE_DIR}/code/libb/b2.c
    ${CMAKE_SOURCE_DIR}/code/libb/b3.c
)
target_link_libraries(libb liba)  # libb 依赖 liba

# 构建主程序
add_executable(main ${CMAKE_SOURCE_DIR}/code/main/main.c)
target_link_libraries(main liba libb)
```

### 编译命令

```bash
# 配置 + 编译
cd build
cmake -G Ninja -DCMAKE_BUILD_TYPE=Release ..
ninja
```

---

## 智能增量编译原理

### 为什么需要智能编译？

- **加速开发**：只编译变化的代码
- **依赖追踪**：当依赖库变化时，下游库也要重新编译
- **缓存复用**：未变化的库直接使用已编译的版本

### 实现思路

```bash
# 核心算法
1. 计算库源码的 SHA256 哈希
2. 与保存的历史哈希对比
3. 哈希变化 → 需要重新编译
4. 哈希一致 → 使用缓存
```

### 依赖链哈希计算

```
计算 libb 的哈希时，需要包含：
  ├── libb 自身的源文件 (b1.c, b2.c, b3.c, libb.h)
  └── libb 依赖的 liba 源文件 (a1.c, a2.c, a3.c, liba.h)
```

### 脚本实现

```bash
#!/bin/bash
# rebuild.sh - 智能增量编译脚本

# 依赖配置
LIB_DEPS="
a:
b:a
"

# 计算库的哈希（包含传递依赖）
calculate_lib_hash() {
    local libname="$1"
    local all_files=""
    
    # 1. 自身源文件
    all_files="$all_files $(find code/lib${libname} -name '*.c' -o -name '*.h')"
    
    # 2. 传递依赖的源文件
    for dep in $(get_all_deps "$libname"); do
        all_files="$all_files $(find code/lib${dep} -name '*.c' -o -name '*.h')"
    done
    
    # 3. 计算哈希
    echo "$all_files" | xargs cat | shasum -a 256 | cut -d' ' -f1
}

# 检查是否需要重新编译
check_needs_rebuild() {
    local libname="$1"
    local current_hash=$(calculate_lib_hash "$libname")
    local saved_hash=$(cat .hash/${libname}.hash 2>/dev/null)
    
    if [ "$current_hash" != "$saved_hash" ]; then
        return 0  # 需要重新编译
    fi
    return 1  # 使用缓存
}
```

---

## 依赖链追踪

### 传递依赖检测

当 liba 发生变化时，libb 也会自动重新编译：

```bash
# 修改 liba 源码
echo "// test" >> code/liba/a1.c

# 重新编译
./build/rebuild.sh

# 输出：
# [WARN] liba: Source changed, rebuilding...
# [INFO] Building library: liba
# [WARN] libb: Dependency changed (deps: a), rebuilding...
# [INFO] Building library: libb
```

### 扩展更多依赖

未来添加 libc 依赖 libb 和 liba：

```bash
# 在配置中添加：
LIB_DEPS="
a:
b:a
c:b,a
"

# 脚本会自动计算传递依赖
# 计算 libc 哈希时包含：libc + libb + liba
```

---

## 使用指南

### 基本命令

```bash
# 智能增量编译
./build/rebuild.sh

# 编译并运行
./build/rebuild.sh run

# 查看状态
./build/rebuild.sh status

# 清理构建
./build/rebuild.sh clean

# 强制重新编译
./build/rebuild.sh rebuild

# 查看依赖图
./build/rebuild.sh deps
```

### 状态输出示例

```
=== Library Status (with dependencies) ===
liba        [no deps] built  up-to-date
libb        [deps:a] built  up-to-date
```

---

## Ninja 进阶

### 判断是否需要重新编译

```bash
# Dry-run 模式（不实际编译）
ninja -n

# 输出示例（无变化时）：
ninja: no work to do.

# 输出示例（有变化时）：
[1/3] Building C object CMakeFiles/liba.dir/code/liba/a2.c.o
[2/3] Linking C static library libs/liba.a
[3/3] Linking C executable main
```

### Ninja 内部机制

| 文件 | 作用 |
|------|------|
| `.ninja_log` | 编译历史记录 |
| `.ninja_deps` | 依赖关系追踪 |
| `build.ninja` | 构建规则 |

### 查看依赖关系

```bash
# 列出所有目标
ninja -t targets

# 查看构建规则
ninja -t rules

# 详细模式
ninja -v -n  # verbose dry-run
```

---

## 总结

### 核心优势

1. **自动依赖追踪**：修改 liba → libb 自动重建
2. **传递依赖计算**：计算哈希时包含所有依赖
3. **增量编译**：只编译变化的代码
4. **易于扩展**：添加新库只需修改配置

### 扩展建议

- 添加动态库支持
- 支持更多构建系统（Make, Meson）
- 集成 CI/CD 流程
- 添加并行编译优化

---

**项目地址**: https://github.com/Neo-Song/rebuildtest
