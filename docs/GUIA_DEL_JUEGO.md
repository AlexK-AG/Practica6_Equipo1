# Guía del juego y de su construcción — Sector 07

Estado revisado el 17 de octubre de 2026. Sector 07 es un shooter **3D en primera persona**, escrito en GDScript. `project.godot` declara Godot 4.7 y GL Compatibility; se ha trabajado con Godot 4.7.2. No se confirma compatibilidad con Godot 4.6. Esta guía describe la versión vigente; [DOCUMENTATION.md](../DOCUMENTATION.md) conserva también el historial de versiones anteriores.

## Cómo se juega

La campaña tiene diez niveles consecutivos. Cada uno tiene una misión por fases: eliminar enemigos permite asegurar zonas, pero **las bajas por sí solas no completan la misión**. El panel superior derecho indica el objetivo y sus requisitos. Algunas puertas se desbloquean al completar etapas. El jugador puede repetir sectores completados, recoger equipo omitido y mejorar sus mejores puntuaciones.

Al abrir, el juego recupera el perfil seleccionado si sigue disponible. También se pueden seleccionar o crear perfiles locales por nombre, sin cuentas ni contraseñas. Cada perfil guarda su progreso, récord, elecciones de mejora, descubrimientos, equipo y entrenamiento. Las opciones son generales del equipo. Eliminar un perfil requiere confirmación y elimina sus datos relacionados; reiniciar la campaña conserva su récord e historial.

Los checkpoints conservan estado del jugador, posición, enemigos y avance de misión. El tiempo acumulado de misión se restaura; las estadísticas del nuevo intento cuentan solo la actividad posterior a esa carga. Un checkpoint no equivale a guardar continuamente cada fotograma.

## Campaña y objetivos

| Nivel | Sector | Misión principal |
|---|---|---|
| 1 | Laboratorio | Restaurar energía, conseguir la tarjeta y asegurar la extracción. |
| 2 | Almacén | Transportar dos cargas, preparar el muelle y resistir dos oleadas de tres enemigos cada una. |
| 3 | Reactor | Estabilizar el reactor, recuperar la carga inicial y evacuar durante la purga de 180 segundos. |
| 4 | Fundición | Desactivar controles y volver al horno de emergencia para apagarlo en 120 segundos. |
| 5 | Biocontención | Destruir tres nidos, resistir 90 segundos de purga y eliminar las amenazas. |
| 6 | Fortaleza | Desactivar defensas, recoger tres llaves de mando y eliminar al capitán. |
| 7 | Comunicaciones | Activar enlaces y completar la transmisión. |
| 8 | Hangar de evacuación | Preparar combustible y defender una carga de 150 PV durante 120 s, con refuerzos agrupados y cuatro cajas de munición. |
| 9 | Arsenal orbital | Recuperar tres núcleos, asegurar el arsenal y trasladar una carga desde la sala inicial a la última, con tres cajas de munición y refuerzos cada 7 s. |
| 10 | Núcleo Áureo | Desactivar energía durante las fases del guardián; el encuentro final cierra la arena. |

`scenes/main.tscn` sigue siendo el primer nivel; los siguientes están en `scenes/levels/level_2.tscn` a `level_10.tscn`. Los escenarios tienen paredes, suelos, techos, iluminación propia, suministros y coberturas. Las oleadas y refuerzos pertenecen a objetivos o habilidades concretas: no todos los enemigos reaparecen indefinidamente.

## Controles, HUD y entrenamiento

Los controles predeterminados son WASD para moverse, ratón para mirar y clic izquierdo/derecho para disparar/apuntar. Shift corre, Espacio salta, R recarga, F usa el cuchillo, E interactúa, 1/2 o la rueda cambia el arma, G lanza granada, Q alterna granadas y Esc pausa. El mando usa stick izquierdo/cruceta para moverse, stick derecho para mirar, gatillos para disparar/apuntar, stick izquierdo pulsado para correr, A para saltar/interactuar, X para recargar, B para cuchillo, Y para arma 1, RB/LB para cambiar arma, stick derecho pulsado para granada, botón Atrás para alternarlas y Start para pausa. Las teclas se pueden reasignar desde configuración. Todas estas acciones discretas se consultan desde el Input Map; la orientación de cámara del ratón conserva el evento de movimiento relativo.

