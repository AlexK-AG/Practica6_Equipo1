# Sector 07 — campaña de contención

## Ergonomía y acciones adicionales para móvil — 29 de octubre de 2026
- El grupo táctil inferior derecho centra FUEGO (104 px) y coloca salto, cuchillo, granada, recarga, carrera, cambio de arma y mira alrededor con blancos secundarios de 76 px. Cambio de arma se muestra con dos armas equipadas; MIRA solo con el arma de precisión y conmuta su zoom a 0,5×. PC conserva su comportamiento.
- El joystick queda fijo abajo a la izquierda; acepta el toque inicial solo dentro de 1,2 veces su radio visual (≈120 px iniciales). El giro táctil agrega muestras antes del paso de física, aplica sensibilidad 1,8× y alcanza hasta 3,5 rad/s. La sensibilidad de cámara del ratón de PC no cambia.
- La sincronización móvil necesita el permiso Android `INTERNET` y HTTP local permitido por la plantilla Gradle (target API 36). El preset activa Gradle, permiso de Internet y tráfico HTTP para la app; el AndroidManifest declara `usesCleartextTraffic`. El estado ahora incluye códigos de red/HTTP cuando falla.
- README y guía documentan distribución, tamaños, radio de activación, zoom, sensibilidad y exportación. La escena principal carga en Godot sin errores nuevos de GDScript; aparecen avisos previos en scripts no relacionados. La prueba del HUD se intentó pero no informó su marcador de finalización. No se pudo exportar la APK aquí: falta el NDK Android `29.0.14206865` requerido por la plantilla Gradle. Falta validar red y multitouch en dispositivo/emulador.

## Interacción táctil y sincronización móvil — 29 de octubre de 2026
- En móvil aparece `InteractButton` cuando un objetivo/suministro activo está a 3,5 m, visible y dentro del campo de mirada. El botón usa la acción Input Map `interact`; en PC se conserva el rayo y la tecla existentes. La guía lista los parámetros táctiles usados.
- Android puede enviar un snapshot de perfil, avance, intentos, acumulados y eventos a `POST /api/mobile-sync`, con token y al seleccionar perfil, guardar checkpoint o finalizar misión. La base de copias `sector07.sqlite.mobile-sync.sqlite` se mantiene separada del guardado PC; la web combina ambas fuentes al consultar. Las trazas de recorrido no se copian.
- `server.mjs --lan` permite la red local; la configuración incluye token en variables de entorno, dirección URL en opciones móviles, y permisos Android `INTERNET`/`VIBRATE`. El README describe la configuración de PowerShell, firewall, Wi-Fi y exportación de APK.
- Verificación: la prueba `tests/web/web_server.mjs` pasa, incluyendo token inválido, sincronización aceptada, perfil/intento/eventos móviles visibles y comprobación de que la base PC conserva sus bytes. Las escenas de inicio y juego cargan en Godot sin errores nuevos de script; aparecen avisos previos en scripts no relacionados. La prueba GDScript headless no pudo completarse en este entorno porque Godot intentó crear `user://C:`. Falta validar el tacto y la conexión desde un APK/dispositivo real. No se alteró el esquema SQLite de la partida local.

## Mejora de controles táctiles en móvil — 29 de octubre de 2026
- El joystick de la izquierda ahora admite activación flotante en su mitad de pantalla y vuelve a su posición de referencia al soltarlo. Los gestos de cámara mantienen las acciones de mirada hasta que el jugador las consume en su siguiente paso de física, evitando que se pierdan al mover y apuntar a la vez.
- Se agregan botones `ReloadButton` y `SprintButton`: recarga dispara la acción del Input Map y correr alterna entre activado/desactivado con cada toque. Las acciones conservan multitouch. Los botones tienen 96 px; pausa pasa al centro superior y la tarjeta de misión vuelve al extremo superior derecho.
- Vitalidad, arsenal y misión se reducen al 88–90 % solo con controles móviles; el layout de PC restaura su escala original. La guía del juego documenta la distribución. No se alteran controles de PC, movimiento del jugador, esquema SQLite, leaderboard ni servidor web.
- Verificación: pendiente de ejecutar el juego y pruebas; validar tacto y disposición en teléfono/emulador después de exportar una APK nueva.

## Acciones unificadas de Input Map — 28 de octubre de 2026
- `Campaign.apply_input_bindings()` centraliza la creación de acciones configurables y sus teclas guardadas, además de disparo, apuntado y cambio de arma por ratón. La misma función incorpora asignaciones estándar de mando para movimiento, cámara con stick derecho, combate, interacción, granadas, armas y pausa; conserva eventos de mando preexistentes y actualiza las teclas sin borrarlos. La zona muerta de movimiento/cámara usa el valor predeterminado de Godot (0,2).
- El jugador ahora detecta apuntado y rueda mediante acciones (`aim`, `weapon_next`, `weapon_previous`) en lugar de inspeccionar botones de ratón; también obtiene el giro del stick derecho desde acciones direccionales. El movimiento relativo del ratón se mantiene para orientar la cámara. La reasignación desde Opciones aplica el cambio inmediatamente, guarda el dato y revierte el Input Map si falla el guardado; restablecer opciones también aplica las teclas predeterminadas.
- README y guía del juego describen las asignaciones de teclado, ratón y mando. Esa fase no agregó archivos ni modificó el esquema SQLite; la capa táctil se documenta en la entrada siguiente.

## Controles táctiles — 28 de octubre de 2026
- `hud.tscn` contiene como nodos Control editables el joystick, el mando móvil y cada botón; se pueden seleccionar y reubicar en el editor 2D. `touch_controls.gd` gestiona los toques, el arrastre derecho para mirar y envía `InputEventAction` al Input Map. El multitouch permite saltar, disparar y moverse a la vez, compartiendo el buffer de salto (0,12 s) y coyote time (0,10 s) del jugador.
- Los controles se muestran en Android/iOS o al activar el modo de prueba en Configuración. PC mantiene sus controles y el movimiento del ratón sigue mirando; en modo de prueba solo se ignora al arrastrar con el botón izquierdo, para que el mouse simule un toque sin mover también la cámara. En Android/iOS se omite el clic izquierdo como disparo para impedir que la emulación de ratón dispare al tocar el joystick. `project.godot` fija landscape, conserva `canvas_items` + `expand` y activa emulación de toque desde ratón para depuración.
- El overlay calcula márgenes a partir de `DisplayServer.get_display_safe_area()`. En móviles el HUD mueve vitalidad bajo el indicador de sector y centra munición en el borde inferior, dejando las esquinas libres para los pulgares. Los botones miden 108 px al 100 % y el tamaño configurable va de 90 a 120 %; opacidad 0,40–0,70 (0,55 predeterminada), zona muerta 0,15–0,25 (0,20 predeterminada). El Input Map renormaliza el recorrido del joystick después de la zona muerta.
- Las opciones de opacidad, tamaño, zona muerta, vibración y modo de prueba se guardan como preferencias existentes en SQLite, sin migración ni cambio de esquema. Daño produce 60 ms y recogida de suministros 40 ms de vibración; Android necesita permiso `VIBRATE` en el preset de exportación. README y guía documentan controles y valores. La interfaz web local no cambia.
- Se añadieron a `addons/godot-sqlite/bin` las bibliotecas Android debug/release para arm64 y x86_64 del lanzamiento fijado Godot-SQLite v4.8 y sus entradas en `gdsqlite.gdextension`. Las DLL Windows existentes se conservaron; no cambió la capa GDScript ni el esquema SQLite. El APK debe exportarse con la arquitectura correspondiente al dispositivo/emulador.
- Verificación de esa integración: el juego carga en PC sin errores nuevos, las seis rutas del manifiesto existen y las DLL Windows mantienen sus hashes previos. La exportación Android desde consola no se pudo comprobar porque el proceso no pudo acceder al directorio de configuración del usuario; queda pendiente instalar y validar el APK en emulador/teléfono.
- Verificación: pendiente de prueba en dispositivo/emulador. Se conservó el lenguaje visual cian/ámbar del HUD existente.

## Estado vigente — 17 de octubre de 2026

- Campaña FPS 3D de diez niveles, misiones por fases, checkpoints, salas desbloqueables y jefe final en el nivel 10.
- Dieciocho subtipos de enemigos, navegación y búsqueda de coberturas, tácticas de apoyo y visión según altura; cajas dobles en zonas con enemigos altos.
- Cinco armas, cuchillo y tres granadas; hallazgos de armas en niveles 1, 3, 6 y 9, y granadas especiales en 2 y 5. Equipación con dos armas diferentes y nueve etapas de mejora.
- Inicio y HUD editables como nodos de sus escenas; índices de enemigos/armas, entrenamiento opcional de 28 pasos y opciones generales con brillo/restablecimiento.
- Guardado principal en SQLite, migración del CFG antiguo y eventos en la misma base. Esquema 3 con 2.400 eventos/400 intentos por perfil y acumulados de tiempo/resultados. La web local Node.js consulta el archivo en lectura mediante `/api/dashboard`; se actualiza al pulsar Actualizar.
- Scripts separados en `core`, `player`, `combat`, `enemies`, `missions`, `persistence`, `ui`, `common` y `visuals`. Modelos OBJ de `assets` agrupados en `assets/models/{enemies,props,structures}` conservando materiales, `.uid`, metadatos y referencias.
- Pruebas conservadas y agrupadas por función. Las nuevas salidas van a `.godot/test-results/`; los fixtures privados SQLite mantienen su ubicación en `.godot/`. `revision/` y el paquete original se conservan íntegros.
- Guías agrupadas en [docs/README.md](docs/README.md). La [guía vigente](docs/GUIA_DEL_JUEGO.md), [SQLite](docs/README_SQLITE.md), [eventos](docs/README_EVENTS.md), [web](web/README.md) y [pruebas](tests/README.md) describen el uso actual. `Agents.md` mantiene las instrucciones del proyecto.

La reorganización cambia ubicaciones y referencias, no las reglas ni el aspecto del juego. Se eliminaron únicamente las carpetas vacías solicitadas. La actualización documental no certifica por sí sola la ejecución de pruebas: el resultado de la verificación de esta reorganización debe informarse por separado.

## Cómo leer el registro histórico

**Las secciones siguientes son entradas acumuladas de versiones anteriores, en orden de incorporación.** Sus cifras y decisiones describen el momento en que se hicieron: siete niveles, seis mejoras, guardado CFG y tutorial estático pertenecen a la versión inicial. Las entradas posteriores y el estado vigente anterior los sustituyen. Se conservan para explicar la evolución; no son instrucciones actuales de uso. Las rutas de scripts/pruebas se actualizaron a su ubicación presente para facilitar la consulta. Los resultados de pruebas anotados más abajo corresponden a aquellas verificaciones, no a una nueva ejecución tras reorganizar carpetas.


## Guía detallada para estudio y presentación

- Se añadió [GUIA_DEL_JUEGO.md](docs/GUIA_DEL_JUEGO.md), que explica mecánicas, menús, perfiles, guardado, score, audio, escenas, instancias y conexiones entre scripts.
- Incluye un catálogo de todos los métodos de los siete scripts del juego, ejemplos del flujo de una partida e indicaciones para presentar o modificar las escenas en Godot.
- El apartado de bloqueo de niveles incorpora una revisión independiente de otro agente: índices desde cero, progreso por perfil, validaciones de acceso, mejoras pendientes y persistencia.
- Esta acción modifica únicamente documentación; no cambia las escenas, el código ni las partidas guardadas.

## Estructura y escenas editables
- FPS 3D en GDScript. `project.godot` inicia `scenes/start.tscn`; el autoload `Campaign` administra perfiles, mejoras, opciones y música.
- Se conservó la organización de nuestro proyecto: `scenes/`, `scripts/`, `assets/`. Mapas, colisiones, luces, personajes y ventanas están guardados como nodos, visibles en el editor.
- `scenes/main.tscn` sigue siendo el nivel 1 por compatibilidad con el proyecto original. `scenes/levels/level_2.tscn` a `level_7.tscn` completan la campaña. Cada raíz usa `game.gd`.
- `Arena` agrupa el escenario. En los mapas adaptados contiene además subgrupos de arquitectura, props e iluminación. `Player` y los enemigos siguen siendo hijos directos de la raíz.
- `scenes/actors/player.tscn` y las trece variantes `enemy_0.tscn` a `enemy_12.tscn` son instancias reutilizables. Se usan modelos del Modular SciFi MegaKit de `assets/`.
- Se extrajo el HUD original a `scenes/ui/hud.tscn`. Los niveles lo instancian sin reconstruirlo al jugar.
- `scenes/ui/upgrade_screen.tscn` y `upgrade_card.tscn` contienen paneles, textos y botones editables. El script rellena opciones, rangos y señales; no genera la ventana por código.
- `assets/ui_theme.tres` centraliza el aspecto del menú y mejoras. La pantalla de Inicio contiene páginas guardadas para perfiles, menú, misiones, configuración, scores y tutorial.

## Perfiles, campaña y guardado
- Al abrir se solicita un nombre de 1 a 20 caracteres. Se puede seleccionar un jugador guardado; mayúsculas/minúsculas y espacios exteriores no crean perfiles distintos.
- Cada jugador conserva niveles completados, mejores scores por nivel, seis elecciones de mejora, mejora pendiente y récord. Los perfiles son locales, sin cuentas ni contraseñas.
- El orden es natural: 1 → 2 → 3 → 4 → 5 → 6 → 7. Solo se habilita una misión si se completó la anterior. La interfaz y el controlador comprueban el bloqueo.
- Al ganar se guarda inmediatamente el resultado y se desbloquea la siguiente misión. Si se sale antes de elegir una mejora, la elección pendiente reaparece al entrar al selector y debe resolverse antes de jugar.
- Volver a una misión comienza desde su inicio, con vida, escudo y munición completos y las mejoras adquiridas. No se guarda la posición ni el combate a mitad de nivel. Morir o abandonar no suma puntos.
- Reiniciar misión conserva las mejoras; Reiniciar campaña borra el avance, puntuación actual y elecciones del jugador activo, tras confirmación. Conserva su récord y los demás perfiles.
- Archivo: `user://campaigns.cfg`, con escritura temporal y copia `.bak`. En Windows, Godot lo ubica normalmente en `%APPDATA%/Godot/app_userdata/Sector 07 - Contencion/`. La carga intenta la copia si el archivo principal no puede leerse. Los errores de guardado se muestran en la interfaz.
- La sensibilidad y los dos volúmenes se guardan como opciones generales del equipo.

## Menú y puntuaciones
- Menú: Jugar, Configuración, Tutorial, Tabla de scores, Cambiar jugador, Reiniciar campaña y Salir.
- Jugar abre tarjetas de misiones con capturas reales del mapa, nombre, estado y resultado. Las bloqueadas muestran qué falta; las completadas pueden repetirse.
- Score por victoria: `100 × bajas + 500 + max(0, 300 - segundos activos) + round(200 × vida / vida máxima)`; el tiempo en pausa no cuenta.
- El total actual suma el mejor resultado de cada misión. Repetir solo mejora ese resultado, sin acumular puntos por repetir. Tampoco concede mejoras duplicadas.
- La tabla ordena perfiles por su récord de total de campaña, de mayor a menor, y muestra el avance de su campaña actual.
- Tutorial estático con tres ilustraciones SVG y controles: WASD, ratón, clic, R, Shift, Espacio, Esc y F cuando se desbloquea cuerpo a cuerpo.

## Niveles y dificultad
| Nivel | Escena | Ambiente / procedencia | Enemigos | Vida enemiga total inicial |
|---|---|---|---:|---:|
| 1 · Laboratorio | main.tscn | Mapa original, frío | 7 | 455 |
| 2 · Almacén | level_2.tscn | Mapa actual, azul | 7 | 619 |
| 3 · Reactor | level_3.tscn | Mapa actual, violeta | 7 | 717 |
| 4 · Fundición | level_4.tscn | Adaptación del nivel 2 del RAR, ámbar | 6 | 762 |
| 5 · Biocontención | level_5.tscn | Adaptación del nivel 3 del RAR, carmesí | 6 | 858 |
| 6 · Fortaleza | level_6.tscn | Adaptación del nivel 4 del RAR, naranja | 8 | 1158 |
| 7 · Núcleo Áureo | level_7.tscn | Variante del bastión, props girados, luz y materiales dorados | 8 | 1541 |

