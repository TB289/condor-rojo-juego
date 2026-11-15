# Biblia de arte — Cóndor Rojo

Referencias del equipo en `assets/refs/` (astronauta chunky, sheet de caminata, Mars Bundle / colonia con domos, paths y Tierra en el cielo).

## Resolución y escala
- **Tiles de suelo:** 16×16 (recomendado; encaja con packs Marte top-down). Alternativa 32×32 si todo el set va a esa escala — no mezclar.
- **Astronauta:** canvas de sprite **32×32 a 48×48** (pies anclados abajo-centro). Silueta chunky, cabeza grande, traje abultado.
- **Viewport de diseño:** 1280×720 o 1920×1080 ventana; cámara con zoom **3× o 4×** sobre tiles 16×16 para look pixelado nítido.
- **Filtro:** Nearest (sin blur).

## Perspectiva y cámara
- **3/4 top-down** (se ve el frente y un poco el techo de edificios), tipo Pokémon clásico / Don't Starve.
- Cámara sigue al player con smoothing suave y lookahead corto hacia la dirección de movimiento.
- **Y-sort** en la capa de entidades (player, props, módulos). El TileMap de terreno no usa Y-sort.
- Capas sugeridas: `Ground` → `Decals` (paths/cráteres) → `Shadows` → `Entities` (Y-sort) → `Overhang` → `Weather` (polvo) → `HUD`.

## Paleta
| Uso | Guía |
|---|---|
| Suelo Marte | Naranjas óxido / terracota / marrón path más oscuro |
| Traje | Blancos y grises claros; sombras gris-azul |
| Visor | Casi negro / navy; un highlight |
| Acento traje | **Rojo** pecho o cinturón (marca Cóndor Rojo) |
| Parche Ecuador | Mini bandera **amarillo / azul / rojo** en hombro o pecho (pocos píxeles, legible) |
| Base | Gris metálico, ventanas cyan/azul, paneles solares azul |
| UI recursos | O2 cyan, power amarillo, escudo violeta, comida verde |
| Cielo | Rojo-marrón a negro; **Tierra** pequeña arriba |

Evitar saturación extrema y outlines negros gordos en todo: outlines oscuros del mismo matiz ayudan a integrar (como en la ref del sheet).

## Astronauta — animaciones MVP
Direcciones MVP: **4** (down, left, right, up). Stretch: 8.

| Animación | Frames (por dirección) | Notas |
|---|---|---|
| idle | 2 (ping-pong) | Respiración / bob suave |
| walk | 4 | Ciclo claro; bob de cuerpo |
| interact | 3 | Brazo / panel |
| carry | 4 walk + 1 idle | Objeto en manos o over-head chico |

Prioridad de dibujo: `walk_down` + `idle_down` primero; luego left/right (flip si hace falta); up al final.

## Mapa Marte — tiles MVP
- Autotile / terreno base rust
- Path (recto, esquina, T, cross)
- Cráteres S/M/L
- Rocas S/M
- Decals de grietas / polvo

## Módulos de base MVP
1. Hábitat cilíndrico (entrada visible)
2. Domo greenhouse (interior verde legible a zoom)
3. Paneles solares (×2)
4. Antena / dish
5. Tanques de oxígeno
6. Rover (estático MVP; manejar stretch)
7. Cajas / props
8. Bandera Ecuador (para la escena de plantado)

## Lista de assets priorizada
**P0 (semana 1):** astronauta 4-dir walk+idle; tiles suelo+path+1 cráter; hábitat; greenhouse; paneles; tanques; HUD iconos; avatar INTI (sol simple); bandera.
**P1:** antena, rover, más rocas/cráteres, dust overlay, Earth sky, interact/carry frames.
**P2:** interiores, más módulos, FX tormenta, cutscene frames.

## Packs de terceros verificados (opcionales)
Usar solo si la licencia permite el uso y se **cita** en créditos (Terms Space Apps: third-party materials deben ser libres/OSI y citados).

| Pack | Link | Notas |
|---|---|---|
| Mars Bundle 16×16 (Maru) | https://maru-98.itch.io/mars-bundle-16x16-topdown-pixel-art | De pago; terreno, edificios, astronautas |
| Mars Surface Pack (Maru) | https://maru-98.itch.io/mars-surface-pack-top-down-pixel-art-16x16-terrain-paths-craters | Terreno, paths, cráteres |
| Martian Asset Pack (Goomba Perron) | https://goombaperron.itch.io/martian-tileset | Gratis, CC0 |
| Mars Power Plant Tileset (DatIndie) | https://datindie.itch.io/mars-tileset | Gratis, 32×32 |
| Mars Base Tileset-DLC (Cute SCKR) | https://comshadow.itch.io/mars-base-pixel-art-tileset-dlc | De pago |

Ideal: prototipar con un pack libre/CC0 o el estilo de las refs propias; el astronauta final debería seguir **sus** refs (acento rojo + parche Ecuador), no copiar un pack tal cual.

## FAQ / legal Space Apps (assets)
La FAQ dice que los equipos no deben empezar el challenge antes del hackathon si participan oficialmente. Los Terms exigen que materiales de terceros sean públicos/open source (o sin restricción) y **citados**. No hay una prohibición explícita de “asset packs” en el texto revisado, pero sí de usar material sin derechos o sin citar.