En Android/iOS se muestran controles táctiles: joystick fijo en la esquina inferior izquierda; grupo inferior derecho con **FUEGO** al centro y acciones secundarias alrededor; pausa centrada arriba y arrastre en el lado derecho para mirar. **CORRER** y **MIRA** alternan encendido/apagado al tocar. La mira solo aparece con el arma de precisión y aplica zoom 0,5×; el botón de cambio de arma aparece si hay dos armas equipadas. Al acercarte a un objetivo o suministro visible, dentro de 3,5 m y delante del jugador, aparece **PULSA PARA TOMAR**. El multitouch permite mover y accionar botones a la vez. El joystick solo acepta el toque inicial dentro de 1,2 veces su radio desde el centro; no se activa al tocar la zona central. La cámara táctil usa 1,8× la sensibilidad general, acumula los desplazamientos antes de procesarlos y alcanza hasta 3,5 rad/s; el ratón de PC no cambia. En `scenes/ui/hud.tscn`, los nodos `Joystick`, `ShootButton`, `JumpButton`, `MeleeButton`, `GrenadeButton`, `ReloadButton`, `SprintButton`, `WeaponButton`, `AimButton`, `InteractButton` y `PauseButton` se pueden reubicar desde el editor 2D; el script adapta offsets al tamaño, preferencias y safe area. Fuego mide 104 px y los botones secundarios 76 px; el tamaño configurable va de 90 a 120 %, con fuego nunca menor de 96 px. La opacidad es 0,40–0,70 (0,55 inicial), zona muerta 0,15–0,25 (0,20 inicial), con vibración y modo de prueba en PC configurables. La vibración es de 60 ms al recibir daño y 40 ms al recoger suministros; Android necesita permisos `VIBRATE` e `INTERNET`. La pantalla queda horizontal con `canvas_items` y `expand`; los controles respetan la safe area. Ver el README para configurar la sincronización de datos móviles con la web local del PC.

El HUD está en `scenes/ui/hud.tscn`: arriba a la izquierda muestra sector, bajas y tiempo; arriba a la derecha, objetivo; abajo a la izquierda, vida y escudo; abajo a la derecha, arma, cargador, reserva y granadas. Los marcadores distinguen objetivos ámbar y equipo/suministros cian. Para interactuar hay que apuntar y estar suficientemente cerca.

El entrenamiento es opcional y se señala si está pendiente. Presenta **28 pasos independientes**, con introducción al HUD, movimiento, interacción, recogidas, armas, recarga, cuchillo, granadas y seis roles básicos de enemigos. Incluye cobertura simple, cobertura alta y búsqueda enemiga. Cada paso retira las indicaciones anteriores. Sus objetos y enemigos de práctica no conceden equipo ni estadísticas de campaña.

## Armas, munición y mejoras

Los perfiles nuevos empiezan con pistola y cuchillo. El fusil se encuentra en la última sala del nivel 1; la escopeta en el 3, precisión en el 6 y plasma en el 9. Los perfiles que existían antes del cambio del fusil lo conservan. El arma se puede usar al recogerla; **debe completarse la misión para conservar su desbloqueo**. Una recogida omitida se puede recuperar repitiendo su nivel.

| Arma | Cargador base | Reserva inicial base | Función |
|---|---:|---:|---|
| Pistola | 12 | 24 | Disparo semiautomático y preciso. |
| Fusil | 24 | 48 | Fuego automático sostenido. |
| Escopeta | 6 | 8 | Ocho perdigones, eficaz a corta distancia. |
| Precisión | 5 | 8 | Daño elevado por impacto y alcance largo. |
| Plasma | 10 | 12 | Fuego automático con explosión secundaria. |

Son valores base de `scripts/combat/weapon_catalog.gd`; las mejoras pueden modificarlos. Cada arma conserva cargador y reserva propios. Recargar transfiere munición; cambiar de arma o usar el cuchillo cancela la recarga. Los suministros respetan límites de reserva. El cuchillo funciona sin munición y tiene alcance y tiempo de recuperación limitados.

Tras desbloquear equipo, la ventana de equipación permite escoger dos armas diferentes entre las disponibles. Hay tres granadas con existencias independientes: básica desde el inicio, fragmentación en la sala final del nivel 2 y estasis en la sala final del 5. Las especiales también requieren recogerlas y completar el sector; estasis ralentiza enemigos.

Las primeras nueve victorias nuevas ofrecen una elección de mejora según la etapa: vida, daño, escudo, reserva de fusil, recarga, regeneración, cargador, blindaje, cuchillo o movilidad. Cada mejora tiene un límite de rangos. Repetir una misión no concede otra elección. Una elección pendiente se conserva si se cierra el juego.

## Enemigos, coberturas y dificultad

El índice reúne **18 subtipos**, sus imágenes, altura, descripción y táctica; los no descubiertos aparecen atenuados. El catálogo limita su introducción por nivel; la tabla indica el primer nivel permitido, no que todos aparezcan en cada sala posterior.

| Primer nivel permitido | Subtipos incorporados |
|---|---|
| 1 | Explorador, Acechador. |
| 2 | Centinela, Asaltante. |
| 3 | Devastador, Depredador, Escudero. |
| 4 | Comandante, Vigía, Corredor. |
| 5 | Guardián, Cazador, Reanimado. |
| 6 | Espectro, Bastión. |
| 7 | Coloso, Intermitente. |
| 8 | Núcleo. |