- Se conservaron geometría y assets de los mapas de referencia, adaptando sus jerarquías y personajes a nuestros scripts. No se copiaron sus autoloads ni su HUD generado en ejecución.
- Se corrigió la fuente de iluminación ambiental de los mapas importados y se añadieron cuatro luces de relleno por mapa, para mantener visibles coberturas y enemigos.
- Aumentan vida total, daño y alcance; disminuye el intervalo base de ataque de 2,64 a 1,68 segundos. Las estadísticas de cada instancia siguen siendo editables en el Inspector.
- Desde el nivel 4, el texto ¡FUEGO! anuncia el disparo durante 0,55 s. Al disparar se vuelve a comprobar la línea de visión y el alcance: cubrirse evita el impacto.
- El Guardián Áureo tiene 450 PV. Bajo la mitad de vida, reduce un 20% su intervalo base entre ataques. Mantiene el aviso previo; no hay ataques inevitables ni daño a través de paredes.
- La navegación se calcula desde las colisiones BoxShape3D guardadas en Arena, incluidas subcarpetas. Área de navegación de ±15 m en niveles 1–5 y ±24 m en 6–7. Se corrigieron puntos de aparición bloqueados en los mapas importados.

## Mejoras equilibradas
Una elección al terminar cada uno de los primeros seis sectores. Sin rarezas aleatorias ni tienda. Los rangos son acumulaciones finitas y se muestran en las tarjetas.

| Mejora | Efecto por rango | Rango máximo disponible |
|---|---|---:|
| Vitalidad | +25 vida máxima | 3 |
| Munición potenciada | +4 daño por disparo | 3 |
| Escudo | +25 capacidad; recupera 10/s tras 3,5 s sin daño | 3 |
| Fusil | 20 daño base, 24 balas, 0,15 s entre disparos | 1 |
| Recarga táctica | Reduce 0,2 s de la recarga de 1,25 s | 2 |
| Nanorreparación | +3 PV/s sobre los 8 iniciales | 2 |
| Cargador | +4 balas | 1 |
| Blindaje | Reduce 8% del daño antes de absorberlo con escudo | 1 |
| Golpe de emergencia | F: 80 daño, 2,2 m, espera 1,2 s | 1 |
| Movilidad | +8% de velocidad | 1 |

- Pistola: 25 daño, 12 balas, intervalo 0,21 s. El fusil ofrece aproximadamente +12% de daño por segundo sin recargas, frente al salto de ×3,7 de la referencia. Tiene más capacidad pero menor daño por bala.
- Máximos individuales alcanzables: 175 PV, 75 escudo, +12 daño, regeneración 14 PV/s, recarga 0,85 s. Las elecciones compiten: no se alcanzan todos simultáneamente.
- Ofertas por etapa: (vida/fusil/escudo), (daño/recarga/golpe), (vida/escudo/regeneración), (daño/cargador/blindaje), (vida/recarga/movilidad), (daño/escudo/regeneración).
- Cambiar de nivel o reiniciar aplica las mejoras guardadas; elegirlas desde Inicio también funciona. Una misión repetida no da otra elección.
- Vida regenera tras cuatro segundos sin daño. La pausa congela movimiento, daño, regeneración, ataques y tiempo de puntuación.

## Audio
- El RAR no contiene WAV/OGG/MP3: su música se sintetiza desde GDScript. Se tomó esa idea y se crearon cuatro pistas WAV ambientales originales de 12 s, con acordes y pulsos suaves: fría, cálida, oscura y dorada.
- Cada ambiente se reproduce en bucle desde el autoload Campaign. Se conserva la música al cambiar entre pantallas y cambia según el sector. Continúa durante la pausa a volumen configurable.
- Se conservaron disparos del jugador y enemigos. Los efectos usan el bus Effects; los enemigos mantienen audio espacial con atenuación.
- Configuración permite ajustar música, efectos y sensibilidad, incluyendo silenciar cada grupo de audio.

## Responsabilidad de los scripts
- `start.gd`: páginas de menú, perfiles, tarjetas de niveles, tabla de scores, opciones y confirmación de reinicio.
- `campaign.gd`: catálogo de siete niveles y diez mejoras, reglas de desbloqueo, datos persistentes y audio general.
- `game.gd`: enemigos presentes, navegación, HUD, pausa, victoria/derrota, score, ventana de mejora y transición.
- `player.gd`: controles, cámara, disparo, recarga, salud/escudo, aplicación de mejoras y golpe corto con retroceso visual.
- `enemy.gd`: persecución, rutas, aviso de disparo, ataque, daño, muerte y aceleración del guardián.
- `upgrade_screen.gd`: rellena las tres tarjetas guardadas y valida/guarda la elección mediante Campaign.
- `kit.gd`: utilidades de geometría/materiales; se sigue usando para trazadoras temporales.

## Presentación en Godot
- F5 abre la selección de jugador. Para recuperar progreso usa el mismo nombre o selecciona un perfil.
- Abre cualquier escena de nivel para ver sus nodos 3D sin ejecutar. Abrir directamente un nivel sin perfil o bloqueado redirige a Inicio al ejecutarlo.
- Abre `scenes/ui/hud.tscn`, `upgrade_screen.tscn` o `upgrade_card.tscn` para mostrar y editar ventanas. Las páginas de Inicio están bajo `Margin/Stack`; activa temporalmente su visibilidad para maquetarlas.
- La copia anterior a esta integración está en `revision/respaldo/before-campaign.zip`; la carpeta está excluida de la importación de Godot.

## Verificación
- Godot instalado y usado: 4.7.2, renderizador Compatibility/OpenGL. No se ha ejecutado en 4.6.
- Todas las pruebas usan `-- --campaign-test` y un archivo separado en `.godot/campaign-tests.cfg`; no alteran perfiles reales. Ejecutarlas de forma secuencial.
- `tests/campaign/smoke.gd`: combate real por rayos, munición, recarga, daño, regeneración, pausa, navegación, bajas, victoria y derrota.
- `tests/campaign/levels.gd`: carga de los siete mapas, rutas de todos los enemigos, aumento de vida total, miniaturas, audio en bucle y guardián final.
- `tests/campaign/campaign.gd`: bloqueo, recorrido 1–7, elección única, perfiles separados, scores sin acumulación abusiva, reinicio conservando récords, escudo y fusil equilibrado.
- Ejecutar campaña y luego el mismo script con `--reload-only` comprueba el guardado en otro proceso, incluidos score, desbloqueo y mejora pendiente.
- Ejemplo: `Godot.exe --headless --path . --script res://tests/campaign/campaign.gd --quit-after 1200 -- --campaign-test`.
- Persistencia: `Godot.exe --headless --path . --script res://tests/campaign/campaign.gd --quit-after 600 -- --campaign-test --reload-only`.
- `tests/tools/campaign_gallery.gd` captura los siete escenarios con renderizador real y genera `assets/previews/levels/level_N.png`. `tests/tools/ui_gallery.gd` captura perfiles, menú, selector, tutorial, opciones, scores y mejoras. Los antiguos gallery/preview delegan en estos scripts.
- Se revisaron capturas para corregir oscuridad, paleta dorada y legibilidad de las ventanas. El entorno aislado muestra advertencias de certificados/configuración; el paquete original conserva avisos de mayúsculas en rutas de textura.

- Resultado final: smoke, campaña, persistencia en otro proceso y niveles pasan con cero fallos. En PowerShell, usa `| Out-String` al final de cada ejecución de Godot.exe si necesitas esperar su terminación antes de lanzar la siguiente prueba.

## Limpieza de archivos de revisión
- Se reunieron los registros `.log` en `revision/logs/` y las capturas `preview*.png` de la raíz, con sus metadatos, en `revision/capturas/`.
- Se trasladaron el respaldo y los mapas de referencia a `revision/respaldo/`, y la herramienta de migración a `revision/herramientas/`. Se conservan como material de revisión, fuera de las escenas del juego.
- `revision/.gdignore` evita que Godot importe las capturas, los respaldos y las herramientas archivadas. Los scripts de captura ahora escriben en esa carpeta.
- Se eliminaron las carpetas vacías `export_templates`, `feature_profiles`, `script_templates` y `text_editor_themes`.
- Se conservaron `assets/previews/` (miniaturas utilizadas por el selector), las texturas, el paquete original con su licencia, las pruebas y `.godot` (caché del editor).
- Para guardar futuros registros sin ensuciar la raíz, añadir `--log-file "C:/ruta/al/proyecto/revision/logs/nombre.log"` al comando de Godot.

## Último disparo y ventana de victoria
- Se separó el final del combate de la presentación del resultado. Al morir el último enemigo se bloquea el combate y se guarda el progreso inmediatamente, pero el árbol no se pausa todavía.
- Se espera al menos 0,4 s antes de abrir las mejoras o la victoria final. Si el sonido del disparo dura más, se espera el tiempo restante más 0,05 s.
- El destello, el retroceso, la trazadora y el indicador de impacto pueden terminar durante esa espera. No se permiten nuevos disparos, daño ni regeneración; tampoco se añade ese tiempo a la puntuación.
- La derrota sigue mostrando su menú inmediatamente. La señal `result_presented` permite verificar la presentación sin asumir que ocurre dentro del disparo.
- `tests/combat/final_shot.gd` comprueba un impacto final real, guardado inmediato, ausencia de pausa/ventana prematura, audio terminado y efectos visuales finalizados antes de las mejoras. Las pruebas de campaña y combate esperan ahora esa señal.

## Expansión jugable — 14 de octubre de 2026

### Armas y controles
- Se creó `scripts/combat/weapon_catalog.gd` con pistola (12/72), fusil (24/144) y escopeta (6/30); cada una conserva cargador y reserva. Los datos permiten ajustar daño, cadencia, alcance, dispersión y recarga por separado.
- Se modificó `scripts/player/player.gd`: dos espacios de armas, cambio con 1/2 o rueda y arsenal interactivo al inicio que alterna fusil/escopeta en el segundo espacio. La pistola permanece en el primero.
- R transfiere únicamente las balas disponibles de la reserva; cambiar de arma o usar el cuchillo cancela la recarga. Pistola/escopeta requieren un clic por disparo; el fusil permite mantener el botón. La escopeta dispara ocho perdigones con dispersión y caída de daño.
- F usa siempre un cuchillo sin munición: 65 de daño y 0,9 s entre ataques. La mejora anterior de cuerpo a cuerpo ahora aumenta su daño a 100 y reduce el intervalo a 0,65 s.
- G lanza una granada física con fusible de 1,6 s, radio de 6 m y comprobación de obstáculos. Se creó `scripts/combat/grenade.gd`; hay tres granadas iniciales y un máximo de cinco.
- Se añadieron geometría sencilla para cuchillo/segundo cañón, movimiento de recarga, retroceso y tono de disparo por arma. Son representaciones iniciales; no se incorporaron modelos externos de armas ni animaciones esqueléticas.

### Mapas, objetivos y suministros
- Se creó `scripts/missions/mission.gd`, instanciado por `game.gd` en cada sector. Las bajas siguen puntuando, pero ya no terminan automáticamente las misiones.
- Los siete escenarios existentes se amplían 1,5 veces en X/Z durante la carga, junto con actores y navegación (2,25 veces la superficie). Se conservan las distribuciones originales; esta ampliación inicial todavía no constituye una reconstrucción de los mapas en nuevos sectores o salas.
- Se creó `scripts/missions/mission_object.gd` para terminales, tarjeta, salida, nidos, arsenal y suministros. E requiere proximidad, apuntar al objeto y visión directa; los nidos reciben disparos y explosiones.
- Laboratorio: recuperar tarjeta y usar la salida. Almacén: recuperar dos suministros, activar defensa, superar cinco oleadas y usar el transporte. Reactor: activar tres terminales y llegar a evacuación antes de 90 s desde la última activación.
- Fundición: desactivar tres controles y salir; `scripts/missions/hazard.gd` añade dos zonas de daño cíclico que se apagan tras desactivar los controles. Biocontención: destruir tres nidos (140 PV), detener sus refuerzos y eliminar las amenazas antes de extraerse.
- Fortaleza: desactivar dos defensas y eliminar las amenazas, incluido el capitán. Núcleo Áureo: desactivar una fuente de energía en cada fase del guardián y eliminar las amenazas antes de usar la salida.
- Cada nivel tiene dos suministros consumibles; restauran reservas, 30 PV y una granada. Completar objetivos intermedios y preparar la siguiente oleada también entrega suministros.
- Se copiaron cinco modelos OBJ/MTL del paquete original a assets: Light_Wide, Cable_1, Vent_Small, Fan_Small y PipeHolder. Se limpiaron sus rutas de textura y se usan como decoración en los puntos de misión. No se modificó el paquete original.

### Oleadas y enemigos
- El Almacén genera cinco oleadas de 5, 7, 9, 11 y 13 enemigos; deja pausas de preparación, separa las apariciones por dos segundos y limita a ocho enemigos vivos. El último refuerzo tiene 300 PV. El modo supervivencia independiente queda pendiente.
- Los refuerzos aparecen en puntos transitables alejados del jugador. Si un enemigo queda inmóvil intentando avanzar durante diez segundos, se recoloca en una celda alcanzable cercana.
- `enemy.gd` asigna seis comportamientos por tipo: asaltante cercano, francotirador con aviso y retirada, tanque con protección frontal, kamikaze que detona cerca, soporte que cura e invocador que añade refuerzos en sectores avanzados.
- El guardián usa escudos entre fases, límites de daño al 66% y 33% de vida y una cadencia mayor en la fase final. Las fuentes siguientes no pueden desactivarse por adelantado.

### Checkpoints y opciones
- Los checkpoints por perfil guardan objetivos, enemigos restantes y estadísticas, posición/orientación, equipo, cargadores, reservas, granadas, suministros consumidos, oleada y tiempo del reactor. Se guardan al completar objetivos, recoger suministros y comenzar/preparar oleadas.
- La pausa distingue reiniciar toda la misión y reintentar desde el último checkpoint. Completar la misión o reiniciar campaña elimina su checkpoint. Los perfiles anteriores siguen funcionando; PostgreSQL no se implementó.
- Se creó `scripts/ui/game_options.gd`: FOV 65–105, tres dificultades, tres resoluciones, pantalla completa, reducción de movimiento/destellos, mira, calidad normal/rendimiento y reasignación de acciones del teclado sin duplicar teclas. ESC permanece reservado para pausa/cancelación y el disparo usa clic izquierdo.
- La dificultad ajusta el daño enemigo (0,7/1/1,3); todavía no cambia composiciones ni separa récords por dificultad. Rendimiento desactiva sombras de luces del escenario y niebla. Las preferencias y los controles se conservan en el archivo actual.
- Se actualizaron HUD, tutorial, descripciones de mejoras, indicaciones de objetivos y opciones de pausa. Se reorganizó la configuración en dos columnas con desplazamiento para evitar desbordamiento.

### Verificación de la expansión
- `tests/campaign/expansion.gd` comprueba los siete objetivos, bloqueo de salidas, acceso a objetivos/suministros, cinco oleadas reales, escudos del jefe, reservas finitas, cancelación de recarga, arsenal, cuchillo, granadas y restauración del checkpoint desde disco.
- Se actualizaron smoke, campaign y final_shot para la victoria por objetivos y las nuevas coordenadas. `tests/helpers/mission_driver.gd` recorre las transiciones sin depender de puntería humana.
- `tests/tools/expansion_gallery.gd` genera capturas de opciones y gameplay en revision/capturas para inspección visual. Validación ejecutada con el Godot instalado: 4.7.2.
- Pendientes de fases posteriores: reconstrucción de salas/rutas alternativas, plasma/precisión, mejoras específicas por arma, modo supervivencia independiente, logros y PostgreSQL. El equilibrio y la duración necesitan sesiones humanas de juego; las pruebas automáticas no establecen una duración de campaña.
- Resultado de verificación: expansión, smoke, niveles, campaña, persistencia en otro proceso y último disparo pasan con cero fallos. Se revisaron capturas con renderizador OpenGL real; se corrigieron el desbordamiento de opciones, el tamaño de rótulos y la posición del arma. El capitán de Fortaleza permanece protegido hasta desactivar ambos controles.

## Diez niveles, salas y progresión de armas — 14 de octubre de 2026

Esta revisión sustituye el arsenal libre y la ampliación por escala de los niveles 1 y 2 descritos en la entrega anterior.

### Salas y campaña
- Se reconstruyeron `scenes/main.tscn` y `scenes/levels/level_2.tscn` como escenas editables con cinco salas cada una, pasillos, puertas abiertas, coberturas, luces y señales de sector. El Laboratorio conecta recepción, investigación, archivo, mantenimiento y extracción. El Almacén conecta acceso, patio de defensa, dos salas de carga y embarque mediante rutas laterales adicionales.
- Los mapas nuevos usan los OBJ y las texturas del paquete SciFi; se añadieron paneles de respaldo para que la forma visual de las paredes coincida con sus colisiones. Las salas iniciales no contienen recogidas de munición ni suministros.
- Los objetivos, las cajas y las entradas de refuerzos se colocan con nodos `MissionPoints`. `game.gd` usa `map_scale = 1` y `room_layout = true` en los mapas de salas y excluye de la navegación las zonas sin suelo; los mapas anteriores conservan su escala.
- La campaña pasa a diez misiones: 7 Comunicaciones (tres enlaces y defensa de transmisión durante 45 s), 8 Hangar de evacuación (combustible y preparación de embarque durante 60 s), 9 Arsenal orbital (tres núcleos y eliminación de amenazas), 10 Núcleo Áureo (guardián por fases, ahora con 900 PV).
- Se crearon las escenas 8 y 9 con salas y recorridos; el antiguo escenario del jefe se trasladó al 10. El sector 7 conserva su geometría, transforma al antiguo jefe en capitán y recibe la misión de comunicaciones. Se actualizaron enlaces al siguiente nivel, nueve elecciones de mejora, menús, miniaturas reales y condición de final de campaña.
- Las mejoras que ya alcanzaron su máximo se sustituyen en la oferta por otras disponibles, evitando una recompensa final imposible de elegir.

