#!/bin/bash

# libbuild.sh - 单独编译指定的库
# 用法: ./libbuild.sh <libname>
# 例: ./libbuild.sh liba 或 ./libbuild.sh libb

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CMAKE_DIR="$SCRIPT_DIR/cmake"
TAR_DIR="$PROJECT_DIR/tar"
TMP_DIR="$TAR_DIR/tmp"
BUILD_DIR="$SCRIPT_DIR"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查参数
if [ $# -lt 1 ]; then
    echo "用法: $0 <libname>"
    echo "例: $0 liba"
    echo "    $0 libb"
    exit 1
fi

LIBNAME="$1"

# 验证库名
case "$LIBNAME" in
    liba|libb)
        ;;
    *)
        log_error "未知库: $LIBNAME"
        echo "支持的库: liba, libb"
        exit 1
        ;;
esac

log_info "=== Building $LIBNAME ==="
log_info "Project: rebuildtest"
log_info "Output: $TAR_DIR"

# 创建输出目录
mkdir -p "$TAR_DIR"
mkdir -p "$TMP_DIR"

# 检查是否需要重新编译
NEED_BUILD=true
LIB_ARCHIVE="$TAR_DIR/${LIBNAME}.a"

if [ -f "$LIB_ARCHIVE" ]; then
    # 计算包含依赖的 hash
    deps=""
    if [ "$LIBNAME" = "libb" ]; then
        deps="liba"
    fi
    
    if [ -n "$deps" ]; then
        LIB_HASH=$(find "$PROJECT_DIR/code/$LIBNAME" "$PROJECT_DIR/code/$deps" -name "*.c" -o -name "*.h" 2>/dev/null | sort | xargs cat | shasum -a 256 | cut -d' ' -f1)
    else
        LIB_HASH=$(find "$PROJECT_DIR/code/$LIBNAME" -name "*.c" -o -name "*.h" | sort | xargs cat | shasum -a 256 | cut -d' ' -f1)
    fi
    HASH_FILE="$PROJECT_DIR/.hash/${LIBNAME}.hash"
    
    if [ -f "$HASH_FILE" ]; then
        SAVED_HASH=$(cat "$HASH_FILE")
        if [ "$LIB_HASH" = "$SAVED_HASH" ]; then
            NEED_BUILD=false
            log_info "$LIBNAME: No changes, using cached"
        fi
    fi
fi

if [ "$NEED_BUILD" = true ]; then
    log_info "Building $LIBNAME..."
    
    # 清理旧的构建文件
    rm -rf "$TMP_DIR/${LIBNAME}" 2>/dev/null || true
    mkdir -p "$TMP_DIR/${LIBNAME}"
    
    # CMake 配置和编译
    cmake -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY="$TAR_DIR" \
        -DLIBRARY_OUTPUT_DIRECTORY="$TAR_DIR" \
        -DPROJECT_ROOT="$PROJECT_DIR" \
        "$CMAKE_DIR" \
        -B "$TMP_DIR/${LIBNAME}"
    
    ninja -C "$TMP_DIR/${LIBNAME}" "$LIBNAME"
    
    # 保存 hash (包含依赖)
    deps=""
    if [ "$LIBNAME" = "libb" ]; then
        deps="liba"
    fi
    
    if [ -n "$deps" ]; then
        LIB_HASH=$(find "$PROJECT_DIR/code/$LIBNAME" "$PROJECT_DIR/code/$deps" -name "*.c" -o -name "*.h" 2>/dev/null | sort | xargs cat | shasum -a 256 | cut -d' ' -f1)
    else
        LIB_HASH=$(find "$PROJECT_DIR/code/$LIBNAME" -name "*.c" -o -name "*.h" | sort | xargs cat | shasum -a 256 | cut -d' ' -f1)
    fi
    mkdir -p "$PROJECT_DIR/.hash"
    echo "$LIB_HASH" > "$PROJECT_DIR/.hash/${LIBNAME}.hash"
    
    log_info "$LIBNAME built successfully: $LIB_ARCHIVE"
else
    log_info "$LIBNAME already up-to-date"
fi

log_info "=== Build Complete ==="

# Clean function
clean_lib() {
    log_info "=== Clean $LIBNAME ==="
    rm -rf "$TMP_DIR/${LIBNAME}"
    rm -f "$TAR_DIR/${LIBNAME}.a"
    rm -f "$PROJECT_DIR/.hash/${LIBNAME}.hash"
    log_info "Clean complete."
}

# Check if clean command
if [ "$2" = "clean" ]; then
    clean_lib
    exit 0
fi
