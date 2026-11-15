extends Node
## Volume and language. Saved in user://settings.cfg. The game reads lang from here.
## GameState.language stays in step so a new run does not forget the choice.
## Touch-layout save/load.

signal language_changed(lang: String)
signal touch_changed
signal touch_layout_changed
signal tutorial_replay
signal keybinds_changed
signal accessibility_changed

const PATH := "user://settings.cfg"

## Visible UI copy. Dialogue and missions stay in their data files.
const UI := {
	"menu.subtitle": {
		"es": "El primer astronauta ecuatoriano",
		"en": "The first Ecuadorian astronaut",
	},
	"menu.play": {"es": "Nueva partida", "en": "New game"},
	"menu.continue": {"es": "Continuar", "en": "Continue"},
	"menu.continue_hint": {"es": "Reanudar la partida de esta sesión (hasta cerrar el juego).", "en": "Resume this session's game (until the app closes)."},
	"menu.how": {"es": "Cómo jugar", "en": "How to play"},
	"menu.options": {"es": "Opciones", "en": "Options"},
	"menu.credits": {"es": "Créditos", "en": "Credits"},
	"menu.nasa": {"es": "Datos de la NASA", "en": "NASA data"},
	"nasa.title": {"es": "Datos de la NASA", "en": "NASA data"},
	"nasa.mission": {"es": "Tu misión", "en": "Your mission"},
	"nasa.example": {"es": "Ejemplo: todavía no hay una partida.", "en": "Example: there is no mission yet."},
	"nasa.hazards": {"es": "Los 5 peligros", "en": "The 5 hazards"},
	"nasa.sources": {"es": "Fuentes", "en": "Sources"},
	"nasa.glossary": {"es": "Glosario", "en": "Glossary"},
	"nasa.photos": {"es": "Fotos", "en": "Photos"},
	"nasa.open": {"es": "Abrir la página", "en": "Open the page"},
	"debrief.nasa": {"es": "Datos de la NASA", "en": "NASA data"},
	"debrief.real": {"es": "Tu misión con datos reales", "en": "Your mission with real data"},
	"hud.dose": {"es": "Dosis hoy %s mSv", "en": "Today %s mSv"},
	"nasa.exercise": {"es": "E: Hacer ejercicio", "en": "E: Exercise"},
	"nasa.exercise_done": {"es": "Ya hiciste ejercicio hoy", "en": "You already exercised today"},
	"nasa.countdown": {"es": "Partículas: %d s", "en": "Particles: %d s"},
	"options.reduce": {"es": "Reducir efectos", "en": "Reduce effects"},
	"options.accessibility": {"es": "Accesibilidad visual", "en": "Visual accessibility"},
	"options.access_off": {"es": "Sin filtro", "en": "No filter"},
	"options.access_contrast": {"es": "Alto contraste", "en": "High contrast"},
	"options.access_blue": {"es": "Azul / amarillo", "en": "Blue / yellow"},
	"options.access_gray": {"es": "Escala de grises", "en": "Grayscale"},
	"menu.quit": {"es": "Salir", "en": "Quit"},
	"how.title": {"es": "Cómo jugar", "en": "How to play"},
	"how.body": {
		"es": "Camina con W A S D o las flechas.\nEspacio o X salta. Shift o el gatillo izquierdo corre afuera.\nE usa lo que tienes cerca.\nEn la puerta del hábitat, del invernadero o de la cueva, E entra. Adentro, E sale.\nAcércate al tanque de oxígeno dentro del hábitat y pulsa E para recargar el traje en 2 segundos.\nEn la cama, E duerme y termina el Día; el diario se abre al dormir.\nDe noche, afuera, F o R1 enciende la lámpara del casco. Gasta energía.\nQ o L1 cambia la misión que sigues.\nTab abre a INTI cuando quieras una pista.\nT alterna el reloj entre x1 y x4.\nEsc pausa la partida.\n\nINTI avisa si hay un peligro. Tú decides.\nEn el invernadero, pulsa E junto al cultivo para sembrar, regar o cosechar según lo que necesite. Si no hay una misión en la cama de cultivo, puedes repetir el ciclo. El tanque azul recarga el agua.\nEn los archivos de los rovers, copia los datos, lee la ficha y responde la pregunta. No hay que llevarse los vehículos.\nEl rover Cóndor es distinto: repáralo manteniendo E en el Sol 1. Desde el Sol 2, E permite subir o bajar; WASD o la palanca táctil sirven para conducir. Mantén Correr y pulsa Interactuar para leer su ficha.\nEn el celular, en horizontal, la palanca mueve y los botones de la derecha actúan.",
		"en": "Walk with W A S D or the arrow keys.\nSpace or X jumps. Shift or the left trigger runs outside.\nE uses what is near you.\nAt the ship airlock, E enters. Walk onto the cave mouth to enter; the cave exit teleports you back outside. Inside the ship, E uses internal passages to reach the laboratory or greenhouse. The living deck has the exterior exit.\nApproach the oxygen station inside the habitat and press E to refill your suit in 2 seconds.\nAt the bed, E sleeps and opens the night journal.\nAt night, outside, F or R1 turns on the helmet lamp. It uses energy.\nQ or L1 switches the mission you are following.\nTab opens INTI when you want a hint.\nT toggles the clock between x1 and x4.\nEsc pauses the game.\n\nINTI warns you if there is danger. You decide.\nIn the greenhouse, press E beside the garden bed to plant, water or harvest depending on what it needs. You can repeat the cycle when no mission is using the planter. The blue tank refills the water.\nAt the rover archives, copy the data, read the card, and answer the question. You do not have to take the vehicles.\nThe Cóndor support rover is different: hold E to repair it on Sol 1. From Sol 2, use E to board or exit, and WASD or the touch joystick to drive. Hold Sprint and press Interact to inspect its information card.\nOn a phone, hold it sideways: the stick moves you and the buttons on the right act.",
	},
	"credits.title": {"es": "Créditos", "en": "Credits"},
	"credits.body": {
		"es": "Hecho por AstroSharks GYE\n\nJose Pacheco\nSebastian Silvestre\nManuel Fernandez\nDaniel Yan\nNoelia Yan\nAmelia Illescas\n\n──────\n\nCóndor Rojo\nEl primer astronauta ecuatoriano en Marte.\n\nHecho para NASA Space Apps 2026, challenge Junior Astronaut Mission Trainer.\n\nDatos reales de la NASA y de la Agencia Espacial Canadiense, guardados el 13 de noviembre de 2026: clima espacial (DONKI), distancia de la luz (JPL Horizons), dosis (Curiosity RAD), salud y plantas (OSDR), lugares (Mars Trek) y fotos de los rovers. No son datos en vivo. Míralos en Datos de la NASA.\n\nArte del equipo.\nRocas, hielo, rover viejo y sonda de los sitios: arte ya del proyecto, reutilizado.\nFotos: NASA/JPL-Caltech.\nFuente: m5x7, Daniel Linssen (CC0).\nMotor: Godot 4.7.",
		"en": "Made by AstroSharks GYE\n\nJose Pacheco\nSebastian Silvestre\nManuel Fernandez\nDaniel Yan\nNoelia Yan\nAmelia Illescas\n\n──────\n\nCóndor Rojo\nThe first Ecuadorian astronaut on Mars.\n\nMade for NASA Space Apps 2026, challenge Junior Astronaut Mission Trainer.\n\nReal data from NASA and the Canadian Space Agency, saved on November 13, 2026: space weather (DONKI), light-time (JPL Horizons), dose (Curiosity RAD), health and plants (OSDR), places (Mars Trek) and rover photos. This is not live data. See them in NASA data.\n\nArt by the team.\nRocks, ice, the old rover and the probe at the sites: art already in the project, reused.\nPhotos: NASA/JPL-Caltech.\nFont: m5x7, Daniel Linssen (CC0).\nEngine: Godot 4.7.",
	},
	"options.title": {"es": "Opciones", "en": "Options"},
	"options.master": {"es": "Volumen", "en": "Volume"},
	"options.music": {"es": "Música", "en": "Music"},
	"options.sfx": {"es": "Efectos", "en": "Effects"},
	"options.language": {"es": "Idioma", "en": "Language"},
	"options.es": {"es": "Español", "en": "Español"},
	"options.en": {"es": "English", "en": "English"},
	"options.screen": {"es": "Pantalla", "en": "Screen"},
	"options.windowed": {"es": "Ventana", "en": "Window"},
	"options.fullscreen": {"es": "Completa", "en": "Full"},
	"options.scale": {"es": "Escala", "en": "Scale"},
	"options.fit": {"es": "Ajustar", "en": "Fit"},
	"options.vsync": {"es": "Vsync", "en": "Vsync"},
	"options.vsync_applied": {"es": "VSync: modo aplicado por Godot.", "en": "VSync: Godot reports the selected mode."},
	"options.vsync_fallback": {"es": "VSync: tu sistema usa otro modo (limitación del renderizador).", "en": "VSync: system reports a different mode (renderer limit)."},
	"options.on": {"es": "Sí", "en": "On"},
	"options.off": {"es": "No", "en": "Off"},
	"intro.brief.mars_title": {"es": "Marte", "en": "Mars"},
	"intro.brief.goals_title": {"es": "Tu misión", "en": "Your mission"},
	"intro.brief.next": {"es": "Continuar", "en": "Continue"},
	"intro.brief.skip": {
		"es": "Esc, Start o clic para saltar",
		"en": "Esc, Start, or click to skip",
	},
	"intro.brief.mars": {
		"es": "La gravedad es 0,38 g, cerca de un tercio de la de la Tierra, y un sol dura 24 horas y 39 minutos. El aire es casi todo dióxido de carbono y muy delgado, y un mensaje a la Tierra tarda entre 3 y 22 minutos.",
		"en": "Gravity is 0.38 g, about a third of Earth's, and a sol lasts 24 hours and 39 minutes. The air is almost all carbon dioxide and very thin, and a message to Earth takes 3 to 22 minutes.",
	},
	"intro.brief.goals": {
		"es": "Sobrevive y arma la base con oxígeno, energía y comida, y recoge datos de rovers que ya no operan. Estudia los minerales, las cuevas y los glaciares de hielo de Marte, y decide tú el resto de cada día.",
		"en": "Survive and set up the base with oxygen, energy, and food, and collect data from rovers that no longer run. Study the minerals, caves, and water-ice glaciers of Mars, and decide the rest of each day yourself.",
	},
	"intro.quito": {"es": "Quito, Ecuador. Año 2040.", "en": "Quito, Ecuador. Year 2040."},
	"intro.travel": {
		"es": "7 meses de viaje\nUnos 6 a 9 meses, según la ventana. Distancia media: 225 millones de km. Una ventana cada 26 meses.",
		"en": "7 months of travel\nAbout 6 to 9 months, depending on the window. Average distance: 225 million km. A window about every 26 months.",
	},
	"intro.day": {"es": "Día 1", "en": "Day 1"},
	"intro.inti": {
		"es": "Hola, soy INTI. Te ayudo, pero las decisiones son tuyas.",
		"en": "Hi, I'm INTI. I help, but the decisions are yours.",
	},
	"pause.title": {"es": "Pausa", "en": "Paused"},
	"pause.resume": {"es": "Continuar", "en": "Continue"},
	"pause.menu": {"es": "Volver al menú principal", "en": "Back to main menu"},
	"pause.sure": {"es": "¿Seguro?", "en": "Are you sure?"},
	"pause.yes": {"es": "Sí", "en": "Yes"},
	"pause.no": {"es": "No", "en": "No"},
	"common.back": {"es": "Volver", "en": "Back"},
	"hud.day": {"es": "Día %d", "en": "Day %d"},
	"hud.to_bed": {
		"es": "Ve a dormir",
		"en": "Go to sleep",
	},
	"bed.sleep": {"es": "E: dormir", "en": "E: sleep"},
	"bed.busy": {
		"es": "E: faltan tareas",
		"en": "E: tasks left",
	},
	"hud.also": {"es": "También: %s", "en": "Also: %s"},
	"hud.sides": {"es": "Secundarias: %s", "en": "Secondary: %s"},
	"module.repair": {"es": "E: reparar", "en": "E: repair"},
	"module.shake": {"es": "E: sacudir", "en": "E: shake"},
	"res.oxygen": {"es": "Oxígeno", "en": "Oxygen"},
	"res.energy": {"es": "Energía", "en": "Energy"},
	"res.food": {"es": "Comida", "en": "Food"},
	"res.shielding": {"es": "Blindaje radiológico", "en": "Radiation shielding"},
	"res.water": {"es": "Agua", "en": "Water"},
	"debrief.menu": {"es": "Volver al menú", "en": "Back to menu"},
	"debrief.again": {"es": "Jugar otra vez", "en": "Play again"},
	"debrief.hint": {"es": "Enter o un toque continúa", "en": "Enter or a tap continues"},
	"inti.tab": {"es": "Tab: INTI", "en": "Tab: INTI"},
	"inti.tab_touch": {"es": "INTI está en +", "en": "INTI is on +"},
	"inti.complete": {"es": "E completa", "en": "E finishes"},
	"inti.close": {"es": "Cerrar", "en": "Close"},
	"ice.pick": {"es": "E: recoger", "en": "E: pick up"},
	"door.enter": {"es": "E: entrar", "en": "E: enter"},
	"door.exit": {"es": "E: salir", "en": "E: exit"},
	"module.daily": {"es": "Cada día: %s", "en": "Each day: %s"},
	"module.status": {"es": "Estado: %s", "en": "Status: %s"},
	"place.hint": {
		"es": "Coloca: %s (%d de %d)\nClick o E para confirmar",
		"en": "Place: %s (%d of %d)\nClick or E to confirm",
	},
	"place.blocked": {
		"es": "Ahí no cabe: busca un lugar libre cerca del lander.",
		"en": "It does not fit there: find a free spot near the lander.",
	},
	"intro.skip": {
		"es": "Esc, Start o clic para saltar",
		"en": "Esc, Start, or click to skip",
	},
	"cut.skip": {"es": "Saltar (Esc)", "en": "Skip (Esc)"},
	"cut.next": {"es": "E o clic: seguir", "en": "E or click: next"},
	"prompt.hand": {"es": "Mano", "en": "Hand"},
	"prompt.south": {"es": "Sur", "en": "South"},
	"prompt.scan": {"es": "Escanear", "en": "Scan"},
	"prompt.sample": {"es": "Muestra", "en": "Sample"},
	"prompt.recover": {"es": "Copiar", "en": "Copy"},
	"prompt.repairing": {"es": "Reparando", "en": "Repairing"},
	"prompt.shaking": {"es": "Sacudiendo", "en": "Shaking"},
	"prompt.need_seed": {"es": "3: semilla", "en": "3: seed"},
	"prompt.need_water": {"es": "2: regadera", "en": "2: can"},
	"module.damaged": {
		"es": "Dañado: hay que repararlo para que vuelva a funcionar",
		"en": "Damaged: repair it so it works again",
	},
	"module.on": {"es": "Funcionando", "en": "Running"},
	"module.off": {
		"es": "Sin energía: no produjo nada este día",
		"en": "No power: it made nothing today",
	},
	"module.shelter": {"es": "Refugio en tormentas", "en": "Shelter in storms"},
	"module.comms": {"es": "Mensajes con la Tierra", "en": "Messages with Earth"},
	"hud.survive": {"es": "Sobrevive hasta el Día 10", "en": "Survive until Day 10"},
	"hud.days_left": {"es": "Faltan %d días.", "en": "%d days left."},
	"hud.day_left": {"es": "Falta 1 día.", "en": "1 day left."},
	"hud.last_night": {"es": "Esta noche cierras el diario.", "en": "Close the journal tonight."},
	"journal.title": {"es": "Diario", "en": "Journal"},
	"journal.mission": {"es": "Misión: %s", "en": "Mission: %s"},
	"journal.dinner": {"es": "Cena", "en": "Dinner"},
	"journal.power": {"es": "Energía", "en": "Power"},
	"journal.event": {"es": "Evento", "en": "Event"},
	"journal.sleep": {"es": "Dormir", "en": "Sleep"},
	"journal.power_use": {
		"es": "Usas %d de %d y el resto carga la batería.",
		"en": "You use %d of %d and the rest charges the battery.",
	},
	"journal.power_all": {
		"es": "Hay %d. Alcanza para todos.",
		"en": "You have %d. Enough for all.",
	},
	"journal.power_none": {
		"es": "Hay %d. No alcanza para un módulo.",
		"en": "You have %d. Not enough for a module.",
	},
	"journal.power_choose": {
		"es": "Hay %d y piden %d. Elige cuáles.",
		"en": "You have %d and they need %d. Choose.",
	},
	"journal.spend": {"es": "Gasta %d de energía.", "en": "Uses %d energy."},
	"journal.summary": {"es": "Así pasó el día %d.", "en": "This is how day %d went."},
	"journal.walked": {
		"es": "Caminaste lejos y el traje usó más oxígeno.",
		"en": "You walked far and the suit used more oxygen.",
	},
	"journal.dust": {
		"es": "Sigue el polvo. Los paneles dieron %d.",
		"en": "Dust remains. The panels made %d.",
	},
	"journal.weak": {
		"es": "Un panel sigue flojo y dio %d.",
		"en": "A panel is still weak and made %d.",
	},
	"journal.panels": {"es": "Los paneles dieron %d de energía.", "en": "The panels made %d energy."},
	"journal.food_low": {"es": "Queda poca comida.", "en": "Food is running low."},
	"journal.o2_low": {"es": "El oxígeno está bajo.", "en": "Oxygen is low."},
	"journal.battery": {
		"es": "Energía baja. Duerme en la cama para subirla.",
		"en": "Energy is low. Sleep in the bed to raise it.",
	},
	"energy.sleep": {
		"es": "Energía baja. Duerme en la cama de la nave, o gana un premio.",
		"en": "Energy is low. Sleep in the ship bed, or earn a reward.",
	},
	"journal.broken": {"es": "Dañado: %s.", "en": "Damaged: %s."},
	"journal.last": {
		"es": "Último día: al dormir, la misión termina.",
		"en": "Last day: the mission ends when you sleep.",
	},
	"journal.note_done": {"es": "Misión cumplida: %s.", "en": "Mission complete: %s."},
	"journal.repaired": {"es": "%s volvió a funcionar.", "en": "%s is working again."},
	"journal.shook": {
		"es": "Sacudiste el panel. Ya está más limpio.",
		"en": "You shook the panel. It is cleaner now.",
	},
	"journal.damaged": {
		"es": "%s quedó dañado. Repáralo al lado.",
		"en": "%s was damaged. Repair it up close.",
	},
	"journal.dinner_log": {"es": "Cena: %s.", "en": "Dinner: %s."},
	"journal.power_log": {
		"es": "Energía de los paneles para: %s.",
		"en": "Panel power goes to: %s.",
	},
	"journal.power_nobody": {
		"es": "Los paneles no alcanzaron.",
		"en": "The panels were not enough.",
	},
	"journal.nobody": {
		"es": "nadie; el resto carga la batería",
		"en": "no one; the rest charges the battery",
	},
	"day.dust": {
		"es": "Todavía hay polvo. Puedes sacudir los paneles.",
		"en": "Dust is still here. You can shake the panels.",
	},
	"day.weak": {
		"es": "Un panel sigue flojo. Si lo sacudes, mañana da mejor.",
		"en": "A panel is still weak. Shake it and tomorrow it works better.",
	},
	"day.fixed": {
		"es": "El panel que arreglaste ya da energía normal.",
		"en": "The panel you fixed is making normal power again.",
	},
	"kit.title": {"es": "Elige el equipo de tu base", "en": "Choose your base kit"},
	"kit.subtitle": {
		"es": "Cada kit trae 3 módulos. Antes de aterrizar puedes hacer 1 cambio.",
		"en": "Each kit brings 3 modules. Before landing you can make 1 change.",
	},
	"kit.remove": {"es": "Cambio: quitar...", "en": "Change: remove..."},
	"kit.add": {"es": "...y poner (o sumar)", "en": "...and add (or include)"},
	"kit.start": {"es": "¡A Marte!", "en": "To Mars!"},
	"kit.yours": {"es": "Tu base: %s", "en": "Your base: %s"},
	"kit.daily": {"es": "Cada día, contigo adentro: %s", "en": "Each day, with you inside: %s"},
	"kit.pick": {
		"es": "Elige qué módulo poner en su lugar.",
		"en": "Choose which module to put in its place.",
	},
	"debrief.learned": {"es": "Lo que aprendiste", "en": "What you learned"},
	"debrief.decisions": {"es": "Tus decisiones", "en": "Your decisions"},
	"debrief.mains": {"es": "Misiones principales", "en": "Main missions"},
	"debrief.sides": {"es": "Misiones secundarias", "en": "Secondary missions"},
	"debrief.day": {"es": "Día %d de %d", "en": "Day %d of %d"},
	"debrief.pending": {"es": "pendiente", "en": "still open"},
	"debrief.none_yet": {
		"es": "Todavía no había decisiones anotadas.",
		"en": "No decisions were written down yet.",
	},
	"debrief.more": {
		"es": "Anotaste %d decisiones. Estas son las últimas:",
		"en": "You wrote down %d decisions. These are the latest:",
	},
	"debrief.logged": {"es": "Día %s · %s", "en": "Day %s · %s"},
	"debrief.preview_title": {"es": "Diario", "en": "Journal"},
	"debrief.preview_body": {
		"es": "Aquí se cierra la misión cuando termina la partida.",
		"en": "The mission closes here when the run ends.",
	},
	"options.touch": {"es": "Controles táctiles", "en": "Touch controls"},
	"options.keybinds": {"es": "Cambiar teclas", "en": "Change key bindings"},
	"options.keybind_jump": {"es": "CONFIGURAR TECLAS ↓", "en": "CONFIGURE KEYBINDS ↓"},
	"controls.choose": {"es": "ELIGE TUS CONTROLES", "en": "CHOOSE YOUR CONTROLS"},
	"controls.later": {"es": "Puedes cambiar entre teclado y pantalla táctil después en Opciones.", "en": "You can switch between keyboard and touchscreen later in Options."},
	"controls.overwrite": {"es": "Atención: una nueva partida sustituirá tu sesión actual. Puedes volver para Continuar.", "en": "Warning: New Game will replace your current session. Go back to Continue instead."},
	"controls.keyboard": {"es": "TECLADO + RATÓN", "en": "KEYBOARD + MOUSE"},
	"controls.touchscreen": {"es": "PANTALLA TÁCTIL", "en": "TOUCHSCREEN"},
	"options.keybind_hint": {"es": "Pulsa una tecla (Esc cancela)", "en": "Press a key (Esc cancels)"},
	"options.keybind_conflict": {"es": "Esa tecla ya está en uso", "en": "That key is already in use"},
	"options.reset_keys": {"es": "Restablecer teclas", "en": "Reset keys"},
	"options.clock": {"es": "Reloj", "en": "Clock"},
	"clock.locked": {"es": "Disponible después de colocar la base", "en": "Available after placing the base"},
	"actions.move_left": {"es": "Izquierda", "en": "Move left"},
	"actions.move_right": {"es": "Derecha", "en": "Move right"},
	"actions.move_up": {"es": "Arriba", "en": "Move up"},
	"actions.move_down": {"es": "Abajo", "en": "Move down"},
	"actions.interact": {"es": "Interactuar", "en": "Interact"},
	"actions.jump": {"es": "Saltar", "en": "Jump"},
	"actions.sprint": {"es": "Correr", "en": "Sprint"},
	"actions.flashlight": {"es": "Linterna", "en": "Flashlight"},
	"actions.minimap": {"es": "Mapa", "en": "Map"},
	"actions.inti": {"es": "INTI", "en": "INTI"},
	"actions.pause": {"es": "Pausa", "en": "Pause"},
	"actions.cycle_mission": {"es": "Cambiar misión", "en": "Cycle mission"},
	"options.touch_auto": {"es": "Auto", "en": "Auto"},
	"options.touch_yes": {"es": "Sí", "en": "Yes"},
	"options.touch_no": {"es": "No", "en": "No"},
	"options.tutorial": {"es": "Tutorial", "en": "Tutorial"},
	"options.tutorial_again": {"es": "Repetir tutorial", "en": "Replay tutorial"},
	"touch.rotate": {"es": "Gira el teléfono", "en": "Rotate your phone"},
	"touch.edit": {"es": "EDITAR", "en": "EDIT"},
	"touch.save": {"es": "GUARDAR", "en": "SAVE"},
	"touch.reset": {"es": "RESTAURAR", "en": "RESET"},
	"touch.edit_hint": {
		"es": "Toca un control, cambia su tamaño con -/+ o arrástralo. Pulsa GUARDAR.",
		"en": "Tap a control, resize with -/+ or drag it. Press SAVE.",
	},
	"touch.tour_close": {"es": "Cerrar tutorial", "en": "Close tutorial"},
	"touch.tour_tap": {"es": "Toca aquí", "en": "Tap here"},
	"touch.tour_stick": {"es": "Desliza para caminar.", "en": "Drag to walk."},
	"touch.tour_interact": {"es": "La mano usa lo de cerca.", "en": "The hand uses what's near."},
	"touch.tour_sprint": {"es": "Correr o saltar.", "en": "Run or jump."},
	"touch.tour_pause": {"es": "Abre el menú.", "en": "Opens the menu."},
	"touch.tour_more": {"es": "Abre INTI, el mapa y las misiones.", "en": "Opens INTI, the map and missions."},
	"touch.arrange": {"es": "Acomodar botones", "en": "Arrange buttons"},
	"tutorial.skip": {"es": "Saltar", "en": "Skip"},
	"tutorial.next": {"es": "Siguiente", "en": "Next"},
	"tutorial.replay_hint": {"es": "Pulsa E o Siguiente para continuar.", "en": "Press E or Next to continue."},
	"farm.refill": {"es": "E: agua (%d/4)", "en": "E: water (%d/4)"},
	"farm.plant": {"es": "E: sembrar (%d)", "en": "E: plant (%d)"},
	"farm.harvest": {"es": "E: cosechar", "en": "E: harvest"},
	"farm.water": {"es": "E: regar", "en": "E: water"},
	"farm.growing": {"es": "Vuelve mañana", "en": "Come back tomorrow"},
	"farm.need_seed": {"es": "Elige la semilla (3).", "en": "Pick the seed (3)."},
	"farm.no_seed": {"es": "No quedan semillas.", "en": "No seeds left."},
	"farm.planted": {"es": "Sembrado. Pulsa E para regar.", "en": "Planted. Press E to water."},
	"farm.need_hand": {"es": "Elige la mano (1).", "en": "Pick the hand (1)."},
	"farm.harvested": {"es": "Cosecha: +12 comida y +1 semilla.", "en": "Harvest: +12 food and +1 seed."},
	"farm.need_water": {"es": "Usa la regadera (2).", "en": "Use the can (2)."},
	"farm.no_water": {"es": "Sin agua. Recarga el tanque azul.", "en": "No water. Refill the blue tank."},
	"farm.watered": {"es": "Regado. Vuelve mañana.", "en": "Watered. Come back tomorrow."},
	"archive.question": {"es": "Pregunta", "en": "Question"},
	"archive.check": {"es": "Comprobar", "en": "Check"},
	"archive.correct": {"es": "Correcto.", "en": "Correct."},
	"archive.retry": {"es": "No es esa. Inténtalo de nuevo.", "en": "Not that one. Try again."},
	"archive.missing": {"es": "No se encontró este archivo.", "en": "This archive could not be found."},
	"journal.cancel": {"es": "Cancelar y volver", "en": "Cancel and return"},
	"tutorial.bars.oxygen": {"es": "AZUL = OXÍGENO. Se gasta afuera y en las cuevas. Dentro de la nave se conserva.", "en": "CYAN = OXYGEN. It drains outside and in caves. The sealed ship preserves it."},
	"tutorial.bars.energy": {"es": "AMARILLO = ENERGÍA. Baja incluso dentro de la nave. Duerme para recuperarla.", "en": "YELLOW = ENERGY. It drains even inside the ship. Sleep to recover it."},
	"tutorial.bars.shielding": {"es": "VERDE = BLINDAJE. Disminuye si te expones a una tormenta solar y se recupera en refugio o después de la tormenta.", "en": "GREEN = RADIATION SHIELDING. It drops during solar-storm exposure and recovers in shelter or after the storm."},
	"tutorial.move.key": {"es": "Muévete con W A S D.", "en": "Move with W A S D."},
	"tutorial.move.pad": {"es": "Muévete con la palanca izquierda.", "en": "Move with the left stick."},
	"tutorial.move.touch": {"es": "Muévete con la palanca de la izquierda.", "en": "Move with the stick on the left."},
	"tutorial.mark.key": {"es": "Sigue la flecha y el mapa (M) hasta la marca.", "en": "Follow the arrow and the map (M) to the mark."},
	"tutorial.mark.pad": {"es": "Sigue la flecha hasta la marca de la misión.", "en": "Follow the arrow to the mission mark."},
	"tutorial.mark.touch": {"es": "Sigue la flecha hasta la marca. El mapa está en el +.", "en": "Follow the arrow to the mark. The map is on the + button."},
	"tutorial.mark_main.key": {"es": "Sigue la flecha y el mapa (M) hasta la misión principal.", "en": "Follow the arrow and the map (M) to the main mission."},
	"tutorial.mark_main.pad": {"es": "Sigue la flecha hasta la misión principal.", "en": "Follow the arrow to the main mission."},
	"tutorial.mark_main.touch": {"es": "Sigue la flecha hasta la marca de la misión principal.", "en": "Follow the arrow to the main mission mark."},
	"tutorial.act.key": {"es": "Pulsa E junto a la marca.", "en": "Press E next to the mark."},
	"tutorial.act.pad": {"es": "Pulsa el botón sur junto a la marca.", "en": "Press the south button next to the mark."},
	"tutorial.act.touch": {"es": "Pulsa el botón de la mano, a la derecha.", "en": "Press the hand button on the right."},
	"tutorial.look.key": {"es": "Abajo a la derecha, junto al mapa: toca el oxígeno.", "en": "Bottom right, by the map: tap the oxygen."},
	"tutorial.look.pad": {"es": "Abajo a la derecha, junto al mapa: oxígeno y energía.", "en": "Bottom right, by the map: oxygen and energy."},
	"tutorial.look.touch": {"es": "Toca el oxígeno, junto al mapa.", "en": "Tap the oxygen, by the map."},
	"tutorial.lamp.key": {"es": "Está oscuro. Pulsa F para la lámpara.", "en": "It is dark. Press F for the lamp."},
	"tutorial.lamp.pad": {"es": "Está oscuro. Pulsa R1 para la lámpara.", "en": "It is dark. Press R1 for the lamp."},
	"tutorial.lamp.touch": {"es": "Está oscuro. Pulsa la lámpara, a la derecha.", "en": "It is dark. Press the lamp on the right."},
}

