# Estilo de arte — Cóndor Rojo

Las medidas del sprint no cambian: tiles de 16x16, frames del personaje de 32x32, resolución base 640x360 y filtro Nearest. Eso ya está en `docs/sprint-specs.md` y lo aplica la sesión S0.

El acabado es pixel art de arcade: formas gordas y redondeadas, píxeles grandes, contornos gruesos, astronauta chibi. Esa parte no se toca. Lo que sí cambia es el color: tiene que verse vivo, no como un naranja plano. La referencia de formas sigue siendo el campamento de `assets/refs/estilo_campamento.png`, en vista 3/4 y con siluetas claras. El bosque de `assets/refs/estilo_bosque.png` sirve para el lado de la luz y el matiz de las sombras, no para la perspectiva. Esas dos imágenes no siguen una cuadrícula de 16. Los sprites del juego sí tienen que seguirla.

Al dibujar, mire `assets/refs/generated/ref_arcade_v2_mars_base_camp.png` y `assets/refs/generated/ref_arcade_v2_astronaut_turnaround.png`. Las otras imágenes de esa carpeta, incluidas las arcade anteriores, se quedan como archivo, pero el color y la luz se toman de estas dos.

La paleta tiene 32 colores: los 22 de antes, más matices de arena, sombras con viraje, destellos y un cielo rosa-naranja. Está en `assets/art/palette/condor_rojo.gpl` (la abren Aseprite y LibreSprite) y pintada en `assets/art/palette/condor_rojo_palette.png`.

## Paleta de 32 colores

No hay negro puro. El tono más oscuro es Sombra profunda `#1A0C14`. Los contornos usan Contorno `#3A1A28`. Cada material se pinta con 2 o 3 tonos planos, más un destello de uno o dos píxeles si es metal o vidrio. No hay degradados suaves. En el suelo, los tonos de arena se mezclan con un dithering suave (puntos alternados), no con una mancha uniforme.

### Arena y roca

| Nombre | Hex |
|---|---|
| Arena muy clara | `#F8E0A0` |
| Arena clara | `#F6C878` |
| Arena | `#E8893A` |
| Ocre | `#D4A05A` |
| Terracota | `#C24A1C` |
| Parche | `#A84828` |
| Roca | `#8A2E14` |
| Piedra | `#C47848` |

### Sombras

| Nombre | Hex |
|---|---|
| Sombra granate | `#8A3058` |
| Sombra púrpura | `#5A2468` |
| Contorno | `#3A1A28` |
| Sombra profunda | `#1A0C14` |

### Base y metal

| Nombre | Hex |
|---|---|
| Destello | `#FFFCE8` |
| Metal claro | `#F0F4F8` |
| Metal | `#7A8C9A` |
| Metal oscuro | `#3A4854` |
| Panel solar | `#2A8AB8` |
| Cristal | `#3ED4E8` |
| Destello de cristal | `#B8F4FF` |

### Traje y bandera

El traje es un blanco crema, con un acento naranja en el pecho o el cinturón. El parche del Ecuador va en el hombro, en pocos píxeles, pero se tienen que distinguir el amarillo, el azul y el rojo. La luz de borde es un filo cálido, de uno o dos píxeles, en el lado contrario a la luz.

| Nombre | Hex |
|---|---|
| Traje claro | `#FFF8EC` |
| Traje sombra | `#B8B0A4` |
| Luz de borde | `#FFE8B0` |
| Naranja del traje | `#FF6A20` |
| Amarillo Ecuador | `#FFE000` |
| Azul Ecuador | `#1A4CDC` |
| Rojo Ecuador | `#E81030` |

### Vegetación, cielo y UI

| Nombre | Hex | Uso |
|---|---|---|
| Hoja clara | `#B4F86A` | Interior del invernadero, puntos de luz |
| Hoja | `#8CE846` | Plantas |
| Hoja oscura | `#2E8A28` | Comida en el HUD, y la sombra de las plantas |
| Cielo rosa | `#FFC0A8` | Cielo, cerca del horizonte |
| Cielo naranja | `#FF8A58` | Cielo, más arriba |
| Cristal | `#3ED4E8` | Oxígeno en el HUD (el mismo que el vidrio) |
| Amarillo Ecuador | `#FFE000` | Energía en el HUD |
| Visor | `#142030` | Visor del casco y fondo del HUD |
| Azul Ecuador | `#1A4CDC` | La Tierra en el cielo, un círculo simple |

## Luz, contorno y sombras

La luz viene siempre de arriba a la izquierda. Las caras de arriba y de la izquierda de cada objeto quedan más claras, hacia el amarillo cálido (Arena muy clara, Luz de borde o Destello). La derecha y abajo van a Sombra granate `#8A3058` o Sombra púrpura `#5A2468`, no al gris. No se cambia de lado de un sprite a otro.

En el filo contrario a la luz, un borde de uno o dos píxeles de Luz de borde o Destello alcanza para que el objeto se separe del suelo. En el metal y el vidrio, un solo píxel de Destello o Destello de cristal hace el brillo. No hace falta más.

Los contornos son gruesos, de un píxel o dos, del color Contorno. En un traje claro, un borde negro se come la silueta. El morado-marrón la separa del suelo sin aplastarla.

Debajo de cada cosa (personaje, roca, módulo, caja) va una sombra plana: un óvalo simple, un poco hacia abajo a la derecha, pintado con Sombra granate o Sombra púrpura. Sin esa mancha el sprite parece flotar.

