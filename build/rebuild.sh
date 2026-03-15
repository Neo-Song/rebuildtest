#!/bin/bash

# rebuild.sh - Smart incremental build script
# 智能增量编译：检查源码变化，仅在需要时重新编译

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CODE_DIR="$PROJECT_DIR/code"
LIBS_DIR="$PROJECT_DIR/libs"
BUILD_DIR="$PROJECT_DIR/build"
HASH_DIR="$PROJECT_DIR/.hash"

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

# Calculate hash of a library source directory
calculate_lib_hash() {
    local libname="$1"
    local lib_dir="$CODE_DIR/lib${libname}"
    if [ -d "$lib_dir" ]; then
        find "$lib_dir" -type f \( -name "*.c" -o -name "*.h" \) -exec cat {} \; | shasum -a 256 | cut -d' ' -f1
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

# Save hash of library source
save_hash() {
    local libname="$1"
    local current_hash=$(calculate_lib_hash "$libname")
    echo "$current_hash" > "$HASH_DIR/${libname}.hash"
    log_info "Saved hash for $libname: ${current_hash:0:16}..."
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
    log_info "=== Smart Incremental Build ==="
    log_info "Project: rebuildtest"
    log_info "Code directory: $CODE_DIR"
    log_info "Libs directory: $LIBS_DIR"
    echo ""
    
    # Create directories if not exist
    mkdir -p "$HASH_DIR"
    mkdir -p "$LIBS_DIR"
    
    # Check if CMake needs to be reconfigured
    if [ ! -f "$BUILD_DIR/build.ninja" ]; then
        log_info "Configuring CMake..."
        cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY="$LIBS_DIR" -DLIBRARY_OUTPUT_DIRECTORY="$LIBS_DIR" "$PROJECT_DIR" -B "$BUILD_DIR"
    fi
    
    local needs_main_rebuild=false
    
    # Check each library
    for libname in "${LIBS[@]}"; do
        if check_needs_rebuild "$libname"; then
            log_warn "$libname: Source changed or not built, rebuilding..."
            build_library "$libname"
            needs_main_rebuild=true
        else
            log_info "$libname: No changes detected, skipping (using cached)"
        fi
    done
    
    # Check if main needs rebuild (if any lib was rebuilt or main is missing)
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

# Show status
show_status() {
    echo ""
    echo "=== Library Status ==="
    for libname in "${LIBS[@]}"; do
        local lib_file="$LIBS_DIR/lib${libname}.a"
        local hash_file="$HASH_DIR/${libname}.hash"
        
        printf "%-10s: " "lib${libname}"
        
        if [ -f "$lib_file" ]; then
            printf "compiled  "
        else
            printf "NOT built "
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

# Clean build
clean_build() {
    log_info "Cleaning build artifacts..."
    rm -rf "$BUILD_DIR"/*
    rm -rf "$LIBS_DIR"/*
    rm -rf "$HASH_DIR"/*
    log_info "Clean complete. Next build will be a full rebuild."
}

# Force rebuild
force_rebuild() {
    log_info "Force rebuild triggered..."
    rm -rf "$HASH_DIR"/*
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
    *)
        echo "Usage: $0 {build|status|clean|rebuild|run}"
        echo ""
        echo "Commands:"
        echo "  build   - Smart incremental build (default)"
        echo "  status  - Show library build status"
        echo "  clean   - Clean build artifacts"
        echo "  rebuild - Force complete rebuild"
        echo "  run     - Build and run"
        exit 1
        ;;
esac