### Señales y recogidas
- Se creó `scripts/missions/objective_beacons.gd`: paneles grandes con nombre, distancia y estado, visibles a través de paredes y fijados al borde de la pantalla cuando el objetivo queda fuera de vista. La salida se muestra bloqueada hasta cumplir sus requisitos. La tarjeta desaparece del indicador tras recogerla y la salida queda habilitada.
- Se aumentaron los rótulos del mundo y se añadieron anillos luminosos: dorado para objetivos, cian para munición. La tarjeta tiene una representación luminosa sobre un soporte del paquete. Los modelos recogidos y sus señales se ocultan.
- `mission.gd` muestra confirmaciones centrales durante 3,5 s, además de la indicación de objetivo. La tarjeta muestra TARJETA OBTENIDA / SALIDA HABILITADA. La munición muestra un recibo con las cantidades de las dos armas equipadas.
- Se generaron tres efectos originales WAV: `pickup_key.wav`, `pickup_ammo.wav` y `weapon_unlock.wav`. Se reproducen por el bus Effects y respetan el volumen configurado. Los suministros de misión del Almacén también usan el sonido de munición.

### Armas y equipamiento
- Pistola y fusil disponibles inicialmente. La escopeta se habilita al acceder al nivel 3, precisión al 6 y plasma al 9. Los desbloqueos se derivan del progreso del perfil y siguen disponibles al repetir misiones anteriores.
- Se eliminó el arsenal que permitía alternar libremente fusil y escopeta. `scripts/ui/loadout_screen.gd` permite elegir dos armas distintas antes de cada misión desde el primer desbloqueo. El juego permanece pausado hasta confirmar; la elección queda guardada por perfil. El cuchillo y las granadas siguen siendo parte fija del equipo.
- Los checkpoints restauran directamente el equipo guardado, sin volver a elegir ni rellenar cargadores. `PlayerController.set_loadout` y `equip` rechazan armas bloqueadas, espacios duplicados o armas ajenas al equipo.
- Precisión: 150 de daño base, cargador de 5, intervalo 1,15 s y alcance de 100 m; clic derecho reduce el FOV para apuntar. Plasma: 65 de daño base, cargador de 10, intervalo 0,45 s y daño secundario decreciente hasta 3 m, comprobando paredes. Se añadieron mira y bobina como geometría visual sencilla.
- Se ajustó la mejora de daño: +1 por perdigón de escopeta, +8 para precisión y +4 para las demás armas. La ampliación de cargador suma +1 para escopeta/precisión, +2 para plasma y +4 para pistola/fusil.

### Munición y guardado
- Reserva inicial base / límite / recogida: pistola 48/96/+24; fusil 96/192/+48; escopeta 18/36/+12; precisión 20/35/+10; plasma 30/60/+15. Se añade un cargador inicial de reserva por cada tres niveles avanzados, sin superar el límite.
- Cada caja abastece exclusivamente las dos armas equipadas. Las reservas de armas no equipadas no crecen. Recargar transfiere balas desde la reserva; cambiar de arma conserva ambos contadores y nunca rellena cargadores.
- Se eliminaron los reabastecimientos automáticos de todos los objetivos. Permanecen las cajas finitas del mapa, los suministros de misión del Almacén y el reabastecimiento entre oleadas. Se mantienen +30 PV y una granada por suministro, con máximo de cinco granadas.
- El nivel 1 tiene tres cajas repartidas entre archivo, mantenimiento y extracción; el 2 tiene cajas en salas de carga y embarque, fuera del acceso inicial. El cuchillo permite continuar si se agotan las reservas.
- El archivo pasa a versión 3. Se conservan perfiles, mejoras, récords y niveles completados de versiones anteriores; se descartan sus checkpoints incompatibles con las nuevas salas. La selección de equipo y los anuncios de desbloqueo se guardan en el mismo perfil. PostgreSQL continúa pendiente.

### Herramientas y verificación
- `revision/herramientas/build_rooms.py` genera las escenas editables y los efectos WAV; los scripts extend_campaign/update_missions/update_room_tests registran la migración realizada. Los escenarios anteriores se conservaron en `revision/respaldo/before-ten-levels`.
- Se actualizaron las pruebas de campaña, niveles, expansión y último disparo para diez misiones, nuevas posiciones y selección de equipo. `tests/campaign/rooms_progression.gd` prueba rutas entre salas, ausencia de suministros iniciales, desbloqueos 3/6/9, selección, sonidos de recogida, límites, duplicados, checkpoints y disparos reales de escopeta, precisión y plasma.
- `tests/tools/rooms_gallery.gd` captura señales, recogidas, equipo y selector. Se revisaron capturas con renderizado OpenGL real y se corrigieron paredes incompletas, materiales, tamaño de marcadores y reservas mostradas en la selección.
- La revisión usa el Godot instalado (4.7.2). El balance tiene límites y cantidades verificadas, pero su ajuste final de dificultad requiere partidas humanas con distintas combinaciones de armas.
- Resultado final: GDScript e importación sin errores; rooms_progression, smoke, levels, expansion, final_shot, campaign y persistencia en otro proceso pasan con cero fallos. Se generaron y revisaron capturas y miniaturas de las diez misiones.

## Indicadores discretos de tarjeta y salida
- Se redujeron los paneles de tarjeta y salida a fuente de 16 px, márgenes pequeños, borde fino y fondo más transparente. Conservan nombre, distancia y estado de bloqueo en una sola línea.
- También se redujeron sus rótulos 3D y anillos luminosos para evitar que tapen la vista. Los indicadores de munición conservan su tamaño.

## Estación cerrada, descubrimiento de armas y tutorial opcional

### Espacios e iluminación
- Los niveles 1, 2, 8 y 9 comparten luz ambiental fría de intensidad 0,44 y luces locales de intensidad 0,7, inferiores a la versión anterior. Reactor (3) y Fortaleza (6) conservan su entorno, colores e intensidad ambiental originales.
- Se añadieron techos visibles con colisión a los diez sectores y al entrenamiento. Los escenarios antiguos también tienen remates superiores de pared para cerrar el espacio hasta el techo. La navegación ignora colisiones por encima de la altura transitable para que el techo no bloquee las rutas.
- Las paredes de los mapas de salas usan paneles metálicos sólidos, con el acabado de los sectores 4/5. Se conservan los modelos, suelos y objetos del paquete SciFi.
- Se rediseñó Reactor como circuito entre regulación, refrigeración, cámara central, armería y evacuación. Fortaleza tiene un bastión central con galerías laterales, defensas y puesto de precisión.
- Hangar (8) tiene una cubierta de vuelo longitudinal con depósitos desplazados y pasarela de embarque. Arsenal (9) tiene un recorrido en U entre almacenes, laboratorio de plasma y salida. Ya no reutilizan los planos de los niveles 1/2.
- `revision/herramientas/build_station_revision.py` genera los mapas cerrados; `close_legacy_walls.py` añade los remates de arenas antiguas y `tune_station_lighting.py` registra el ajuste de orientación e iluminación. Se conservaron los escenarios previos en `revision/respaldo/before-enclosed-station`.

### Armas encontradas durante la misión
- Se eliminó el desbloqueo automático por alcanzar un nivel. La escopeta está en la armería del Reactor (3), precisión en el puesto de Fortaleza (6), y plasma en su laboratorio del Arsenal orbital (9). Cada arma tiene modelo sobre soporte, señal y recogida con E.
- Recogerla la equipa inmediatamente en el segundo espacio y guarda el hallazgo en el checkpoint. El jugador debe completar ese sector para añadirla al arsenal permanente del perfil. Si no la recoge, puede repetir el nivel más adelante.
- La selección de equipo no aparece antes del primer hallazgo ni interrumpe la primera visita a una misión de descubrimiento. Después de completar ese nivel con el arma recogida, la ventana aparece en misiones posteriores y solo ofrece las armas aseguradas.
- `PlayerController.discover_weapon`, `mission.gd` y `Campaign.complete_level` separan el arma de la partida de los desbloqueos permanentes. Reintentar restaura equipo y munición del checkpoint; abandonar una misión no concede automáticamente su arma.
- El guardado pasa a versión 4. Conserva progreso, récords y mejoras; elimina checkpoints incompatibles con los mapas nuevos y sustituye los antiguos desbloqueos automáticos por armas que deben encontrarse. PostgreSQL sigue pendiente.

### Reservas y oleadas
- Se redujeron las reservas iniciales / máximas / recogida: pistola 24/48/+12; fusil 48/96/+24; escopeta 8/18/+6; precisión 8/15/+5; plasma 12/30/+8.
- Se eliminó el cargador adicional de reserva por tramo de campaña. Especialista en fusil ahora añade 12 balas iniciales, respetando el máximo. Los suministros siguen abasteciendo únicamente las dos armas equipadas y no regeneran cargadores.
- Los refuerzos se eligen aleatoriamente entre celdas transitables distribuidas por el mapa, en lugar de utilizar siempre el portal más lejano. Se comprueba la ruta, una distancia mínima de 12 m al jugador, separación de enemigos/objetos y distancia respecto a la aparición anterior. El límite de enemigos vivos y los tiempos entre refuerzos permanecen.

### Interfaz y entrenamiento
- La misión se muestra en un panel compacto arriba a la derecha; vida y munición se distribuyen en dos líneas a la izquierda. Se retiró la franja de controles inferior y se recolocó el aviso de regeneración.
- Todos los marcadores de objetivos y suministros usan ahora el formato compacto de 14 px. También se redujeron rótulos 3D, anillos, tarjeta física, tarjetas del selector (cuatro por fila), mejoras y ventana de equipamiento.
- Se creó `scenes/tutorial.tscn`, un circuito opcional accesible desde Entrenamiento opcional en el inicio. Sustituye la antigua página estática TutorialPage.
- El circuito enseña movimiento y orientación, correr/saltar, disparo a un blanco, recarga real, cuchillo a corta distancia, granada, recogida de munición y cambio de arma. Las instrucciones muestran las teclas configuradas. Se puede salir desde la pausa.
- El tutorial no concede puntuación de campaña ni modifica sus niveles, mejoras, armas o checkpoint. Completarlo guarda únicamente la marca de entrenamiento completado.

### Verificación
- `tests/world/station_revision.gd` verifica techos físicos, iluminación común, navegación, interfaz, reservas reducidas, variedad de apariciones, recogida de armas por raycast, restauración desde disco, desbloqueo tras completar la misión y tutorial sin alterar la campaña. `rooms_progression.gd` pasa a ejecutar esta revisión.
- Se actualizaron los recorridos de campaña y sus herramientas de captura para recoger armas dentro de los sectores. `tests/tools/station_gallery.gd` genera vistas interiores, planos sin techo solo para miniaturas, la recogida de escopeta, el entrenamiento, el selector y el equipo.
- Se inspeccionaron capturas reales con OpenGL; los techos permanecen visibles durante el gameplay. Las miniaturas se regeneran desde los escenarios nuevos. El ajuste fino de dificultad sigue requiriendo partidas humanas.
- Resultado final: GDScript sin errores y pruebas de estación/tutorial, smoke, niveles, expansión, último disparo, campaña y persistencia en otro proceso con cero fallos. Se revisaron las nuevas miniaturas y las tarjetas compactas; también se corrigieron acentos y símbolos en la pantalla de mejoras.


## Misiones iniciales, enemigos y presentación (octubre 2026)

### Misiones de los sectores 1–3
- Se añadió `scripts/missions/early_missions.gd`, con objetivos por etapas, señalización del objetivo activo, indicadores físicos de completado y encuentros que deben asegurarse para avanzar.
- Laboratorio (1): restablecer energía en mantenimiento, anular seguridad, recuperar tarjeta, activar baliza y superar la emboscada de extracción. La energía desactiva las descargas de mantenimiento.
- Almacén (2): recuperar y transportar cada carga de un ala al muelle; llevar carga reduce movimiento al 80 %, permite combatir y se restaura en el checkpoint. Entregarla abastece munición. Después se prepara generador/autorización y se resisten cinco oleadas con combinaciones de roles.
- Reactor (3): recuperar dos fusibles, reparar refrigeración, regular presión, estabilizar reactor e iniciar purga. La reparación desactiva las descargas. La purga da 120 segundos para evacuar y cierra la compuerta de la galería este, actualizando colisión y navegación; la galería oeste permanece transitable. La armería con escopeta sigue siendo un desvío opcional.
- Los siete criterios de ampliación se concretan en cadenas de objetivos con efectos visibles, encuentros por zonas, combates obligatorios en fases concretas, galerías alternativas, peligros cíclicos anunciados, reservas opcionales en desvíos y checkpoints por etapa.
- `hazard.gd` anuncia la descarga antes de activarse. Hay reservas ocultas con munición/granadas/curación según el abastecimiento existente; su marcador solo aparece a menos de 5 m.
- Los checkpoints guardan etapa, carga, escudo, alerta y encuentro de cada enemigo sin duplicar defensores ni multiplicar otra vez sus estadísticas. Solo se descartan checkpoints anteriores incompatibles de los tres sectores modificados; se conserva la campaña.

### Enemigos y dificultad
- Se añadieron las escenas `enemy_13.tscn`, `enemy_14.tscn` y `enemy_15.tscn`, reutilizando modelos del kit: Escudero con escudo frontal visible de 70 puntos sin regeneración, Corredor con ráfaga de tres tiros y Bastión que reduce 35 % el daño a aliados a menos de 7 m. Flanquear ignora el escudo; destruir el Bastión elimina su protección.
- Los enemigos de los primeros tres sectores patrullan cerca de su origen hasta detectar al jugador por visión/proximidad o recibir daño. Los refuerzos de oleadas entran alertados. Se conservan los roles anteriores de blindaje, francotirador, kamikaze, sanador e invocador.
- Todos los intervalos base de ataque se reducen al 78 % de los anteriores. `enemy_catalog.gd` centraliza el índice y los multiplicadores de dificultad: Accesible daño/frecuencia/movimiento 70/85/85 %, Normal 100/100/100 %, Difícil 130/125/120 %. La frecuencia divide el intervalo entre ataques; la elección se aplica al iniciar/reiniciar misión y se explica en configuración.
- El menú incluye un índice de 16 enemigos con nombre, función, comportamiento, color y táctica de respuesta.

### Iluminación y menú
- Almacén (2) cambia a ambiente ámbar industrial moderado (.40). Hangar (8) usa cian (.38), depósitos ámbar y embarque verde. Arsenal (9) usa violeta (.39), plasma turquesa y núcleos coral. Se conserva la geometría y los techos.
- `menu_presentation.gd` rediseña el inicio con botones cian/ámbar, presentación de la estación e imagen real del reactor sin HUD. `start.gd` integra el índice de enemigos y la pista de menú.
- Se generó `assets/audio/menu_tension.wav`, composición sintetizada original de 32 segundos con pulso, percusión y capas de tensión, en bucle y respetando el volumen existente. Herramienta reproducible: `revision/herramientas/build_menu_music.py`.
- `tests/tools/menu_revision_gallery.gd` verifica y captura menú/índice con perfil aislado; las imágenes quedan en `revision/capturas/menu-revision-*.png`.

### Verificación de esta revisión
- `tests/campaign/early_campaign.gd` comprueba orden y combate obligatorio, transporte, restauración en disco sin duplicados, cierre de compuerta con ruta alternativa, finalización de sectores, escalado de las tres estadísticas, absorción frontal/flanqueo y protección de Bastión.
- Se actualizó el recorrido de misiones y las expectativas antiguas de cantidad de enemigos/iluminación en smoke, expansión y estación para cubrir el comportamiento nuevo.
- Resultado: importación/editor sin errores GDScript; early_campaign, smoke, levels, expansion, station_revision, final_shot, campaign y persistencia en proceso separado con cero fallos. Galerías de estación y menú correctas; se inspeccionaron capturas y se regeneraron las miniaturas con las nuevas luces. El ajuste de tiempos y dificultad requiere partidas humanas.


## Campaña completa, inteligencia y menús dinámicos