Los asaltos buscan ángulos libres; francotiradores mantienen distancia y aumentan daño con la distancia; tanques protegen aliados; kamikazes preparan cargas; curadores se colocan detrás de aliados y muestran enlaces verdes; invocadores anuncian refuerzos y liberan dos unidades cerca de su cuerpo al morir. Escudero protege frontalmente, Bastión protege al grupo, Reanimado puede revivir una vez e Intermitente anuncia su desfase. Los detalles completos están en `scripts/enemies/enemy_catalog.gd` y sus comportamientos en `enemy_tactics.gd`.

La navegación considera obstáculos y puertas, busca recorridos alternativos y evita aliados. Los disparos comprueban línea de tiro; otro enemigo puede bloquearla. Al perder al jugador inspeccionan la última posición vista y sus alrededores antes de volver a vigilar. No conocen continuamente la posición oculta del jugador.

Los enemigos de hasta 1,3 m mantienen su comportamiento de visión desde su altura; los mayores pueden ver y disparar sobre cajas simples si la línea queda libre. Hay cajas dobles para cubrirse de enemigos altos. Una pared o cobertura suficientemente alta sigue bloqueando la visión y activa la búsqueda normal.

| Dificultad | Vida enemiga | Daño | Frecuencia de ataque | Movimiento |
|---|---:|---:|---:|---:|
| Fácil | ×0,85 | ×0,70 | ×0,85 | ×0,85 |
| Normal | ×1 | ×1 | ×1 | ×1 |
| Difícil | ×1,25 | ×1,30 | ×1,25 | ×1,20 |

Son multiplicadores del catálogo; se combinan con la identidad del subtipo y la progresión del nivel. Aumentar dificultad no convierte todos los enemigos en el mismo rol.

## Puntuaciones, opciones y audio

La victoria calcula `100 × bajas + 500 + max(0, 300 − segundos activos de misión) + round(200 × vida / vida máxima)`. La pausa no incrementa ese tiempo. El total actual suma la mejor puntuación de cada nivel; repetirlo mejora ese registro sin acumular puntos repetidos. El récord sobrevive al reinicio de campaña.

Configuración incluye audio, sensibilidad, teclas, dificultad, campo de visión, pantalla completa, resolución, escala de render, brillo, mira, reducción de movimiento/destellos y restablecimiento de valores. La opción de calidad fue retirada de la interfaz. Los cambios de pantalla se confirman con recuperación si no se aceptan. El modo incrustado del editor puede limitar cambios de ventana; para comprobarlos hay que ejecutar el juego en ventana independiente.

El menú usa `assets/audio/menu_tension.wav`; los niveles tienen pistas acordes a su ambiente. Música y efectos tienen volumen configurable. Las armas, recargas, recogidas y granadas tienen efectos propios. Campaign administra la música entre escenas; no se requiere el servidor web para escucharla.

## Arquitectura y escenas editables

| Carpeta de scripts | Responsabilidad |
|---|---|
| `core` | Control del nivel, navegación común, pausa, resultados y transiciones. |
| `player` | Movimiento, cámara, vida, inventario y acciones del jugador. |
| `combat` | Catálogos de armas/granadas y granadas físicas. |
| `enemies` | Catálogo, despliegue, búsqueda, evasión y tácticas. |
| `missions` | Objetivos, primeras/últimas misiones, puertas, marcadores y peligros. |
| `persistence` | Campaign, SQLite y cola de eventos. |
| `ui` | Inicio, HUD, opciones, equipación, mejoras, índices y tutorial. |
| `common` | Utilidades del kit. |
| `visuals` | Materiales, detalles de estación y efectos de combate. |

`project.godot` inicia `scenes/start.tscn` y carga `scripts/persistence/campaign.gd` como autoload `Campaign`. Inicio tiene sus páginas principales guardadas como nodos; el script actualiza datos y conecta señales. Cada nivel usa `scripts/core/game.gd`, instancia al jugador de `scenes/actors/player.tscn`, las variantes de enemigos y el HUD. El controlador configura la misión y delega las condiciones de victoria a sus objetivos. La ventana de mejoras usa su escena UI; la de equipación se construye desde `scripts/ui/loadout_screen.gd`.

`assets/models/enemies`, `props` y `structures` agrupan los modelos OBJ usados; se conservan materiales y referencias. Los originales del kit siguen en `Modular SciFi MegaKit[Standard]/`. `revision/` conserva capturas y herramientas históricas; no es contenido necesario para ejecutar la campaña. `.godot/` es caché generada y también aloja fixtures privados de prueba: no es la carpeta del guardado personal.

## SQLite, eventos y página local

