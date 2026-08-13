#!/usr/bin/env python3
"""Script para corregir casts en media_provider.dart"""

import re

filepath = '/workspace/lib/providers/media_provider.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Reemplazar (map['xxx'] as List?) con (map['xxx'] as? List)
patterns = [
    (r"\(map\['images'\] as List\?\)", r"(map['images'] as? List)"),
    (r"\(map\['videos'\] as List\?\)", r"(map['videos'] as? List)"),
    (r"\(map\['screenshots'\] as List\?\)", r"(map['screenshots'] as? List)"),
    (r"\(map\['audios'\] as List\?\)", r"(map['audios'] as? List)"),
    (r"\(map\['recentFiles'\] as List\?\)", r"(map['recentFiles'] as? List)"),
]

changes = 0
for pattern, replacement in patterns:
    matches = len(re.findall(pattern, content))
    if matches > 0:
        content = re.sub(pattern, replacement, content)
        changes += matches
        print(f"Reemplazado: {pattern} → {replacement} ({matches})")

if changes > 0:
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"✓ {filepath}: {changes} casts corregidos")
else:
    print("Sin cambios necesarios")