### Sectores rediseñados
- Se sustituyeron las arenas antiguas de 4, 5, 7 y 10 por mapas editables con habitaciones conectadas, rutas laterales, coberturas, techos y salas identificadas. Se conservan sus Environment originales, energía ambiental .8, materiales de suelo/pared y paletas industriales, biológicas y áureas. Las luces locales se adaptan a las salas sin elevar la luz ambiental.
- Fundición (4): recorrido de hornos, refrigeración, prensa, pasarela y montacargas. Biocontención (5): cuarentena, laboratorios laterales, incubadora central y purga. Comunicaciones (7): enlaces laterales, generadores, repetidor y transmisor. Núcleo Áureo (10): umbral, aislamiento, fuentes laterales, cámara central del Guardián y ascensor.
- Autoría reproducible: `revision/herramientas/build_late_rooms.py`, que solo reconstruye esos cuatro sectores y conserva sus ambientes desde `revision/respaldo/before-late-campaign`.

### Misiones del 4 al 10
- `scripts/missions/late_missions.gd` añade etapas, objetivo activo, señal de completado, encuentros obligatorios, reservas opcionales y checkpoints para los siete sectores. Los niveles 1–3 conservan su controlador de etapas existente.
- 4: fusible, bomba de refrigeración, tres controles industriales, apertura del montacargas y salida. El control del horno abre un atajo térmico; la galería oeste siempre permite continuar. El último control apaga los peligros.
- 5: muestra, sellado de cuarentena, tres nidos destructibles, purga de 30 segundos y extracción. Los nidos generan refuerzos mientras no se destruyan; durante la purga hay otra defensa. Los objetivos protegidos anuncian que primero hay que asegurar el sector.
- 6: reconocimiento, dos defensas, llave de mando, capitán y acceso al núcleo. Solo desactivar ambas defensas elimina el escudo del capitán. El arma de precisión sigue encontrándose en su puesto opcional.
- 7: tres enlaces, generador, transmisión, defensa de 45 segundos, confirmación y extracción. 8: transportar dos cargas de combustible al hangar (movimiento al 80 %), autorización, carga y defensa de 60 segundos antes de embarcar.
- 9: tres núcleos, sincronización de plasma, sellado y salida del arsenal. La recogida del plasma sigue siendo opcional y requiere completar el nivel para conservarlo.
- 10: autorización, aislamiento, tres fuentes ligadas a las fases 66/33 % del jefe, descarga final y salida. El Guardián conserva 900 PV, limita su persecución a la cámara y acelera en la última fase. Los refuerzos/defensores y el jefe deben quedar eliminados para salir.
- Se extendieron los peligros cíclicos con aviso y desactivación por objetivo a los sectores restantes. El abastecimiento de ciertas etapas y las reservas laterales ayudan a sostener las misiones ampliadas sin generar munición infinita.
- Los checkpoints de 4–10 usan mission_version 3 y guardan etapas, carga, defensores, escudos, estadísticas escaladas y furia del jefe sin repetir refuerzos ni multiplicadores al reintentar. Solo se descartan checkpoints anteriores incompatibles de esos niveles; se conservan progreso, mejoras y armas permanentes.

### Subtipos y descubrimiento
- Los 16 subtipos del índice tienen apariciones reales: los antiguos Vigía, Guardián, Cazador, Espectro, Coloso y Núcleo ya se distribuyen en los sectores rediseñados y sus encuentros. No fue necesario añadir más subtipos.
- `enemy_catalog.gd` añade TUNING por subtipo para daño, movimiento y frecuencia de ataque. Los corredores/cazadores presionan con velocidad; los tanques y pesados conservan menor movilidad y mayor daño; soportes y francotiradores mantienen funciones distintas.
- El sector aumenta gradualmente daño (+4.5 % por nivel posterior al primero), objetivo de movimiento (+1.8 %) y frecuencia (+3 %), además de los multiplicadores de dificultad existentes. Se mezcla velocidad de escena/subtipo para respetar la identidad; velocidad base final limitada a 4.6 m/s e intervalo mínimo .48 s, con ráfagas particulares. Los avisos de francotiradores conservan al menos .7 s.
- Los enemigos de todos los niveles patrullan antes de detectar al jugador; los refuerzos llegan alertados. Se añadieron detalles visuales de rol usando piezas del kit: blindaje, lentes, depósitos, cruces de soporte y antenas.
- `Campaign.discover_enemy` registra un subtipo al verlo en el campo visual, a menos de 28 m y con línea de visión, o al dañarlo. La colección es propia de cada perfil, persiste en disco y se conserva al reiniciar la campaña. Los perfiles antiguos empiezan a registrar observaciones desde esta revisión.

### Menús, imágenes y música
- El inicio rota tres capturas reales cada siete segundos, con fundido respetando la opción de movimiento reducido. Se rediseñaron perfiles de jugadores, selector, índice, opciones y presentación compartida; cian, ámbar, violeta y verde aparecen como acentos moderados. Mejoras y pausa recibieron estilos acordes.
- El índice tiene 16 vistas renderizadas desde las escenas reales de enemigos. Los descubiertos muestran nombre, rol y táctica; los demás muestran imagen atenuada y NO DESCUBIERTO. Cambiar de jugador actualiza el estado.
- Se corrigió el audio del inicio con un AudioStreamPlayer MenuMusic propio de la escena, bucle explícito de 32 segundos, volumen configurado y composición original con medios audibles. Al cambiar a gameplay se libera el reproductor del menú. No se fuerza sonido si el usuario tiene el volumen a cero.
- Las imágenes están en `assets/previews/menu`, `levels`, `enemies` y `weapons`, con referencias activas y herramientas actualizadas. Generadores: `tests/tools/build_menu_previews.gd`, `tests/tools/weapon_previews.gd` y `tests/tools/station_gallery.gd`; migrador: `revision/herramientas/organize_previews.py`.
- `loadout_screen.gd` usa dos tarjetas con vistas previas de armas reales, colores por arma, ranura activa y estadísticas. Los selectores deshabilitan recíprocamente el arma ocupada y la confirmación también rechaza duplicados. Conserva los desbloqueos y la validación de PlayerController.

### Verificación
- `tests/campaign/late_campaign.gd` comprueba los diez controladores, rutas, mapas y techos nuevos, luz original, orden de etapas, combate obligatorio, restauración sin duplicados/reescalado, fases y furia del jefe, presencia real de los 16 subtipos, descubrimientos aislados por perfil y escalado por nivel/dificultad.
- `tests/ui/loadout_visual.gd` verifica bloqueo de armas duplicadas, actualización de ranuras y selección válida con un perfil simulado. `tests/tools/menu_revision_gallery.gd` usa guardado privado y comprueba imágenes, descubrimientos, cambio de diapositiva, controles, señal de audio real, bucle, silencio/reanudación y ajuste de pausa.
- La galería de estación ahora tiene archivo privado de visualización para no competir con las partidas de las pruebas; genera las miniaturas de los diez mapas y capturas interiores con sus techos visibles.
- Resultado final: importación/editor sin errores GDScript; early_campaign, late_campaign, smoke, levels, expansion, station_revision, final_shot, campaign, persistencia en otro proceso y equipación con cero fallos. MENU REVISION PASS y STATION GALLERY PASS; se inspeccionaron las capturas de perfiles, índice, equipación y mapas rediseñados. Permanecen advertencias previas de mayúsculas Textures/textures del paquete original; no afectan la ejecución comprobada en Windows. El ajuste fino de dificultad y duración requiere partidas humanas.


## Superficies, sectores bloqueados y nuevas amenazas

### Texturas del kit
- Se añadió `scripts/visuals/station_surfaces.gd` y se aplica al iniciar cada mapa, incluido el entrenamiento. Paredes, suelo y techo usan los atlas originales Trim_02/01/03, sus normales y mapas ORM del Modular SciFi MegaKit.
- El mapeado triplanar en coordenadas de mundo mantiene el tamaño del patrón entre salas; se usan materiales compartidos por categoría, mipmaps y metal/rugosidad moderados. Se conservan las luces de cada sector. Las capturas y miniaturas se regeneraron con las superficies nuevas.

### Puertas y sala del jefe
- `scripts/missions/sector_doors.gd` crea compuertas físicas en todos los accesos transitables a las salas seleccionadas. La lógica identifica los cruces en el perímetro de cada sala y cierra también entradas alternativas; no depende de un único pasillo.
- Cada nivel tiene dos o tres grupos de acceso importantes (Biocontención incluye cuarentena/purga/extracción): archivo y extracción, carga este y embarque, reactor y evacuación, control térmico y montacargas, incubadora y purga, puesto de precisión y mando, enlaces/transmisor/extracción, depósitos y embarque, núcleos/depósito/salida orbital, y cámara del Guardián.
- Las salas se abren al completar sus objetivos previos; embarque y extracción de defensa esperan además el final de oleadas, carga o purga. Las puertas anuncian el requisito a corta distancia, muestran luz de bloqueo y añaden sonido y aviso al desbloquearse. Las rutas de exploración iniciales siguen disponibles.
- Abrir/cerrar actualiza la colisión y AStarGrid2D; se conserva una base de navegación para combinar puertas sin abrir paredes ni sobrescribir otros bloqueos. Las puertas ya abiertas no vuelven a cerrarse salvo el evento de combate final.
- En el nivel 10, completar autorización y aislamiento permite entrar en la cámara. Cruzar su interior sella todos los accesos, guarda checkpoint y anuncia el combate. Las tres fuentes de energía se trasladaron dentro de la sala para poder completar las fases sin salir. Derrotar al jefe abre todos los accesos.
- Los checkpoints de misión pasan a versión 4, guardando el sellado de la arena y las habilidades en curso. Los checkpoints antiguos incompatibles se descartan al entrar; se conserva la campaña, mejoras, récords y armas permanentes.

### Dieciocho subtipos y progresión
- Se añadieron `enemy_16.tscn` (Reanimado) y `enemy_17.tscn` (Intermitente), reutilizando modelos y piezas del kit. Ambos tienen miniatura y entrada del índice con descubrimiento por perfil.
- Reanimado aparece desde el nivel 5: su primera caída inicia una reanimación de cuatro segundos. El núcleo expuesto admite 45 puntos de daño para impedirla; si termina, recupera 60 % de vida y solo puede hacerlo una vez. Una caída pendiente sigue contando como amenaza y no concede una baja hasta la muerte definitiva. El aviso mantiene su tamaño legible al caer el cuerpo.
- Intermitente aparece desde el nivel 7: tras un aviso de .8 s desaparece durante 1.8 s, sin atacar ni recibir daño. Reaparece en una posición cercana, alejada al menos 5 m del jugador y conectada mediante navegación real; no atraviesa compuertas bloqueadas. Da un segundo de reacción antes de volver a disparar.
- Los estados de reanimación, núcleo, resurrección consumida, escala, desfase y siguiente desaparición se guardan/restauran junto con escudo y furia. Las granadas y armas respetan la intangibilidad; los checkpoints no repiten mejoras de estadísticas.
- Los francotiradores buscan 24 m de separación, retroceden bajo 18 m siguiendo rutas transitables, alcanzan 38 m y hacen 45 % más daño sobre su ajuste anterior. Conservan aviso de disparo.
- Centinelas ganan 60 % de vida, Guardianes 85 %, Colosos 40 % y Escuderos/Bastiones 15 %. Los tanques y escudos giran más despacio para permitir flanqueos.
- Los sanadores alcanzan aliados visibles a 12 m y curan 28 + 2 por nivel; su intervalo base baja a 2.8 s y se ajusta por presión/dificultad. Bastión protege a 9 m con línea de visión. Los invocadores piden grupos variados con mayor frecuencia y solo cuando tienen una ruta al jugador, evitando invocaciones desde salas cerradas.
- `enemy_catalog.gd` incluye MIN_LEVEL; los grupos dinámicos lo respetan. `revision/herramientas/progressive_enemy_rosters.py` distribuye los 18 tipos en escenas: asalto/francotirador en 1; tanques/kamikazes en 2; sanadores/depredadores/escudos en 3; invocadores/vigías/corredores en 4; pesados/cazadores/reanimados en 5; soporte avanzado en 6; colosos/desfase en 7; Núcleo en 8 y combinaciones completas en 9–10.

### Música por nivel
- Se añadieron diez composiciones originales sintetizadas en `assets/audio/levels/`, una por sector, de 32 s estéreo a 22.05 kHz y en bucle. Laboratorio: drones clínicos; Almacén: pulso logístico; Reactor: alarmas; Fundición: percusión metálica; Biocontención: ambiente orgánico; Fortaleza: ritmo marcial; Comunicaciones: radio; Hangar: graves espaciales; Arsenal: electrónica; Núcleo: tensión oscura.
- `Campaign.play_music` selecciona la pista y configura todo su bucle; mantiene volumen/silencio del usuario y la independencia del reproductor del menú. No se usaron muestras descargadas. Generador reproducible: `revision/herramientas/build_level_music.py`.

### Verificación
- `tests/campaign/sector_systems.gd` recorre físicamente el orden de los diez sectores, verifica ruta al objetivo activo en cada etapa y raycast de colisión de puertas, superficies PBR, introducción por nivel, los 18 tipos, sellado/restauración/apertura de la cámara, reanimación/destrucción de núcleo/desfase y mejoras de tanque, sanador y francotirador.
- `tests/helpers/navigation_checks.gd` separa conectividad geométrica de bloqueos intencionados al actualizar las regresiones anteriores. El recorrido de pruebas resuelve también núcleos y desfases; estas ayudas solo existen en pruebas.
- `tests/audio/level_music.gd` verifica diez recursos distintos, duración, estéreo, reproducción, bucle y volumen/silencio sin escribir partidas reales. Las galerías regeneran las 18 imágenes del índice, escenas del menú y miniaturas de los diez mapas.
- Resultado final: editor/importación sin errores GDScript; sector_systems, early_campaign, smoke, levels, expansion, station_revision, late_campaign, final_shot, campaña y persistencia con cero fallos. Índice/menú con 18 miniaturas, galería de estación y diez pistas de audio verificados; capturas de superficies inspeccionadas. El ajuste de dificultad durante partidas humanas sigue siendo la referencia para futuros retoques de balance.

## Decoración, materiales de combate, sonidos y gestión de perfiles

### Objetos y visibilidad
- `scripts/visuals/station_details.gd` añade decoración temática del kit a los diez niveles y al tutorial: cajas, columnas, barriles, consolas, ventilación y cables. La colocación es determinista, moderada y reserva espacio alrededor de objetivos, suministros, armas, entradas y posiciones iniciales. Cada obstáculo se rechaza si corta una ruta previamente disponible; después se reconstruye la navegación.
- `scripts/visuals/surface_visibility.gd` audita bordes abiertos de las mallas del kit, uniendo posiciones separadas por costuras UV. `Kit.model` y la revisión del escenario aplican materiales de dos caras únicamente a objetos abiertos afectados; los sólidos cerrados mantienen su culling. Los materiales se duplican para conservar texturas y evitar cambiar recursos compartidos. No se modifican los archivos originales del paquete.

### Enemigos y armas
- `assets/shaders/alien_skin.gdshader` añade poros, pliegues y microrelieve mediante material procedural. Los 18 subtipos conservan sus mallas originales, forma, tamaño y color del catálogo; los accesorios reciben metal texturizado del kit.
- `scripts/visuals/combat_visuals.gd` centraliza los modelos visuales de pistola, fusil, escopeta, precisión, plasma y cuchillo: metal y polímero con normales, cañones cilíndricos cerrados, raíles, tornillos, empuñaduras y detalles luminosos propios. Primera persona, armas encontradas y miniaturas utilizan el mismo modelo. Una luz suave exclusiva de la capa del arma permite ver el metal sin iluminar las salas.
- El rediseño conserva daño, munición, cadencia, desbloqueos, colisiones e interacciones existentes. Los materiales de accesorios abiertos mantienen la corrección de reversos.

### Audio de armas
- Se crearon siete efectos originales en `assets/audio/weapons/`: disparos distintos para las cinco armas y movimiento/impacto del cuchillo. Combinan transitorios mecánicos, graves, resonancia y componentes electrónicos; no usan muestras descargadas.
- `player.gd` selecciona el archivo propio de cada arma y lo reproduce a su tono original en el canal Effects. El cuchillo tiene reproductor independiente. Generador reproducible: `revision/herramientas/build_weapon_audio.py`.

### Perfiles e índices
- El menú de operadores permite eliminar el perfil guardado seleccionado mediante confirmación con su nombre y Cancelar preseleccionado. Borrar uno inactivo conserva la selección actual; borrar el activo obliga a escoger perfil y borrar el último deja el estado vacío.
- `Campaign.delete_profile` revierte la operación si falla la escritura y actualiza el respaldo después de un borrado correcto, evitando recuperar por accidente el perfil eliminado. Se eliminan también sus datos de campaña, arsenal, descubrimientos y récords.
- `scripts/ui/weapon_index.gd` añade un arsenal con las cinco armas y el cuchillo, miniaturas, función y estadísticas base. Lee los desbloqueos permanentes de cada perfil; las armas pendientes aparecen atenuadas e indican su nivel de adquisición. El cuchillo figura como permanente.
- Se regeneraron las 18 imágenes de enemigos, las seis de armas, las escenas del menú y las diez vistas de niveles. Las carpetas `assets/previews/enemies`, `weapons`, `menu` y `levels` permanecen separadas.

