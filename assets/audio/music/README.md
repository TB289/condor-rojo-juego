# Música y efectos

Copia los archivos con estos nombres. No hace falta cambiar código. Si un archivo no está, el juego sigue en silencio.

Formato esperado: **.ogg**. Si el mismo nombre existe en `.mp3` o `.wav`, también sirve.

En el import de Godot, activa **Loop** en las pistas que hacen loop (`AudioStreamOggVorbis.loop`, o Loop Mode en el .wav) y reimporta. El juego también pide loop al reproducirlas.

## Música (`assets/audio/music/`)

| Archivo | Loop | Cuándo |
|---|---|---|
| `menu.ogg` | sí | Menú principal |
| `intro.ogg` | no (una vez) | Debrief de llegada e intro. Si falta, sigue `menu.ogg` o silencio |
| `surface_day.ogg` | sí | Superficie de día |
| `surface_night.ogg` | sí | Superficie al anochecer. Si falta una de las dos, queda la otra |
| `interior.ogg` | sí | Dentro del hábitat o del invernadero. Al salir vuelve la de la superficie |
| `storm.ogg` | sí, más baja | Mientras hay tormenta de polvo. Si no está, no pasa nada |
| `event_sting.ogg` | no (una vez) | Solo si no hay `storm.ogg`, una vez por tormenta |

`intro.ogg` no se repite: si es más corta que la intro, termina y queda en silencio. El resto de las pistas en loop se quedan hasta el cambio de contexto.

## Efectos (`assets/audio/sfx/`)

Opcionales. Si faltan, no hay error.

| Archivo | Cuándo |
|---|---|
| `footstep.ogg` | Paso al caminar afuera |
| `jump.ogg` | Salto |
| `land.ogg` | Aterrizaje (junto al polvo) |
| `ui_click.ogg` | Clic en un botón de menú |
| `door.ogg` | Entrar o salir de un interior |

Van por el bus SFX. La música va por el bus Music. El volumen y el mute a 0 salen de Opciones.
