# MusicRK Backend API

Este es el servidor API que da soporte a la aplicación MusicRK. Proporciona servicios de búsqueda de canciones, álbumes y descargas directas procesadas y convertidas a MP3 con metadatos incrustados.

El backend cuenta con una integración avanzada de **spotdl** y un **gestor de rotación de IPs (Tor / IPv6)** para evitar el bloqueo automático por parte de servidores de streaming.

---

## Requisitos de Entorno

*   **Python 3.10+**
*   **FFmpeg** (Instalado en el PATH del sistema)
*   **Tor** (Servicio activo en puertos `9050`/`9051` si se habilita la rotación por proxy)

---

## Instalación y Configuración Local

1.  Navega a esta carpeta:
    ```bash
    cd backend
    ```
2.  Crea y activa tu entorno virtual:
    ```bash
    python -m venv venv
    # Windows:
    .\venv\Scripts\activate
    # Linux/Mac:
    source venv/bin/activate
    ```
3.  Instala los requisitos:
    ```bash
    pip install -r requirements.txt
    ```
4.  Inicia el servidor en modo desarrollo:
    ```bash
    python server.py
    ```

El servidor se iniciará en `http://localhost:5001`.

---

## Despliegue con Docker (Recomendado)

El backend incluye un `Dockerfile` y un script de inicio (`start.sh`) que levantan automáticamente el servidor Flask junto con un servicio de Tor configurado para rotar identidades de IP en tiempo real ante bloqueos de descarga.

### Construir Imagen:
```bash
docker build -t musicrk-backend .
```

### Iniciar Contenedor:
```bash
docker run -d -p 5001:5001 --name musicrk-backend musicrk-backend
```

---

## Endpoints de la API

*   `POST /search`
    *   **Body (JSON)**: `{"query": "nombre canción"}`
    *   **Descripción**: Devuelve una lista de resultados de canciones de YouTube.
*   `POST /download`
    *   **Body (JSON)**: `{"id": "video_id", "title": "titulo", "author": "autor"}`
    *   **Descripción**: Descarga el audio, lo convierte a MP3 a 320kbps, añade la carátula/metadatos y devuelve el archivo de audio.
*   `POST /search_albums`
    *   **Body (JSON)**: `{"query": "nombre album"}`
    *   **Descripción**: Devuelve una lista de álbumes oficiales encontrados.
*   `POST /download_album`
    *   **Body (JSON)**: `{"id": "playlist_id", "title": "titulo", "author": "autor"}`
    *   **Descripción**: Descarga todas las canciones pertenecientes al álbum en una carpeta dedicada y comprimida, permitiendo la bajada en lote.
*   `GET /health`
    *   **Descripción**: Verifica el estado de salud de los servicios del backend (incluyendo la disponibilidad del proxy de Tor).

---

## Términos de Licencia y Uso

Para conocer las limitaciones de distribución y uso no comercial del código fuente del backend, consulte el archivo [LICENSE.txt](file:///c:/Users/RISK/Desktop/Proyectos/%202026/FLUTTER/musicrk_1/LICENSE.txt) ubicado en la raíz del proyecto.