### Verificación de esta revisión
- `tests/combat/combat_redesign.gd` comprueba los diez niveles: cantidad moderada de obstáculos, rutas a objetivos/suministros/armas, mallas originales y colores de enemigos, selección de cinco modelos y sonidos propios, y cuchillo independiente.
- `tests/world/surface_visibility.gd` audita veinte mallas, verifica aislamiento de materiales y mantiene el culling de sólidos. La comparación gráfica comprueba visibilidad por detrás de superficies abiertas.
- `tests/audio/weapon_audio.gd` verifica los siete efectos, duración, reproducción, mezcla, canal Effects y silencio. `tests/persistence/profile_management.gd` comprueba confirmación/cancelación, borrado activo/inactivo/último, persistencia, respaldo y fallo de escritura con archivos aislados.
- Las galerías de armas, enemigos, menú y estación se regeneraron y revisaron visualmente. Las comprobaciones usan perfiles de prueba, no partidas del usuario.
- Resultado: importación/editor sin errores GDScript; sector_systems, combat_redesign, early_campaign, smoke, levels, expansion, station_revision, late_campaign, final_shot, campaña y recarga de campaña pasan con cero fallos. También pasan audio, reversos, gestión de perfiles, equipación y las galerías de menú/armas/enemigos/estación.

## Sonidos de recarga
- Se añadieron cinco efectos originales `assets/audio/weapons/*_reload.wav`, uno por arma: mecanismos y cargadores para pistola/fusil/precisión, inserciones para escopeta y celda con carga electrónica para plasma. Generador reproducible sin muestras externas: `revision/herramientas/build_reload_audio.py`.
- `player.gd` reproduce la recarga en un canal independiente del disparo, dentro de Effects y respetando su volumen/silencio. La velocidad del audio se ajusta a la duración con mejoras; cambiar de arma, usar cuchillo o finalizar la partida lo detiene. No suena con cargador lleno, sin reserva, durante pausa ni al repetir una recarga en curso.
- Se amplió `tests/combat/combat_redesign.gd` para comprobar sonidos por arma, sincronización, canal de efectos, cancelación y condiciones que no deben reproducir audio.

## Reactor, suministros, combate y equipo táctico

### Accesos y cajas iniciales
- La compuerta de emergencia de la purga del nivel 3 se trasladó del cruce en T al tramo recto del pasillo este, en (17, 0, -2). Su colisión cubre el ancho real del paso y la navegación bloquea el mismo corte; se conserva la galería oeste para evacuar.
- Se añadieron cajas SUMINISTROS DE ACCESO a 3–7 metros del inicio en los niveles 3 y 5, accesibles antes de abrir sectores. Se conservan los identificadores históricos de las cajas y la persistencia de suministros ya recogidos.

### Enemigos
- Acechador y Vigía disparan a cualquier distancia dentro de su alcance, con aviso y línea de visión. El daño crece gradualmente desde aproximadamente 60 % del daño del francotirador a quemarropa hasta 125 % a 38 m; mantienen la retirada táctica.
- Los sanadores actúan cada 2,1 s de base en lugar de 2,8 s; nivel y dificultad siguen ajustando ese intervalo. Los aliados que efectivamente recuperan vida muestran tres anillos verdes ascendentes durante 0,75 s. No se muestra curación sobre aliados con vida completa.
- Comandante y Coloso liberan dos refuerzos al morir, una sola vez: Comandante elige Explorador/Asaltante/Depredador y Coloso Guardián/Corredor/Bastión. Usan los puntos válidos de generación y cuentan para los objetivos de eliminación.
- La dificultad también multiplica la vida máxima enemiga: Fácil ×0,85, Normal ×1 y Difícil ×1,25, además de las diferencias de cada subtipo. Incluye jefes; la restauración de checkpoints conserva vida máxima/actual sin multiplicarlas de nuevo.

### Granadas y audio
- `scripts/combat/grenade_catalog.gd` define Básica desde el nivel 1 (160 de daño máximo, radio 6 m, tres iniciales), Fragmentación recogible en el nivel 2 (220, 7 m, dos iniciales) y Estasis recogible en el nivel 5 (45, 7,5 m, dos iniciales). El daño disminuye con la distancia. Estasis reduce el movimiento al 45 % durante cinco segundos; no afecta a enemigos intangibles o muertos ni atraviesa paredes.
- G lanza la granada seleccionada y Q alterna los tipos disponibles; ambas acciones son configurables. El HUD muestra tipo, cantidades separadas y la tecla configurada para alternar. Una caja añade una granada del tipo seleccionado respetando su máximo.
- Las granadas especiales se usan al encontrarlas y quedan desbloqueadas permanentemente al completar su nivel. Haberlo superado antes no las entrega automáticamente: se puede repetir el nivel 2 o 5 para recoger la pendiente y conservarla al terminar. Saltársela mantiene la recogida disponible. Los checkpoints guardan tipos, cantidades, selección, descubrimientos y ralentización; los antiguos conservan su contador de granadas básicas.
- Hay cuatro sonidos originales en `assets/audio/grenades`: lanzamiento y explosión propia de cada tipo. La explosión usa un reproductor independiente que termina aunque desaparezca el proyectil o aparezca la pausa del resultado. Respeta Effects. Generador: `revision/herramientas/build_grenade_audio.py`.

### HUD
- `scripts/ui/game_hud.gd` presenta paneles de sector/bajas/tiempo, vitalidad/escudo/reparación, arma/cargador/reserva/progreso de recarga y equipo táctico. Usa cian, ámbar y verde; los valores críticos cambian a rojo. El centro de apuntado queda libre.
- El panel de misión conserva su posición superior derecha y separa etapa, objetivo e instrucciones. Las etiquetas originales conservan sus datos para compatibilidad; su presentación anterior se oculta.

### Verificación
- `tests/campaign/access_supply.gd`: cajas iniciales accesibles, recogida y persistencia; compuerta del reactor cubre el pasillo completo y coincide con la navegación.
- `tests/enemies/enemy_difficulty_health.gd`: seis roles y jefe en las tres dificultades, guardado a disco y restauración de vida dañada sin duplicar ajustes.
- `tests/enemies/enemy_feedback.gd`: disparo real de francotirador a cinco metros, daño creciente, curación visible y expiración de ralentización. Captura revisada en `revision/capturas/enemy-healing-feedback.png`.
- `tests/combat/grenades.gd`: perfiles avanzados repiten 2/5, no hay desbloqueo por progreso, inventarios separados, selección, checkpoints antiguos/nuevos, daño/ralentización, sonidos y persistencia.
- `tests/ui/hud_layout.gd`: paneles y centro despejado, estados de vida/recarga, cantidades y tecla reasignada; capturas gráficas revisadas. Los tests con valores base fijan Normal explícitamente.
- Resultado integrado: editor/importación sin errores GDScript; sector_systems, early_campaign, smoke, levels, expansion, station_revision, late_campaign, combat_redesign, final_shot, campaña y recarga de campaña pasan con cero fallos. Las pruebas nuevas de mapas, vida por dificultad, granadas, HUD y efectos de enemigos también pasan; se revisaron las capturas del HUD y la curación verde.

## HUD editable en el editor
- `scenes/ui/hud.tscn` contiene ahora los nodos reales de los paneles de sector, vida/escudo y armamento, además de objetivos y notificaciones. Se pueden seleccionar, mover y cambiar fuentes, tamaños, márgenes y StyleBoxes desde la vista 2D/Inspector sin ejecutar el juego.
- Los paneles se encuentran en `Interface/GameHUD/{SectorInstrument,VitalsInstrument,ArsenalInstrument}` y `Interface/MissionPanel`. Sus contenedores Content tienen etiquetas con nombres descriptivos; el botón RetryCheckpoint también queda guardado en la escena de pausa.
- `game_hud.gd` deja de construir la interfaz por código: enlaza los nodos existentes y actualiza datos y colores de estado. Los colores de aviso/peligro son exportados al Inspector y las barras conservan sus colores base editados, con estilos duplicados por instancia para no modificar otros HUD.
- `game.gd` utiliza el GameHUD de la escena compartida; `mission.gd` usa MissionSource y MissionNotification existentes. Se conserva el diseño, los objetivos dinámicos, la pausa y la compatibilidad de las etiquetas originales.
- `tests/ui/hud_layout.gd` comprueba que los paneles existen antes de entrar al árbol, que el HUD funciona por separado y conserva cambios de fuente, y que no se duplican instrumentos al iniciar. La galería conserva el aspecto y los estados normal, crítico, recarga y tipos de granada.
- Verificación final: importación/editor sin errores GDScript; HUD gráfico, smoke, diez niveles y station_revision pasan con cero fallos. Capturas de la interfaz revisadas.

## Entrenamiento por fases y marca de pendiente
- El acceso al entrenamiento muestra una exclamación y texto ámbar mientras el perfil no lo haya completado; después aparece como completado y puede repetirse. Reiniciar la campaña conserva esa marca de aprendizaje.
- `scripts/ui/tutorial_guide.gd` y la escena editable `scenes/ui/tutorial_guide.tscn` organizan 25 pasos independientes con botón Siguiente. Las explicaciones liberan el cursor y detienen los controles del jugador; las prácticas lo capturan y solo permiten avanzar al realizar la acción. La guía se oculta durante pausa y resultado.
- La primera parte señala y explica vida/escudo/reparación, arma/cargador/reserva/granadas, objetivos y telemetría. Luego explica los marcadores ámbar/cian, distancias y requisitos de acceso.
- Se conserva y amplía la práctica previa: movimiento, terminal con E, tarjeta con E, suministros con E, introducción al arsenal, disparo, recarga real, cambio de arma, cuchillo y granada. Se añaden una escopeta y granada de fragmentación exclusivamente de demostración para practicar recogida con E y selección de tipo. Ninguna se desbloquea en la campaña por entrenar.
- Cada paso muestra un único objeto/indicador pertinente. Los objetivos posteriores quedan ocultos, sin colisión y no admiten interacción ni daño prematuro; las notificaciones del paso anterior se limpian al avanzar. La guía de prácticas queda a la izquierda para mantener despejada la mira.
- Se presentan por separado Explorador, Acechador, Centinela, Asaltante, Devastador y Comandante con imagen, comportamiento y respuesta recomendada. Son explicaciones seguras, sin activar combate real ni marcar descubrimientos del perfil.
- Las instrucciones utilizan las teclas configuradas. El entrenamiento proporciona recursos mínimos de práctica si se agotaron para evitar bloqueos, y verifica una recarga terminada del mismo arma, sin aceptar una cancelación por cambio de equipo.
- `tests/ui/tutorial_steps.gd` recorre los 25 pasos, comprueba bloqueos, visibilidad/colisión exclusiva, rutas y superficies de interacción reales, pausa, persistencia del completado y conservación de progreso, puntuación, checkpoint y desbloqueos. `tests/helpers/tutorial_driver.gd` actualiza el recorrido de regresión anterior.

## Configuración mejorada
- Se separa tamaño de ventana (1280×720, 1600×900, 1920×1080, adaptado al monitor) de escala de render 3D (50–100 %). La escala conserva nítidos los controles del HUD y funciona en ventana o pantalla completa. La vista incrustada identifica que el editor controla el tamaño/modo y deshabilita esos dos controles con explicación.
- Los cambios de pantalla se previsualizan con confirmación y reversión automática tras diez segundos reales. Cancelar, salir de configuración o fallar el guardado restaura el modo, tamaño y posición anteriores; guardar un perfil durante la previsualización no consolida la pantalla pendiente.
- Calidad Bajo: sin sombras, niebla ni suavizado; Medio: sombras originales y MSAA 2×, sin niebla; Alto: sombras/niebla originales y MSAA 4×. Las descripciones indican su efecto. La dificultad muestra vida, daño, frecuencia y movimiento del catálogo, aclarando que se aplica al iniciar/reiniciar la misión desde cero.
- Se añade brillo del escenario de 75–135 % mediante exposición sobre el valor original, sin acumular cambios ni alterar luces/colores de autor. `GameController.apply_visual_options` aplica brillo, calidad y FOV al instante, conservando el zoom del arma de precisión.
- Restablecer ajustes recupera audio, sensibilidad, controles e imagen, con confirmación para pantalla; conserva perfiles, progreso, récords, equipo y descubrimientos. Los controles del menú se sincronizan con los valores restablecidos.
- `tests/ui/options_revision.gd` pasa en modo gráfico y headless: confirmación/cancelación/timeout/salida/fallo de escritura, guardado durante previsualización, política incrustada, restablecimiento sin pérdida y calidad/brillo/FOV. Se comprobó ventana independiente real y luminancia del render Compatibility: 0,128 a 0,168 entre 75 % y 135 % de brillo. La política incrustada se verificó con contexto simulado, sin ejecutar una sesión incrustada interactiva.

## Música de menú más oscura
- `revision/herramientas/build_menu_music.py` conserva la base de suspenso y añade pulsos de tambor sintético espaciados, resonancias graves y bajo contenido. Tras el ajuste solicitado se retiraron palmas y platillos brillantes y se bajó una octava el motivo repetido de fondo y sus capas agudas.
- Se regeneró `assets/audio/menu_tension.wav`: 32 s estéreo, pico 0,88 sin saturación, bucle continuo. Las versiones previas se respaldan en `revision/respaldo/menu-audio-base`.
- `tests/audio/menu_audio.gd` verifica duración, estéreo, cruce del bucle sin detenerse, navegación entre páginas sin reiniciar la pista, silencio/reactivación y transición independiente a la música del primer nivel: cero fallos.
- Verificación integrada final: editor sin errores GDScript; tutorial de 25 pasos, opciones (gráfico/headless), música, sector_systems, early_campaign, smoke, diez niveles, station_revision, late_campaign, campaña y recarga de campaña pasan sin fallos. Capturas de guía, tarjetas independientes, configuración, confirmación de pantalla y brillo revisadas; las pruebas utilizaron perfiles aislados.

## Menú Start editable como escena
- El diseño completo de `scenes/start.tscn` queda guardado como nodos: principal con presentación dinámica, selección/borrado de perfiles, diez tarjetas de niveles, configuración, tabla de récords, dieciocho tarjetas de enemigos, seis de armas y ventanas de confirmación. Se conserva la escena reutilizable de mejoras.
- Las páginas están en `Margin/Stack/{MainPage,ProfilePage,LevelsPage,SettingsPage,ScoresPage,EnemyPage,WeaponPage}`. Para editar una página oculta en la vista 2D, activa su visibilidad y oculta temporalmente las otras; al ejecutar, el controlador selecciona la página correspondiente.
- Principal: `MainPage/Layout/Buttons` y `MainPage/Layout/Hero`; perfiles: `ProfilePage/Layout/{Welcome,Access}`; configuración: `SettingsPage/Layout/{AudioPanel,OptionsPanel}`. Las etiquetas, controles y contenidos de las tarjetas tienen nombres descriptivos.
- `start.gd` enlaza los nodos y actualiza datos, sin crear ni reorganizar la interfaz. Los índices actualizan los nodos existentes según el perfil, conservan estilos editados y atenúan el equipo o enemigos pendientes. Se mantienen borrado con confirmación, bloqueos de niveles, descubrimientos y desbloqueos permanentes.
- `game_options.gd` enlaza controles y diálogos ya guardados en la escena; mantiene brillo, calidad, controles, restablecimiento y reversión de pantalla. `menu_slideshow.gd` usa Timer guardado como SlideTimer e imágenes exportadas al Inspector; el intervalo y las imágenes son editables. MenuMusic también es un nodo de la escena y libera su reproducción al salir.
- `tests/ui/start_scene.gd` comprueba que todos los nodos existen antes de ejecutar, que no se crean/reparentan al iniciar o cambiar páginas, que se conservan cambios de texto/fuente y que el fondo cambia automáticamente. Se revisaron capturas de principal, perfiles, índices, niveles, configuración y pausa; se conservó el espaciado original de los textos.

## Música de menú simplificada
- La mezcla final se reduce a tres capas: base oscura continua, pulso grave sintético tipo pum y motivo bajo discreto. Se eliminan el golpe ruidoso tipo taz y la percusión adicional; el pulso usa 46/92 Hz y ataque suave, con mayor presencia sin imitar un tambor acústico.
- Se mantiene el bucle de 32 s y la armonía de suspenso original. Pico 0,86 sin saturación; reproducción, bucle, volumen y navegación del menú verificados. Las mezclas anteriores se conservan en los respaldos de revisión.
- Verificación final: start_scene, opciones, gestión de perfiles, galería de menú con audio audible, música, entrenamiento, campaña y recarga de campaña pasan sin fallos; editor sin errores GDScript. Las pruebas limpian la reproducción pausada antes de terminar y utilizan archivos de perfil aislados.

