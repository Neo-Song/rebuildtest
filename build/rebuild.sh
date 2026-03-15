#!/bin/bash

# rebuild.sh - Smart incremental build script with dependency support
# 智能增量编译：支持库依赖链，自动检测被依赖库的变化

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CODE_DIR="$PROJECT_DIR/code"
LIBS_DIR="$PROJECT_DIR/libs"
BUILD_DIR="$PROJECT_DIR/build"
HASH_DIR="$PROJECT_DIR/.hash"

# ===== 依赖配置 =====
# 格式: "库名:依赖1,依赖2,..."
# 每个库一行，用换行隔开
LIB_DEPS="
a:
b:a
"

# Libraries to build (without lib prefix)
LIBS=("a" "b")

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get direct dependencies for a library
get_direct_deps() {
    local libname="$1"
    local line
    while IFS=':' read -r lib deps; do
        if [ "$lib" = "$libname" ]; then
            echo "$deps"
            return
        fi
    done <<< "$LIB_DEPS"
}

# Get all dependencies (including transitive)
get_all_deps() {
    local libname="$1"
    local result=""
    local to_process="$libname"
    local processed=""
    
    while [ -n "$to_process" ]; do
        # Get first item
        local current=$(echo "$to_process" | awk '{print $1; exit}')
        # Remove first item
        to_process=$(echo "$to_process" | awk '{$1=""; print $0}' | xargs)
        
        # Skip if already processed
        if echo "$processed" | grep -qw "$current"; then
            continue
        fi
        processed="$processed $current"
        
        # Get deps of current
        local deps=$(get_direct_deps "$current")
        if [ -n "$deps" ]; then
            for dep in $(echo "$deps" | tr ',' ' '); do
                if ! echo "$processed" | grep -qw "$dep"; then
                    result="$result $dep"
                    to_process="$to_process $dep"
                fi
            done
        fi
    done
    
    echo "$result" | xargs
}

# Calculate hash for a library including all dependencies
calculate_lib_hash() {
    local libname="$1"
    local lib_dir="$CODE_DIR/lib${libname}"
    local all_files=""
    
    # 1. Add this library's own source files
    if [ -d "$lib_dir" ]; then
        all_files="$all_files $(find "$lib_dir" -type f \( -name '*.c' -o -name '*.h' \))"
    fi
    
    # 2. Add all dependent libraries' source files (transitive)
    local all_deps=$(get_all_deps "$libname")
    for dep in $all_deps; do
        local dep_dir="$CODE_DIR/lib${dep}"
        if [ -d "$dep_dir" ]; then
            all_files="$all_files $(find "$dep_dir" -type f \( -name '*.c' -o -name '*.h' \))"
        fi
    done
    
    if [ -n "$all_files" ]; then
        echo "$all_files" | xargs cat | shasum -a 256 | cut -d' ' -f1
    else
        echo "dir_not_found"
    fi
}

# Check if library needs rebuild (returns 0 if needs rebuild, 1 if not)
check_needs_rebuild() {
    local libname="$1"
    local lib_hash_file="$HASH_DIR/${libname}.hash"
    local current_hash=$(calculate_lib_hash "$libname")
    
    # Check if hash file exists
    if [ ! -f "$lib_hash_file" ]; then
        return 0  # Needs rebuild
    fi
    
    local stored_hash
    stored_hash=$(cat "$lib_hash_file")
    
    # Check if hash matches
    if [ "$current_hash" != "$stored_hash" ]; then
        return 0  # Needs rebuild
    fi
    
    # Also check if library file exists
    if [ ! -f "$LIBS_DIR/lib${libname}.a" ]; then
        return 0  # Needs rebuild
    fi
    
    return 1  # No rebuild needed
}

# Save hash of library source (including dependencies)
save_hash() {
    local libname="$1"
    local current_hash=$(calculate_lib_hash "$libname")
    local deps=$(get_direct_deps "$libname")
    if [ -z "$deps" ]; then
        deps="none"
    fi
    echo "$current_hash" > "$HASH_DIR/${libname}.hash"
    log_info "Saved hash for lib${libname} (deps: $deps): ${current_hash:0:16}..."
}

# Build a single library
build_library() {
    local libname="$1"
    local lib_target="lib${libname}"
    log_info "Building library: $lib_target"
    ninja -C "$BUILD_DIR" "$lib_target"
    save_hash "$libname"
}

