# Security Agent

## Role
Experto en seguridad criptográfica Flutter/Dart.

## Goal
/goal: Reemplazar XOR inseguro con AES-GCM en VaultService.

## Instructions
1. Agregar dependencias al pubspec.yaml:
   - encrypt: ^5.0.3
   - pointycastle: ^3.7.3

2. Modificar lib/services/vault_service.dart:
   - Reemplazar _xorBytes() con AES-GCM
   - Usar PBKDF2 para derivación de claves
   - Generar IV aleatorio de 16 bytes
   - Actualizar magic tag a NFILE_VAULT_V2

3. Mantener compatibilidad con archivos antiguos

4. Agregar logging de seguridad

5. NO modificar archivos fuera de vault_service.dart