## Ambiente continuo del menú sin pitidos ni percusión
- Se retiran el motivo ocasional y el pulso de percusión de `assets/audio/menu_tension.wav`. Queda una base grave de suspenso y ciencia ficción con modulación lenta, sin golpes ni notas repentinas.
- El generador conserva 32 s estéreo y alinea los osciladores y la modulación con el bucle para evitar saltos al repetir. Pico 0,28 sin saturación; la diferencia entre muestras al cerrar el bucle (160) es menor que el mayor paso normal de la pista (182).
- Importación del editor sin errores GDScript y `tests/audio/menu_audio.gd` con cero fallos: reproducción, cruce del bucle, navegación, silencio/reactivación y transición al nivel. Se conserva respaldo de la mezcla anterior en `revision/respaldo/menu-audio-base`.

## Corrección de audibilidad e importación de menu_tension.wav
- Se vuelve a generar directamente `assets/audio/menu_tension.wav`, sin pitidos, motivo ocasional ni tambor. La base sostenida incorpora armónicos graves y medios bajos para escucharse también en bocinas pequeñas, con pico 0,65 y RMS 0,233 sin saturación.
- La importación del WAV cambia de compresión a PCM de 16 bits para evitar decodificación comprimida durante la reproducción. El bucle de 32 s mantiene continuidad de osciladores y modulación; la unión es menor que un paso normal de la señal.
- Se verificó que Start referencia este mismo archivo y que la música guardada del usuario estaba en 60 %. No se modificaron sus ajustes ni sus perfiles. La prueba gráfica captura la salida Master del menú con volumen 45 %: RMS 0,088, reproducción y cruce del bucle correctos, cero fallos. El editor reimportó el recurso sin errores GDScript.

## Toque tecno y pop oscuro en el menú
- Se actualiza el mismo `assets/audio/menu_tension.wav` conservando el ambiente sci-fi: bajo sintetizado redondeado a 120 BPM y progresión menor de cuatro acordes mezclada suavemente con la base sostenida. No se reincorporan tambores ni pitidos.
- Las envolventes suaves, los acordes solapados y las frecuencias alineadas al bucle evitan ataques bruscos y discontinuidades. Se conservan 32 s, estéreo PCM sin compresión y pico 0,65 sin saturación (RMS 0,186). La unión entre extremos es menor que un paso normal de la onda.
- Mezcla anterior respaldada en `revision/respaldo/menu-audio-base/menu-before-techno-pop.wav`.
- Verificación: importación sin errores GDScript y prueba gráfica de audio del menú con cero fallos; salida Master RMS 0,082 al 45 %, bucle, navegación y silencio/reactivación correctos.

## Arreglo electrónico con mayor variedad para el menú
- Se rehace el arreglo del mismo `assets/audio/menu_tension.wav` para que los elementos musicales destaquen sobre el ambiente. Incluye bajo sintetizado con armónicos, secuencia de notas sincopadas, cuatro acordes menores, una melodía de respuesta y transiciones tonales, sin tambor ni pitidos de alarma.
- Las cuatro frases de ocho segundos alternan intensidad y armonía. Se reduce el zumbido sostenido y se añaden ecos estéreo circulares que conservan sus colas al repetir el bucle de 32 s, manteniendo PCM sin compresión y envolventes suaves. La mezcla anterior queda respaldada en `revision/respaldo/menu-audio-base/menu-before-expanded-arrangement.wav`.
- Verificación: pico 0,75 sin saturación, RMS 0,186 y unión del bucle de 78 unidades frente al mayor paso normal de 2064. Importación sin errores GDScript; prueba gráfica menu_audio con cero fallos y salida Master RMS 0,090 al 45 %, incluyendo repetición, navegación y silencio/reactivación.


## Índice de enemigos y simplificación de configuración
- Las 18 tarjetas del índice separan descripción y táctica con encabezados propios, un divisor y colores de lectura distintos. Los nuevos elementos permanecen como nodos editables en `scenes/start.tscn` y se ocultan en enemigos todavía no descubiertos.
- Se retira el selector de calidad y su explicación de la configuración. Se conserva la clave interna de calidad para leer perfiles existentes sin alterar su renderizado. La dificultad antes llamada Accesible ahora se presenta como Fácil, conservando sus modificadores.
- Importación sin errores GDScript, prueba `start_scene` y galería gráfica del menú aprobadas. Se revisó visualmente la nueva separación de las tarjetas en `revision/capturas/menu-revision-index.png`.
- `options_revision` aprobada: ausencia del selector de calidad, nombre Fácil y funcionamiento de pantalla, brillo, controles y restauración sin modificar el progreso de perfiles.

## Fusil como hallazgo del primer nivel y compatibilidad de perfiles
- Los perfiles nuevos empiezan la campaña con pistola y cuchillo. El fusil se recoge con la interacción habitual en la sala final de extracción del Laboratorio (nivel 1), mediante el marcador editable `MissionPoints/WeaponPickup` de `scenes/main.tscn`. Se equipa al recogerlo y se desbloquea permanentemente al completar esa misión. Si se omite, puede recuperarse repitiendo el nivel 1.
- La versión de guardado pasa a 5. Al cargar datos anteriores se concede el fusil a todos los perfiles existentes, activos o no, sin quitar otras armas ni alterar progreso, puntos de control o ajustes. La migración se guarda después de leer la configuración; una marca distingue el equipamiento inicial antiguo y lo conserva al reiniciar esa campaña. Los perfiles creados después no reciben ese privilegio.
- El inventario y los controles admiten una sola arma mientras la segunda ranura está vacía: tecla 2 y rueda no causan errores ni conceden equipo. Al encontrar un arma se incorpora la segunda ranura. La ventana de equipación aparece en misiones posteriores cuando hay al menos dos armas permanentes disponibles.
- El paso «Conoce tu arsenal» del tutorial explica el hallazgo del fusil en la última sala del nivel 1, las excepciones para perfiles anteriores y la recuperación al repetir. El entrenamiento conserva pistola y fusil de práctica sin concederlos a la campaña.
- `tests/campaign/rifle_unlock.gd` verifica migración de múltiples perfiles, persistencia sin migrar usuarios nuevos, controles con una sola arma, posición/ruta/rayo de interacción del fusil, recogida, munición y hallazgo en punto de control, desbloqueo tras completar y repetición si se omite; también comprueba el arsenal y texto del tutorial. Prueba aprobada con datos aislados. Las pruebas de arsenal completo ahora declaran explícitamente el fusil en sus perfiles de prueba.
- Verificación integrada: rifle_unlock, tutorial_steps, station_revision, expansion y campaña completa de diez niveles aprobados; recarga de campaña en un segundo proceso también aprobada. Menú, configuración y galería gráfica verificados por el subagente de menú; sin errores GDScript en las ejecuciones finales.

## Granadas especiales en las salas finales
- Fragmentación permanece en el nivel 2 y ahora se encuentra en Embarque, detrás del cierre que se abre tras completar las cinco oleadas. Ralentización permanece en el nivel 5 y pasa al interior de Extracción médica, accesible tras completar la purga.
- Ambas ubicaciones quedan editables mediante `MissionPoints/GrenadePickup` en sus escenas. `Mission.add_grenade_pickup` respeta esa posición aunque la sala esté bloqueada al iniciar; solo utiliza la colocación automática anterior cuando no existe marcador. Se conservan identificadores, recogida con interacción, existencias, puntos de control, desbloqueo al terminar y recuperación en repeticiones.
- Importación de Godot sin errores GDScript y `tests/combat/grenades.gd` con cero fallos: posición exacta, bloqueo al inicio, ruta al desbloquear, rayo de interacción libre, recogida, munición separada, explosiones, ralentización, guardado y desbloqueo permanente.

## Navegación de persecución y coberturas
- `GameController.route` conserva la validación estricta de destinos y salas. La nueva `pursuit_route` conecta posiciones físicamente libres pegadas a cajas con nodos seguros cercanos (hasta 2,25 m), validando segmentos contra geometría y puertas. No abre celdas ni mueve actores para resolver la ruta.
- `navigation_segment_clear` comprueba dos alturas y un margen lateral opcional; excluye personajes del trazado global. La cuadrícula conserva el margen de seguridad, las puertas siguen bloqueando el paso y la arena del jefe no puede saltarse.
- El enemigo sigue correctamente el primer nodo recuperado, aunque su posición no coincida con una celda transitable. La recuperación de atasco fuerza un nuevo cálculo, también cuando falta ruta, y sustituye el antiguo teletransporte de rescate.

## Evasión entre aliados y ángulos de tiro
- `enemy_steering.gd` separa la intención de movimiento de la locomoción. Calcula el tamaño físico del enemigo, comprueba barridos de su colisión y selecciona un carril lateral estable para adelantar a aliados lentos cuando cabe. En pasos estrechos mantiene las colisiones y puede esperar en lugar de atravesar otros cuerpos.
- Los tiradores buscan posiciones laterales alcanzables si otro enemigo o una cobertura tapan al jugador. Los francotiradores solo priorizan retirada con visión; sin una retirada válida conservan la posibilidad de aproximarse. Los resultados y decisiones de evasión usan cachés breves y vuelven a validar obstáculos para reducir trabajo repetido.
- Los rayos de disparo siguen deteniéndose ante paredes, cajas y aliados; no hay fuego amigo ni daño a través de obstáculos. Los enemigos alertados investigan una posición comunicada o vista, sin actualizar automáticamente la última posición conocida mientras el jugador está oculto.

## Tácticas de los dieciocho subtipos
- `enemy_tactics.gd` mantiene intención, percepción, canales y temporizadores por enemigo; `enemy.gd` aplica movimiento, disparos, daño y fases. Los niveles de aparición y los multiplicadores existentes de vida/daño/velocidad se conservan. Los tiempos de habilidades reciben un ajuste moderado por sector y dificultad, con límite para conservar los avisos.
- Explorador busca ángulos y se recoloca; Acechador cambia de posición tras dos disparos; Centinela se interpone para proteger soportes; Asaltante anuncia un sprint lateral; Depredador flanquea con avance cuando otro aliado distrae; Vigía se recoloca después de cada tiro.
- Guardián ocupa una posición defensiva del grupo durante cuatro segundos; Cazador anuncia una carga recta y mantiene su dirección aunque el jugador esquive; Escudero escolta soportes con su escudo direccional; Corredor dispara tres tiros, hace una pausa y se desplaza lateralmente.
- Devastador prioriza al aliado más necesitado y Espectro alterna pacientes y busca cobertura con visión del objetivo. Sus canales verdes de 0,95/0,8 s pueden interrumpirse con daño o pérdida de visión; completarlos deja la estela verde. El enfriamiento base posterior es 1,55/1,25 s, ajustado moderadamente por dificultad y nivel.
- Comandante anuncia un canal de 1,8 s interrumpible, escoge presión frontal, kamikaze cercano o flanqueador según el encuentro, y limita a tres sus refuerzos vivos. Coloso prepara durante 2,6 s una baliza de 90 PV destructible para solicitar un refuerzo pesado; limita a dos sus refuerzos y a dos las balizas simultáneas. Los límites de población para iniciar canales son 18/20. Los refuerzos usan los puntos seguros del mapa, sin aparecer necesariamente en la baliza. Se mantienen los dos refuerzos de los invocadores al morir.
- Núcleo hace ráfagas de cuatro tiros hacia la última posición visible, con pausa de 1,6 s y memoria de ataque de cinco segundos; la supresión no revela al jugador oculto ni atraviesa geometría. Bastión busca el grupo y muestra conexiones violetas a los aliados visibles dentro de su radio de protección.
- Reanimado conserva núcleo y única resurrección; tras recuperarse entra en sobrecarga anunciada de siete segundos, con movimiento y ataques más rápidos. Intermitente anuncia con un aro la posición lateral de reaparición, mantiene el aviso visible durante su fase y revalida espacio, separación del jugador y puertas antes de aparecer.
- Los jefes conservan sus fases, invulnerabilidad y límites de arena; quedan fuera de las habilidades de subtipo ordinarias.
- Los checkpoints guardan canales, memoria, ráfagas, carga, sobrecarga, destino anunciado y salud de la baliza. Al cargar se reconstruyen los avisos y se revalida la percepción. Los checkpoints antiguos reciben valores predeterminados sin perder vida o munición. El catálogo compartido actualiza las dieciocho descripciones/tácticas del índice y los roles del tutorial.

## Verificación de navegación e IA táctica
- `navigation_cover` comprueba Cover199, recuperación de ambos extremos, esquinas, componentes desconectados, límites de mapa, puertas y arena sellada. `enemy_steering` y `enemy_steering_scene` comprueban barrido físico, escala de colisión, adelantamiento, ángulo de tiro y retirada sin visión.
- `enemy_ai_integration` ejecuta el controlador real: el explorador rodea Cover199 sin teletransportarse, el kamikaze adelanta al tanque manteniendo separación y el francotirador primero respeta al aliado que bloquea y después recupera tiro lateral. Incluye puntos de control nuevos/antiguos y puertas cerradas.
- `enemy_tactics` verifica explícitamente las dieciocho tácticas, interrupciones, límites, dirección de carga fija, memoria de supresión, avisos y restauración. `enemy_phase_feedback` confirma en una escena real que el destino permanece visible durante el desfase y al restaurar. `enemy_ai_pressure` mantiene los dieciocho tipos juntos durante 300 pasos físicos en un mapa real, sin errores de estado o ejecución.
- Todas esas pruebas pasan. También pasan campaña completa de diez niveles y recarga en otro proceso, early_campaign, sector_systems, los tres ajustes de vida por dificultad, granadas, curación/disparo gráficos, entrenamiento y Start. La galería gráfica del menú pasa y se revisó la legibilidad de las nuevas descripciones. Importación sin errores GDScript; partidas de prueba aisladas de los perfiles reales.

## Corrección del vaivén de exploradores observado en la grabación
- Se analizó la grabación local de nueve segundos y se reprodujo una situación equivalente con dos exploradores y las cajas de la sala este del nivel 1. Antes del ajuste recorrían la cobertura sin disparar: cero tiros y cero daño durante nueve segundos; uno invertía su desplazamiento lateral repetidamente.
- El explorador ahora conserva brevemente una línea de tiro recién adquirida y completa un disparo antes de solicitar otro desplazamiento lateral. Las recolocaciones comprueban que el destino mantenga tiro limpio y que el recorrido físico quepa; si no hay una alternativa útil, mantiene el tiro en vez de rebotar junto a la pared. Las oclusiones muy breves por aliados no revierten inmediatamente la decisión.
- La evasión limita la distancia de comprobación al siguiente punto cercano de la ruta: ya no rechaza una aproximación segura porque el barrido se prolongue más allá de ese punto y choque con la caja posterior. Se conserva el barrido físico y la colisión con paredes y aliados.
- Los nuevos tiempos de espera del explorador se guardan en su estado táctico; los puntos de control anteriores reciben los valores predeterminados.
- `tests/enemies/scout_cover_motion.gd` verifica ambos exploradores durante nueve segundos en la escena real. Tras el cambio completan seis y cinco disparos, con 385 y 335 pasos de visión libre de 540; antes eran cero disparos y cuatro/cero pasos de visión. La prueba exige tiro real sostenido de ambos y daño al jugador. Se actualizaron las comprobaciones del explorador en `enemy_tactics` para validar mantener el ángulo, disparar y después recolocarse, incluyendo guardado.
- Verificación final: importación sin errores GDScript; scout_cover_motion, enemy_tactics, enemy_steering y enemy_ai_integration aprobados sin fallos. Se conserva persecución alrededor de cajas, adelantamiento de tanques, tiro bloqueado por aliados, puertas cerradas y compatibilidad de puntos de control.

## Búsqueda local después de perder al jugador
- `enemy_search.gd` añade una investigación compartida para enemigos alertados: se aproximan a la última posición recordada y, si llegan sin recuperar visión o no progresan, recorren hasta seis puntos cercanos y transitables. La búsqueda tiene límites de tiempo; si se agota, vuelven a su puesto y dejan de perseguir.
- Los puntos se calculan con la memoria del enemigo y la geometría, sin seguir las coordenadas actuales del jugador oculto. Se comprueban rutas, volumen de colisión y puertas; no se abren conexiones ni se teletransportan enemigos. Los ángulos de aproximación se revalidan periódicamente para responder a aliados que obstruyen el tiro.
- La visión recuperada actualiza la memoria y devuelve el control a las tácticas habituales. Curación, escolta, protección del grupo, canales, carga comprometida, supresión y desfase mantienen sus prioridades; los jefes conservan sus reglas de arena.
- `mission.gd` guarda y restaura el progreso de investigación en los checkpoints; las partidas anteriores reciben un estado inicial compatible. Al perder visión también se orientan hacia su destino recordado, evitando mirar directamente al jugador oculto.
- `tests/enemies/enemy_search.gd` reproduce la cobertura de la captura en los 18 subtipos aislados, exige recuperación de visión y disparos del explorador, comprueba independencia de la ubicación oculta, prioridades de soporte, puerta cerrada, agotamiento y checkpoints nuevos/antiguos con vida y munición conservadas. Los perfiles de prueba están aislados.
- Verificación: enemy_search, scout_cover_motion, enemy_ai_integration, enemy_tactics, enemy_steering, navigation_cover, enemy_phase_feedback, enemy_ai_pressure y sector_systems aprobados. La regresión de los dos exploradores completa seis y cuatro disparos durante nueve segundos, con 418 y 292 pasos de visión libre de 540.