El cielo es un tinte rosa-naranja, con Cielo rosa abajo y Cielo naranja arriba, también mezclado a dithering si hace falta. Un círculo pequeño de Azul Ecuador basta para la Tierra.

## Suelo

El suelo de Marte no es un naranja solo. Se arma con varios tonos de arena y ocre: zonas más claras, parches de Terracota o Parche, alguna Piedra o Roca suelta, y un dithering suave entre dos colores vecinos. Los puntos del dithering son grandes y escasos, al tamaño del píxel de arcade, no una textura de foto. Un tile de 16x16 puede tener el color base, dos o tres puntos de un tono vecino y, de vez en cuando, una piedrita.

## Formas

Formas simples, redondeadas y gordas. Esa regla no cambia con el color. Se evitan las grietas finas, el granito de la arena y los remaches sueltos. Si un módulo se entiende con un bloque, una puerta y un par de ventanas, está listo. El volumen viene de los 2 o 3 tonos, del viraje de la sombra y de un destello, no de más detalle.

## Personaje a 32x32

El astronauta es chibi: casco grande, cuerpo corto, piernas cortas, silueta clara a 32x32. El casco ocupa cerca de la mitad de la altura del frame. Una prueba útil: si se reduce a la mitad y todavía se distingue del fondo, va bien.

Hay dos versiones del mismo cuerpo, con casco y sin casco, en hojas distintas y con la misma cuadrícula. Por ejemplo `astronaut_helmet_walk.png` y `astronaut_nohelmet_walk.png`. Así Godot cambia de una a otra sin retocar las animaciones. El casco no se dibuja como un recorte suelto encima del cuerpo, porque se descuadra.

La hoja sigue la regla de siempre: las filas van hacia abajo, izquierda, derecha y arriba; las columnas son los frames de la animación. Los pies quedan en y=29..30 del frame, centrados en x=16.

### Tiempos de animación

- Caminar: 4 a 6 frames, a 8-10 cuadros por segundo. Con 4 frames a 8 fps alcanza, que es lo que ya espera `docs/sprint-specs.md`.
- Quieto: 2 a 4 frames, a 4 fps, con una respiración leve. El setup actual usa 2 frames a 3 fps. Si se sube a 4 fps, hay que cambiarlo también en el SpriteFrames.
- Los pasos suenan en los frames 1 y 3 del ciclo de caminar, que es cuando el pie toca el suelo. En una tira de 4 frames, son el primero y el tercero.

Si se agregan frames, actualice también el SpriteFrames.

## Tamaño de cada objeto, en tiles

El mundo se mide en tiles de 16. Los módulos ocupan múltiplos de 16. El origen va en la base del objeto (los pies, o el borde de abajo del edificio).

| Objeto | Píxeles | Tiles |
|---|---|---|
| Suelo (un tile) | 16x16 | 1x1 |
| Astronauta | 32x32 | 2 de alto |
| Roca o cráter mediano | 32x32 | 2x2 |
| Hábitat | 64x48 | 4x3 |
| Invernadero | 64x48 | 4x3 |
| Panel solar | 48x32 | 3x2 |
| Tanques de oxígeno | 32x32 | 2x2 |
| Antena | 32x48 | 2x3 |
| Rover | 48x32 | 3x2 |
| Lander | 64x64 | 4x4 |
| Bandera del Ecuador | 16x32 | 1x2 |
| Ícono del HUD | 16x16 | se muestra al doble |
| Avatar de INTI | 32x32 |  |

## En Aseprite o LibreSprite

1. Abra `assets/art/characters/astronaut_walk.png`, o la hoja que vaya a dibujar, y no cambie el tamaño del lienzo.
2. En Vista > Grilla, ponga 32x32 para el personaje y 16x16 para los tiles. El modo mosaico ayuda a ver cómo encaja el suelo.
3. Paleta > Importar, y elija `assets/art/palette/condor_rojo.gpl`. Fije esa paleta y pinte solo con esos 32 colores. Si entra un color de más, se nota al lado de otro sprite.
4. Para las dos versiones del traje, duplique la hoja con casco, borre el casco en la copia y dibuje la cabeza en el mismo sitio. Las manos, los pies y el acabado del cuerpo tienen que coincidir.
5. En la animación de caminar, marque en qué frames cae el pie (1 y 3) para enganchar después el sonido.
6. Exporte en PNG, en la misma carpeta y con el mismo nombre que el placeholder. Godot lo toma solo si la grilla no cambió.

## En PixelLab

PixelLab sirve para el primer borrador. El sprite final se limpia a mano.

Suba `assets/refs/generated/ref_arcade_v2_astronaut_turnaround.png` o su propio dibujo. Pida las 4 direcciones a 32x32, en vista 3/4 desde arriba, estilo arcade, chibi, casco grande. Para caminar, 4 frames por dirección. Para quieto, 2 si alcanza el tiempo.

Si la herramienta deja cargar una paleta, use `condor_rojo.gpl` o la tira de `condor_rojo_palette.png`. Si no, después de generar, en Aseprite restringa la paleta y remapee a los 32 colores.

En Aseprite o LibreSprite hay que repasar píxeles sueltos, dejar los pies a la misma altura en todos los frames, pintar el acento naranja y el parche de la bandera, pasar el contorno a `#3A1A28` y dejar un filo de Luz de borde. Luego se arma el sheet (filas down, left, right, up) y se guarda encima del placeholder.

La referencia de la base en Marte está en `assets/refs/generated/ref_arcade_v2_mars_base_camp.png`. Sirve para ambientar tiles y módulos. No se recorta para pegarla en el juego.
