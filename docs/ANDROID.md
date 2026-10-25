# Android · Universal Agents 25

Versión 0.2.0, paquete `com.universalagents25.app`, versionCode 1. Android 8.0/API 26 o posterior. La app es una Activity Java con WebView del sistema y utiliza `https://universalagents25.com/` y sus cuentas Supabase. Requiere conexión a Internet; las funciones de contratación y ejecución de agentes siguen en desarrollo.

## Uso

Los controles nativos abren Inicio y Mi cuenta, permiten volver por el historial o recargar. Un error de carga muestra Reintentar. El giro conserva la WebView y los formularios; el almacenamiento de sesión pertenece a la instalación de la app. La confirmación o recuperación recibida por correo se abre en el navegador: después de confirmar, vuelve a la app e inicia sesión allí. La app y el navegador no comparten automáticamente su sesión.

## Compilación

Se usan JDK 17, AGP 9.3.0, Gradle 9.8.0 con SHA-256 fijado, plataforma `platforms;android-37.0` y build-tools 36.0.0. No hay dependencias de ejecución adicionales; JUnit 4.13.2 se utiliza solo en pruebas. Define `ANDROID_HOME`/`JAVA_HOME` en el entorno del proceso, o la ruta local del SDK en `android/local.properties`, que está ignorado.

```powershell
cd android
.\gradlew.bat testDebugUnitTest lintDebug assembleDebug --no-daemon
```

El APK se genera en `android/app/build/outputs/apk/debug/app-debug.apk`. Es una compilación **debug firmada para pruebas**, no una publicación de Play Store. El APK es universal al no incluir bibliotecas nativas por arquitectura. Las claves y los caches de compilación no forman parte del repositorio ni del artefacto distribuido.

## Seguridad

- WebView acepta internamente solo HTTPS del host exacto `universalagents25.com`, en puerto 443 o predeterminado y sin usuario embebido en la URL.
- Enlaces HTTPS externos, correo y teléfono se abren mediante una aplicación externa. Esquemas `javascript`, `file`, `content`, `data` e `intent` quedan bloqueados.
- No hay puente JavaScript a código nativo, acceso a archivos/contenido, contenido mixto ni tráfico HTTP sin cifrar. Los errores TLS se cancelan y se muestran al usuario.
- No se conceden cámara, micrófono, geolocalización o selector de archivos. El único permiso solicitado es Internet. Las copias de seguridad de datos de la app están deshabilitadas para excluir sesiones.
- Las contraseñas y la configuración SMTP no se guardan en la app. La autenticación y los permisos siguen dependiendo de Supabase Auth/RLS.

## Verificación

Las pruebas JUnit cubren el límite de confianza de URLs, incluidos hosts parecidos, credenciales embebidas, puertos y esquemas inseguros. Lint trata las advertencias como errores; se excluye únicamente la recomendación de usar versiones de herramientas más nuevas porque las versiones están fijadas. CI compila el APK y ejecuta pruebas/lint además de las comprobaciones de web y PostgreSQL.

La firma, la alineación ZIP, la versión, el paquete y los permisos del APK se verifican antes de copiarlo a Drive. La prueba de interfaz, teclado, navegación y sesión en un dispositivo Android queda pendiente: no había teléfono conectado ni emulador utilizable; activar la aceleración del emulador requería cambiar Windows y reiniciar. Esta limitación no se presenta como una prueba superada.
