# Pruebas y herramientas

Los archivos se conservan organizados por responsabilidad. Ejecutar desde la raíz del proyecto. Estas instrucciones no implican que cada prueba se haya ejecutado tras la reorganización.

| Carpeta | Alcance |
|---|---|
| `campaign/` | Flujo de diez niveles, misiones iniciales/finales, expansión, salas, sectores, suministros y desbloqueo del fusil. |
| `enemies/` | Navegación, búsqueda, evasión, altura/cobertura, dificultad, tácticas y retroalimentación de enemigos. |
| `combat/` | Granadas, último disparo y apariencia de combate. |
| `ui/` | HUD, Inicio, opciones, equipación y entrenamiento. |
| `persistence/` | Perfiles, migración SQLite, historial, eventos, transacciones y recuperación. |
| `world/` | Estación, superficies y visibilidad por ambas caras. |
| `audio/` | Música de menú/niveles y efectos de armas. |
| `helpers/` | Controladores compartidos de misiones, navegación y tutorial; rutas de resultados. |
| `tools/` | Galerías, capturas y generación de previews. Son herramientas, no todas son pruebas pasivas. |
| `web/` | Servidor HTTP/SQLite, interfaz de navegador, lectura intacta de la base PC y sincronización autenticada de snapshots móviles. |

## Godot

Usar siempre **`-- --campaign-test`** para aislar el guardado del usuario. Las pruebas de persistencia emplean bases privadas dentro de `.godot/`; no sustituir sus rutas por la SQLite personal.

```powershell
& "C:/Program Files/Godot/Godot.exe" --headless --path . --script tests/persistence/sqlite_storage.gd -- --campaign-test
& "C:/Program Files/Godot/Godot.exe" --headless --path . --script tests/persistence/sqlite_events.gd -- --campaign-test
& "C:/Program Files/Godot/Godot.exe" --headless --path . --script tests/persistence/sqlite_history.gd -- --campaign-test
& "C:/Program Files/Godot/Godot.exe" --headless --path . --script tests/campaign/campaign.gd -- --campaign-test
```

`sqlite_storage.gd`, `sqlite_events.gd` y `campaign.gd` tienen modos `--reload-only` que deben ejecutarse después de su prueba inicial, en otro proceso, conservando el fixture creado. `sqlite_storage.gd --existing-save-check` comprueba una copia del CFG anterior sin modificar su origen. Las pruebas de fallo provocan errores SQL intencionales de bloqueo, corrupción o rollback; revisar el resultado final además del log.

Las pruebas visuales necesitan un renderizador y ventana adecuados: omitir `--headless` cuando se capturan imágenes o se comprueba la ventana. Las herramientas de `tools/` pueden regenerar previews dentro de `assets/` o modificar escenas de prueba; revisar su código antes de ejecutarlas. No lanzar toda esa carpeta como si fueran verificaciones de solo lectura.

No ejecutar en paralelo pruebas que compartan el fixture por defecto `campaign-tests.sqlite`. Los resultados nuevos y capturas se guardan bajo `.godot/test-results/{logs,capturas}` cuando la herramienta genera estos archivos; los fixtures SQLite conservan sus rutas privadas existentes. Los registros históricos en `revision/` no se borran ni se trasladan.

## Web

Node.js 24 o superior; para la prueba del servidor no hay que instalar paquetes.

```powershell
node tests/web/web_server.mjs
node tests/web/web_ui.cjs
node tests/web/web_connection.cjs
```

Las dos últimas requieren Playwright y Edge de desarrollo. `SECTOR07_PLAYWRIGHT_MODULE` permite indicar una instalación existente. Esto es una dependencia de las pruebas, no de la web en uso normal. `web_connection.cjs --real` realiza una consulta explícita al guardado real y comprueba que no cambien sus bytes; no es necesario para las pruebas aisladas habituales.

El servidor se inicia con `iniciar_web.cmd` o `node web/server.mjs`. Ver [web/README.md](../web/README.md) para los comandos, contrato API y límites de funcionamiento.


## Retención del historial
`tests/persistence/sqlite_retention.gd` comprueba 300 páginas de eventos y 50 de intentos por perfil, mezclando eventos de juego/menú y resultados/sesiones duplicadas, opciones globales, protección de sesión activa, migración al esquema vigente, acumulados e integridad transaccional. Usa siempre --campaign-test. Las pruebas web incluyen paginación de 300/50 páginas y mantenimiento de métricas acumuladas.


## Reproducción y estadísticas web

- `godot --headless --path . --script tests/persistence/sqlite_replay.gd -- --campaign-test`:
  crea `.godot/replay-private.sqlite`, migra 3→4 y verifica mapa/movimientos reales,
  equipación, retención e integridad en niveles 1/3/4/10.
- `node tests/web/replay.cjs`: después de la anterior, prueba SQLite→HTTP→navegador,
  reproducción, pausa, velocidad, barra temporal, subtipos, móvil, equipación/favorita,
  intentos antiguos y ausencia de escrituras. Requiere Playwright/Edge como las demás
  pruebas de navegador; no es una dependencia de la web.
- `node tests/web/analytics.cjs` y `node tests/web/equipment.mjs`: cálculo diario,
  deduplicación, desconocidos, empates, atribución histórica y HTML seguro.

Todas usan bases privadas. Las capturas se guardan en `.godot/test-results/capturas/`.


## Misiones de carga

- `godot --headless --path . --script tests/campaign/hangar_defense.gd -- --campaign-test`:
  defensa 120 s / 150 PV, tandas 2/6 s y 3/7 s, 44 refuerzos, munición, daño real,
  HUD, final, checkpoint y destrucción.
- `godot --headless --path . --script tests/campaign/arsenal_delivery.gd -- --campaign-test`:
  nueva extracción del nivel 9, presión 1–2/7 s, tres suministros, entrega con
  refuerzos vivos y restauración de checkpoints nuevos/anteriores.


`tests/campaign/sector_finales.gd` comprueba los finales ampliados de los sectores 3–6: carga de evacuación, horno de emergencia, tres llaves, purga de 90 s, relojes, rutas, guardias y checkpoints. Ejecutar con `-- --campaign-test`.
