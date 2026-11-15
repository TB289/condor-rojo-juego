# Especificaciones del sprint (mandan sobre otros docs)

## Resolución y pantalla
- Viewport base 640x360. Ventana 1280x720 (x2); en 1920x1080 escala x3.
- Stretch mode `viewport`, aspect `keep`, scale_mode `integer`. Píxeles siempre cuadrados y nítidos.
  Si el texto del HUD se ve muy tosco, se puede pasar a `canvas_items` más adelante; no mezclar a mitad del sprint.
- Filtro de texturas por defecto: Nearest. Snap 2D de transforms y vértices al píxel: activado.
- Renderer: Compatibility (obligatorio para el export Web).

## Tamaños
- Tile de suelo: 16x16. Toda la escala del mundo se mide en tiles de 16.
- Personaje: frames de 32x32 (2 tiles de alto), pies en y=29..30 del frame, centrado en x=16.
- Props: 32x32 (rocas medianas, cráteres). Módulos: múltiplos de 16 (hábitat 64x48, invernadero 64x48, panel 48x32, tanques 32x32, antena 32x48, rover 48x32, lander 64x64, bandera 16x32).
- Íconos de HUD: 16x16 (se muestran x2). Avatar INTI: 32x32.

## Personaje
- Sheets: filas = direcciones (0 down, 1 left, 2 right, 3 up), columnas = frames.
- idle: 2 frames, 3 fps. walk: 4 frames, 8 fps. interact: 3 frames, 10 fps sin loop.
- Nombres en SpriteFrames: `idle_down`, `idle_left`, `idle_right`, `idle_up`, `walk_down`, ..., `interact_up`.
- AnimatedSprite2D centered, offset (0, -14). El origen del Player está en los pies.
- Movimiento: max_speed 90 px/s, acceleration 900, friction 1200 (ajustables).

## Mapa y cámara
- Ground: TileMapLayer sin Y-sort. Entities: Node2D con Y-sort (player, props, módulos, lander).
- Capas: Ground, Decals, Entities (Y-sort), Weather (polvo), HUD (CanvasLayer).
- Cámara: smoothing 6, lookahead máx 24 px, zoom 1, límites del mapa.

## Recursos
- Solo 3 visibles: oxígeno (cian), energía (amarillo), comida (verde). Agua opcional como 4.º recurso, apagada por defecto.
- 0..100 cada uno. El escudo de radiación no es una barra: es el hábitat y las decisiones en tormentas solares.

## Loop
- 1 sol = 3 minutos. Partida = 10 sols. Diario al final de cada sol con 2 o 3 decisiones.
- Mínimo 3 finales. Nada trágico: si algo llega a 0, protocolo de rescate y debrief.

## INTI
- Panel con avatar, texto corto, preguntas rápidas y campo libre (140 caracteres).
- Pregunta libre: POST al proxy propio (`/api/inti`), nunca a la API directo. La key vive solo en el servidor.
- Siempre hay fallback offline con líneas guionadas.
- INTI enseña, avisa y da pistas. Nunca decide ni aplica una decisión.