Godot escribe directamente en `user://sector07.sqlite`, normalmente `%APPDATA%/Godot/app_userdata/Sector 07 - Contencion/sector07.sqlite` en Windows. El complemento Godot-SQLite incluido aporta las bibliotecas Windows x86_64. No hace falta Node.js, internet ni servidor para jugar y guardar.

La primera carga importa el antiguo CFG si corresponde; después SQLite es la fuente de datos. Perfiles, configuración y checkpoints preservan tipos de Godot en BLOB y exponen JSON y tablas relacionales para consultas. El esquema 2 añade sesiones y eventos sin reconstruir acciones históricas inexistentes. El esquema 3 conserva hasta 2.400 eventos y 400 intentos por perfil, eliminando los más antiguos y manteniendo acumulados de tiempo, bajas y resultados. Los eventos se guardan cada dos segundos y con cambios de progreso/pausas; un cierre forzado puede perder el último lote pendiente. Las copias `.bak` se actualizan al guardar progreso/configuración, no cada lote periódico.

La web es independiente: `iniciar_web.cmd` inicia Node.js 24 o superior y abre `http://localhost:3000`. `web/server.mjs` consulta la misma base **solo en lectura** y devuelve JSON en `/api/dashboard`; `web/app.js` presenta resumen, jugadores, clasificación, historial, descubrimientos y eventos. Funciona mientras juegas o con el juego cerrado. Hay que mantener abierto el servidor y pulsar **Actualizar** para consultar nuevos datos; no hay refresco automático.

Más detalle: [guardado SQLite](README_SQLITE.md), [eventos](README_EVENTS.md) y [web y sus secciones](../web/README.md).

## Cómo trabajar con el proyecto

1. Importar `project.godot` en Godot y ejecutar Inicio con F5.
2. Abrir escenas de niveles, `start.tscn` o `hud.tscn` para editar sus nodos. Ejecutar un nivel bloqueado o sin perfil redirige a Inicio.
3. Modificar código por responsabilidad y conservar los `.uid`. Mover recursos desde el editor o actualizar todas las rutas y sus metadatos conjuntamente.
4. Comprobar errores GDScript y ejecutar pruebas relevantes en bases privadas con `-- --campaign-test`.
5. Documentar mecánicas y acciones en `DOCUMENTATION.md`; actualizar esta guía cuando cambie el comportamiento vigente.

Las pruebas y herramientas están organizadas en [tests/README.md](../tests/README.md). Esta actualización documental no equivale a ejecutar toda la batería de pruebas de la reorganización.


## Defensa de carga y extracción del arsenal

En el nivel 8, tras preparar combustible y autorizar vuelo, «Iniciar carga» activa
una defensa de **120 segundos**. La carga tiene **150 PV**, visibles en el HUD y
sobre el objeto. Los enemigos pueden acercarse y atacarla; paredes, coberturas y
aliados bloquean los disparos. Acercarte a un atacante puede desviar su atención
hacia ti. Si destruyen la carga, la misión falla; el fuego del jugador no la daña.
Hay cuatro cajas de munición alrededor de la zona de defensa.

Los refuerzos aparecen juntos por tanda: dos cada 6 s durante el primer minuto
(t=6…60), y tres cada 7 s durante el segundo (t=67…116). Son 18 tandas / 44 unidades
programadas si hay espacio válido. Al llegar a 120 s cesan estas tandas y se abre
el embarque; aún debes superar sus defensores. El checkpoint conserva vida de
la carga, tiempo transcurrido, siguiente tanda y suministros consumidos.

En el nivel 9, asegurar la antigua salida abre la fase final: vuelve a la sala
inicial, recoge la carga con sus tres cajas de munición y entrégala en la última
sala. El traslado reduce el movimiento al 80 %. Desde que se habilita el regreso
aparecen uno o dos enemigos cada 7 s en puntos aleatorios válidos del mapa. No
hay que eliminar esos refuerzos para recoger o entregar; cesan al finalizar.
El checkpoint conserva la carga, enemigos, cajas usadas y temporizador.


### Finales ampliados de los sectores 3 a 6
- Reactor (3): purga de 180 s. Recuperar la carga de la sala inicial, custodiada por dos enemigos, y volver a evacuación con ella; movimiento al 80 %. El paso este sigue cerrado.
- Fundición (4): después del grupo final se activa Apagar fragua; volver al horno de emergencia, defendido por cuatro enemigos, y desactivarlo en 120 s. El apagado detiene el reloj y habilita la salida. Agotar el tiempo provoca derrota.
- Biocontención (5): purga de 90 s con cinco o seis refuerzos programados; la extracción exige terminar la purga y eliminar las amenazas restantes.
- Fortaleza (6): recoger tres llaves de mando (oeste, este y central), custodiadas por tres enemigos cada una, antes de asegurar al capitán y acceder al núcleo.