## Formación de curadores, refuerzos locales y búsqueda ampliada
- Devastador y Espectro se colocan detrás de un aliado respecto a la amenaza observada. Priorizan al paciente herido; cuando nadie necesita curación, conservan una formación de retaguardia con la primera línea. Reevalúan su posición cada 0,65 s y comprueban espacio físico, rutas, separación y visión del aliado. Conservan sus canales de curación y evitan abandonar aliados sanos para iniciar una búsqueda individual.
- Comandante y Coloso liberan sus dos refuerzos junto al lugar de la muerte. `spawn_enemy` admite un origen opcional y elige primero ese punto o el espacio libre más próximo, hasta cinco metros, sin atravesar paredes/puertas ni solapar cuerpos. Conservan sus respectivas listas de subtipos y la protección contra invocaciones duplicadas al morir. Las oleadas y las invocaciones normales mantienen su distribución habitual.
- La inspección local aumenta de seis a diez destinos y de doce a veinte segundos. Los candidatos abarcan hasta ocho metros de la última posición conocida; se mantienen los límites, la comprobación de rutas y el regreso a vigilancia al agotarse la búsqueda.
- Se amplían enemy_tactics (retaguardia con aliados sanos), sector_systems (dos refuerzos locales, subtipos y separación) y enemy_search (presupuesto de búsqueda ampliado y finito).
- Verificación aprobada: enemy_tactics, sector_systems, enemy_search con los 18 subtipos, enemy_ai_pressure, enemy_ai_integration y scout_cover_motion. Importación final sin errores de GDScript; permanecen avisos existentes de mayúsculas/minúsculas en rutas de texturas del kit.

## Visión y disparos por altura; cajas dobles
- `enemy_steering.gd` calcula la altura del cuerpo desde su colisión real. Los enemigos de hasta 1,3 m mantienen el origen de tiro de 0,8 m y sus comprobaciones anteriores de torso/percepción. Los de más de 1,3 m usan un origen próximo a la parte superior del cuerpo y comprueban cabeza expuesta y torso del jugador con rayos físicos.
- Detección inicial, percepción táctica, ángulos de tiro y disparo real comparten las comprobaciones de altura para los grandes. Cada disparo revalida el punto visible, respeta el alcance, paredes y aliados; se conservan avisos, tiempos de ataque, daño y habilidades. Si la cobertura oculta al jugador, continúan usando la búsqueda existente.
- Se añadieron 24 cajas superiores de los assets existentes como nodos editables `Arena/DoubleCover...Upper`: niveles 1–10 con 2, 2, 2, 2, 3, 3, 2, 1, 3 y 4 pilas respectivamente. Se eligieron cajas de salas con enemigos grandes; cada pila mide 2,6 m y mantiene la huella de la caja original, sin estrechar los pasillos. Visual y colisión se apilan sin separación.
- `tests/enemies/enemy_height_cover.gd` verifica los 18 subtipos: visión y daño real sobre una caja simple según altura, bloqueo físico con dos cajas y activación de búsqueda. Comprueba además alineación, colisión, altura y presencia de las 24 pilas en las escenas de los diez niveles.
- Verificación aprobada: enemy_height_cover (18 subtipos y 24 pilas), enemy_search, enemy_tactics, enemy_steering, enemy_ai_integration, enemy_ai_pressure, scout_cover_motion, navigation_cover, sector_systems y campaña completa con recarga en otro proceso. Importación sin errores de GDScript; permanecen los avisos anteriores de mayúsculas/minúsculas en texturas del kit.

## Entrenamiento de coberturas
- Se añaden tres lecciones independientes después de practicar el disparo: cubrirse con una caja frente a enemigos pequeños, buscar cajas dobles o paredes frente a enemigos altos y cambiar de posición mientras los enemigos investigan el último lugar donde vieron al jugador.
- Las dos primeras muestran ejemplos visuales de enemigos pequeños y altos; cada explicación avanza con Siguiente sin superponerse con los objetos o marcadores de otros ejercicios. El entrenamiento pasa de 25 a 28 pasos y su cierre incluye las coberturas.
- `tutorial_steps` comprueba orden, avance independiente, imágenes, ausencia de objetivos superpuestos y conservación del progreso de campaña. La prueba completa pasa en modo headless y gráfico; se revisaron las tres capturas para confirmar legibilidad y botones visibles.

## Altura en el índice de enemigos
- Las 18 tarjetas de `start.tscn` incluyen un nodo Height debajo del rol, con formato español como «ALTURA · 1,65 m». Se muestra al descubrir al enemigo, junto con su descripción y táctica.
- `enemy_catalog.gd` consulta la colisión y escala de las escenas originales sin instanciar enemigos ni mantener otra tabla de medidas. `menu_presentation.gd` actualiza las etiquetas conservando los nodos editables y el diseño de las tarjetas.
- `start_scene` verifica las 18 alturas contra sus escenas, el estado descubierto y la jerarquía estable. Prueba aprobada y captura gráfica revisada sin solapamientos.
- Verificación conjunta final de menú y tutorial aprobada; importación sin errores de GDScript. Se conservan los avisos anteriores de rutas de texturas del kit.

## Persistencia SQLite de perfiles y configuración
- `campaign_store.gd` sustituye el guardado CFG por SQLite nativo (`user://sector07.sqlite`), con Godot-SQLite v4.8/MIT incluido para Windows x86_64. No depende de servidores o runtimes externos. El complemento y su procedencia se documentan en `addons/godot-sqlite/PROJECT_NOTES.md`.
- `campaign.gd` migra automáticamente el CFG y sus versiones anteriores conservando el archivo original. Perfiles, récords, puntuaciones, mejoras, armas/granadas, descubrimientos, equipación, entrenamiento, opciones, teclas y checkpoints se guardan en la base. El perfil activo también persiste. Tipos de Godot se conservan mediante BLOB; tablas relacionales y JSON permiten consultas futuras desde la web.
- Guardado transaccional, UUID de perfil estable, comprobación de integridad y respaldo SQLite. La recuperación de una base ausente/dañada conserva el archivo dañado y no reimporta perfiles eliminados. Un esquema futuro o una migración ilegible bloquean escrituras. La selección de perfil revierte sus cambios si falla el guardado.
- `game.gd` registra un resumen por intento con victoria, derrota o abandono, nivel, dificultad, puntos, bajas, fechas y tiempo activo. Reiniciar campaña conserva ese historial; eliminar el perfil borra sus filas relacionadas. El entrenamiento queda fuera. `mission.gd` conserva tiempo acumulado en checkpoints; los intentos reanudados cuentan solo actividad nueva en su historial.
- `README_SQLITE.md` explica ubicación, tablas, migración, copias, alcance y pruebas. No se integró todavía la web ni telemetría exhaustiva de acciones.
- Se adaptan profile_management, options_revision y rifle_unlock al nuevo formato sin cambiar su comportamiento. Nuevas pruebas sqlite_storage y sqlite_history incluyen transacciones fallidas, bloqueo de escritura, perfiles eliminados, base dañada/ausente, tipos de checkpoint, recarga en otro proceso e historial real de partidas.
- Verificación final: sqlite_storage y recarga en otro proceso (incluye fallos SQL provocados), sqlite_history, profile_management, options_revision, rifle_unlock, grenades, tutorial_steps, start_scene, enemy_search, enemy_ai_integration, sector_systems, early_campaign y campaña completa de diez niveles con recarga aprobados. Se migró una copia de los cuatro perfiles del CFG real y se comprobó igualdad de todos sus datos; el archivo real permaneció intacto. SQLite integrity_check confirmó integridad y tablas consultables. Importación final sin errores GDScript; permanecen avisos anteriores de rutas de texturas.

## Página web de consulta — interfaz
- Se crea `web/` con HTML, CSS y JavaScript independientes: resumen, jugadores, clasificación, historial, descubrimientos y eventos. Reutiliza vistas previas del juego y una paleta oscura con acentos verde, ámbar y violeta; navegación adaptable a escritorio y móvil.
- Búsqueda, filtros, paginación, fichas de perfil, detalle de partidas/eventos, niveles y desbloqueos visuales, alturas de enemigos descubiertos y CSV de vistas filtradas. El ranking mantiene el puesto global al buscar y distingue récord de puntos actuales.
- Estado inicial sin conexión; demostración explícita con datos ficticios, aviso persistente y exportaciones identificadas. Errores de conexión no muestran datos inventados. El navegador no lee ni modifica SQLite ni el guardado del juego.
- Adaptador preparado para `GET /api/dashboard`, con validación de datos y estado de registro detallado pendiente. `web/README.md` define contrato y pasos siguientes: servidor local de consulta, conexión a SQLite y futura captura de eventos. Todavía no se implementa ese servidor ni se altera el juego.
- `web/.gdignore` evita importar la web en Godot. `tests/web/web_ui.cjs` prueba el navegador y simula únicamente respuestas de API durante las pruebas; revisa seis vistas, filtros, datos desconectados/demo, CSV, diálogos, imágenes y resoluciones de 390/760/1440 px.
- Verificación: web_ui aprobada en Edge headless, incluidos respuestas de API interceptadas, rechazo de respuestas incompatibles, texto escapado, independencia de filtros, conservación de puestos globales e imágenes válidas. Capturas revisadas en escritorio y teléfono. La web puede abrirse directamente sin servidor; sus datos reales quedan pendientes de conexión.
- Comprobaciones adicionales: sintaxis de los tres JS y start_scene con SQLite aprobados, sin errores GDScript. El intento de abrir otro editor encontró una copia temporal de la DLL SQLite ocupada; no se modificó el complemento ni se cerró el editor existente. La ejecución del juego y la prueba del menú cargaron SQLite correctamente.


## Eventos de juego en la misma SQLite
- Esquema 2: `run_sessions` registra intentos activos/finalizados/interrumpidos; `game_events` registra acciones con ID y secuencia únicos, fecha UTC, tiempo acumulado de misión, tiempo activo del intento y detalles JSON. La vista `event_log` añade perfil, nivel y dificultad. Se migra el esquema 1 sin alterar los datos anteriores ni inventar acciones históricas.
- `game_events.gd`, propiedad de Campaign, conserva una cola entre escenas y durante pausas. Guarda por lotes cada 2 s, en pausas y junto con checkpoints/progreso/resultados mediante transacciones; una escritura fallida conserva el lote para reintentar sin duplicarlo. Al reiniciar se detectan procesos terminados y se marca el último intento como interrumpido, sin resultado inventado.
- `player.gd`, `enemy.gd` y `grenade.gd` registran disparos válidos, recargas completas/canceladas, cambios de arma/equipación, cuchillo, tipos de granada, impactos y bajas definitivas, daño a vida/escudo y transiciones de movimiento/carrera/salto. Se conservan daños, tiempos, azar, navegación, modelos, sonido y reglas existentes.
- `mission.gd`, `early_missions.gd` y `late_missions.gd` registran recogidas, suministros efectivos, descubrimientos, refuerzos/invocaciones, objetivos de los diez niveles, checkpoints, oleadas y puntos/desbloqueos al completar un nivel. El tutorial no suma actividad a la campaña.
- `profile_events` registra creación/selección de perfiles, reinicios de campaña, mejoras y cambios reales de configuración. Las mejoras se capturan en Campaign para incluir también las elegidas en el menú después de reabrir el juego. Los cambios globales de opciones no se atribuyen a un jugador.
- Reiniciar campaña conserva registros; eliminar un perfil elimina sus sesiones/eventos relacionados. El respaldo se actualiza con guardados de estado, sin copiar toda la base por cada lote de combate. Un cierre forzado puede perder el último lote sin confirmar; una escritura que siga fallando al cerrar no puede conservar una cola solo en memoria.
- `README_EVENTS.md` enumera los eventos, esquema, consultas y límites. Se actualizan README_SQLITE y el contrato pendiente de la web. No se conecta todavía el servidor web ni se añaden monedas u otras mecánicas.
- Nueva prueba `sqlite_events.gd`: migración, acciones reales, pausas/movimiento, recogidas, daño/granadas, rollback provocado, reintentos sin duplicados, cierres interrumpidos, eliminación, reinicio, tutorial y recarga en otro proceso, siempre con bases privadas.
- Verificación final aprobada: sqlite_events y su recarga en otro proceso, sqlite_storage y recarga, sqlite_history, campaña completa de diez niveles y recarga, options_revision, grenades y enemy_ai_integration. Sin errores GDScript; los errores SQL registrados en las pruebas son fallos provocados para comprobar rollback y reintentos. Consultas externas con Python/SQLite confirmaron `integrity_check=ok`, esquema 2 y objetivos registrados en todos los niveles. Las pruebas usaron únicamente bases privadas.


## Conexión local de la web con SQLite
- `web/server.mjs` sirve la interfaz y `GET /api/dashboard` mediante Node.js 24 y SQLite integrado, sin paquetes externos. Localiza `sector07.sqlite` en AppData y admite `--db`, `--port`, `SECTOR07_DB_PATH` y `PORT`. Solo escucha en loopback y sirve archivos públicos; no expone la base ni archivos del servidor.
- Abre SQLite con `readOnly`, `query_only` y una transacción corta por actualización; no crea, migra ni escribe guardados. Lee perfiles, progreso, desbloqueos, mejoras, equipación, resultados y eventos. Usa UUID estables y une historial/sesiones por ID para evitar duplicados. Informa errores de archivo ausente, bloqueo, corrupción y versión incompatible.
- Contrato web 2 con partidas en curso/interrumpidas y eventos de juego, perfil y configuración general. `app.js` conserva demostración/contrato 1 y añade estados, nombres de eventos, contexto de menú/sistema, secuencia, detalles y mensajes reales de conexión. Los intentos sin cierre confirmado no inventan puntos ni fecha final ni alteran el porcentaje de victorias.
- Se mantienen las seis secciones, filtros, fichas, imágenes y CSV. «Actualizar» consulta de nuevo sin reiniciar el servidor; salir de demostración recupera los datos reales. El detalle muestra las últimas 100 acciones y la bitácora permite consultar/exportar todas. No se modifican scripts, escenas ni reglas del juego.
- `iniciar_web.cmd` comprueba Node y abre el navegador; `web/package.json` ofrece npm start/test sin instalaciones adicionales. `web/README.md` explica arranque, cada sección y archivo, contrato, rutas, puertos, errores y alcance. README_SQLITE y README_EVENTS reflejan la conexión implementada.
- Nuevas pruebas `web_server.mjs` y `web_connection.cjs`: recorrido real navegador/HTTP/SQLite, lectura, actualizaciones y eliminaciones, estados/referencias, ausencia de duplicados, opciones generales, CSV, datos escapados, móvil y errores, con bases privadas. --real comprobó 4 perfiles, 13 intentos y 87 eventos sin cambiar los bytes del guardado. También aprobaron web_ui y start_scene, sin errores GDScript/JavaScript; capturas reales de resumen/eventos revisadas visualmente.


## Reorganización de carpetas y documentación — 16 de octubre de 2026
- Se eliminan únicamente las cuatro carpetas vacías solicitadas: export_templates, feature_profiles, script_templates y text_editor_themes. Se conservan íntegros revision/ y Modular SciFi MegaKit[Standard]/; la comparación de hashes confirma que no se añadieron, eliminaron ni modificaron sus archivos.
- Los 20 modelos OBJ y sus MTL/import se agrupan en assets/models/enemies, props y structures. Se actualizan referencias estáticas, resolución dinámica de Kit.model, rutas relativas de texturas y selección de superficies con backface culling. Se preservan los UID de scripts e importaciones.
- Los 35 scripts se distribuyen por responsabilidad. Se conservan los 55 archivos originales de pruebas/herramientas y se organizan por área; se añade test_paths como helper de salidas. Los resultados nuevos van a .godot/test-results, sin alterar las revisiones históricas. Se corrigen imports y directorios base de las pruebas Node y el comando npm test.
- Las guías se agrupan en docs/, con índice; la guía general sustituye la descripción obsoleta de siete niveles/CFG por el estado actual. Se actualizan rutas, comandos y enlaces de documentación propia, manteniendo Agents.md, licencias y documentos históricos/de terceros. El registro anterior conserva su contexto histórico.
- Verificación aprobada: carga de los 88 scripts GDScript actuales (juego y pruebas/helpers), campaña de diez niveles y recarga en otro proceso, Inicio, tutorial, 18 subtipos/24 coberturas dobles, auditoría de 20 mallas, apariencia de combate en diez niveles, eventos SQLite, almacenamiento y recarga, servidor web, conexión HTTP/SQLite/navegador e interfaz de seis vistas. Auditoría sin referencias rotas ni cambios de UID; enlaces Markdown locales válidos.
- El escaneo inicial del editor encontró la copia temporal de la DLL SQLite ocupada y referencias UID antiguas antes de reconstruir el índice; no se modificó la extensión ni se cerró el editor existente. La ejecución normal de Godot y las pruebas posteriores cargaron SQLite y las nuevas rutas correctamente. Los errores SQL de las pruebas de fallos son intencionales.


