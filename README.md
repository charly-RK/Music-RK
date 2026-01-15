# MusicRK 🎵

Una aplicación de música moderna y completa para Android, desarrollada con Flutter. Reproduce música local, descarga canciones de YouTube, gestiona playlists y mucho más.

![Flutter](https://img.shields.io/badge/Flutter-3.8.1-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.8.1-0175C2?logo=dart)
![License](https://img.shields.io/badge/License-Private-red)

## ✨ Características

### 🎵 Reproductor de Música
- Reproducción de música local del dispositivo
- Notificación de reproducción en segundo plano con controles completos
- Visualización de carátulas de álbum
- Control de reproducción: play/pause, siguiente, anterior
- Barra de progreso interactiva
- Persistencia del estado de reproducción

### 📚 Gestión de Biblioteca
- Visualización de todas las canciones
- Organización por álbumes
- Gestión de artistas
- Sistema de favoritos
- Creación y gestión de playlists personalizadas

### 📥 Descarga de YouTube
- Búsqueda de canciones en YouTube
- Descarga de audio en formato MP3 (320kbps)
- Conversión automática con FFmpeg
- Integración directa con la biblioteca de música

### 🎨 Interfaz de Usuario
- Diseño moderno con tema azul y blanco
- Animaciones fluidas y transiciones suaves
- Interfaz intuitiva y fácil de usar
- Soporte para modo oscuro

## 🏗️ Arquitectura del Proyecto

El proyecto está dividido en dos componentes principales:

```
musicrk_1/
├── musicrk/          # Aplicación Flutter
│   ├── lib/
│   │   ├── config/   # Configuración de la app
│   │   ├── pag/      # Páginas/Pantallas
│   │   ├── services/ # Servicios (audio, descargas, etc.)
│   │   └── widgets/  # Widgets reutilizables
│   └── assets/       # Recursos (imágenes, etc.)
│
└── backend/          # Servidor Python para YouTube
    ├── server.py     # API Flask
    └── downloads/    # Archivos descargados
```

## 🚀 Instalación y Configuración

### Requisitos Previos

- Flutter SDK 3.8.1 o superior
- Dart SDK 3.8.1 o superior
- Android Studio / VS Code
- Python 3.8+ (para el backend)
- FFmpeg (para conversión de audio)

### 1. Clonar el Repositorio

```bash
git clone https://github.com/TU_USUARIO/musicrk.git
cd musicrk
```

### 2. Configurar la Aplicación Flutter

```bash
cd musicrk
flutter pub get
```

### 3. Configurar el Backend (Opcional - para descargas de YouTube)

```bash
cd ../backend
pip install -r requirements.txt
```

Ver [backend/README.md](backend/README.md) para instrucciones detalladas del backend.

### 4. Ejecutar la Aplicación

```bash
cd musicrk
flutter run
```

## 📱 Permisos Necesarios

La aplicación requiere los siguientes permisos en Android:

- **Almacenamiento**: Para leer archivos de música del dispositivo
- **Notificaciones**: Para mostrar controles de reproducción
- **Internet**: Para descargar música de YouTube (opcional)

## 🛠️ Tecnologías Utilizadas

### Frontend (Flutter)
- **just_audio**: Reproducción de audio
- **audio_service**: Reproducción en segundo plano
- **on_audio_query**: Consulta de archivos de música
- **sqflite**: Base de datos local
- **shared_preferences**: Almacenamiento de preferencias
- **flutter_local_notifications**: Notificaciones
- **http**: Comunicación con el backend

### Backend (Python)
- **Flask**: Framework web
- **yt-dlp**: Descarga de videos de YouTube
- **FFmpeg**: Conversión de audio

## 📖 Documentación Adicional

- [Configuración del Backend](backend/README.md)

## 🎯 Características Próximas

- [ ] Ecualizador integrado
- [ ] Letras de canciones
- [ ] Compartir canciones
- [ ] Temas personalizables
- [ ] Sincronización en la nube
- [ ] Soporte para podcasts

## 🐛 Problemas Conocidos

- La descarga de YouTube puede fallar ocasionalmente debido a cambios en la API de YouTube
- Algunos dispositivos pueden requerir permisos adicionales para acceder al almacenamiento

## 🤝 Contribuciones

Este es un proyecto privado. Si deseas contribuir, por favor contacta al autor.

## 📄 Licencia

Este proyecto es privado y no está disponible para uso público sin autorización.

## 👨‍💻 Autor

**RISK KEEP**

## 🙏 Agradecimientos



---