## The editable primary keyboard key for each action. Arrow-key alternatives and
## controller mappings stay unchanged when one of these keys is rebound.
const DEFAULT_KEYS := {
	"move_left": KEY_A, "move_right": KEY_D, "move_up": KEY_W, "move_down": KEY_S,
	"interact": KEY_E, "jump": KEY_SPACE, "sprint": KEY_SHIFT,
	"flashlight": KEY_F, "minimap": KEY_M, "inti": KEY_TAB,
	"pause": KEY_ESCAPE, "cycle_mission": KEY_Q,
}
const EDITABLE_ACTIONS := ["move_left", "move_right", "move_up", "move_down", "interact", "jump", "sprint", "flashlight", "minimap", "inti", "pause", "cycle_mission"]

const VIEW_W := 640
const VIEW_H := 360

## Linear 0..1. 0 mutes the bus.
var lang: String = "en"
var master: float = 1.0
var music: float = 1.0
var sfx: float = 1.0
## Windowed by default. 0 = largest multiple that fits. 2, 3, or 4 = that multiple of 640x360
## as the starting size. The player can drag the edge afterwards; the stretch follows.
var fullscreen: bool = false
var window_scale: int = 0
var vsync_on: bool = true
## auto shows the pads on a touch screen. yes forces them. no hides them.
var touch_mode: String = "auto"
## Saved on-screen pad positions, as ratios of the 640x360 view (center of each control).
## Empty means "use the automatic layout that avoids the HUD".
var touch_layout: Dictionary = {}
const TOUCH_LAYOUT_VERSION := 2
## Each touch control has its own size; 1.0 is the original size.
var touch_scales: Dictionary = {}
var touch_tutorial_done: bool = false
## Action -> physical keycode overrides, saved to user://settings.cfg.
var keybinds: Dictionary = {}
## The day-1 guide. Stays on after it finishes or the player skips it.
var tutorial_done: bool = false
## Tracks the newly added cyan/yellow/green resource explanation separately,
## so existing players receive it once without repeating the old controls tour.
var resource_intro_done: bool = false
## Id of the space-weather scenario used last run. Not a mid-game save.
var last_scenario: String = ""
## Hides the faint particle specks during a solar storm.
var reduce_effects: bool = false
## 0 standard, 1 high contrast, 2 blue/yellow separation, 3 grayscale.
var accessibility_mode: int = 0

