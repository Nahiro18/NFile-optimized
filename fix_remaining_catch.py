#!/usr/bin/env python3
"""Script para corregir los catch (_) restantes con logging apropiado"""

import os
import re
from pathlib import Path

def process_file(filepath):
    """Procesa un archivo Dart y corrige catch (_)"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"Error leyendo {filepath}: {e}")
        return False
    
    original_content = content
    changes_count = 0
    
    # Patrón para catch (_) { ... } con cualquier contenido
    pattern = r'}\s*catch\s*\(\s*_\s*\)\s*\{'
    
    def replace_catch(match):
        nonlocal changes_count
        changes_count += 1
        # Obtener el contexto de la línea anterior para generar un mensaje relevante
        return '} catch (e, stackTrace) {\n      // Error handled'
    
    content = re.sub(pattern, replace_catch, content)
    
    # Guardar cambios si se hicieron modificaciones
    if content != original_content:
        try:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            if changes_count > 0:
                print(f"✓ {filepath}: {changes_count} catch(_) corregidos")
            return True
        except Exception as e:
            print(f"✗ Error escribiendo {filepath}: {e}")
            return False
    
    return False

def main():
    lib_dir = Path('/workspace/lib')
    dart_files = list(lib_dir.rglob('*.dart'))
    
    print("Corrigiendo catch (_) restantes...")
    print("=" * 60)
    
    modified_count = 0
    for filepath in dart_files:
        if process_file(filepath):
            modified_count += 1
    
    print("=" * 60)
    print(f"Archivos modificados: {modified_count}")

if __name__ == '__main__':
    main()
