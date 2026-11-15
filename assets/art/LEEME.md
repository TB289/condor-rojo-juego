# Arte

El suelo, los módulos y los iconos se rehacen con `py -3 tools/make_placeholders.py` (necesita Pillow). Ese script no toca las hojas del astronauta: `astronaut_idle.png` y `astronaut_walk.png` son la copia aprobada de `characters/pixellab/helmet/`, e `astronaut_interact.png` se queda. Si se cambia el tamaño o la cantidad de frames, hay que correr `tools/build_frames.gd`.

| Archivo | Tamaño | Grilla |
|---|---|---|
| characters/astronaut_idle.png | 64x128 | 2 frames x 4 filas (down, left, right, up), 32x32 |
| characters/astronaut_walk.png | 128x128 | 4 frames x 4 filas |
| characters/astronaut_interact.png | 96x128 | 3 frames x 4 filas |
| tiles/mars_tiles_16.png | 64x32 | 4x2 tiles de 16: suelo A, suelo B, piedras, camino / cráter, roca, grietas, polvo |
| tiles/mars_props_32.png | 96x32 | cráter mediano, roca mediana, roca grande |
| base/habitat.png, greenhouse.png | 64x48 | origen en la base |
| base/solar_panel.png, rover.png | 48x32 | |
| base/oxygen_tank.png, crates.png | 32x32 | |
| base/antenna_dish.png | 32x48 | |
| base/lander.png | 64x64 | |
| base/flag_ecuador.png | 16x32 | |
| ui/icon_oxygen|energy|food|water.png | 16x16 | |
| ui/inti_avatar.png | 32x32 | |

Las imágenes de `refs/generated/` son solo referencia de estilo (no son pixel art real a escala). No las usen como sprites.