var _has_display_save := false
var _checking_window := false
var _pending_scale := 2


func _ready() -> void:
	_ensure_buses()
	var save_after := _load()
	_apply_keybinds()
	_apply_audio()
	if DisplayServer.get_name() != "headless":
		get_tree().root.size_changed.connect(_on_root_resized)
	call_deferred("_boot_display", save_after)


func text(key: String) -> String:
	var row: Variant = UI.get(key, {})
	if not row is Dictionary:
		return key
	return String(row.get(lang, row.get("es", key)))


## English field beside the Spanish one: title / title_en. Empty English falls back.
func pick(data: Dictionary, key: String) -> String:
	if lang == "en":
		var english := String(data.get("%s_en" % key, ""))
		if not english.strip_edges().is_empty():
			return english
	return String(data.get(key, ""))


## A string list and its _en twin. Used by the debrief lesson points.
func pick_list(data: Dictionary, key: String) -> Array:
	if lang == "en":
		var english: Variant = data.get("%s_en" % key, [])
		if english is Array and not (english as Array).is_empty():
			return english
	var value: Variant = data.get(key, [])
	return value if value is Array else []


## Both languages in one string, so a line can switch without being rebuilt.
func pack(spanish: String, english: String) -> String:
	return spanish + "\u001f" + english