## Icono de Sector 07
- `icon.svg` reutiliza el mini logo vectorial 07 de `web/assets/mark.svg`, conservando sus colores y formas, con tamaño de 128 × 128. `project.godot` mantiene su referencia al icono del proyecto.


## Preparación para GitHub
- Se añade `.gitignore` en la raíz para excluir cachés de Godot, resultados de pruebas, revision/, dependencias Node, exportaciones locales, bases personales y sus auxiliares, configuración local y temporales. Se conservan fuentes, assets, documentación, pruebas, archivos `.uid`/`.import` de recursos y las dos DLL originales de SQLite. No se inicializa ni publica un repositorio.


## README principal del repositorio
- Se añade README.md en la raíz con descripción general, contenido, requisitos, controles e inicio del juego. Explica la base SQLite por usuario, datos y eventos, significado del tiempo activo, leaderboard local y diferencias entre récord/puntos actuales, arranque y secciones de la web, conexión de solo lectura, estructura, pruebas y licencias incluidas. Enlaces y rutas locales comprobados; no se modifica código ni guardados.


## Retención por perfil — 17 de octubre de 2026
- Se establecen cupos de 2.400 eventos y 400 intentos únicos por perfil, equivalentes a 300/50 páginas de 8 filas. Eventos de juego y acciones del menú comparten cupo; las opciones generales conservan otro cupo de 2.400. Se eliminan primero registros antiguos, se priorizan sesiones activas y los eventos de intentos eliminados se borran en cascada.
- Esquema SQLite 3: la limpieza es transaccional al abrir/migrar y en los guardados/lotes. history_archive conserva cantidades, tiempo activo y bajas agrupados por perfil/nivel/resultado antes de eliminar detalles. No se cambia progreso, récord, equipo ni dificultad. El servidor sigue siendo de lectura y mantiene compatibilidad con esquemas anteriores.
- API y web muestran el historial retenido y suman acumulados al tiempo total, cantidades de intentos/victorias, balance y actividad por sector. Los CSV contienen solo detalles conservados; con todos los jugadores se suman cupos. Se actualizan README, guías SQLite/eventos/juego/web y documentación de pruebas.
- Nuevas pruebas de retención y ampliación de pruebas HTTP/navegador: más de 400 partidas, miles de eventos, perfiles independientes, cupo global, orden, limpieza repetida, sesión activa, migración, totales preservados y rollback de borrado fallido. Se utilizan únicamente bases privadas.
- Verificación final aprobada: sqlite_retention (incluye migración, empates, reinicio, acumulados y rollback intencional), sqlite_events, sqlite_history, sqlite_storage, web_server, web_connection y web_ui. El navegador verificó 300/50 páginas y conservación del tiempo acumulado. No se usó la base personal para las pruebas.


## Coberturas en la cámara del jefe — 17 de octubre de 2026
- Se añaden dos pilas de dos cajas (2,6 m de altura) dentro de la sala del jefe del nivel 10, a ambos lados del paso central. Usan el modelo y material existentes, con colisión en ambas cajas y nodos editables en la escena. Los accesos, terminales y puntos iniciales permanecen despejados.
- La comprobación de coberturas contempla ahora 26 pilas en la campaña.
- Verificación: prueba de altura/cobertura de los 18 subtipos y las 26 pilas, y campaña avanzada con rutas a objetivos, progreso y fases del jefe: aprobadas, sin errores de GDScript.


## Partidas, recorridos y estadísticas web — 17 de octubre de 2026
- Nueva sección 07 «Partidas y recorridos», con listado paginado y filtros. El detalle del intento añade equipación inicial y un mapa cenital del escenario real, con paredes, coberturas y estado de puertas de sector. El jugador deja un trazo; los enemigos aparecen sin trazo, identificados por instancia/subtipo y jefe. Reproducir, pausar, reiniciar, desplazarse en el tiempo y velocidades 0,5×/1×/2×/4×. Diseño adaptable y controles de teclado.
- `run_replay.gd` registra posiciones X/Z cada 0,5 s de tiempo activo, desde el comienzo del intento hasta su cierre. Captura la geometría con colisiones del nivel ya escalado, incluyendo decoración generada y compuertas de misión de niveles 3/4. Pausas y checkpoints vacían las muestras pendientes antes del guardado. Los enemigos muertos/desvanecidos dejan de aparecer; reapariciones e invocaciones se capturan en las muestras siguientes. No altera navegación, combate, misiones ni escenas.
- SQLite 4 agrega `replay_runs` (mapa y equipación elegida) y `replay_chunks` (lotes de muestras). Se escriben con la sesión en las transacciones existentes; no consumen el cupo de eventos y se borran en cascada al eliminar el intento/perfil. La cola se conserva si falla una escritura. Se mantienen el límite de 400 intentos y los acumulados anteriores. Los intentos previos no inventan recorridos; los cierres forzados conservan únicamente las muestras confirmadas.
- `GET /api/replay?run=ID` consulta bajo demanda la misma SQLite en solo lectura; el dashboard declara disponibilidad sin descargar todas las posiciones. Se conserva compatibilidad con bases 1/2/3. El servidor y el juego deben actualizarse juntos; reiniciar el servidor tras cambiar archivos.
- Resumen incorpora actividad por día de inicio local (selector jugadores únicos/partidas, ventana de hasta 30 días), armas presentes en equipaciones y mejoras elegidas. Usa información conservada, sin atribuir fechas a acumulados antiguos. Equipación por intento y combinación favorita por jugador se calculan con datos del mismo intento; desconocidos y empates se indican expresamente, sin inferir historia del equipo actual del perfil.
- Se añaden `analytics.js/css`, `equipment.js`, `replay.js/css` y `replay-data.mjs`, sin nuevas dependencias de ejecución. La demostración tiene un mapa/recorrido ficticio rotulado, separado de datos reales.
- Verificación con bases privadas: migración 3→4, geometría real de niveles 1/3/4/10, muestras del jugador y enemigos, identidad estable, equipación durable, supervivencia al podado de eventos, borrado en cascada, integridad SQLite y recorrido HTTP/navegador con reproducción, pausa, velocidad, barra temporal, fichas, intentos antiguos y móvil. También pasan eventos, retención, almacenamiento, servidor, interfaz anterior, conexión HTTP y cálculos de gráficas/equipación. Capturas de escritorio/móvil inspeccionadas. No se modifica la base personal durante las pruebas.


## Defensa del hangar y transporte del arsenal — 17 de octubre de 2026
- Nivel 8: `hangar_defense.gd` sustituye la defensa de 60 s por 120 s con carga física de 150 PV. Genera tandas en una misma zona, con colocación segura sin superponer cuerpos: 2 enemigos cada 6 s hasta t=60 y 3 cada 7 s desde t=67 hasta t=116 (44 unidades programadas). El temporizador detiene los refuerzos al completarse. Se añaden un marcador de carga y cuatro de munición editables en la escena.
- `defense_cargo.gd` recibe únicamente daño enemigo. Los atacantes usan navegación, colisión, daño y cadencia propios; buscan posiciones de ataque válidas, aliados/paredes bloquean tiros y el jugador cercano puede atraer su atención. Se preservan acciones especiales ya comprometidas y el comportamiento habitual fuera de esta defensa. La carga destruida provoca derrota. La barra de 150 PV es un nodo de `hud.tscn`; también se muestra su vida sobre el objeto.
- Checkpoints del hangar conservan vida, reloj, próxima tanda y cajas consumidas. Los checkpoints anteriores mantienen su progreso: una defensa antigua en curso se amplía conservando el tiempo ya transcurrido; una ya completada permanece completada. La navegación incorpora la colisión real de la carga y sus marcadores protegen espacio frente a decoración generada.
- Nivel 9 (subagente existente): `arsenal_delivery.gd` mantiene objetivos 0–4 y convierte la antigua salida en asegurado del sector; añade recogida en la sala inicial y entrega en la última. Hay tres cajas de munición junto a la carga, movimiento al 80 % y tandas aleatorias de 1–2 enemigos cada 7 s durante regreso/traslado. Los refuerzos no bloquean recogida/entrega y se detienen al ganar. Se corrige el indicador de salida para reflejar ese requisito.
- El nuevo estado del transporte se guarda en el checkpoint; se conserva compatibilidad con etapas 0–5 antiguas. Se registran eventos de daño/destrucción/defensa/recogida/entrega y tandas, con nombres legibles en la web. Se actualizan las descripciones de campaña y guía. No hay cambio de esquema SQLite: se utilizan checkpoint y eventos existentes.
- Pruebas nuevas: `hangar_defense.gd` verifica las 18 tandas/44 enemigos, cuatro suministros accesibles, final exacto, ataques reales (incluido asalto pesado sin memoria del jugador), fuego amigo ignorado, HUD, restauración de vida/tiempo/cajas usadas y derrota por destrucción. `arsenal_delivery.gd` verifica las ocho etapas, tres cajas/rutas, refuerzos, recogida/entrega con enemigos vivos, restauración y seis estados de checkpoint anteriores. Ambas pasan sin errores GDScript, usando bases privadas. La campaña avanzada también pasa.
- Verificación complementaria aprobada: integración de IA (búsqueda de cobertura, adelantamiento entre aliados y reposicionamiento del francotirador), disposición del HUD y sintaxis JavaScript de los nuevos nombres de eventos.


### Defensa del Almacén: cuatro oleadas (2026-10-17)
- El nivel 2 ahora genera cuatro oleadas de 3, 5, 5 y 7 enemigos. Contador, avisos, autorización del transporte y apertura de embarque comparten el nuevo límite. Se conservan las pausas, reabastecimientos, ritmo de aparición y refuerzo especial al final de la última oleada.
- Las pruebas de expansión comprueban las cuatro cantidades y el final de la misión; los recorridos compartidos usan el mismo límite. Los checkpoints previos conservan la oleada en curso y no agregan nuevas oleadas después de la cuarta.


### Ajuste final de oleadas del Almacén (2026-10-17)
- La defensa del nivel 2 queda en tres oleadas de 3, 4 y 5 enemigos (12 en total). Se actualizan avisos, descripción de campaña, guía y prueba de expansión. El contador y el desbloqueo del transporte usan automáticamente el límite de tres. Se conservan pausas, reabastecimientos y características de los enemigos.


### Nuevos objetivos finales en sectores 3–6 (2026-10-17)
- Reactor: purga de 180 s, carga en la sala inicial con dos guardias y evacuación obligatoria con carga. Se conserva el cierre este y la velocidad de transporte al 80 %.
- Fundición: el anterior encuentro final pasa a Apagar fragua; inicia emergencia de 60 s para volver al horno del ala este, eliminar cuatro guardias y desactivarlo. Desactivar cancela el temporizador y habilita la salida; agotar el tiempo causa derrota.
- Fortaleza: tres llaves de mando distribuidas en oeste, este y sala central, con dos, tres y dos guardias; deben recogerse antes de asegurar al capitán.
- Biocontención: purga de 90 s y cinco o seis refuerzos; se mantiene el límite de ocho amenazas simultáneas, las posiciones aleatorias y la limpieza final de enemigos.
- Los nuevos objetivos usan modelos existentes de carga, tarjetas y terminales; HUD e indicadores siguen la etapa activa. Migración localizada de checkpoints conserva inventario, bajas y suministros, añade los objetivos pendientes y amplía los relojes antiguos en curso. No se cambia el esquema SQLite.
- Prueba sector_finales.gd: rutas, cantidades de guardias, carga, llaves, bloqueos, relojes, derrota por agotamiento, refuerzos y restauración de checkpoints. Se adaptan los recorridos de campaña a los 90 s de purga.
- Verificación: sector_finales.gd, late_campaign.gd y early_campaign.gd pasan sin fallos de comprobación; sintaxis de web/app.js válida. Las pruebas headless de campaña emiten avisos de limpieza/renderer al cerrar, sin errores de GDScript.


### Ajuste de dificultad y actividad por sector (2026-10-18)
- Almacén (2): dos oleadas de tres enemigos; contador, mensajes, campaña y prueba de expansión usan el nuevo límite. Se conservan tipos de enemigos, pausas y refuerzo especial final.
- Fundición (4): la emergencia de la fragua dura 120 s; mensajes y guía actualizados. Un checkpoint anterior con reloj activo recibe los 60 s adicionales sin perder tiempo ya transcurrido.
- Fortaleza (6): cada una de las tres llaves de mando está custodiada por tres enemigos. Al restaurar un checkpoint anterior en una de esas etapas se completa el grupo sin duplicar los guardias existentes. Revisión local de checkpoints 2; sin cambio de esquema SQLite.
- Web (subagente existente): Actividad por sector permite elegir tiempo activo o dificultad por derrotas, y presentar estas últimas como número o porcentaje sobre victorias + derrotas. Incluye históricos archivados, deduplica cada intento y respeta el filtro de jugador; excluye abandonos, partidas abiertas e interrumpidas del denominador. Se muestra derrotas/partidas resueltas y se aclara que perder por tiempo u objetivos también es una derrota. Los sectores sin muestra se distinguen de un 0 % real. Nuevos módulos sector-stats.js/css y autorización de sus archivos en el servidor.
- Verificación: expansión de campaña y sector_finales pasan, incluyendo dos oleadas de tres, reloj de 120 s, tres guardias por llave y migración de checkpoints de revisión 1. Pruebas web de cálculos, SQLite/HTTP sin escrituras e interfaz escritorio/móvil pasan; capturas revisadas.


### Vibración de cámara y balanceo al caminar (2026-10-18)
- Las explosiones de granada básica producen una vibración visual breve; la granada de fragmentación usa una intensidad y duración mayores. La fuerza disminuye con la distancia a la explosión y no altera la dirección de puntería.
- La cámara acompaña suavemente el paso cuando el jugador se desplaza sobre suelo, con algo más de amplitud al correr. La opción «Movimiento reducido» desactiva el balanceo y la vibración.
- La granada de estasis también vibra al explotar; si detona a 3 m o menos y tiene línea de visión, reduce temporalmente la velocidad del jugador.
- Las explosiones dañan al jugador dentro del radio y con línea de visión; el daño cae con la distancia y activa el indicador rojo existente. Mientras dure la ralentización por estasis, aparece un marco azul tenue en el borde de la pantalla.
- El marco de estasis es una bruma azul translúcida con bordes degradados y variación nubosa animada, en lugar de líneas sólidas. El rayo del arma de plasma usa un morado más definido.
- El rayo de plasma es violeta y el disparo de precisión naranja. La regeneración reproduce un tono suave; por debajo del 50 % de la vida máxima actual aparece una nube roja en los bordes, y bajo el 40 % suena un latido que acelera y aumenta de volumen cuanto menor sea la salud. Sus WAV viven en `assets/audio/player/`.
- El plasma dispara un rayo violeta y el rifle de precisión uno naranja más saturado. La nube roja de salud crítica se extiende más hacia el centro cuanto más baja la vida, medida respecto al máximo actual. El latido tiene más presencia y se acelera y sube de volumen según la salud faltante. La regeneración reproduce un zumbido grave y ascendente, a volumen bajo y con una pausa entre repeticiones. Su WAV está en `assets/audio/player/health_regen.wav`, junto al latido en `assets/audio/player/heartbeat.wav`.
- El clic electrónico del arma vacía solo se reproduce cuando el cargador y la reserva están agotados. Intentar lanzar una granada sin stock produce un aviso sonoro propio, con un breve intervalo entre avisos. Los WAV están en `assets/audio/weapons/empty_click.wav` y `assets/audio/grenades/no_grenade.wav`.
- Al acertar a un enemigo, la mira cambia a amarillo durante 0,18 s. El salto conserva la pulsación hasta 0,12 s para ejecutarla al tocar el suelo; el almacenamiento solo afecta al salto.
- El menú de pausa se dibuja sobre los elementos del HUD y oculta los avisos temporales mientras está abierto. Al reanudar, los avisos pendientes vuelven a su ciclo normal.
