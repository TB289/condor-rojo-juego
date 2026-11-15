# Jugar en la web (GitHub Pages y celular)

- El preset Web exporta a `docs/index.html`, sin hilos (`variant/thread_support=false`). GitHub Pages no puede enviar las cabeceras COOP/COEP, así que SharedArrayBuffer debe quedarse apagado.
- En la carpeta `docs/` deben existir `.nojekyll` y `.gdignore` para que Pages sirva los archivos y Godot no reimporte la exportación.
- `html/canvas_resize_policy=2` deja que el lienzo siga al contenedor. El `head_include` del preset pone un `viewport` para teléfono, `overflow: hidden`, `touch-action: none` y el lienzo al 100%, con los colores de la paleta (espacio, navy, contorno, inti).
- No fije el canvas a 640x360 en CSS: eso impediría que el juego llene el teléfono o la ventana del navegador.
- Instale las export templates de Godot 4.7 en el editor antes de exportar. Después de exportar, abra la página en un teléfono en horizontal y en un computador, y compruebe que la ventana se pueda redimensionar.

## Pantalla de carga personalizada (AstroSharks)

1. El logo editable original está en `assets/branding/condor_logo.png` (pixel art del astronauta y Marte).
2. El preset `Web` referencia `web/condor_shell.html` en **HTML > Custom HTML Shell**; Godot usa este archivo al exportar, por lo que no hay que editar `docs/index.html` a mano.
3. La etiqueta `$GODOT_SPLASH` apunta automáticamente a `docs/index.png` después de exportar. Godot genera ese PNG a partir de `application/boot_splash/image` en `project.godot`, que también apunta al logo. Así no hace falta copiar recursos manualmente a `docs/`.
4. La pantalla visual se muestra **solo en el navegador**: durante la descarga real del `.wasm` y `.pck`, el progreso viene de `onProgress`. Si el navegador no puede calcular el total, se muestra una animación de carga sin porcentaje inventado.
5. Godot tiene `boot_splash/show_image=false` para evitar el splash del motor una vez que se inicia. El icono de la app y el favicon Web usan la misma imagen del proyecto.
6. Para subir la nueva versión a GitHub Pages, exporta **Web** de nuevo a `docs/index.html`, y publica **todos** los archivos actualizados de `docs/` (HTML, JS, WASM, PCK y PNG). Un ZIP con solo el proyecto fuente no actualiza el sitio por sí solo.
7. Comprobación: abre la versión recién exportada mediante un servidor web (Godot **Run in Browser** o GitHub Pages), no haciendo doble clic en el HTML con `file://`. Prueba celular en horizontal y escritorio.

Nota: hay un `icon.svg` antiguo en la raíz, pero ya no se usa como icono del proyecto.