func visible_text(stored: String) -> String:
	var cut := stored.find("\u001f")
	if cut < 0:
		return stored
	if lang == "en":
		return stored.substr(cut + 1)
	return stored.substr(0, cut)


## "E: recoger" becomes "Mano: recoger" or "Sur: recoger" for the device in use.
func with_interact(line: String) -> String:
	if line.is_empty():
		return ""
	var body := line
	if body.begins_with("E: "):
		body = body.substr(3)
	elif body.begins_with("E:"):
		body = body.substr(2).strip_edges()
	else:
		return line
	return "%s: %s" % [interact_name(), body]


func interact_name() -> String:
	var device := "key"
	if TouchControls != null and TouchControls.has_method(&"prompt_device"):
		device = String(TouchControls.call(&"prompt_device"))
	if device == "touch":
		return text("prompt.hand")
	if device == "pad":
		return text("prompt.south")
	return OS.get_keycode_string(primary_key("interact"))


## Formats a UI key in both languages. en_args defaults to es_args when the numbers match.
func format_both(key: String, es_args: Array = [], en_args: Array = []) -> String:
	var row: Dictionary = UI.get(key, {})
	var spanish := String(row.get("es", key))
	var english := String(row.get("en", key))
	var english_args := en_args if not en_args.is_empty() else es_args
	if not es_args.is_empty():
		spanish = spanish % es_args
	if not english_args.is_empty():
		english = english % english_args
	return pack(spanish, english)


