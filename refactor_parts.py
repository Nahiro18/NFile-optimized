import re

pref_path = 'lib/providers/preferences_mixin.dart'
fmp_path = 'lib/providers/file_manager_provider.dart'

with open(pref_path, 'r') as f:
    pref_lines = f.readlines()

imports = []
new_pref_lines = []
for line in pref_lines:
    if line.startswith('import '):
        imports.append(line)
    else:
        new_pref_lines.append(line)

new_pref_content = "part of 'file_manager_provider.dart';\n" + "".join(new_pref_lines)

with open(pref_path, 'w') as f:
    f.write(new_pref_content)

with open(fmp_path, 'r') as f:
    fmp_content = f.read()

# filter out imports that are already in fmp_content
fmp_imports = re.findall(r'^import .*;$', fmp_content, flags=re.MULTILINE)
unique_imports = [imp for imp in imports if imp.strip() not in fmp_imports and 'file_manager_provider.dart' not in imp]

# find last import
last_import_idx = fmp_content.rfind('import ')
if last_import_idx != -1:
    end_of_line = fmp_content.find('\n', last_import_idx)
    insert_idx = end_of_line + 1
else:
    insert_idx = 0

fmp_content = fmp_content[:insert_idx] + "".join(unique_imports) + "\npart 'preferences_mixin.dart';\n" + fmp_content[insert_idx:]

with open(fmp_path, 'w') as f:
    f.write(fmp_content)

print("Refactored successfully")
