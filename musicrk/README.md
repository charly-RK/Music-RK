# MusicRK - Flutter App 🎵

Aplicación móvil de música desarrollada con Flutter que permite reproducir música local, descargar canciones de YouTube y gestionar tu biblioteca musical.

## 📱 Características Principales

### Reproducción de Audio
- ✅ Reproducción de música local del dispositivo
- ✅ Notificación con controles de reproducción en segundo plano
- ✅ Visualización de carátulas de álbum
- ✅ Barra de progreso interactiva
- ✅ Controles: play/pause, siguiente, anterior, favoritos
- ✅ Persistencia del estado de reproducción

### Gestión de Biblioteca
- ✅ Todas las canciones
- ✅ Álbumes
- ✅ Artistas
- ✅ Favoritos
- ✅ Playlists personalizadas
- ✅ Búsqueda de canciones

### Descargas de YouTube
- ✅ Búsqueda de videos en YouTube
- ✅ Descarga de audio en MP3 (320kbps)
- ✅ Conversión automática
- ✅ Integración con la biblioteca

## 🚀 Instalación

### Requisitos
- Flutter SDK 3.8.1+
- Dart SDK 3.8.1+
- Android Studio o VS Code
- Dispositivo Android o emulador

### Pasos

1. **Instalar dependencias**:
```bash
flutter pub get
```

2. **Generar iconos de la app** (opcional):
```bash
flutter pub run flutter_launcher_icons
```

3. **Ejecutar la aplicación**:
```bash
flutter run
```

## 🏗️ Estructura del Proyecto

```
lib/
├── config/
│   └── api_config.dart          # Configuración del backend
├── pag/
│   ├── inicio.dart              # Página principal
│   ├── all_songs.dart           # Todas las canciones
│   ├── albums.dart              # Vista de álbumes
│   ├── artistas.dart            # Vista de artistas
│   ├── favoritos.dart           # Canciones favoritas
│   ├── playlists.dart           # Gestión de playlists
│   ├── play.dart                # Reproductor principal
│   └── download_youtube.dart    # Descarga de YouTube
├── services/
│   ├── audio_player_handler.dart    # Servicio de audio en segundo plano
│   ├── download_service.dart        # Servicio de descargas
│   ├── favorites_service.dart       # Gestión de favoritos
│   └── playlist_service.dart        # Gestión de playlists
├── widgets/
│   ├── optimized_album_art.dart     # Widget de carátula optimizado
│   └── ...
└── main.dart                    # Punto de entrada
```

## 🔧 Configuración

### Backend de YouTube (Opcional)

Si deseas usar la función de descarga de YouTube, necesitas configurar el backend:

1. Ver instrucciones en [SETUP_BACKEND.md](SETUP_BACKEND.md)
2. Configurar la URL del backend en `lib/config/api_config.dart`:

```dart
class ApiConfig {
  static const String baseUrl = 'https://tu-backend.railway.app';
}
```

### Permisos de Android

Los permisos necesarios ya están configurados en `android/app/src/main/AndroidManifest.xml`:

- `READ_EXTERNAL_STORAGE` - Leer archivos de música
- `WRITE_EXTERNAL_STORAGE` - Guardar descargas
- `INTERNET` - Descargar de YouTube
- `FOREGROUND_SERVICE` - Reproducción en segundo plano
- `WAKE_LOCK` - Mantener reproducción activa

## 📦 Dependencias Principales

```yaml
dependencies:
  # Audio
  just_audio: ^0.9.40              # Reproducción de audio
  audio_service: ^0.18.15          # Servicio en segundo plano
  on_audio_query: ^2.9.0           # Consulta de archivos de música
  
  # Base de datos
  sqflite: ^2.4.2                  # Base de datos SQLite
  shared_preferences: ^2.2.2       # Preferencias
  
  # Descargas
  http: ^1.2.2                     # Peticiones HTTP
  ffmpeg_kit_flutter_new: ^4.1.0   # Conversión de audio
  
  # UI
  flutter_local_notifications: ^17.2.3  # Notificaciones
  file_picker: ^8.0.0              # Selector de archivos
  share_plus: ^10.1.3              # Compartir
```

## 🎨 Diseño

La aplicación utiliza un diseño moderno con:
- **Tema principal**: Azul (#1976D2) con fondos blancos
- **Animaciones fluidas**: Transiciones suaves entre pantallas
- **Glassmorphism**: Efectos de vidrio esmerilado
- **Notificación personalizada**: Controles completos en la notificación

## 🔨 Compilar para Producción

### APK
```bash
flutter build apk --release
```

### App Bundle (para Google Play)
```bash
flutter build appbundle --release
```

Los archivos compilados estarán en:
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- Bundle: `build/app/outputs/bundle/release/app-release.aab`

## 🐛 Solución de Problemas

### Error de permisos
Si la app no puede leer música:
1. Verifica que los permisos estén en el Manifest
2. En Android 11+, asegúrate de solicitar `MANAGE_EXTERNAL_STORAGE`

### Error de compilación de Gradle
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

### Problemas con audio_service
Asegúrate de tener las configuraciones correctas en:
- `android/app/src/main/AndroidManifest.xml`
- Servicio de audio declarado

## 📚 Recursos

- [Documentación de Flutter](https://docs.flutter.dev/)
- [just_audio](https://pub.dev/packages/just_audio)
- [audio_service](https://pub.dev/packages/audio_service)
- [on_audio_query](https://pub.dev/packages/on_audio_query)

## 🤝 Contribuir

Este es un proyecto privado. Para contribuciones, contacta al autor.

## 📄 Licencia

Proyecto privado - Todos los derechos reservados.

---

**Desarrollado con ❤️ usando Flutter**