func set_last_scenario(id: String) -> void:
	if id == last_scenario:
		return
	last_scenario = id
	_save()


func set_reduce_effects(on: bool) -> void:
	reduce_effects = on
	_save()


func set_lang(value: String) -> void:
	var next := "en" if value == "en" else "es"
	if next == lang:
		return
	lang = next
	GameState.language = lang
	_save()
	language_changed.emit(lang)


func set_master(value: float) -> void:
	master = clampf(value, 0.0, 1.0)
	_apply_bus("Master", master)
	_save()


func set_music(value: float) -> void:
	music = clampf(value, 0.0, 1.0)
	_apply_bus("Music", music)
	_save()


func set_sfx(value: float) -> void:
	sfx = clampf(value, 0.0, 1.0)
	_apply_bus("SFX", sfx)
	_save()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply_display()
	_save()


## 0 fits the monitor. 2, 3, and 4 ask for that multiple when it fits.
func set_window_scale(scale: int) -> void:
	window_scale = scale if scale == 2 or scale == 3 or scale == 4 else 0
	apply_display()
	_save()


func set_vsync_on(on: bool) -> void:
	vsync_on = on
	apply_display()
	_save()


func set_accessibility_mode(mode: int) -> void:
	var next := clampi(mode, 0, 3)
	if accessibility_mode == next:
		return
	accessibility_mode = next
	_save()
	accessibility_changed.emit()


