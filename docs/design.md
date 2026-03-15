# Smart Build - 智能增量构建系统

## 📋 设计目标

本项目旨在解决多人协作开发中的编译效率问题：

1. **减少不必要的编译** - 通过源码 hash 判断是否需要重新编译
2. **共享预编译库** - 将编译产物推送到 GitHub，他人可直接使用
3. **透明的增量构建** - 开发者无感知地享受增量编译的好处

### 核心场景

```
开发者 A 修改代码 → 编译 → 推送到 GitHub (包含 .a + .hash)
                                    ↓
开发者 B Clone → 获得预编译库 + Hash
              运行 smartbuild.sh → 比较 hash → 决定是否重编
```

---

## 🏗️ 实现方案

### 1. Hash 计算机制

每个库的 hash 包含：
- **自身源码** - 所有 .c 和 .h 文件的内容
- **传递依赖** - 依赖库的源码（修改 liba 时，依赖 liba 的 libb 也会检测到变化）

```bash
# libb 的 hash 计算包含：
#   - libb 自身的源码 (b1.c, b2.c, b3.c, libb.h)
#   - liba 的源码 (a1.c, a2.c, a3.c, liba.h) ← 传递依赖
```

### 2. 增量编译逻辑

```
smartbuild.sh 执行流程：
1. 检查 libs/liba.hash vs 当前 liba 源码 hash
   └── 相同 → liba 跳过编译
   └── 不同 → 重新编译 liba

2. 检查 libs/libb.hash vs 当前 libb+liba 源码 hash
   └── 相同 → libb 跳过编译
   └── 不同 → 重新编译 libb

3. 编译 main（检查时间戳决定是否重编）
```

### 3. 目录结构

```
rebuildtest/
├── code/              # 源代码
│   ├── main/         # 主程序
│   ├── liba/         # 静态库 A（无依赖）
│   └── libb/         # 静态库 B（依赖 liba）
│
├── libs/             # 编译产物 + Hash（推送到 GitHub）
│   ├── liba.a        # 预编译的 liba
│   ├── liba.hash     # liba 源码 hash
│   ├── libb.a        # 预编译的 libb
│   ├── libb.hash     # libb 源码 hash（含 liba 依赖）
│   └── (tmp/)        # 不推送，临时构建
│
├── tar/              # 临时构建目录（Git 忽略）
│   ├── main          # 主程序可执行文件
│   └── tmp/          # CMake 中间文件
│       ├── liba/     # liba 构建目录
│       ├── libb/     # libb 构建目录
│       └── main/     # main 构建目录
│
└── build/            # 构建脚本（Git 管理）
    ├── cmake/        # CMake 配置
    │   ├── CMakeLists.txt
    │   ├── liba/     # liba CMake 配置
    │   ├── libb/     # libb CMake 配置
    │   └── main/     # main CMake 配置
    ├── libbuild.sh   # 单独编译库脚本
    └── smartbuild.sh # 智能编译主程序脚本
```

---

## 🔧 技术要点

### 1. CMake 配置分离

每个库有独立的 CMakeLists.txt：
- `build/cmake/liba/CMakeLists.txt` - 构建 liba
- `build/cmake/libb/CMakeLists.txt` - 构建 libb（链接 liba）
- `build/cmake/main/CMakeLists.txt` - 构建 main（链接 liba、libb）

### 2. 输出目录分离

| 类型 | 输出目录 | 是否推送 |
|------|----------|----------|
| 静态库 (.a) | libs/ | ✅ 是 |
| Hash 文件 | libs/ | ✅ 是 |
| 可执行文件 | tar/ | ❌ 否 |
| CMake 中间文件 | tar/tmp/ | ❌ 否 |

### 3. Hash 计算一致性

两个脚本（libbuild.sh 和 smartbuild.sh）使用相同的 hash 计算逻辑：
```bash
# 必须保持完全一致
find "$code_dir" -name "*.c" -o -name "*.h" | sort | xargs cat | shasum -a 256
```

### 4. 依赖追踪

通过配置声明依赖关系：
```bash
# libbuild.sh / smartbuild.sh 中的配置
LIB_DEPS["libb"]="liba"  # libb 依赖 liba
```

---

## 📖 使用指南

### 基本命令

```bash
# Smart Build（自动检测是否需要重编）
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

---

## ✅ 验证结果

### 1. 增量编译验证

```bash
# 首次编译（全部重新编译）
$ ./build/smartbuild.sh
[INFO] liba needs rebuild    ← 检测到需要编译
[INFO] Building liba...
[INFO] libb needs rebuild    ← 检测到需要编译（libb 依赖 liba）
[INFO] Building libb...
[INFO] main not found, building...

# 再次运行（跳过编译）
$ ./build/smartbuild.sh
[INFO] liba: up-to-date, skipping    ← 使用缓存
[INFO] libb: up-to-date, skipping    ← 使用缓存
[INFO] main is up-to-date
```

### 2. 依赖变化验证

```bash
# 修改 liba 源码
$ echo "// test" >> code/liba/a1.c

# 重新编译
$ ./build/smartbuild.sh
[INFO] liba needs rebuild           ← liba 需要重编
[INFO] Building liba...
[INFO] libb needs rebuild          ← libb 也要重编（因为依赖 liba）
[INFO] Building libb...
[INFO] main is older than libs, rebuilding...
```

### 3. 目录验证

```bash
# libs/（推送到 GitHub）
$ ls -la libs/
-rw-r--r--  liba.a
-rw-r--r--  liba.hash
-rw-r--r--  libb.a
-rw-r--r--  libb.hash

# tar/（Git 忽略）
$ ls -la tar/
-rwxr-xr-x  main
drwxr-xr-x  tmp/
```

---

## 🔄 扩展指南

### 添加新库

1. 在 `code/` 下创建源码目录
2. 在 `build/cmake/` 下创建 CMakeLists.txt
3. 在 `libbuild.sh` 和 `smartbuild.sh` 的 `LIBS` 数组中添加库名
4. 配置依赖关系（如果需要）

### 示例：添加 libc 依赖 libb

```bash
# 1. 创建 code/libc/ 和 build/cmake/libc/

# 2. 在 libbuild.sh 中添加：
LIBS=("liba" "libb" "libc")
LIB_DEPS["libc"]="libb"  # libc 依赖 libb
```

---

## 📝 注意事项

1. **Hash 文件必须推送** - 否则他人无法享受增量编译
2. **.a 文件必须推送** - 预编译库的二进制兼容性
3. **保持 hash 计算一致** - 两个脚本必须使用相同的算法
4. **跨平台注意** - 不同平台的 .a 文件不通用，需要分别编译

---

**项目地址**: https://github.com/Neo-Song/rebuildtest
