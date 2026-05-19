# MusicRK

MusicRK es una aplicación móvil de música desarrollada con **Flutter** e integrada con un backend en **Python (Flask)**. Está diseñada para ofrecer una experiencia avanzada de reproducción multimedia y permitir la búsqueda y descarga directa de música de alta calidad (320kbps MP3) con metadatos y portadas completas.

El sistema de descargas del backend cuenta con un mecanismo de reintentos automático que incluye **rotación de IPs** (a través de la red Tor o asignación dinámica de IPv6) para evadir las restricciones y bloqueos automáticos de descarga de YouTube.

---

## Estructura del Repositorio

*   **`musicrk/`**: Aplicación frontend desarrollada en Flutter para dispositivos móviles.
*   **`backend/`**: Servidor API en Python (Flask) que procesa las búsquedas de canciones/álbumes y gestiona las descargas y conversiones.

---

## Requisitos Previos del Sistema

Antes de iniciar, debes tener instalados los siguientes componentes en tu sistema host:

1.  **Flutter SDK**: Sigue la guía oficial de instalación en [flutter.dev](https://docs.flutter.dev/get-started/install).
2.  **Python 3.10 o superior**: Disponible en [python.org](https://www.python.org/).
3.  **FFmpeg** (Mandatorio): Crítico para codificar y empotrar metadatos en los archivos MP3 descargados.
    *   **Windows**: Descarga desde [ffmpeg.org](https://ffmpeg.org/download.html), extrae el archivo y añade la carpeta `bin` a las variables de entorno de tu sistema (PATH).
    *   **Linux**: `sudo apt update && sudo apt install ffmpeg`
    *   **Mac**: `brew install ffmpeg`
4.  **Tor** (Opcional): Si deseas habilitar la rotación automática de IP a través de proxies locales para descargas masivas ininterrumpidas.
    *   **Windows**: Descarga e instala Tor Browser o el servicio autónomo de Tor. Configura el puerto de control `9051` y el puerto SOCKS `9050`.
    *   **Linux**: `sudo apt install tor`

---

## Guía de Instalación y Despliegue

### 1. Clonar el Proyecto
```bash
git clone https://github.com/charly-RK/Music-RK.git
cd Music-RK
```

---

### 2. Configurar y Levantar el Backend (Python)

Puedes levantar el backend de dos formas: **Localmente** o mediante **Docker**.

#### Opción A: Despliegue Local (Tradicional)
1.  Navega a la carpeta del backend:
    ```bash
    cd backend
    ```
2.  Crea e instala las dependencias en un entorno virtual:
    ```bash
    # Crear venv
    python -m venv venv
    
    # Activar venv (Windows)
    .\venv\Scripts\activate
    # Activar venv (Linux/Mac)
    source venv/bin/activate
    
    # Instalar librerías
    pip install -r requirements.txt
    ```
3.  Inicia el servidor Flask:
    ```bash
    python server.py
    ```
    El backend se iniciará localmente en `http://localhost:5001`.

#### Opción B: Despliegue con Docker
El backend está completamente containerizado. El contenedor incluye automáticamente Python, FFmpeg, y el servicio de Tor preconfigurado para rotación de IPs.
1.  Desde la raíz del proyecto, navega a `backend/` y construye la imagen:
    ```bash
    cd backend
    docker build -t musicrk-backend .
    ```
2.  Ejecuta el contenedor exponiendo el puerto `5001`:
    ```bash
    docker run -d -p 5001:5001 --name musicrk-backend musicrk-backend
    ```

---

### 3. Configurar y Levantar el Frontend (Flutter)

1.  Navega a la carpeta de la aplicación móvil:
    ```bash
    cd ../musicrk
    ```
2.  Obtén todas las dependencias del SDK de Dart y Flutter:
    ```bash
    flutter pub get
    ```
3.  **Configurar dirección IP de la API**:
    *   Abre el archivo `lib/config/api_config.dart`.
    *   Reemplaza el host por la dirección IP de tu máquina en la red local (ejemplo: `http://192.168.1.100:5001` si estás probando con un celular físico conectado a la misma red WiFi).
4.  Lanza la aplicación en tu emulador o dispositivo físico conectado:
    ```bash
    flutter run
    ```

---

---

## Términos de Licencia y Uso

Este proyecto es propiedad privada de **Risk-Keep**. Se permite su clonación, edición y ejecución local estrictamente para fines de **aprendizaje, estudio o uso personal no comercial**. Queda expresamente prohibido su despliegue comercial en producción, redistribución o publicación en tiendas de aplicaciones sin previo consentimiento.

Para ver todos los términos y exclusiones legales, consulte el archivo [LICENSE.txt](file:///c:/Users/RISK/Desktop/Proyectos/%202026/FLUTTER/musicrk_1/LICENSE.txt).
