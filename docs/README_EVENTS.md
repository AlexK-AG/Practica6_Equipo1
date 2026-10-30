# Registro de eventos local

**Estado vigente: esquema SQLite 4.** El registro de eventos se incorporó en el
esquema 2 y la retención se añadió en el 3; ambas funciones siguen activas en el
esquema 4. Este último también guarda mapas y muestras periódicas del jugador y
los enemigos para reproducir recorridos en la web. Esas muestras viven en
`replay_runs` y `replay_chunks`, separadas de esta bitácora; consulta
[README_SQLITE.md](README_SQLITE.md#esquema-actual-4-recorridos) para el detalle
de almacenamiento.

El registro introducido en el esquema 2 amplía **la misma** `user://sector07.sqlite`. Se actualiza al abrir
el juego, conservando perfiles, configuración, historial y checkpoints. No se
reconstruyen acciones anteriores a esta versión. No hay servidor ni envío de
datos a internet. La web local ya consulta estos datos mediante `web/server.mjs`;
ver [web/README.md](../web/README.md) para el arranque.

## Tablas

- `run_sessions`: un intento de un nivel, asociado al perfil. Conserva nivel,
  dificultad inicial (0 fácil, 1 normal, 2 difícil), fechas UTC, tiempo activo,
  bajas, proceso propietario y estado: `in_progress`, `victory`, `defeat`,
  `abandoned` o `interrupted`.
- `game_events`: acciones de esa sesión. Columnas normales para ID, sesión,
  secuencia, tipo, fecha, segundos de misión y segundos activos del intento.
  `payload_json` guarda los detalles variables de cada tipo de evento.
- `event_log`: vista de eventos con perfil, nivel y dificultad, preparada para
  consultas. Una sesión tiene muchos eventos; no se duplica el perfil completo.
- `profile_events`: creación/selección del perfil, reinicio de campaña, elección
  de mejoras y cambios de configuración. Estas acciones pueden ocurrir en el
  menú sin una partida abierta. La configuración es general: sus filas tienen
  `profile_id IS NULL`; las demás se vinculan a su perfil.
- `run_history` y `leaderboard` siguen conservando sus funciones anteriores.
  `run_history.id = run_sessions.id` para nuevos intentos finalizados. Los
  resultados históricos antiguos pueden no tener sesión ni eventos detallados.

## Eventos del juego

| Tipos | Detalles principales |
|---|---|
| `run_started` | Carga de checkpoint y tiempo acumulado de partida al entrar |
| `run_ended` | Resultado, puntos, bajas y tiempo del intento |
| `session_interrupted` | Última fecha confirmada de una sesión cuyo proceso terminó |
| `shot_fired` | Arma, munición, reserva y número de perdigones; una fila por disparo válido |
| `reload_started`, `reload_completed`, `reload_cancelled` | Arma, transferencia real de balas o motivo de cancelación |
| `weapon_switched`, `loadout_selected` | Cambio válido y equipación elegida |
| `melee_used` | Uso del cuchillo |
| `grenade_used`, `grenade_exploded`, `grenade_selected` | Tipo, cantidad restante o posición de explosión |
| `enemy_hit` | Subtipo, daño efectivo a vida/escudo/núcleo y origen del daño cuando se conoce |
| `enemy_killed` | Muerte definitiva, subtipo y origen conocido; no cuenta dos veces un reviviente |
| `enemy_discovered`, `enemy_spawned` | Nuevo descubrimiento o refuerzo/invocación |
| `player_damaged` | Daño recibido y daño efectivo a vida y escudo |
| `movement_started`, `movement_stopped` | Transiciones de desplazamiento efectivo |
| `sprint_started`, `sprint_ended`, `jumped` | Carrera y salto aceptado |
| `level_paused`, `level_resumed` | Cambios reales de pausa, incluida pérdida de foco/equipación |
| `weapon_found`, `grenade_found` | Objeto y arma/granada recogida |
| `supply_collected` | Identidad de la caja recogida, incluida la reserva oculta |
| `supply_received` | Aumento efectivo de salud/granadas e inventario antes/después; incluye entregas y oleadas |
| `objective_completed` | Objetivo completado y si era el final; cubre los diez niveles |
| `checkpoint_created`, `wave_started` | Estado del checkpoint generado y número de oleada |
| `level_completed` | Puntos, puntuación total y armas/granadas encontradas al completar el nivel |

`profile_events` usa `profile_created`, `profile_selected`, `campaign_reset`,
`upgrade_chosen` (etapa 1–9 e identificador de mejora) y `settings_changed`
(grupo cambiado y valores anterior/nuevo). Una confirmación de opciones que no
cambia valores no genera otro evento. La selección de mejora se registra tanto
desde la victoria como desde el menú, incluso tras cerrar y reabrir el juego.

Encontrar un arma/granada y desbloquearla permanentemente son momentos distintos:
la recogida se registra inmediatamente; se conserva al completar la misión,
según las reglas existentes. `unlocks` sigue indicando qué está desbloqueado.
Los eventos no conceden puntos, vida ni objetos. Actualmente no hay monedas:
no se inventan eventos ni una mecánica de moneda para llenar estadísticas.

El entrenamiento opcional queda fuera de los eventos de campaña. Las entradas
de movimiento registran transiciones, no cada fotograma, tecla o movimiento
del ratón. La bitácora no guarda posiciones por fotograma ni cada punto de regeneración. El recorrido del esquema 4 guarda muestras de posición separadas cada 0,5 s.
El ID de enemigo distingue instancias dentro de una sesión; no identifica al
mismo enemigo a través de un checkpoint y un intento nuevo.

## Guardado y recuperación

`scripts/persistence/game_events.gd` mantiene una cola propiedad de `Campaign`, que sobrevive a los
cambios de escena. Se escribe mediante transacciones cada **2 segundos** y en
las pausas. Recogidas, objetivos y checkpoints incorporan la cola al guardado
del progreso; la finalización incorpora eventos y resumen del intento. Los
eventos de perfil y de opciones se guardan con su cambio correspondiente.
Las secuencias y los IDs únicos evitan duplicados al reintentar un lote.

Si una escritura falla, el lote permanece en memoria para reintentar, y se
informa mediante `Campaign.save_error` y un aviso de Godot. Un fallo persistente
que dure hasta cerrar el proceso no puede garantizar la conservación de esa
cola. Un cierre forzado puede perder la actividad posterior al último lote
confirmado, normalmente hasta 2 segundos. Al abrir de nuevo el juego se marca
como `interrupted` el intento cuyo proceso ya no existe, usando su último
tiempo confirmado; nunca se inventa una victoria, derrota o tiempo posterior.

Las copias `.bak` se actualizan con los guardados de progreso/configuración,
no con cada lote periódico, para no copiar una base creciente cada 2 segundos.
Si se recupera una base dañada se restaura lo que contenía esa última copia.
Eliminar un perfil elimina en cascada sus sesiones y eventos; reiniciar la
campaña conserva el historial. Los cambios de opciones generales no pertenecen
a un perfil y no se eliminan al borrar un jugador.

## Consultas de ejemplo

```sql
SELECT profile_id, level_number, event_type, occurred_at, payload_json
FROM event_log ORDER BY occurred_at DESC, session_id, sequence DESC LIMIT 100;

SELECT profile_id, level_number, outcome, duration_seconds, kills
FROM run_sessions ORDER BY started_at DESC;

SELECT profile_id, event_type, COUNT(*) AS total
FROM event_log GROUP BY profile_id, event_type;

SELECT profile_id, event_type, occurred_at, payload_json
FROM profile_events ORDER BY occurred_at DESC;
```

La API local `GET /api/dashboard` lee estas tablas y las adapta al contrato web 2.
Incluye intentos activos/interrumpidos y acciones del menú sin fila en
`run_history`. El navegador consulta el servidor; el servidor abre SQLite
solo en lectura. Detalles en [web/README.md](../web/README.md).

## Verificación

Siempre usar `-- --campaign-test`. `tests/persistence/sqlite_events.gd` utiliza una base
privada y verifica migración desde esquema 1, disparo/recarga, pausas,
movimiento, recogidas reales, daño, granadas, rollback, reintentos sin duplicados,
interrupciones, aislamiento del tutorial, reinicio y eliminación de perfiles.
Su modo `--reload-only` verifica los eventos en otro proceso. Los fallos SQL
provocados por las pruebas están identificados como intencionales.


## Retención del historial — introducida en esquema 3

Estos límites y acumulados se mantienen en el esquema 4. La etiqueta «esquema
3» señala cuándo se añadió la función, no el esquema requerido actualmente.

- Máximo **2.400 eventos por jugador** (300 páginas de 8 filas), combinando game_events y profile_events del perfil. Los cambios generales con perfil nulo tienen otro cupo de 2.400.
- Máximo **400 intentos únicos por jugador** (50 páginas), contando una sola vez un resultado que esté tanto en run_history como en run_sessions. Se priorizan las sesiones en curso; se eliminan primero los intentos antiguos cerrados.
- La limpieza ocurre al abrir/migrar la base y en cada transacción de guardado/lote. No afecta al estado del perfil, puntuaciones, mejoras, configuración ni desbloqueos. Los eventos de intentos eliminados se borran en cascada, aunque no se haya alcanzado su cupo independiente.
- Antes de eliminar intentos se suman sus cantidades, duración activa y bajas en history_archive, agrupados por perfil/nivel/resultado. No conserva IDs, fechas ni detalles de esos intentos. El tiempo total y los totales de resultados de la web suman registros conservados y acumulados; los CSV exportan únicamente detalles conservados.
- La migración desde esquemas 1/2 es automática en Godot. La web sigue siendo de lectura y limita también su respuesta para bases anteriores; no escribe ni limpia el archivo por sí sola. Para aplicar el borrado real hay que abrir el juego actualizado.
- SQLite puede reutilizar las páginas liberadas: eliminar filas no implica que el archivo disminuya de tamaño inmediatamente. Reiniciar una campaña conserva los acumulados; eliminar el perfil los elimina en cascada.
- `tests/persistence/sqlite_retention.gd` verifica migración, cupos independientes, orden, partida activa, duplicados entre tablas, duración acumulada, limpieza repetida y rollback de una limpieza fallida.


## Recorridos (esquema 4)

Las posiciones periódicas se guardan aparte en `replay_runs`/`replay_chunks`, no como
eventos de movimiento. Así, la animación no agota el cupo de 2.400 eventos. Registra
jugador y enemigos cada 0,5 s de tiempo activo; el mapa y la equipación inicial
pertenecen al intento. Se eliminan con la partida/perfil y no reconstruyen intentos
antiguos. Los eventos `movement_started`/`movement_stopped` conservan su significado.
