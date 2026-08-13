#!/usr/bin/env python3
"""Script para corregir casts inseguros específicos que el patrón general no detectó"""

import re
from pathlib import Path

files_to_fix = {
    '/workspace/lib/services/archive_service.dart': [
        (r"args\['sourcePaths'\] as List<String>", r"args['sourcePaths'] as? List<String> ?? []"),
        (r"args\['internalPathsToDelete'\] as List<String>", r"args['internalPathsToDelete'] as? List<String> ?? []"),
    ],
    '/workspace/lib/services/background_archive_service.dart': [
        (r"args\['sourcePaths'\] as List<String>", r"args['sourcePaths'] as? List<String> ?? []"),
    ],
    '/workspace/lib/services/remote/lan_client.dart': [
        (r"json\.decode\(stored\) as List<dynamic>", r"(json.decode(stored) as? List<dynamic>) ?? []"),
    ],
    '/workspace/lib/services/preferences_service.dart': [
        (r"jsonDecode\(str\) as List;", r"(jsonDecode(str) as? List) ?? [];"),
        (r"jsonDecode\(str\) as List<dynamic>;", r"(jsonDecode(str) as? List<dynamic>) ?? [];"),
    ],
    '/workspace/lib/services/network_connections_service.dart': [
        (r"json\.decode\(str\) as List<dynamic>", r"(json.decode(str) as? List<dynamic>) ?? []"),
    ],
    '/workspace/lib/services/vault_service.dart': [
        (r"jsonDecode\(str\) as List;", r"(jsonDecode(str) as? List) ?? [];"),
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
            print(f"  - {pattern} → {replacement} ({matches})")
    
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
    print("Corrigiendo casts inseguros específicos...")
    print("=" * 60)
    
    modified_count = 0
    for filepath, patterns in files_to_fix.items():
        if process_file(filepath, patterns):
            modified_count += 1
    
    print("=" * 60)
    print(f"Archivos modificados: {modified_count}")

if __name__ == '__main__':
    main()
