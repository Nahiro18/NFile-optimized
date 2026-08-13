#!/usr/bin/env python3
"""Script para corregir los casts restantes de Map"""

import re
from pathlib import Path

files_to_fix = {
    '/workspace/lib/services/preferences_service.dart': [
        (r"jsonDecode\(str\) as Map<String, dynamic>", r"(jsonDecode(str) as? Map<String, dynamic>) ?? {}"),
    ],
    '/workspace/lib/services/vault_service.dart': [
        (r"jsonDecode\(metadataStr\) as Map<String, dynamic>", r"(jsonDecode(metadataStr) as? Map<String, dynamic>) ?? {}"),
    ],
    '/workspace/lib/providers/media_provider.dart': [
        (r"jsonDecode\(jsonStr\) as Map<String, dynamic>", r"(jsonDecode(jsonStr) as? Map<String, dynamic>) ?? {}"),
        (r"params\['docExts'\] as List<String>\? \?\? \[\]", r"(params['docExts'] as? List<String>) ?? []"),
        (r"params\['archExts'\] as List<String>\? \?\? \[\]", r"(params['archExts'] as? List<String>) ?? []"),
        (r"params\['apkExts'\] as List<String>\? \?\? \[\]", r"(params['apkExts'] as? List<String>) ?? []"),
    ],
}

def process_file(filepath, patterns):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"Error leyendo {filepath}: {e}")
        return False
    
    original_content = content
    changes_count = 0
    
    for pattern, replacement in patterns:
        matches = len(re.findall(pattern, content))
        if matches > 0:
            content = re.sub(pattern, replacement, content)
            changes_count += matches
            print(f"  - {pattern[:50]}... → {replacement[:50]}... ({matches})")
    
    if content != original_content:
        try:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"✓ {filepath}: {changes_count} casts corregidos")
            return True
        except Exception as e:
            print(f"✗ Error escribiendo {filepath}: {e}")
            return False
    
    return False

def main():
    print("Corrigiendo casts inseguros de Map restantes...")
    print("=" * 60)
    
    modified_count = 0
    for filepath, patterns in files_to_fix.items():
        if process_file(filepath, patterns):
            modified_count += 1
    
    print("=" * 60)
    print(f"Archivos modificados: {modified_count}")

if __name__ == '__main__':
    main()
