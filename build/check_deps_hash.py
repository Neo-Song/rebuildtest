#!/usr/bin/env python3
"""
check_deps_hash.py - 检查组件是否需要重新编译

用法: python3 check_deps_hash.py <component_name>
例: python3 check_deps_hash.py liba
    python3 check_deps_hash.py libb

返回值:
    need_rebuild  - 组件源码或依赖有变化，需要重新编译
    not_rebuild  - 组件源码无变化，不需要重新编译
"""

import os
import sys
import hashlib
import subprocess
from pathlib import Path

# 依赖配置（与 shell 脚本保持一致）
LIB_DEPS = {
    "liba": [],      # liba 无依赖
    "libb": ["liba"],  # libb 依赖 liba
}

def find_source_files(directory):
    """查找目录下所有 .c 和 .h 文件"""
    c_files = list(Path(directory).rglob("*.c"))
    h_files = list(Path(directory).rglob("*.h"))
    return sorted(c_files + h_files)

def calculate_hash(component_name, project_root):
    """
    计算组件的 hash（包含依赖）
    算法与 shell 脚本保持一致：
    find ... -name "*.c" -o -name "*.h" | sort | xargs cat | shasum -a 256
    """
    code_dir = Path(project_root) / "code"
    component_dir = code_dir / component_name
    
    all_files = []
    
    # 1. 添加依赖的源文件（先加依赖）
    deps = LIB_DEPS.get(component_name, [])
    for dep in deps:
        dep_dir = code_dir / dep
        if dep_dir.exists():
            all_files.extend(find_source_files(dep_dir))
    
    # 2. 添加组件自身的源文件
    if component_dir.exists():
        all_files.extend(find_source_files(component_dir))
    
    if not all_files:
        return "no_source_files"
    
    # 3. 计算 hash（按排序顺序）
    hasher = hashlib.sha256()
    for file_path in all_files:
        try:
            with open(file_path, 'rb') as f:
                hasher.update(f.read())
        except Exception as e:
            print(f"Warning: Could not read {file_path}: {e}")
    
    return hasher.hexdigest()

def read_saved_hash(component_name, project_root):
    """读取保存的 hash"""
    hash_file = Path(project_root) / "libs" / f"{component_name}.hash"
    if hash_file.exists():
        with open(hash_file, 'r') as f:
            return f.read().strip()
    return None

def main():
    if len(sys.argv) < 2:
        print("用法: python3 check_deps_hash.py <component_name>")
        print("例: python3 check_deps_hash.py liba")
        sys.exit(1)
    
    component_name = sys.argv[1]
    
    # 获取项目根目录（脚本所在目录的父目录）
    script_dir = Path(__file__).parent.resolve()
    project_root = script_dir.parent.resolve()
    
    print(f"=== Check Component: {component_name} ===")
    print(f"Project root: {project_root}")
    print()
    
    # 检查组件是否有效
    if component_name not in LIB_DEPS:
        print(f"Error: Unknown component '{component_name}'")
        print(f"Available components: {', '.join(LIB_DEPS.keys())}")
        sys.exit(1)
    
    # 计算当前 hash
    print(f"[1] Calculating current hash for {component_name}...")
    current_hash = calculate_hash(component_name, project_root)
    print(f"    Current hash: {current_hash}")
    
    # 显示依赖信息
    deps = LIB_DEPS.get(component_name, [])
    if deps:
        print(f"    Dependencies: {', '.join(deps)}")
    else:
        print(f"    Dependencies: none")
    print()
    
    # 读取保存的 hash
    print(f"[2] Reading saved hash from libs/{component_name}.hash...")
    saved_hash = read_saved_hash(component_name, project_root)
    
    if saved_hash is None:
        print(f"    Saved hash: NOT FOUND (first build?)")
        print()
        print("=> Result: need_rebuild (no saved hash)")
        sys.exit(0)  # Exit with 0 but return need_rebuild
    
    print(f"    Saved hash: {saved_hash}")
    print()
    
    # 比较 hash
    print(f"[3] Comparing hashes...")
    print(f"    Current: {current_hash}")
    print(f"    Saved:   {saved_hash}")
    print()
    
    if current_hash == saved_hash:
        print("=> Result: not_rebuild (hashes match)")
        print("    No rebuild needed - using cached library")
    else:
        print("=> Result: need_rebuild (hashes differ)")
        print("    Source code or dependencies changed - rebuild required")
    
    # 返回结果
    if current_hash == saved_hash:
        print("not_rebuild")
    else:
        print("need_rebuild")

if __name__ == "__main__":
    main()
