# Datos de la NASA en Cóndor Rojo

Datos reales de la NASA y de la Agencia Espacial Canadiense, guardados en el juego el 13 de noviembre de 2026. No son datos en vivo. El juego no hace ninguna llamada de red mientras se juega.

## Qué se usa y de dónde

Los archivos están en `data/nasa/`. Un solo lector (`NasaData`) los carga al arrancar.

| Dato | Origen | Cómo se consultó |
|---|---|---|
| Clima espacial | NASA CCMC DONKI | API de `ccmc.gsfc.nasa.gov`, del 2024-01-01 al 2026-11-13: 1.941 llamaradas, 85 de clase X, 214 registros SEP, 62 tormentas geomagnéticas, 4.578 CME |
| Retraso de la luz y ángulo Sol-Tierra-Marte | NASA JPL Horizons | Marte visto desde la Tierra, 00:00 UT, 2024–2026 |
| Dosis en la Estación | NASA OSDR RadLab | DosTel1 y DosTel2, abril y mayo de 2024 |
| Salud y plantas | NASA OSDR | Estudios OSD-342, 396, 937, 946, 984, 269, 772, 766 y 476 |
| Lugares | NASA Mars Trek | Coordenadas y nombres IAU |
| Fotos | NASA Image and Video Library | Seis fotos de dominio público, crédito NASA/JPL-Caltech |
| Lo demás | Páginas de la NASA y de la CSA | Hechos de Marte, radiación, MOXIE, rovers, comida y ejercicio |

Cada partida elige uno de seis periodos reales (febrero, mayo, octubre y diciembre de 2024, noviembre de 2025, enero de 2026). Los Días 1 a 10 del juego son las diez fechas de ese periodo.

Usamos tormentas reales que vio la NASA en esas fechas, como si llegaran a tu base. No todas apuntaban a Marte. Esas tormentas las vieron instrumentos cerca de la Tierra.

## Por qué no hay datos en vivo

El juego se juega en una escuela sin internet y en GitHub Pages. Si pidiera el clima del día, una partida sin red se quedaría vacía. Los números van guardados y siempre dicen la fecha de consulta: 13 de noviembre de 2026. La pantalla de fuentes puede abrir una página en el navegador; eso no trae datos al juego.

## Dato real y valor de juego

| Qué | Número | Qué es |
|---|---|---|
| Dosis de fondo, cada Día, estés donde estés | 0,67 mSv | Dato real (Curiosity RAD, agosto 2012 a junio 2013) |
| Blindaje de un interior contra partículas de tormenta | 50 % (×0,5) | Dato real (NASA OCHMO, promedio) |
| Tormenta level 2, toda la ventana afuera | 2,0 mSv | Valor de juego |
| Tormenta level 3, toda la ventana afuera | 5,0 mSv | Valor de juego |
| Hábitat con refugio de bolsas, o cueva | ×0,25 | Valor de juego (NASA dice que más masa y las cuevas protegen más, sin dar esta cifra) |
| Aviso del sensor | 30 s | Valor de juego (en Marte las partículas tardan decenas de minutos) |
| Ventana de la tormenta | 60 s | Valor de juego |
| Momento del aviso | entre el 25 % y el 60 % del Día | Valor de juego |
| 1 minuto de luz | 2 s de juego | Valor de juego (ida y vuelta = minutos de luz × 4) |
| Ejercicio | −2 energía, −2 comida, 3 s, una vez por Día | Valor de juego |
| Músculos flojos | tras 2 Días seguidos sin ejercicio; correr y saltar ×0,85 | Valor de juego (en el espacio se pierde cerca de 1 % de hueso por mes) |
| Refugio de bolsas | −6 comida, −4 energía | Valor de juego |
| Cerrar el hábitat | −2 energía | Valor de juego |
| Seguir con el plan | +6 comida al día siguiente | Valor de juego |
| Tope del final ejemplar | 12,0 mSv | Valor de juego |

