# Guardado local en SQLite

**Estado vigente: esquema 4.** Esta guía describe el esquema actual y conserva
referencias a los esquemas 2 y 3 únicamente para explicar la evolución y las
migraciones. El esquema 4 añade los recorridos de partidas; perfiles, progreso,
eventos e historial siguen almacenándose en la misma base.

El juego guarda directamente en `user://sector07.sqlite`; no necesita Node.js,
Python, un servidor abierto ni conexión a internet. En Windows, con el nombre
actual del proyecto, corresponde a:

`%APPDATA%/Godot/app_userdata/Sector 07 - Contencion/sector07.sqlite`

## Migración y recuperación

En el primer arranque se importa automáticamente `campaigns.cfg` (o su `.bak`
si el principal no se puede leer). Se conservan perfiles, puntos, récords,
mejoras, desbloqueos, descubrimientos, equipación, entrenamiento, configuración,
teclas y checkpoints completos. Se mantienen las migraciones históricas de
versiones anteriores. El CFG original no se modifica ni se elimina.

Una vez inicializada la base, SQLite es la fuente del guardado. Un perfil
eliminado no vuelve a importarse del CFG. Se conserva `sector07.sqlite.bak`
mediante la función de respaldo de SQLite después de guardar. Si la base falta
o está dañada y el respaldo es válido, se recupera. La base dañada se conserva
con un sufijo `.corrupt-...`. Una versión de esquema futura bloquea la escritura
para evitar degradar datos. Los cambios se guardan mediante transacciones.

## Datos consultables

| Tabla o vista | Información |
|---|---|
| `profiles` | Identidad, UUID estable, récord, mejora pendiente, tutorial y estado completo |
| `level_progress` | Nivel 1–10, completado y mejor puntuación |
| `unlocks` | Armas, granadas y enemigos descubiertos |
| `upgrades` | Mejora elegida en cada etapa |
| `settings` | Audio, sensibilidad, pantalla, accesibilidad y teclas |
| `run_history` | Victorias, derrotas y abandonos desde esta versión |
| `run_sessions` | Intentos activos, finalizados e interrumpidos |
| `game_events` / `event_log` | Acciones con secuencia, tiempos y detalles, asociadas al intento |
| `profile_events` | Acciones del perfil, mejoras y cambios de configuración |
| `leaderboard` | Récord y progreso por jugador para la clasificación local |
| `history_archive` | Acumulados de intentos antiguos eliminados por retención; esquema 3 |
| `metadata` | Versión, perfil seleccionado y origen de migración |

Los BLOB `state`/`value` preservan sin pérdidas los tipos de Godot, incluidas
posiciones y arrays de los checkpoints. `state_json`/`value_json` facilitan
consultas externas; las tablas de progreso y desbloqueos tienen columnas SQL
normales. Las proyecciones se actualizan junto con el estado en la misma
transacción. La web local consulta estos datos en lectura; no se deben modificar solo las
proyecciones, porque el juego restaura el estado completo.

`run_history` registra nivel, dificultad, resultado, puntuación, bajas, tiempo
activo y fechas UTC por intento. Al cargar un checkpoint, el historial cuenta
solo el tiempo y bajas nuevos del intento; el tiempo acumulado de misión se
conserva en el checkpoint. Entrar en el entrenamiento no crea partidas de
campaña. Reiniciar la campaña conserva el historial y récord; eliminar un
perfil elimina también sus registros relacionados. Un mismo resultado no se
inserta dos veces. Los intentos se cierran al ganar, perder, reiniciar, volver
al menú o salir normalmente; un cierre forzado del proceso no inventa un
resultado. No se reconstruye un historial que el guardado anterior no tenía.

La interfaz web de consulta está conectada mediante `web/` (ver [web/README.md](../web/README.md)).
El registro de eventos se incorporó en el esquema 2 y continúa en el esquema
vigente; consulta [README_EVENTS.md](README_EVENTS.md) para tipos, consultas y
límite de retención. El esquema 4 añade mapas y muestras de recorrido, que la
web solicita para cada partida y representa como trazo del jugador. La web se
conecta mediante Node.js: el dashboard lee la base del juego en solo lectura.
La sincronización móvil opcional guarda copias en `sector07.sqlite.mobile-sync.sqlite`,
sin escribir en la base principal del PC; los recorridos móviles no se transfieren.
Ejecuta `iniciar_web.cmd` y entra a `http://localhost:3000`; ver [web/README.md](../web/README.md).

## Dependencia y pruebas

Se incluye [Godot-SQLite v4.8](https://github.com/2shady4u/godot-sqlite/releases/tag/v4.8)
(MIT), con bibliotecas para Windows x86_64 y Android arm64/x86_64, en variantes
debug y release. Así, la misma capa de guardado SQLite puede usarse en el editor,
PC, teléfonos Android de 64 bits y emuladores x86_64; no cambia el esquema. La
lógica del juego y de la persistencia está escrita en GDScript. Otros destinos
requieren sus bibliotecas correspondientes del complemento.

Siempre pasar `-- --campaign-test` al ejecutar pruebas: evita el guardado real.
`tests/persistence/sqlite_storage.gd` verifica migración, valores completos, consultas, transacciones,
concurrencia, copias, corrupción, eliminación y versiones futuras. Su modo
`--reload-only` comprueba persistencia en otro proceso; `--existing-save-check`
prueba una copia del CFG real sin alterarlo. Las pruebas de fallo provocan
intencionalmente errores SQL de bloqueo, rollback y archivo corrupto.
`tests/persistence/sqlite_history.gd` verifica los resultados y tiempos en escenas reales.

El controlador principal de guardado está en `scripts/persistence/campaign.gd`,
las consultas en `scripts/persistence/campaign_store.gd` y la cola de eventos
en `scripts/persistence/game_events.gd`. Más comandos en [tests/README.md](../tests/README.md).


## Retención automática
La retención, incorporada en el esquema 3 y vigente en el 4, conserva hasta
2.400 eventos y 400 intentos únicos por perfil (300 y 50 páginas de 8 filas).
Se aplica al abrir y guardar; elimina primero lo más antiguo y conserva los
acumulados de tiempo, bajas y resultados en `history_archive`. No cambia
progreso, equipo ni récords. Las opciones generales tienen 2.400 eventos
propios. Los eventos de intentos eliminados también se eliminan. Véanse [los
detalles de retención](README_EVENTS.md#retención-del-historial--esquema-3).


## Esquema actual: 4, recorridos

`replay_runs` guarda mapa y equipación por sesión; `replay_chunks` guarda lotes JSON
de posiciones con índice estable y tiempo activo. Ambos se enlazan mediante claves
foráneas con borrado en cascada. Las muestras cada 0,5 s se escriben en las mismas
transacciones que sesiones/eventos, sin consumir el cupo de bitácora. La retención de
400 intentos elimina sus recorridos; la limpieza de eventos no los elimina. La
migración crea las tablas sin inventar posiciones antiguas y conserva los perfiles.
La web consulta un intento bajo demanda en `/api/replay?run=ID`, solo en lectura.