func set_touch_mode(value: String) -> void:
	var next := value if value == "yes" or value == "no" else "auto"
	if next == touch_mode:
		return
	touch_mode = next
	_save()
	touch_changed.emit()


## Replace only the primary keyboard binding. Other keyboard alternatives and
## joypad mappings stay intact. Escape remains the cancel key while rebinding.
func primary_key(action: String) -> int:
	return int(keybinds.get(action, DEFAULT_KEYS.get(action, 0)))


func set_keybind(action: String, physical_key: int) -> bool:
	# T is reserved for the fixed x1/x4 time toggle, not an editable binding.
	if not DEFAULT_KEYS.has(action) or physical_key <= 0 or physical_key == KEY_F11 or physical_key == KEY_T:
		return false
	for other in EDITABLE_ACTIONS:
		if other == action:
			continue
		# Include alternate keys such as the cursor arrows, not just WASD.
		for event in InputMap.action_get_events(StringName(other)):
			if event is InputEventKey and (event as InputEventKey).physical_keycode == physical_key:
				return false
	var prior := primary_key(action)
	if prior == physical_key:
		return true
	_swap_key(action, prior, physical_key)
	if physical_key == int(DEFAULT_KEYS[action]):
		keybinds.erase(action)
	else:
		keybinds[action] = physical_key
	_save()
	keybinds_changed.emit()
	return true


