# Guía de Configuración - YouTube Download Backend

## 📋 Resumen
Tu app ahora usa un servidor backend Python para descargar música de YouTube, ya que los paquetes directos de Flutter no funcionan.

## 🔧 Configuración Inicial

### Paso 1: Instalar Python y FFmpeg

1. **Instalar Python** (si no lo tienes):
   - Descarga desde: https://www.python.org/downloads/
   - Durante la instalación, **marca "Add Python to PATH"**
   - Verifica: abre CMD y ejecuta `python --version`

2. **Instalar FFmpeg**:
   - **Opción A - Chocolatey** (recomendado):
     ```cmd
     choco install ffmpeg
     ```
   
   - **Opción B - Manual**:
     - Descarga desde: https://ffmpeg.org/download.html
     - Extrae y agrega a PATH
   
   - Verifica: `ffmpeg -version`

### Paso 2: Configurar el Backend

1. Abre una terminal en la carpeta del backend:
   ```cmd
   cd "C:\Users\RISK\Desktop\Proyectos\ 2026\FLUTTER\musicrk_1\musicrk\backend"
   ```

2. Instala las dependencias de Python:
   ```cmd
   pip install -r requirements.txt
   ```

### Paso 3: Obtener tu IP Local

1. Abre CMD y ejecuta:
   ```cmd
   ipconfig
   ```

2. Busca "IPv4 Address" en tu adaptador WiFi
   - Ejemplo: `192.168.1.100`

3. Edita el archivo `lib/config/api_config.dart`:
   ```dart
   static const String baseUrl = 'http://TU_IP_AQUI:5000';
   ```
   Reemplaza `TU_IP_AQUI` con tu IP (ejemplo: `192.168.1.100`)

## 🚀 Uso Diario

### Iniciar el Servidor Backend

1. Abre una terminal en la carpeta backend:
   ```cmd
   cd "C:\Users\RISK\Desktop\Proyectos\ 2026\FLUTTER\musicrk_1\musicrk\backend"
   python server.py
   ```

2. Verás:
   ```
   🚀 YouTube Download Server Starting...
   📁 Download directory: ...
   🌐 Server running on http://0.0.0.0:5000
   ```

3. **IMPORTANTE**: Mantén esta terminal abierta mientras uses la app

### Usar la App

1. Asegúrate de que:
   - El servidor backend está corriendo
   - Tu PC y dispositivo Android están en la misma red WiFi
   - El firewall permite conexiones en el puerto 5000

2. Abre la app en tu dispositivo/emulador

3. Ve a "Buscar y Descargar"

4. Busca una canción y descárgala

5. Los archivos MP3 se guardarán en `/storage/emulated/0/Music/`

## 🔍 Solución de Problemas

### "No se puede conectar al servidor"

1. Verifica que el servidor está corriendo
2. Verifica que la IP en `api_config.dart` es correcta
3. Prueba el servidor desde el navegador: `http://TU_IP:5000/health`
4. Verifica el firewall de Windows

### "Error de descarga"

1. Verifica que FFmpeg está instalado: `ffmpeg -version`
2. Revisa los logs del servidor en la terminal
3. Asegúrate de tener espacio en disco

### Configurar Firewall (si es necesario)

1. Abre "Windows Defender Firewall"
2. Click en "Advanced settings"
3. Click en "Inbound Rules" → "New Rule"
4. Selecciona "Port" → Next
5. TCP, puerto 5000 → Next
6. Allow the connection → Next
7. Aplica a todos los perfiles → Next
8. Nombre: "Python Flask Server" → Finish

## 📝 Notas

- El servidor debe estar corriendo cada vez que quieras descargar música
- Los archivos se descargan primero al servidor, luego se transfieren al dispositivo
- Puedes cerrar el servidor cuando no lo uses
- Los archivos descargados en el servidor quedan en `backend/downloads/`

## 🎯 Próximos Pasos (Opcional)

Para uso en producción, considera:
- Desplegar el backend en un servidor cloud (Heroku, Railway, etc.)
- Usar HTTPS para conexiones seguras
- Agregar autenticación al backend
