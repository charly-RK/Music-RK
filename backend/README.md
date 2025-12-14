# YouTube Download Backend Server

Backend server para descargar audio de YouTube usando yt-dlp.

## Requisitos

- Python 3.8 o superior
- FFmpeg instalado en el sistema

## Instalación

1. **Instalar Python** (si no lo tienes):
   - Descarga desde https://www.python.org/downloads/
   - Durante la instalación, marca "Add Python to PATH"

2. **Instalar FFmpeg**:
   - Descarga desde https://ffmpeg.org/download.html
   - O usa chocolatey: `choco install ffmpeg`
   - Verifica con: `ffmpeg -version`

3. **Instalar dependencias de Python**:
   ```bash
   cd backend
   pip install -r requirements.txt
   ```

## Ejecutar el Servidor

```bash
python server.py
```

El servidor se ejecutará en `http://0.0.0.0:5000`

## Obtener tu IP Local

Para conectar desde el emulador/dispositivo Android:

**Windows:**
```bash
ipconfig
```
Busca "IPv4 Address" en tu adaptador WiFi (ejemplo: `192.168.1.100`)

**Configurar en Flutter:**
Edita `lib/config/api_config.dart` y usa tu IP:
```dart
static const String baseUrl = 'http://192.168.1.100:5000';
```

## Endpoints

### POST /search
Buscar videos en YouTube
```json
{
  "query": "nombre de la canción"
}
```

### POST /download
Descargar y convertir a MP3
```json
{
  "video_id": "ID_del_video",
  "title": "Nombre de la canción"
}
```

### GET /health
Verificar que el servidor está funcionando

## Notas

- Los archivos se guardan en `backend/downloads/`
- El servidor debe estar corriendo mientras usas la app
- Asegúrate de que el firewall permita conexiones en el puerto 5000