func reset_keybinds() -> void:
	for action in EDITABLE_ACTIONS:
		_swap_key(action, primary_key(action), int(DEFAULT_KEYS[action]))
	keybinds.clear()
	_save()
	keybinds_changed.emit()


func _apply_keybinds() -> void:
	for action in EDITABLE_ACTIONS:
		if keybinds.has(action):
			# Ignore an old custom binding for T to avoid triggering two actions.
			if primary_key(action) == KEY_T:
				keybinds.erase(action)
				continue
			_swap_key(action, int(DEFAULT_KEYS[action]), primary_key(action))


func _swap_key(action: String, old_key: int, new_key: int) -> void:
	var name := StringName(action)
	if not InputMap.has_action(name):
		InputMap.add_action(name)
	for event in InputMap.action_get_events(name):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == old_key:
			InputMap.action_erase_event(name, event)
	var new_event := InputEventKey.new()
	new_event.physical_keycode = new_key
	InputMap.action_add_event(name, new_event)


func set_touch_position(id: String, ratio: Vector2) -> void:
	touch_layout[id] = Vector2(clampf(ratio.x, 0.04, 0.96), clampf(ratio.y, 0.08, 0.96))
	touch_layout_changed.emit()


func touch_scale(id: String) -> float:
	return clampf(float(touch_scales.get(id, 1.0)), 0.6, 1.8)


func set_touch_scale(id: String, value: float) -> void:
	touch_scales[id] = snappedf(clampf(value, 0.6, 1.8), 0.1)
	touch_layout_changed.emit()


func complete_touch_tutorial() -> void:
	touch_tutorial_done = true
	_save()


func save_touch_layout() -> void:
	_save()


func reset_touch_layout() -> void:
	touch_layout.clear()
	touch_scales.clear()
	touch_layout_changed.emit()
	_save()


func has_touch_layout() -> bool:
	return not touch_layout.is_empty()


func touch_center(id: String, fallback: Vector2, view: Vector2) -> Vector2:
	# Layouts saved before the compact pads have no "more" key. Ignore them.
	if not touch_layout.has("more") or not touch_layout.has(id):
		return fallback
	var ratio: Variant = touch_layout[id]
	if typeof(ratio) != TYPE_VECTOR2:
		return fallback
	var r: Vector2 = ratio
	return Vector2(view.x * r.x, view.y * r.y)



func replay_tutorial() -> void:
	tutorial_done = false
	resource_intro_done = false
	touch_tutorial_done = false
	_save()
	tutorial_replay.emit()


func complete_resource_intro() -> void:
	if resource_intro_done:
		return
	resource_intro_done = true
	_save()


func complete_tutorial() -> void:
	if tutorial_done:
		return
	tutorial_done = true
	_save()


## Keys whose Spanish or English copy is empty.
func audit_ui() -> PackedStringArray:
	var missing := PackedStringArray()
	for key in UI.keys():
		var row: Dictionary = UI[key]
		if String(row.get("es", "")).strip_edges().is_empty() or String(row.get("en", "")).strip_edges().is_empty():
			missing.append(String(key))
	return missing


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode != KEY_F11 and key.physical_keycode != KEY_F11:
		return
	set_fullscreen(not fullscreen)
	get_viewport().set_input_as_handled()


## Largest integer scale whose client area fits the usable screen, minus a title bar.
func max_fit_scale() -> int:
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return 2
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var max_w := maxi(usable.size.x - 8, VIEW_W)
	var max_h := maxi(usable.size.y - _title_reserve(), VIEW_H)
	var scale := mini(int(max_w / float(VIEW_W)), int(max_h / float(VIEW_H)))
	return maxi(scale, 1)


func effective_window_scale() -> int:
	var fit := max_fit_scale()
	if window_scale <= 0:
		return fit
	return clampi(window_scale, 1, fit)


func _ensure_buses() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _apply_audio() -> void:
	GameState.language = lang
	_apply_bus("Master", master)
	_apply_bus("Music", music)
	_apply_bus("SFX", sfx)


