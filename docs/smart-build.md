# Smart Build - 智能增量编译指南

本文档详细介绍如何使用 CMake + Ninja 实现智能增量编译，包括依赖链追踪和自动重新编译功能。

## 目录

1. [项目概述](#项目概述)
2. [构建系统](#构建系统)
3. [智能增量编译原理](#智能增量编译原理)
4. [依赖链追踪](#依赖链追踪)
5. [使用指南](#使用指南)
6. [Ninja 进阶](#ninja-进阶)
7. [CMake 进阶技巧](#cmake-进阶技巧)

---

## 项目概述

### 项目结构

```
rebuildtest/
├── code/                    # 源代码
│   ├── main/main.c          # 主程序
│   ├── liba/               # 静态库 A (无依赖)
│   │   ├── a1.c, a2.c, a3.c
│   │   └── liba.h
│   └── libb/               # 静态库 B (依赖 liba)
│       ├── b1.c, b2.c, b3.c
│       └── libb.h
│
├── libs/                    # 编译产物 + Hash（推送到 GitHub）
│   ├── liba.a              # 预编译的 liba
│   ├── liba.hash          # liba 源码 hash
│   ├── libb.a             # 预编译的 libb
│   ├── libb.hash          # libb 源码 hash（含依赖）
│   └── (tmp/)             # 不推送，临时构建
│
├── tar/                    # 临时构建目录（Git 忽略）
│   ├── main               # 可执行文件
│   └── tmp/               # CMake 中间文件
│       ├── liba/          # liba 构建目录
│       ├── libb/          # libb 构建目录
│       └── main/          # main 构建目录
│
└── build/                  # 构建脚本
    ├── cmake/             # CMake 配置
    │   ├── CMakeLists.txt
    │   ├── liba/          # liba CMake 配置
    │   ├── libb/          # libb CMake 配置
    │   └── main/          # main CMake 配置
    ├── libbuild.sh        # 单独编译库的脚本
    └── smartbuild.sh      # 智能编译主程序脚本
```

### 依赖关系

```
main
├── liba (无依赖)
└── libb (依赖 liba)
```

### 目录用途说明

| 目录 | 用途 | 是否推送 GitHub |
|------|------|----------------|
| code/ | 源代码 | ✅ 是 |
| libs/ | 编译产物 + Hash | ✅ 是 |
| tar/ | 临时构建文件 | ❌ 否 |
| build/ | 构建脚本 | ✅ 是 |

---

## 构建系统

### 独立 CMake 配置

每个库有独立的 CMakeLists.txt，实现分离构建：

**build/cmake/liba/CMakeLists.txt**
```cmake
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
```

**build/cmake/libb/CMakeLists.txt**
```cmake
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

target_link_libraries(libb liba)  # libb 依赖 liba
```

**build/cmake/main/CMakeLists.txt**
```cmake
# main 主程序 CMake 配置

set(MAIN_SOURCES
    ${PROJECT_ROOT}/code/main/main.c
)

add_executable(main ${MAIN_SOURCES})

set_target_properties(main PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${PROJECT_ROOT}/tar  # 输出到 tar/
)

target_include_directories(main PRIVATE
    ${PROJECT_ROOT}/code/liba
    ${PROJECT_ROOT}/code/libb
)

target_link_libraries(main 
    ${PROJECT_ROOT}/libs/liba.a   # 从 libs/ 链接
    ${PROJECT_ROOT}/libs/libb.a
)
```

### 编译命令

```bash
# 方式 1：使用 smartbuild.sh（推荐）
./build/smartbuild.sh

# 方式 2：单独编译某个库
./build/libbuild.sh liba
./build/libbuild.sh libb
```

---

## 智能增量编译原理

### 为什么需要智能编译？

- **加速开发**：只编译变化的代码
- **依赖追踪**：当依赖库变化时，下游库也要重新编译
- **缓存复用**：未变化的库直接使用已编译的版本
- **团队协作**：推送预编译库到 GitHub，他人可直接使用

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
  └── libb 依赖的 liba 源文件 (a1.c, a2.c, a3.c, liba.h)  ← 传递依赖
```

### 脚本实现

**smartbuild.sh - 智能编译主程序**
```bash
# 依赖配置
LIBS=("liba" "libb")
LIB_DEPS["libb"]="liba"  # libb 依赖 liba

# 计算库的哈希（包含传递依赖）
calculate_lib_hash() {
    local libname="$1"
    
    # 传递依赖 (先加依赖，再加自身)
    if [ "$libname" = "libb" ]; then
        all_files=$(find "$PROJECT_DIR/code/liba" "$lib_dir" -name "*.c" -o -name "*.h" | sort | xargs cat | shasum -a 256)
    else
        all_files=$(find "$lib_dir" -name "*.c" -o -name "*.h" | sort | xargs cat | shasum -a 256)
    fi
}

# 检查是否需要重新编译
check_lib_needs_rebuild() {
    local current_hash=$(calculate_lib_hash "$libname")
    local saved_hash=$(cat "libs/${libname}.hash")
    
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
./build/smartbuild.sh

# 输出：
# [WARN] liba needs rebuild
# [INFO] Building liba...
# [WARN] libb needs rebuild    ← 因为依赖 liba 也需要重编
# [INFO] Building libb...
```

### 扩展更多依赖

未来添加 libc 依赖 libb 和 liba：

```bash
# 在 libbuild.sh / smartbuild.sh 中添加：
LIBS=("liba" "libb" "libc")
LIB_DEPS["libb"]="liba"
LIB_DEPS["libc"]="libb,liba"  # libc 依赖 libb 和 liba

# 脚本会自动计算传递依赖
# 计算 libc 哈希时包含：libc + libb + liba
```

---

## 使用指南

### 基本命令

```bash
# 智能增量编译（自动检测是否需要重编）
./build/smartbuild.sh

# 编译并运行
./build/smartbuild.sh run

# 清理临时文件（保留 libs/）
./build/smartbuild.sh clean

# 强制重新编译所有
./build/smartbuild.sh rebuild

# 单独编译某个库
./build/libbuild.sh liba
./build/libbuild.sh libb

# 清理某个库
./build/libbuild.sh liba clean
```

### 工作流程

**开发者 A（修改代码后）：**
```bash
# 1. 修改代码
vim code/liba/a1.c

# 2. 编译
./build/smartbuild.sh

# 3. 推送到 GitHub（包含 libs/）
git add libs/
git commit -m "Update prebuilt libraries"
git push
```

**开发者 B（获取更新后）：**
```bash
# 1. Pull 最新代码
git pull

# 2. Smart Build（自动判断是否需要重编）
./build/smartbuild.sh

# 如果 libs/ 中的 .a 和 .hash 与源码匹配，会跳过编译！
```

### 状态输出示例

```
=== Smart Build (Main Program) ===
Project: rebuildtest
Output: /Users/.../rebuildtest/libs

[INFO] liba: up-to-date, skipping
[INFO] libb: up-to-date, skipping
[INFO] main is up-to-date

=== Build Complete ===
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
| `compile_commands.json` | 编译命令数据库 |

### 查看依赖关系

```bash
# 列出所有目标
ninja -t targets

# 查看构建规则
ninja -t rules

# 详细模式
ninja -v -n  # verbose dry-run

# 查看目标的依赖
ninja -t deps <target_name>
```

### 并行编译

```bash
# 使用多核编译
ninja -j4    # 4 个并行任务
ninja -j$(nproc)  # 使用所有 CPU 核心
```

---

## CMake 进阶技巧

### 输出目录配置

```cmake
# 设置输出目录
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${PROJECT_ROOT}/libs)  # 静态库
set(LIBRARY_OUTPUT_DIRECTORY ${PROJECT_ROOT}/libs)       # 动态库
set(RUNTIME_OUTPUT_DIRECTORY ${PROJECT_ROOT}/tar)        # 可执行文件
```

### 头文件目录

```cmake
# 为目标添加头文件搜索路径
target_include_directories(liba PUBLIC
    ${PROJECT_ROOT}/code/liba
)

# PRIVATE: 仅当前目标使用
# PUBLIC: 当前目标和依赖目标都使用
# INTERFACE: 仅依赖目标使用
```

### 链接库

```cmake
# 链接静态库
target_link_libraries(libb liba)  # libb 链接 liba

# 链接系统库
target_link_libraries(main m)     # 链接数学库
target_link_libraries(main pthread) # 链接线程库
```

### 生成位置无关代码（静态库）

```cmake
# 为静态库生成位置无关代码
set_target_properties(liba PROPERTIES
    POSITION_INDEPENDENT_CODE ON
)
```

### 调试和发布构建

```cmake
# 设置构建类型
set(CMAKE_BUILD_TYPE Release)  # Release / Debug / RelWithDebInfo / MinSizeRel

# 或在命令行指定
cmake -DCMAKE_BUILD_TYPE=Release ...
```

---

## 总结

### 核心优势

1. **自动依赖追踪**：修改 liba → libb 自动重建
2. **传递依赖计算**：计算哈希时包含所有依赖
3. **增量编译**：只编译变化的代码
4. **团队协作**：推送 libs/ 到 GitHub，他人可直接使用
5. **易于扩展**：添加新库只需修改配置
6. **目录分离**：临时文件和产物分离

### 扩展建议

- 添加动态库支持
- 支持更多构建系统（Make, Meson）
- 集成 CI/CD 流程
- 添加并行编译优化
- 添加单元测试集成

---

## 附录：Git 忽略配置

```gitignore
# 临时构建目录
tar/

# 编译产物（保留 libs/）
# libs/ 应该推送到 GitHub

# IDE
.vscode/
.idea/

# OS
.DS_Store
```

---

**项目地址**: https://github.com/Neo-Song/rebuildtest
