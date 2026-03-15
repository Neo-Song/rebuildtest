#!/bin/bash

# smartbuild.sh - 智能编译主程序
# 自动检测库是否需要重新编译，按需构建

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
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 库列表
LIBS=("liba" "libb")

# 计算库的 hash（包含依赖）
calculate_lib_hash() {
    local libname="$1"
    local lib_dir="$PROJECT_DIR/code/$libname"
    local all_files=""
    
    # 传递依赖 (先加依赖，再加自身，保持与 libbuild.sh 一致)
    if [ "$libname" = "libb" ]; then
        all_files=$(find "$PROJECT_DIR/code/liba" "$lib_dir" -name "*.c" -o -name "*.h" 2>/dev/null | sort | xargs cat | shasum -a 256 | cut -d' ' -f1)
    else
        all_files=$(find "$lib_dir" -name "*.c" -o -name "*.h" 2>/dev/null | sort | xargs cat | shasum -a 256 | cut -d' ' -f1)
    fi
    
    echo "$all_files"
}

# 检查库是否需要重新编译
check_lib_needs_rebuild() {
    local libname="$1"
    local lib_archive="$TAR_DIR/${libname}.a"
    local hash_file="$PROJECT_DIR/.hash/${libname}.hash"
    
    # 库文件不存在，需要编译
    if [ ! -f "$lib_archive" ]; then
        return 0
    fi
    
    # hash 文件不存在，需要编译
    if [ ! -f "$hash_file" ]; then
        return 0
    fi
    
    # 比较 hash
    local current_hash=$(calculate_lib_hash "$libname")
    local saved_hash=$(cat "$hash_file")
    
    if [ "$current_hash" != "$saved_hash" ]; then
        return 0
    fi
    
    return 1
}

# 编译单个库
build_lib() {
    local libname="$1"
    log_info "Building $libname..."
    "$SCRIPT_DIR/libbuild.sh" "$libname"
}

# 编译主程序
build_main() {
    log_info "Building main..."
    
    # 创建构建目录
    mkdir -p "$TMP_DIR/main"
    
    # CMake 配置
    cmake -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY="$TAR_DIR" \
        -DLIBRARY_OUTPUT_DIRECTORY="$TAR_DIR" \
        -DRUNTIME_OUTPUT_DIRECTORY="$TAR_DIR" \
        -DPROJECT_ROOT="$PROJECT_DIR" \
        "$CMAKE_DIR" \
        -B "$TMP_DIR/main"
    
    # 编译
    ninja -C "$TMP_DIR/main" main
}

# Smart Build 模式
smart_build() {
    log_info "=== Smart Build (Main Program) ==="
    log_info "Project: rebuildtest"
    log_info "Output: $TAR_DIR"
    echo ""
    
    # 创建输出目录
    mkdir -p "$TAR_DIR"
    mkdir -p "$TMP_DIR"
    
    local needs_rebuild=false
    local rebuild_libs=()
    
    # 检查每个库
    for libname in "${LIBS[@]}"; do
        if check_lib_needs_rebuild "$libname"; then
            log_warn "$libname needs rebuild"
            rebuild_libs+=("$libname")
            needs_rebuild=true
        else
            log_info "$libname: up-to-date, skipping"
        fi
    done
    
    # 如果有库需要重建
    if [ "$needs_rebuild" = true ]; then
        echo ""
        log_info "Building changed libraries..."
        for libname in "${rebuild_libs[@]}"; do
            build_lib "$libname"
        done
    fi
    
    # 编译主程序
    echo ""
    if [ -f "$TAR_DIR/main" ]; then
        log_info "main already exists, checking if rebuild needed..."
        # 检查 main 是否需要重新编译（简单检查：比库文件新否）
        local main_time=$(stat -f "%m" "$TAR_DIR/main" 2>/dev/null || stat -c "%Y" "$TAR_DIR/main" 2>/dev/null)
        local liba_time=$(stat -f "%m" "$TAR_DIR/liba.a" 2>/dev/null || stat -c "%Y" "$TAR_DIR/liba.a" 2>/dev/null)
        
        if [ "$main_time" -lt "$liba_time" 2>/dev/null ]; then
            log_info "main is older than libs, rebuilding..."
            build_main
        else
            log_info "main is up-to-date"
        fi
    else
        log_info "main not found, building..."
        build_main
    fi
    
    echo ""
    log_info "=== Build Complete ==="
    log_info "Output directory: $TAR_DIR"
}

# 强制重建模式
force_rebuild() {
    log_info "Force rebuild mode..."
    
    # 清理 hash
    rm -f "$PROJECT_DIR/.hash"/*.hash
    
    # 重建所有库
    for libname in "${LIBS[@]}"; do
        build_lib "$libname"
    done
    
    # 重建主程序
    build_main
}

# 直接编译模式（不检查依赖）
direct_build() {
    log_info "=== Direct Build (Main Program) ==="
    build_main
}

# Clean build artifacts
clean_build() {
    log_info "=== Clean Build Artifacts ==="
    
    # Clean tmp build directories
    if [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"/*
        log_info "Cleaned: $TMP_DIR"
    fi
    
    # Clean output files
    rm -f "$TAR_DIR"/*.a "$TAR_DIR"/main
    log_info "Cleaned: $TAR_DIR"
    
    # Clean hash files
    rm -f "$PROJECT_DIR/.hash"/*.hash
    log_info "Cleaned: $PROJECT_DIR/.hash"
    
    log_info "Clean complete."
}

# Show usage
usage() {
    echo "用法: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  (无参数)    - Smart Build: 自动检测库是否需要重建"
    echo "  smart       - 同上，Smart Build 模式"
    echo "  direct      - 直接编译主程序（不检查库）"
    echo "  rebuild     - 强制重建所有库和主程序"
    echo "  clean       - 清理构建产物"
    echo "  run         - 编译并运行"
    echo ""
    echo "Examples:"
    echo "  $0           # Smart Build"
    echo "  $0 run       # 编译并运行"
    echo "  $0 clean     # 清理构建产物"
}

# 主程序
case "${1:-smart}" in
    smart)
        smart_build
        ;;
    direct)
        direct_build
        ;;
    rebuild)
        force_rebuild
        ;;
    clean)
        clean_build
        ;;
    run)
        smart_build
        if [ -f "$TAR_DIR/main" ]; then
            echo ""
            log_info "Running main..."
            "$TAR_DIR/main"
        else
            log_error "Executable not found!"
            exit 1
        fi
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        log_error "未知命令: $1"
        usage
        exit 1
        ;;
esac