func _boot_display(save_after: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not _has_display_save:
		_pick_default_display()
		save_after = true
	apply_display()
	if save_after:
		_save()


func _pick_default_display() -> void:
	fullscreen = false
	vsync_on = true
	var fit := max_fit_scale()
	if fit >= 3:
		window_scale = 3
	elif fit >= 2:
		window_scale = 2
	else:
		window_scale = 0


func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_apply_vsync()
	if OS.has_feature("web"):
		# The custom HTML shell owns canvas dimensions; Godot follows browser resizes.
		# Only request fullscreen after explicit user interaction in the Options screen.
		if fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if fullscreen:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	var scale := effective_window_scale()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	# 2x / 3x / 4x / fit pick a starting size. The border stays draggable after that.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
	var size := Vector2i(VIEW_W * scale, VIEW_H * scale)
	DisplayServer.window_set_size(size)
	_place_window(size)
	_pending_scale = scale
	if not _checking_window:
		_checking_window = true
		_confirm_client_scale.call_deferred()


func _confirm_client_scale() -> void:
	_checking_window = false
	var requested := _pending_scale
	if fullscreen or OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return
	var got := DisplayServer.window_get_size()
	if got.x >= VIEW_W * requested and got.y >= VIEW_H * requested:
		return
	var fit := mini(int(got.x / float(VIEW_W)), int(got.y / float(VIEW_H)))
	fit = maxi(fit, 1)
	if fit >= requested:
		return
	var size := Vector2i(VIEW_W * fit, VIEW_H * fit)
	DisplayServer.window_set_size(size)
	_place_window(size)


## Viewport stretch already scales the 640x360 image. Do not write the window size here:
## this runs while the player is dragging the border.
func _on_root_resized() -> void:
	if fullscreen or OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return
	if DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED):
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)


func _place_window(size: Vector2i) -> void:
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var extra_x := usable.size.x - size.x
	var extra_y := usable.size.y - size.y - _title_reserve()
	var left := usable.position.x + maxi(int(extra_x / 2.0), 0)
	var top := usable.position.y + maxi(int(extra_y / 2.0), 0)
	DisplayServer.window_set_position(Vector2i(left, top))


func _title_reserve() -> int:
	match OS.get_name():
		"macOS":
			return 36
		"Windows":
			return 56
		_:
			return 48


func _apply_vsync() -> void:
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.VSYNC_ENABLED if vsync_on else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)
	# The Compatibility renderer or the platform may override this request.
	# The Options screen displays the actual engine-reported value.


func vsync_matches_request() -> bool:
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return false
	var desired := DisplayServer.VSYNC_ENABLED if vsync_on else DisplayServer.VSYNC_DISABLED
	return DisplayServer.window_get_vsync_mode() == desired


func _apply_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	if linear <= 0.001:
		AudioServer.set_bus_mute(idx, true)
		return
	AudioServer.set_bus_mute(idx, false)
	AudioServer.set_bus_volume_db(idx, linear_to_db(linear))


func _read_touch_layout(raw: Variant) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var data: Dictionary = raw
	for key in data.keys():
		var value: Variant = data[key]
		if typeof(value) == TYPE_VECTOR2:
			out[String(key)] = value
	return out


## True when the file was missing or had no display section, so the first boot can save defaults.
func _load() -> bool:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return true
	lang = "en" if String(config.get_value("locale", "lang", "en")) == "en" else "es"
	master = clampf(float(config.get_value("audio", "master", 1.0)), 0.0, 1.0)
	music = clampf(float(config.get_value("audio", "music", 1.0)), 0.0, 1.0)
	sfx = clampf(float(config.get_value("audio", "sfx", 1.0)), 0.0, 1.0)
	var touch := String(config.get_value("play", "touch_mode", "auto"))
	touch_mode = touch if touch == "yes" or touch == "no" else "auto"
	touch_layout = _read_touch_layout(config.get_value("input", "touch_layout", {}))
	if int(config.get_value("input", "touch_layout_version", 0)) < TOUCH_LAYOUT_VERSION:
		touch_layout.clear()
	var scales: Variant = config.get_value("input", "touch_scales", {})
	if scales is Dictionary:
		for name in scales.keys():
			touch_scales[String(name)] = clampf(float(scales[name]), 0.6, 1.8)
	touch_tutorial_done = bool(config.get_value("play", "touch_tutorial_done", false))
	var saved_keys: Variant = config.get_value("input", "keybinds", {})
	if saved_keys is Dictionary:
		for action in saved_keys.keys():
			if DEFAULT_KEYS.has(String(action)) and int(saved_keys[action]) > 0:
				keybinds[String(action)] = int(saved_keys[action])
	tutorial_done = bool(config.get_value("play", "tutorial_done", false))
	resource_intro_done = bool(config.get_value("play", "resource_intro_done", false))
	last_scenario = String(config.get_value("play", "last_scenario", ""))
	reduce_effects = bool(config.get_value("play", "reduce_effects", false))
	accessibility_mode = clampi(int(config.get_value("play", "accessibility_mode", 0)), 0, 3)
	_has_display_save = config.has_section("display")
	if not _has_display_save:
		return true
	fullscreen = bool(config.get_value("display", "fullscreen", false))
	var scale := int(config.get_value("display", "window_scale", 0))
	window_scale = scale if scale == 2 or scale == 3 or scale == 4 else 0
	vsync_on = bool(config.get_value("display", "vsync", true))
	return false


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("locale", "lang", lang)
	config.set_value("audio", "master", master)
	config.set_value("audio", "music", music)
	config.set_value("audio", "sfx", sfx)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "window_scale", window_scale)
	config.set_value("display", "vsync", vsync_on)
	config.set_value("play", "touch_mode", touch_mode)
	config.set_value("input", "touch_layout", touch_layout)
	config.set_value("input", "touch_layout_version", TOUCH_LAYOUT_VERSION)
	config.set_value("input", "touch_scales", touch_scales)
	config.set_value("play", "touch_tutorial_done", touch_tutorial_done)
	config.set_value("input", "keybinds", keybinds)
	config.set_value("play", "tutorial_done", tutorial_done)
	config.set_value("play", "resource_intro_done", resource_intro_done)
	config.set_value("play", "last_scenario", last_scenario)
	config.set_value("play", "reduce_effects", reduce_effects)
	config.set_value("play", "accessibility_mode", accessibility_mode)
	config.save(PATH)