# Main build function
smart_build() {
    log_info "=== Smart Incremental Build with Dependencies ==="
    log_info "Project: rebuildtest"
    log_info "Code directory: $CODE_DIR"
    log_info "Libs directory: $LIBS_DIR"
    echo ""
    
    # Show dependency graph
    echo "Dependency graph:"
    for libname in "${LIBS[@]}"; do
        local deps=$(get_direct_deps "$libname")
        if [ -n "$deps" ]; then
            echo "  lib${libname} depends on: $deps"
        else
            echo "  lib${libname} (no dependencies)"
        fi
    done
    echo ""
    
    # Create directories if not exist
    mkdir -p "$HASH_DIR"
    mkdir -p "$LIBS_DIR"
    
    # Check if CMake needs to be reconfigured
    if [ ! -f "$BUILD_DIR/build.ninja" ]; then
        log_info "Configuring CMake..."
        cmake -G Ninja -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY="$LIBS_DIR" \
            -DLIBRARY_OUTPUT_DIRECTORY="$LIBS_DIR" \
            "$PROJECT_DIR" -B "$BUILD_DIR"
    fi
    
    local needs_main_rebuild=false
    
    # Build in order: a first (no deps), then b (depends on a)
    local sorted_libs=("a" "b")
    
    # Check each library
    for libname in "${sorted_libs[@]}"; do
        if check_needs_rebuild "$libname"; then
            local deps=$(get_direct_deps "$libname")
            if [ -n "$deps" ]; then
                log_warn "lib${libname}: Dependency changed or not built, rebuilding (deps: $deps)..."
            else
                log_warn "lib${libname}: Source changed or not built, rebuilding..."
            fi
            build_library "$libname"
            needs_main_rebuild=true
        else
            local deps=$(get_direct_deps "$libname")
            if [ -n "$deps" ]; then
                log_info "lib${libname} (deps: $deps): No changes detected, skipping"
            else
                log_info "lib${libname}: No changes detected, skipping"
            fi
        fi
    done
    
    # Check if main needs rebuild
    if [ ! -f "$BUILD_DIR/main" ]; then
        needs_main_rebuild=true
    fi
    
    if [ "$needs_main_rebuild" = true ]; then
        log_info "Building main executable..."
        ninja -C "$BUILD_DIR" main
    else
        log_info "main: No changes detected, skipping"
    fi
    
    echo ""
    log_info "=== Build Complete ==="
    log_info "Libraries: $LIBS_DIR"
    log_info "Executable: $BUILD_DIR/main"
}

# Show status with dependency info
show_status() {
    echo ""
    echo "=== Library Status (with dependencies) ==="
    for libname in "${LIBS[@]}"; do
        local lib_file="$LIBS_DIR/lib${libname}.a"
        local hash_file="$HASH_DIR/${libname}.hash"
        local deps=$(get_direct_deps "$libname")
        
        printf "lib%-8s " "$libname"
        
        # Show deps
        if [ -n "$deps" ]; then
            printf "[deps:%s] " "$deps"
        else
            printf "[no deps] "
        fi
        
        if [ -f "$lib_file" ]; then
            printf "built  "
        else
            printf "NOT   "
        fi
        
        if [ -f "$hash_file" ]; then
            local stored_hash current_hash
            stored_hash=$(cat "$hash_file")
            current_hash=$(calculate_lib_hash "$libname")
            if [ "$stored_hash" = "$current_hash" ]; then
                printf "up-to-date"
            else
                printf "needs rebuild"
            fi
        else
            printf "no hash"
        fi
        echo ""
    done
}

# Clean build (keep rebuild.sh and this script itself)
clean_build() {
    log_info "Cleaning build artifacts..."
    
    # Clean build directory (but keep rebuild.sh)
    if [ -d "$BUILD_DIR" ]; then
        find "$BUILD_DIR" -mindepth 1 -maxdepth 1 ! -name 'rebuild.sh' -exec rm -rf {} \; 2>/dev/null || true
    fi
    
    # Clean libs
    if [ -d "$LIBS_DIR" ]; then
        rm -f "$LIBS_DIR"/*.a
    fi
    
    # Clean hash
    if [ -d "$HASH_DIR" ]; then
        rm -f "$HASH_DIR"/*.hash
    fi
    
    log_info "Clean complete. Next build will be a full rebuild."
}

# Force rebuild
force_rebuild() {
    log_info "Force rebuild triggered..."
    rm -f "$HASH_DIR"/*.hash
    smart_build
}

# Parse arguments
case "${1:-build}" in
    build)
        smart_build
        ;;
    status)
        show_status
        ;;
    clean)
        clean_build
        ;;
    rebuild)
        force_rebuild
        ;;
    run)
        smart_build
        if [ -f "$BUILD_DIR/main" ]; then
            "$BUILD_DIR/main"
        else
            log_error "Executable not found!"
            exit 1
        fi
        ;;
    deps)
        echo "Dependency graph:"
        for libname in "${LIBS[@]}"; do
            local all_deps=$(get_all_deps "$libname")
            local direct_deps=$(get_direct_deps "$libname")
            if [ -z "$direct_deps" ]; then
                direct_deps="none"
            fi
            if [ -z "$all_deps" ]; then
                all_deps="none"
            fi
            echo "  lib${libname}:"
            echo "    direct: $direct_deps"
            echo "    transitive: $all_deps"
        done
        ;;
    *)
        echo "Usage: $0 {build|status|clean|rebuild|run|deps}"
        echo ""
        echo "Commands:"
        echo "  build   - Smart incremental build with dependency tracking"
        echo "  status  - Show library build status"
        echo "  clean   - Clean build artifacts (keeps rebuild.sh)"
        echo "  rebuild - Force complete rebuild"
        echo "  run     - Build and run"
        echo "  deps    - Show dependency graph"
        exit 1
        ;;
esac
