#!/usr/bin/env python3
"""Script para corregir casts inseguros restantes"""

import os
import re
from pathlib import Path

def process_file(filepath):
    """Procesa un archivo Dart y corrige casts inseguros"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"Error leyendo {filepath}: {e}")
        return False
    
    original_content = content
    changes_count = 0
    
    # Reemplazar "as List<String>" con "as? List<String>"
    pattern1 = r"(\w+)\s+as\s+List<"
    matches1 = len(re.findall(pattern1, content))
    if matches1 > 0:
        content = re.sub(pattern1, r"\1 as? List<", content)
        changes_count += matches1
    
    # Reemplazar "as List<dynamic>" con "as? List<dynamic>"
    pattern1b = r"(\w+)\s+as\s+List<dynamic>"
    matches1b = len(re.findall(pattern1b, content))
    if matches1b > 0:
        content = re.sub(pattern1b, r"\1 as? List<dynamic>", content)
        changes_count += matches1b
    
    # Reemplazar "as List" simple (sin tipo) con "as? List"
    pattern2 = r"(\w+)\s+as\s+List\b(?!\?)"
    matches2 = len(re.findall(pattern2, content))
    if matches2 > 0:
        content = re.sub(pattern2, r"\1 as? List", content)
        changes_count += matches2
    
    # Reemplazar "as Map<String" con "as? Map<String"
    pattern3 = r"(\w+)\s+as\s+Map<"
    matches3 = len(re.findall(pattern3, content))
    if matches3 > 0:
        content = re.sub(pattern3, r"\1 as? Map<", content)
        changes_count += matches3
    
    # Reemplazar "as Map" simple con "as? Map"
    pattern4 = r"(\w+)\s+as\s+Map\b(?!\?)"
    matches4 = len(re.findall(pattern4, content))
    if matches4 > 0:
        content = re.sub(pattern4, r"\1 as? Map", content)
        changes_count += matches4
    
    # Guardar cambios si se hicieron modificaciones
    if content != original_content:
        try:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            if changes_count > 0:
                print(f"✓ {filepath}: {changes_count} casts corregidos")
            return True
        except Exception as e:
            print(f"✗ Error escribiendo {filepath}: {e}")
            return False
    
    return False

def main():
    lib_dir = Path('/workspace/lib')
    dart_files = list(lib_dir.rglob('*.dart'))
    
    print("Corrigiendo casts inseguros...")
    print("=" * 60)
    
    modified_count = 0
    for filepath in dart_files:
        if process_file(filepath):
            modified_count += 1
    
    print("=" * 60)
    print(f"Archivos modificados: {modified_count}")

if __name__ == '__main__':
    main()
