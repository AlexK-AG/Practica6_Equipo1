# Sector 07 · Web local conectada a SQLite

La página consulta la base local del juego. Por defecto, el servidor solo la lee;
si se activa la sincronización móvil, recibe una copia independiente desde el
celular y la guarda en `sector07.sqlite.mobile-sync.sqlite`. Nunca escribe esa
copia dentro de la base principal del juego de PC. No se necesita Internet: el
envío funciona en la red Wi‑Fi local.

## Arranque rápido en Windows

1. Tener **Node.js 24 o superior**. En este equipo ya está instalado; se
   comprueba con `node --version`.
2. Hacer doble clic en **`iniciar_web.cmd`**, en la raíz del proyecto.
3. Se abrirá el navegador en **http://localhost:3000**. Mantener abierta la
   consola del servidor mientras se usa la web.
4. Jugar normalmente. En la página, pulsar **Actualizar** para volver a leer
   los datos guardados. El juego guarda eventos por lotes cada 2 segundos
   y también al guardar progreso; esperar ese guardado antes de actualizar.
5. Para detener el servidor, pulsar **Ctrl+C** en su consola. Cerrar solo la
   pestaña no detiene el servidor. Detener el servidor no afecta al juego.

La web funciona con el juego cerrado y también mientras está abierto. Si
no existe la base, abrir el juego y crear/seleccionar un perfil primero.
El siguiente Actualizar encontrará la base sin reiniciar el servidor.

También se puede iniciar desde PowerShell en la raíz del proyecto:

```powershell
node web/server.mjs
```

O desde la carpeta `web`:

```powershell
npm start
```

