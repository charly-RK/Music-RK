# Guía de Despliegue en Railway

## 🚀 Método 1: Deploy Automático (SIN Docker - Recomendado)

Railway detecta automáticamente Python y usa `Procfile`.

### Pasos:

1. **Sube a GitHub** (si no lo has hecho):
   ```cmd
   cd "C:\Users\RISK\Desktop\Proyectos\ 2026\FLUTTER\musicrk_1\backend"
   git init
   git add .
   git commit -m "Backend para Railway"
   git remote add origin https://github.com/TU_USUARIO/musicrk-backend.git
   git branch -M main
   git push -u origin main
   ```

2. **Ve a Railway**: https://railway.app/

3. **Login con GitHub**

4. **New Project** → **Deploy from GitHub repo**

5. **Selecciona** `musicrk-backend`

6. **Railway detecta automáticamente**:
   - Python
   - Instala `requirements.txt`
   - Ejecuta `Procfile`

7. **Espera 3-5 minutos** al deploy

8. **Genera dominio**:
   - Click en tu servicio
   - Settings → Generate Domain
   - Copia la URL: `https://tu-app.up.railway.app`

9. **Actualiza Flutter**:
   ```dart
   static const String baseUrl = 'https://tu-app.up.railway.app';
   ```

---

## 🐳 Método 2: Con Docker (Más Control)

Si prefieres usar Docker:

### Archivos Creados:
- ✅ `Dockerfile` - Configuración de Docker
- ✅ `.dockerignore` - Archivos a excluir

### Pasos:

1. **Sube a GitHub** (incluye Dockerfile):
   ```cmd
   git add Dockerfile .dockerignore
   git commit -m "Add Docker support"
   git push
   ```

2. **Railway detectará automáticamente** el Dockerfile

3. **Deploy** - Railway construirá la imagen Docker

### Ventajas de Docker:
- ✅ FFmpeg incluido garantizado
- ✅ Mismo entorno en local y producción
- ✅ Más control sobre dependencias

---

## 📊 Comparación

| Método | Facilidad | Velocidad | Recomendado |
|--------|-----------|-----------|-------------|
| **Sin Docker** | ⭐⭐⭐⭐⭐ | Rápido | ✅ Sí |
| **Con Docker** | ⭐⭐⭐⭐ | Medio | Para avanzados |

---

## 🔧 Configuración Adicional (Opcional)

### Variables de Entorno en Railway:

Si necesitas configurar algo:
1. Click en tu servicio
2. Variables → New Variable
3. Agrega:
   - `PYTHON_VERSION`: `3.11`

---

## 💰 Uso de Créditos

Tu backend consumirá aproximadamente:
- **$0.50 - $1.50 USD/mes** en Railway
- Los $5 USD gratis son más que suficientes

### Monitoreo:
- Ve a tu proyecto en Railway
- Click "Usage" para ver consumo

---

## ✅ Verificar que Funciona

1. **Abre en navegador**: `https://tu-app.up.railway.app/health`
   - Deberías ver: `{"status":"ok","message":"Server is running"}`

2. **Prueba en la app** - busca una canción

---

## 🔄 Actualizar el Backend

Cuando hagas cambios:

```cmd
git add .
git commit -m "Descripción del cambio"
git push
```

Railway re-desplegará automáticamente.

---

## 🐛 Solución de Problemas

### Si el deploy falla:
1. Revisa logs en Railway (pestaña "Deployments")
2. Verifica que `requirements.txt` esté correcto
3. Asegúrate de que `Procfile` existe

### Si FFmpeg no funciona:
- Con Docker: Ya está incluido
- Sin Docker: Railway incluye FFmpeg por defecto

### Si las descargas son lentas:
Aumenta timeout en `Procfile`:
```
web: gunicorn server:app --bind 0.0.0.0:$PORT --timeout 600 --workers 2
```

---

## 🎯 Recomendación Final

**Usa el Método 1 (Sin Docker)** - es más fácil y Railway lo maneja perfectamente.

Solo usa Docker si:
- Quieres control total
- Necesitas dependencias específicas del sistema
- Ya conoces Docker

¡Listo! Con cualquiera de los dos métodos tendrás tu backend funcionando en Railway.
