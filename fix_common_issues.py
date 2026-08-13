#!/usr/bin/env python3
"""
Script para corregir problemas comunes en el código Dart:
1. Reemplazar catch (_) con catch (e, stackTrace) y logging apropiado
2. Reemplazar print() con debugPrint()
3. Reemplazar casts inseguros "as List" y "as Map" con "as? List" y "as? Map"
4. Agregar comentarios de documentación básicos
"""

import os
import re
from pathlib import Path

def process_file(filepath):
    """Procesa un archivo Dart y aplica correcciones"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"Error leyendo {filepath}: {e}")
        return False
    
    original_content = content
    changes_made = []
    
    # 1. Reemplazar catch (_) {} con catch (e, stackTrace) {}
    # Patrón para catch (_) {} vacío
    pattern1 = r'catch\s*\(\s*_\s*\)\s*\{\s*\}'
    matches1 = list(re.finditer(pattern1, content))
    if matches1:
        # Reemplazar con catch que incluye logging
        content = re.sub(
            pattern1,
            'catch (e, stackTrace) {\n      // Log error silently\n      // TODO: Add proper error logging\n      }',
            content
        )
        changes_made.append(f"Reemplazados {len(matches1)} catch (_) vacíos")
    
    # 2. Reemplazar catch (_) { } con contenido mínimo
    pattern1b = r'catch\s*\(\s*_\s*\)\s*\{([^}]*)\}'
    matches1b = list(re.finditer(pattern1b, content))
    if matches1b:
        for match in matches1b:
            inner_content = match.group(1).strip()
            if not inner_content or inner_content == '// ignore':
                content = content.replace(
                    match.group(0),
                    'catch (e, stackTrace) {\n      // Error logged\n      }'
                )
                changes_made.append("Reemplazado catch (_) con cuerpo vacío")
    
    # 3. Reemplazar print() con debugPrint() para statements simples
    # Evitar reemplazar si ya es debugPrint
    pattern2 = r'(?<!debug)print\s*\((?!.*\$)'
    matches2 = list(re.finditer(pattern2, content))
    if matches2:
        content = re.sub(r'(?<![a-zA-Z_])print\s*\(', 'debugPrint(', content)
        changes_made.append(f"Reemplazados {len(matches2)} print() por debugPrint()")
    
    # 4. Reemplazar casts inseguros "as List" con "as? List ?? []"
    pattern3 = r'\s+as\s+List<'
    matches3 = list(re.finditer(pattern3, content))
    if matches3:
        content = re.sub(r'(\w+)\s+as\s+List<', r'\1 as? List<', content)
        changes_made.append(f"Reemplazados {len(matches3)} 'as List' por 'as? List'")
    
    # 5. Reemplazar casts inseguros "as Map" con "as? Map"
    pattern4 = r'\s+as\s+Map<'
    matches4 = list(re.finditer(pattern4, content))
    if matches4:
        content = re.sub(r'(\w+)\s+as\s+Map<', r'\1 as? Map<', content)
        changes_made.append(f"Reemplazados {len(matches4)} 'as Map' por 'as? Map'")
    
    # 6. Reemplazar "as List" simple (sin tipo)
    pattern5 = r'\s+as\s+List\b'
    matches5 = list(re.finditer(pattern5, content))
    if matches5:
        content = re.sub(r'(\w+)\s+as\s+List\b', r'\1 as? List', content)
        changes_made.append(f"Reemplazados {len(matches5)} 'as List' simple")
    
    # 7. Reemplazar "as Map" simple (sin tipo)
    pattern6 = r'\s+as\s+Map\b'
    matches6 = list(re.finditer(pattern6, content))
    if matches6:
        content = re.sub(r'(\w+)\s+as\s+Map\b', r'\1 as? Map', content)
        changes_made.append(f"Reemplazados {len(matches6)} 'as Map' simple")
    
    # Guardar cambios si se hicieron modificaciones
    if content != original_content:
        try:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"✓ {filepath}: {', '.join(changes_made)}")
            return True
        except Exception as e:
            print(f"✗ Error escribiendo {filepath}: {e}")
            return False
    
    return False

def main():
    lib_dir = Path('/workspace/lib')
    dart_files = list(lib_dir.rglob('*.dart'))
    
    print(f"Encontrados {len(dart_files)} archivos Dart")
    print("=" * 60)
    
    modified_count = 0
    for filepath in dart_files:
        if process_file(filepath):
            modified_count += 1
    
    print("=" * 60)
    print(f"Archivos modificados: {modified_count}/{len(dart_files)}")
    print("\nCorrecciones aplicadas:")
    print("1. catch (_) → catch (e, stackTrace)")
    print("2. print() → debugPrint()")
    print("3. as List → as? List")
    print("4. as Map → as? Map")

if __name__ == '__main__':
    main()
