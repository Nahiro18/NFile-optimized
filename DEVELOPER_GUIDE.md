# Guía para Desarrolladores - NFile

## Descripción

NFile es una aplicación de administración de archivos moderna y estética para Android, construida con Flutter. Ofrece una experiencia premium con tema oscuro AMOLED, reproductores multimedia integrados y operaciones de archivo avanzadas.

## Arquitectura

### State Management
- **Provider Pattern**: Usamos `provider` para gestión de estado
- **ChangeNotifier**: Los providers extienden ChangeNotifier para notificar cambios
- **MultiProvider**: Múltiples providers en el árbol de widgets

### Estructura de Carpetas

```
lib/
├── core/                    # Utilidades y configuración base
│   ├── theme.dart          # Sistema de temas (light/dark/amoled)
│   ├── utils.dart          # Utilidades de archivos y formateo
│   └── icon_fonts/         # Iconos personalizados (Broken icons)
│
├── models/                 # Modelos de datos
│   ├── file_item_model.dart
│   ├── app_info_model.dart
│   └── network_connection_model.dart
│
├── providers/              # Estado de la aplicación
│   ├── file_manager_provider.dart    # Operaciones de archivos
│   └── media_provider.dart           # Indexación de multimedia
│
├── services/               # Servicios de negocio
│   ├── vault_service.dart           # Bóveda segura (AES-256-GCM)
│   ├── archive_service.dart         # Compresión/descompresión
│   ├── preferences_service.dart     # Preferencias del usuario
│   ├── recycle_bin_service.dart     # Papelera de reciclaje
│   └── remote/                      # Clientes de red (FTP, SFTP, WebDAV)
│
└── ui/                     # Interfaz de usuario
    ├── screens/            # Pantallas completas
    │   ├── home_screen.dart
    │   ├── directory_screen.dart
    │   └── vault_explorer_screen.dart
    └── widgets/            # Widgets reutilizables
        ├── file_item.dart
        └── storage_overview.dart
```

## Configuración del Entorno

### Requisitos
- Flutter SDK 3.11.5 o superior
- Dart SDK 3.11.5 o superior
- Android Studio / VS Code
- Git

### Instalación

```bash
# Clonar el repositorio
git clone https://github.com/Nahiro18/NFile-optimized.git
cd NFile-optimized

# Instalar dependencias
flutter pub get

# Ejecutar en modo debug
flutter run

# Construir APK de release
flutter build apk --release
```

## Testing

### Ejecutar Tests

```bash
# Todos los tests
flutter test

# Tests con cobertura
flutter test --coverage

# Tests específicos
flutter test test/services/vault_service_test.dart
```

### Escribir Tests

Los tests siguen la estructura:
```dart
void main() {
  group('NombreDelServicio', () {
    test('debería hacer X', () async {
      // Arrange
      // Act
      // Assert
    });
  });
}
```

## Seguridad

### VaultService (Bóveda Segura)

La bóveda usa **AES-256-GCM** para cifrado:

- **Derivación de claves**: PBKDF2 con 100,000 iteraciones
- **Salt**: 32 bytes aleatorios por contraseña
- **IV**: 16 bytes aleatorios por archivo
- **Autenticación**: GCM proporciona autenticación integrada

### Ejemplo de Uso

```dart
// Configurar contraseña
await VaultService.setPassword('MiContraseñaSegura123!');

// Cifrar archivo
final record = await VaultService.lockFile(
  file: File('/path/to/secret.txt'),
  password: 'MiContraseñaSegura123!',
  inPlace: false, // Guardar en directorio privado de la app
);

// Descifrar archivo
final file = await VaultService.unlockFile(
  record: record,
  password: 'MiContraseñaSegura123!',
);
```

## Optimizaciones Implementadas

### 1. LRU Cache para Thumbnails
- Límite de 100 thumbnails en memoria
- Evicción automática de items más antiguos
- Persistencia en disco para carga rápida

### 2. Operaciones Asíncronas
- Cálculo de tamaño de directorios sin bloquear UI
- Streams para listado de archivos
- Isolates para operaciones pesadas

### 3. Cache JSON Optimizado
- Límite de 1000 items por categoría
- Compresión gzip para reducir tamaño
- Carga lazy al iniciar la app

## Cómo Contribuir

1. Fork el repositorio
2. Crea una rama: `git checkout -b feature/tu-feature`
3. Haz tus cambios
4. Ejecuta tests: `flutter test`
5. Commit: `git commit -m "feat: descripción"`
6. Push: `git push origin feature/tu-feature`
7. Abre un Pull Request

### Convenciones de Commit

- `feat:` Nueva funcionalidad
- `fix:` Corrección de bug
- `docs:` Cambios en documentación
- `style:` Formato de código
- `refactor:` Refactorización
- `test:` Agregar o modificar tests
- `chore:` Tareas de mantenimiento

## Licencia

Este proyecto está bajo la licencia MIT. Ver `LICENSE` para más detalles.

## Contacto

- GitHub: [@Nahiro18](https://github.com/Nahiro18)
- Issues: [Reportar bug](https://github.com/Nahiro18/NFile-optimized/issues)