La dosis no termina la partida y no resta oxígeno ni comida. Con estas dosis nadie se enferma en 10 Días. Sí cuenta para el final ejemplar.

Los datos de ejercicio vienen de la Estación Espacial (microgravedad) y de estudios de reposo en cama. En Marte la gravedad es 38 % de la Tierra y todavía no se sabe cuánto hueso se pierde. En el juego el efecto llega antes para que se note.

En el juego los lugares reales están cerca para que puedas visitarlos. En Marte están a miles de kilómetros entre sí.

## Los 5 peligros del vuelo espacial

Fuente: NASA Human Research Program, [5 Hazards of Human Spaceflight](https://www.nasa.gov/hrp/hazards/).

| Peligro | En el juego | Dato real | Fuente |
|---|---|---|---|
| Radiación | Contador de dosis y tormentas solares. El refugio se paga con comida y energía. | 0,67 mSv al día en la superficie. El blindaje baja las partículas de una tormenta a la mitad. | Curiosity RAD; NASA OCHMO |
| Aislamiento | Mensajes de Quito que llegan tarde, o no llegan en la conjunción. INTI acompaña. | Vivir lejos y en un lugar pequeño cansa la mente. | NASA HRP |
| Distancia de la Tierra | Retraso real de la luz, días sin contacto y sin reabastecimiento. | Un mensaje tarda entre 3 y 22 minutos. | Mars Relay Network; JPL Horizons |
| Gravedad | Bicicleta en el hábitat. Si no te ejercitas, afuera corres más lento. | En la Estación se entrenan unas 2 horas al día. Cerca de 1 % de hueso por mes sin ejercicio. | NASA; OSDR OSD-342 y OSD-946 |
| Ambiente cerrado u hostil | Oxígeno, energía, comida, polvo y plantas que limpian el aire. | El aire de Marte es 95 % CO₂ y 0,16 % oxígeno. Las plantas dan comida y oxígeno. | NASA NSSDC; CSA Tomatosphere |

## Fuentes

Consultadas el 13 de noviembre de 2026. La lista con cada enlace está en `data/nasa/sources.json` y dentro del juego, en Datos de la NASA.

- NASA Human Research Program: 5 Hazards of Human Spaceflight — https://www.nasa.gov/hrp/hazards/
- NASA CCMC DONKI — https://ccmc.gsfc.nasa.gov/tools/DONKI/
- NASA JPL Horizons — https://ssd.jpl.nasa.gov/horizons/
- NASA OSDR RadLab — https://visualization.osdr.nasa.gov/radlab/
- NASA Open Science Data Repository — https://osdr.nasa.gov/bio/repo/
- OSD-342, OSD-396, OSD-937, OSD-946, OSD-984, OSD-269, OSD-772, OSD-766, OSD-476 — https://osdr.nasa.gov/bio/repo/data/studies/
- NASA Mars Trek — https://trek.nasa.gov/mars/
- NASA Science: Mars Facts — https://science.nasa.gov/mars/facts/
- NASA NSSDC: Mars Fact Sheet — https://nssdc.gsfc.nasa.gov/planetary/factsheet/marsfact.html
- NASA JPL: Mars at a Glance — https://www.jpl.nasa.gov/news/press_kits/insight/landing/facts/mars-at-a-glance/
- SwRI / Hassler et al. 2014, Science (Curiosity RAD) — https://www.swri.org/press-release/swri-scientists-publish-first-radiation-measurements-surface-mars
- NASA Science: Radiation Exposure Comparisons — https://science.nasa.gov/resource/radiation-exposure-comparisons-with-mars-trip-calculation/
- NASA: NASA Watches Mars Light Up During Epic Solar Storm — https://www.nasa.gov/solar-system/planets/mars/nasa-watches-mars-light-up-during-epic-solar-storm/
- NASA JSC SRAG FAQ — https://srag.jsc.nasa.gov/SpaceRadiation/FAQ/FAQ.cfm
- NASA-STD-3001, límite de carrera 600 mSv — https://www.nasa.gov/reference/4-0-human-performance/
- NASA OCHMO: Radiation Protection Technical Brief — https://www.nasa.gov/wp-content/uploads/2023/03/radiation-protection-technical-brief-ochmo.pdf
- NASA: Orion Radiation Protection Plan — https://www.nasa.gov/missions/artemis/orion/scientists-and-engineers-evaluate-orion-radiation-protection-plan/
- NASA Science: Mars Relay Network — https://science.nasa.gov/mars/mars-relay-network/
- NASA: Mars Communications Disruption and Delay — https://www.nasa.gov/wp-content/uploads/2024/01/mars-communications-disruption-and-delay.pdf
- NASA: Counteracting Bone and Muscle Loss in Microgravity — https://www.nasa.gov/missions/station/iss-research/counteracting-bone-and-muscle-loss-in-microgravity/
- CSA: Physical activity in space — https://www.asc-csa.gc.ca/eng/astronauts/living-in-space/physical-activity-in-space.asp
- CSA: Food production toolkit — https://www.asc-csa.gc.ca/eng/youth-educators/toolkits/food-production/
- CSA: Tomatosphere — https://www.asc-csa.gc.ca/eng/youth-educators/tomatosphere.asp
- CSA: Eating in space — https://www.asc-csa.gc.ca/eng/astronauts/living-in-space/eating-in-space.asp
- CSA: Growing healthy food — https://www.asc-csa.gc.ca/eng/sciences/food-production/growing-healthy-food-in-space-and-remote-areas.asp
- NASA: MOXIE — https://www.nasa.gov/missions/mars-2020-perseverance/perseverance-rover/nasas-oxygen-generating-experiment-moxie-completes-mars-mission/
- NASA: Opportunity mission ends — https://www.nasa.gov/news-release/nasas-record-setting-opportunity-rover-mission-on-mars-comes-to-end/
- NASA Science: Spirit — https://science.nasa.gov/mission/mer-spirit/
- NASA Science: Seven Possible Cave Skylights — https://science.nasa.gov/resource/seven-possible-cave-skylights-on-mars/
- NASA JPL: Buried Glaciers on Mars — https://www.jpl.nasa.gov/news/nasa-spacecraft-detects-buried-glaciers-on-mars
- NASA Image and Video Library — https://images.nasa.gov/
- NASA Space Apps 2026: Junior Astronaut Mission Trainer — https://www.spaceappschallenge.org/2026/challenges/junior-astronaut-mission-trainer/
- Fotos PIA17760, PIA14508, PIA22930, PIA19807, PIA26302, PIA24485 — NASA/JPL-Caltech

---

# NASA data in Cóndor Rojo

Real data from NASA and the Canadian Space Agency, saved in the game on November 13, 2026. This is not live data. The game makes no network calls while you play.

## What is used, and where it comes from

The files live in `data/nasa/`. One reader (`NasaData`) loads them at startup.

| Data | Source | How it was read |
|---|---|---|
| Space weather | NASA CCMC DONKI | API at `ccmc.gsfc.nasa.gov`, 2024-01-01 to 2026-11-13: 1,941 flares, 85 X-class, 214 SEP records, 62 geomagnetic storms, 4,578 CMEs |
| Light delay and Sun-Earth-Mars angle | NASA JPL Horizons | Mars as seen from Earth, 00:00 UT, 2024–2026 |
| Dose on the Station | NASA OSDR RadLab | DosTel1 and DosTel2, April and May 2024 |
| Health and plants | NASA OSDR | Studies OSD-342, 396, 937, 946, 984, 269, 772, 766, and 476 |
| Places | NASA Mars Trek | Coordinates and IAU names |
| Photos | NASA Image and Video Library | Six public-domain photos, credit NASA/JPL-Caltech |
| The rest | NASA and CSA pages | Mars facts, radiation, MOXIE, rovers, food, and exercise |

Each run picks one of six real periods (February, May, October, and December 2024, November 2025, January 2026). Game Days 1 to 10 are the ten dates of that period.

We use real storms NASA recorded on those dates, as if they reached your base. Not all of them were aimed at Mars. Instruments near Earth are the ones that saw them.

## Why there is no live data

The game is played at a school with no internet, and on GitHub Pages. Asking for today's weather would leave an offline run empty. The numbers are saved, and they always name the access date: November 13, 2026. The sources screen can open a page in the browser. That does not bring data into the game.

## Real data and game values

| What | Number | What it is |
|---|---|---|
| Background dose, every Day, wherever you are | 0.67 mSv | Real (Curiosity RAD, August 2012 to June 2013) |
| An interior against storm particles | 50% (×0.5) | Real (NASA OCHMO, average) |
| Level 2 storm, the whole window outside | 2.0 mSv | Game value |
| Level 3 storm, the whole window outside | 5.0 mSv | Game value |
| Habitat with a bag shelter, or the cave | ×0.25 | Game value (NASA says more mass and caves protect more, and does not give this figure) |
| Sensor warning | 30 s | Game value (on Mars the particles take tens of minutes) |
| Storm window | 60 s | Game value |
| When the warning starts | between 25% and 60% of the Day | Game value |
| 1 minute of light | 2 game seconds | Game value (round trip = light-minutes × 4) |
| Exercise | −2 energy, −2 food, 3 s, once per Day | Game value |
| Floppy muscles | after 2 Days in a row without exercise; run and jump ×0.85 | Game value (in space, bone loss is about 1% per month) |
| Bag shelter | −6 food, −4 energy | Game value |
| Close the habitat | −2 energy | Game value |
| Stick to the plan | +6 food the next day | Game value |
| Exemplary-ending cap | 12.0 mSv | Game value |

The dose never ends the run and never subtracts oxygen or food. At these doses nobody gets sick in 10 Days. It does count toward the exemplary ending.

The exercise facts come from the Space Station (microgravity) and from bed-rest studies. Mars gravity is 38% of Earth's, and nobody yet knows how much bone is lost there. In the game the effect arrives sooner so you can feel it.

In the game these real places are close together so you can visit them. On Mars they are thousands of kilometers apart.

## The 5 hazards of human spaceflight

Source: NASA Human Research Program, [5 Hazards of Human Spaceflight](https://www.nasa.gov/hrp/hazards/).

| Hazard | In the game | Real fact | Source |
|---|---|---|---|
| Radiation | Dose counter and solar storms. The shelter is paid for with food and energy. | 0.67 mSv a day on the surface. Shielding cuts storm particles by half. | Curiosity RAD; NASA OCHMO |
| Isolation | Messages from Quito that arrive late, or not at all in conjunction. INTI stays with you. | Living far away in a small place tires the mind. | NASA HRP |
| Distance from Earth | Real light delay, days with no contact, and no resupply. | A message takes 3 to 22 minutes. | Mars Relay Network; JPL Horizons |
| Gravity | A bike in the habitat. Skip it and you run slower outside. | On the Station, astronauts train about 2 hours a day. About 1% of bone per month without exercise. | NASA; OSDR OSD-342 and OSD-946 |
| Closed or hostile environment | Oxygen, energy, food, dust, and plants that clean the air. | Mars air is 95% CO₂ and 0.16% oxygen. Plants give food and oxygen. | NASA NSSDC; CSA Tomatosphere |

## Sources

Accessed on November 13, 2026. The full list, with every link, is in `data/nasa/sources.json` and inside the game, on the NASA data screen.

- NASA Human Research Program: 5 Hazards of Human Spaceflight — https://www.nasa.gov/hrp/hazards/
- NASA CCMC DONKI — https://ccmc.gsfc.nasa.gov/tools/DONKI/
- NASA JPL Horizons — https://ssd.jpl.nasa.gov/horizons/
- NASA OSDR RadLab — https://visualization.osdr.nasa.gov/radlab/
- NASA Open Science Data Repository — https://osdr.nasa.gov/bio/repo/
- OSD-342, OSD-396, OSD-937, OSD-946, OSD-984, OSD-269, OSD-772, OSD-766, OSD-476 — https://osdr.nasa.gov/bio/repo/data/studies/
- NASA Mars Trek — https://trek.nasa.gov/mars/
- NASA Science: Mars Facts — https://science.nasa.gov/mars/facts/
- NASA NSSDC: Mars Fact Sheet — https://nssdc.gsfc.nasa.gov/planetary/factsheet/marsfact.html
- NASA JPL: Mars at a Glance — https://www.jpl.nasa.gov/news/press_kits/insight/landing/facts/mars-at-a-glance/
- SwRI / Hassler et al. 2014, Science (Curiosity RAD) — https://www.swri.org/press-release/swri-scientists-publish-first-radiation-measurements-surface-mars
- NASA Science: Radiation Exposure Comparisons — https://science.nasa.gov/resource/radiation-exposure-comparisons-with-mars-trip-calculation/
- NASA: NASA Watches Mars Light Up During Epic Solar Storm — https://www.nasa.gov/solar-system/planets/mars/nasa-watches-mars-light-up-during-epic-solar-storm/
- NASA JSC SRAG FAQ — https://srag.jsc.nasa.gov/SpaceRadiation/FAQ/FAQ.cfm
- NASA-STD-3001, career limit 600 mSv — https://www.nasa.gov/reference/4-0-human-performance/
- NASA OCHMO: Radiation Protection Technical Brief — https://www.nasa.gov/wp-content/uploads/2023/03/radiation-protection-technical-brief-ochmo.pdf
- NASA: Orion Radiation Protection Plan — https://www.nasa.gov/missions/artemis/orion/scientists-and-engineers-evaluate-orion-radiation-protection-plan/
- NASA Science: Mars Relay Network — https://science.nasa.gov/mars/mars-relay-network/
- NASA: Mars Communications Disruption and Delay — https://www.nasa.gov/wp-content/uploads/2024/01/mars-communications-disruption-and-delay.pdf
- NASA: Counteracting Bone and Muscle Loss in Microgravity — https://www.nasa.gov/missions/station/iss-research/counteracting-bone-and-muscle-loss-in-microgravity/
- CSA: Physical activity in space — https://www.asc-csa.gc.ca/eng/astronauts/living-in-space/physical-activity-in-space.asp
- CSA: Food production toolkit — https://www.asc-csa.gc.ca/eng/youth-educators/toolkits/food-production/
- CSA: Tomatosphere — https://www.asc-csa.gc.ca/eng/youth-educators/tomatosphere.asp
- CSA: Eating in space — https://www.asc-csa.gc.ca/eng/astronauts/living-in-space/eating-in-space.asp
- CSA: Growing healthy food — https://www.asc-csa.gc.ca/eng/sciences/food-production/growing-healthy-food-in-space-and-remote-areas.asp
- NASA: MOXIE — https://www.nasa.gov/missions/mars-2020-perseverance/perseverance-rover/nasas-oxygen-generating-experiment-moxie-completes-mars-mission/
- NASA: Opportunity mission ends — https://www.nasa.gov/news-release/nasas-record-setting-opportunity-rover-mission-on-mars-comes-to-end/
- NASA Science: Spirit — https://science.nasa.gov/mission/mer-spirit/
- NASA Science: Seven Possible Cave Skylights — https://science.nasa.gov/resource/seven-possible-cave-skylights-on-mars/
- NASA JPL: Buried Glaciers on Mars — https://www.jpl.nasa.gov/news/nasa-spacecraft-detects-buried-glaciers-on-mars
- NASA Image and Video Library — https://images.nasa.gov/
- NASA Space Apps 2026: Junior Astronaut Mission Trainer — https://www.spaceappschallenge.org/2026/challenges/junior-astronaut-mission-trainer/
- Photos PIA17760, PIA14508, PIA22930, PIA19807, PIA26302, PIA24485 — NASA/JPL-Caltech