**No hace falta `npm install`**, Python, PostgreSQL ni instalar un servidor SQL.
Se utilizan HTTP y SQLite incluidos en Node.js. Referencia técnica:
[SQLite en Node.js 24](https://nodejs.org/download/release/latest-v24.x/docs/api/sqlite.html).

Abrir `index.html` con doble clic solo muestra la interfaz estática. Para
consultar datos reales hay que entrar a la dirección del servidor local.

## Qué hace cada sección

| Sección | Qué muestra y qué permite hacer |
|---|---|
| **Resumen** | Número de perfiles e intentos, tiempo activo registrado, mejor récord, misiones recientes y resultados. «Actividad por sector» permite elegir tiempo activo o dificultad medida por número/porcentaje de derrotas. Filtro por jugador. El porcentaje de victorias usa intentos con resultado conocido; excluye en curso e interrumpidos. |
| **Jugadores** | Buscar perfiles, consultar récord y progreso, abrir su ficha y acceder a sus partidas o descubrimientos. Son los mismos perfiles del juego; no es un registro de cuentas nuevo. |
| **Clasificación** | Leaderboard real, ordenable por récord, puntos actuales o niveles completados. El récord sobrevive al reiniciar campaña; los puntos actuales suman los mejores resultados de sus niveles. Buscar conserva el puesto global. Agrupa todas las dificultades. |
| **Historial** | Intentos ganados, perdidos, abandonados, en curso o interrumpidos. Filtros por jugador, nivel, dificultad, resultado y periodo; detalle del intento y exportación CSV de la selección filtrada. |
| **Descubrimientos** | Elegir un perfil para consultar armas, granadas, equipación, mejoras, niveles y 18 subtipos de enemigos con imágenes y alturas. Muestra qué está desbloqueado o pendiente. |
| **Partidas y recorridos** | Todos los intentos conservados, filtros y detalle con equipación y reproducción del mapa. Trazo del jugador y enemigos identificados por subtipo, sin trazo. |
| **Registro de eventos** | Disparos, recargas, daño, recogidas, objetivos, oleadas, pausas, cambios de equipo y acciones del menú. Filtros por jugador, acción y texto; detalles y CSV. La opción «Configuración general» muestra cambios de opciones que no pertenecen a un jugador. |

Las tablas se paginan de ocho en ocho. **Exportar CSV** incluye todos los
resultados de los filtros, no solo la página visible. El detalle de una partida
muestra sus últimas 100 acciones para mantener el diálogo manejable; el registro
de eventos permite consultar/exportar el conjunto completo.

### Comparar dificultad por sector

En **Resumen → Actividad por sector**, el selector **Mostrar** alterna el tiempo
activo habitual con **Dificultad · derrotas**. En esta última opción, **Medida**
permite elegir número de derrotas o porcentaje. Cada barra indica también la
muestra como derrotas / partidas resueltas; por ejemplo, **2 / 5 y 40 %**.

El porcentaje se calcula como **derrotas ÷ (victorias + derrotas) × 100**.
Abandonos, partidas en curso e interrumpidas quedan fuera del denominador y no
cuentan como derrotas. Una derrota representa una misión perdida: puede deberse
a la muerte del jugador, al tiempo agotado o a un objetivo fallido. Por eso la
gráfica se rotula «Derrotas», sin afirmar que cada resultado fue una muerte.

Una barra sin victorias ni derrotas muestra **—**, mientras que un nivel con
victorias y ninguna derrota muestra **0 %**. Los porcentajes usan una escala
común de 0–100 %. El número de derrotas y el tiempo se escalan contra el sector
con mayor valor. Se incluyen los acumulados archivados, se respeta el filtro
global de jugador y cada intento cuenta una vez aunque aparezca en las tablas
de resultados y sesiones. Todas las dificultades del juego se agrupan; la
muestra visible ayuda a interpretar niveles con pocos intentos.

Pruebas específicas: `node tests/web/sector_stats.cjs`,
`node tests/web/sector_stats_sqlite.mjs` y
`node tests/web/sector_stats_ui.cjs` desde la raíz. La última requiere el mismo
Playwright/Edge de desarrollo que las otras pruebas de navegador; la web en uso
normal continúa sin dependencias adicionales.

**Ver demostración** carga datos ficticios identificados y separados de los
reales. No los mezcla ni los guarda en SQLite. Al salir de demostración desde el
servidor, intenta recuperar la conexión real. Las exportaciones de demostración
llevan `demostracion` en el nombre.

## Cómo funciona la conexión

```text
Godot (scripts/persistence/campaign_store.gd y game_events.gd)
  guarda perfiles, progreso, resultados y eventos en sector07.sqlite
    Node.js (web/server.mjs) lee SQLite y responde GET /api/dashboard
      Navegador (web/app.js) muestra y filtra la respuesta JSON
```

- **SQLite:** archivo persistente en `%APPDATA%/Godot/app_userdata/Sector 07 - Contencion/sector07.sqlite`.
  Corresponde a `user://sector07.sqlite` en Godot.
- **`server.mjs`:** sirve archivos públicos y abre SQLite con `readOnly` y
  `query_only=ON`. Una transacción corta por solicitud da una lectura coherente
  y se cierra enseguida. No migra, crea, corrige ni escribe perfiles. Abre el
  archivo en cada actualización para reflejar cambios o recuperación del respaldo.
- **`GET /api/dashboard`:** convierte filas SQL en JSON. Une `run_history` con
  `run_sessions` por su ID para no contar dos veces un intento. Envía UUID de
  perfil estables. `profile_events` incluye acciones sin sesión; las opciones
  globales se presentan como «Configuración general».
- **`app.js`:** solicita ese JSON al cargar y al pulsar Actualizar, valida los
  datos y construye estadísticas, filtros, fichas y exportaciones. No accede al
  archivo SQLite. No hay actualización automática periódica.
- **`index.html` y `styles.css`:** estructura y apariencia existentes.
  `catalog.js` y `assets/` aportan nombres e imágenes, no estadísticas.
  `demo.js` solo se utiliza cuando se activa la demostración.
- **`iniciar_web.cmd`:** comprueba Node, inicia el servidor y abre el navegador.
  `package.json` ofrece `npm start` y `npm test`, sin dependencias adicionales.

Por defecto, el servidor escucha solo en `127.0.0.1`; `localhost` significa este
equipo. El modo `--lan` lo hace accesible a dispositivos de la red local y
permite `POST /api/mobile-sync`, protegido con el token `SECTOR07_SYNC_TOKEN`.
Solo los perfiles, progreso, historial, eventos y acumulados móviles se copian;
la base principal de PC sigue en solo lectura y los recorridos móviles no se
transfieren. No se recomienda publicar el puerto ni configurar reenvío en el
router. Editar/eliminar perfiles sigue correspondiendo al juego. La base y los
archivos privados no se sirven como descargas.

Para iniciar la sincronización, sigue los pasos y el comando PowerShell de
[README.md](../README.md#sincronizar-el-móvil-con-la-web-del-pc). La consola
indica la dirección local para introducir en el celular. `GET /api/dashboard`
combina ambas bases de lectura; al pulsar **Actualizar** se ven las partidas
que el teléfono haya enviado.

## Otra ruta o puerto

Si el puerto está ocupado:

```powershell
node web/server.mjs --port 3001 --open
```

Para otra copia del juego o una base de pruebas:

```powershell
node web/server.mjs --db "C:/ruta/sector07.sqlite" --port 3001
```

Las rutas relativas de `--db` se resuelven desde la carpeta donde se inicia el
comando. Se admiten las variables `SECTOR07_DB_PATH` y `PORT`; los parámetros de
línea de comandos tienen prioridad. El lanzador admite los mismos argumentos:
`iniciar_web.cmd --port 3001`.

## Errores y alcance de los datos

- **Sin conexión:** comprobar que la consola esté abierta y la dirección use
  el puerto indicado; pulsar Actualizar.
- **Base no encontrada:** abrir el juego o indicar la ruta con `--db`. La web
  no crea una base vacía por accidente.
- **El juego está guardando:** esperar y volver a actualizar. Una lectura
  bloqueada informa un error y no sustituye los datos por una demo.
- **Versión incompatible/base incompleta:** usar las versiones correspondientes
  del juego y la web. El servidor no cambia el esquema del archivo.
- **Historial incompleto:** los eventos se registran desde que se añadió esa
  función. Perfiles antiguos pueden tener récords/desbloqueos sin historial
  anterior equivalente; no se reconstruyen acciones inventadas.
- **Partida en curso:** muestra el último estado confirmado en SQLite, no una
  comprobación en directo del proceso. Tras un cierre forzado, Godot marca la
  interrupción al arrancar nuevamente. No se inventan un resultado, puntuación
  ni hora de finalización para intentos sin cierre confirmado.

Se presentan hasta **2.400 eventos y 400 intentos por jugador** (300 y 50 páginas de 8 filas). El cupo de eventos combina acciones del juego y del menú. La configuración general tiene un cupo propio de 2.400. Con «Todos los jugadores» se suman los cupos y pueden verse más páginas.

Godot aplica el borrado real de los registros más antiguos al abrir y guardar, mediante el esquema SQLite 4. El dashboard sigue consultando la base del juego en solo lectura y limita su respuesta si esa base todavía no se ha actualizado. `POST /api/mobile-sync` escribe únicamente en la base separada de copias móviles. Los eventos de una partida eliminada desaparecen de la copia móvil al volver a sincronizar, por lo que el cupo de eventos es un máximo, no una cantidad garantizada.

`history_archive` conserva acumulados por jugador/nivel/resultado. Resumen y ficha del jugador suman esos acumulados a los detalles conservados para mantener tiempo total, bajas y resultados. Los filtros del historial y los CSV consultan solo los detalles conservados. Para archivos con muchos perfiles, la paginación SQL sería una mejora futura; los cupos actuales limitan el volumen por perfil.

El código puede subirse a GitHub. La SQLite personal permanece en AppData y no
se incluye en el repositorio. GitHub Pages sirve archivos estáticos: no ejecuta
este servidor ni accede al AppData del equipo.

## Contrato de datos

La API devuelve `schemaVersion: 2`, `databaseSchemaVersion`, `generatedAt`,
`capabilities`, `players`, `runs`, `events`, `retention` y `historyArchive`. La interfaz sigue admitiendo el
contrato 1 para demostración y pruebas existentes.

- Niveles y etapas: **1–10** y **1–9**, respectivamente.
- Perfiles: `id` (UUID), `name`, `record`, `completedLevels`, `scores`,
  `weaponUnlocks`, `grenadeUnlocks`, `discoveredEnemies`, `upgrades`,
  `tutorialCompleted` y `loadout`. Proyecciones SQL más JSON de equipación;
  no se decodifican BLOB de Godot.
- Intentos: `id`, `playerId`, `level`, `difficulty`, `outcome`, `durationSeconds`,
  `score`, `kills`, `startedAt`, `endedAt`, `updatedAt`. Dificultad: 0 fácil,
  1 normal, 2 difícil. Resultados: `victory`, `defeat`, `abandoned`, `in_progress`,
  `interrupted`. Puntuación/final pueden ser nulos sin resultado confirmado.
- Eventos: `id`, `scope` (`game`, `profile`, `system`), `runId`, `playerId`,
  `level`, `type`, `occurredAt`, `payload`. Menú: `runId`/`level` nulos.
  Opciones generales: también `playerId` nulo. Juego: añade `sequence`,
  `missionSeconds` y `activeSeconds`.
- `retention` declara tamaño de página y cupos; `historyArchive` aporta acumulados con `playerId`, `level`, `outcome`, `attempts`, `durationSeconds` y `kills`. Desde la versión 3 de SQLite se conservan estos acumulados; bases 1/2 anteriores se siguen pudiendo consultar.
- Base con esquema 1: perfiles e historial consultables, con
  `capabilities.events: false`. La migración al esquema 2 la hace Godot.
- Error: HTTP 503 y `{ "error": { "code": "...", "message": "..." } }`.
  No se presenta como una respuesta vacía exitosa.

## Pruebas

```powershell
node tests/web/web_server.mjs
```

Verifica SQLite privada, mapeo, unión de sesiones/resultados, cambios confirmados
mientras el servidor está abierto, archivos ausentes/corruptos, versiones,
bloqueos, lectura y rutas HTTP públicas/privadas. No requiere paquetes de pruebas.

Con Playwright y Edge para desarrollo:

```powershell
node tests/web/web_ui.cjs
node tests/web/web_connection.cjs
node tests/web/web_connection.cjs --real
```

`SECTOR07_PLAYWRIGHT_MODULE` permite una instalación existente de Playwright;
no se necesita para usar la web. `web_connection` prueba navegador → HTTP → SQLite
sin interceptar la API. `--real` consulta el guardado real y verifica que sus
bytes queden iguales. Capturas en `.godot/test-results/capturas/web-connected-*.png`.

La interfaz conserva filtros, CSV, datos escapados, navegación adaptable y
separación real/demo. `web/.gdignore` evita importaciones en Godot. No se
modifican reglas de combate, escenas ni estética del juego. El registro de recorridos añade instrumentación a los scripts de persistencia y al controlador del nivel.


## Recorridos de partidas y gráficas

La sección **Partidas y recorridos** permite abrir cada intento y consultar resultado,
equipación, acciones y mapa. El mapa reproduce posiciones reales del jugador y de
enemigos vivos/visibles, con nombres de subtipo y marcador del jefe. Incluye reproducción,
pausa, reinicio, barra de tiempo y velocidades de 0,5× a 4×. El jugador deja un trazo;
los enemigos solo muestran su posición. Los saltos grandes de posición no dibujan un
trayecto inventado. El plano usa las colisiones reales del escenario al comenzar el intento.

El juego nuevo registra muestras X/Z cada medio segundo de **tiempo activo**, sin
pausas, mediante `scripts/persistence/run_replay.gd`. Guarda lotes en la misma SQLite,
esquema **4**, en `replay_runs` y `replay_chunks`. No son eventos de la bitácora y no
consumen sus 2.400 filas por jugador. Se conservan mientras exista su intento (hasta
400 por perfil); eliminar un intento o perfil elimina también su recorrido. Un cierre
forzado conserva solo las muestras ya confirmadas, sin reconstruir el tramo perdido.

**Las partidas anteriores no tienen recorridos**: el detalle lo indica y mantiene
los resultados/eventos que sí existen. Un intento reanudado desde checkpoint registra
su propio tramo, desde cero segundos de ese intento. El tutorial no crea recorridos.
La demostración usa un recorrido y plano ilustrativos rotulados como ficticios.

`GET /api/replay?run=ID` carga el mapa y las muestras de un solo intento al abrirlo,
con lectura consistente y sin escrituras. `GET /api/dashboard` añade `hasReplay`,
`loadout`, `loadoutSource` y `favoriteLoadout`. `replay-data.mjs` es privado;
`replay.js/css`, `equipment.js` y `analytics.js/css` son archivos públicos.

En **Resumen**, la gráfica diaria alterna jugadores únicos que jugaron / intentos
iniciados por fecha local, durante los últimos 30 días con referencia a la última
actividad registrada. Otra gráfica cuenta presencia de armas en las equipaciones
iniciales conocidas por partida (no disparos), y otra, elecciones confirmadas de
mejoras. La ficha de cada jugador muestra su combinación favorita, sin distinguir
orden de slots, e indica empates. No se infiere equipo histórico del perfil actual.
Las estadísticas detalladas están limitadas por el historial conservado; los
acumulados antiguos sin fechas/equipación no se reparten entre días ni armas.

Tras actualizar el proyecto, **reinicia el juego y el servidor web**. Godot migra la
base conservando perfiles y partidas; el dashboard la consulta en solo lectura.
La ruta de sincronización móvil escribe solo en su base separada y requiere `--lan`
y token. No hay que instalar paquetes adicionales ni copiar la base a `web/`.
