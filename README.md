# Sector 07 — Contención

![Logo de Sector 07](icon.svg)

**Shooter 3D en primera persona desarrollado en Godot con GDScript**, ambientado en una estación de ciencia ficción. Combina combate, exploración, misiones por etapas y gestión de recursos a lo largo de diez niveles.

El proyecto incluye **persistencia local en SQLite**, un **leaderboard por perfiles** y una **web local para consultar progreso, resultados y eventos del juego**.

## Contenido del juego

- **10 niveles** con objetivos propios: restaurar energía, transportar cargas, resistir oleadas, estabilizar instalaciones, defender transmisiones y enfrentarse al jefe final.
- **18 subtipos de enemigos**, con roles de asalto, francotirador, tanque, kamikaze, curador, invocador, escudo, resurrección y desfase.
- **5 armas de fuego y un cuchillo**, con munición limitada, recargas y equipación de dos armas diferentes.
- **3 tipos de granada:** básica, fragmentación y estasis, que ralentiza enemigos.
- **Desbloqueos y mejoras permanentes por perfil**, con equipo que se encuentra durante las misiones.
- **Coberturas, cajas dobles y búsqueda enemiga:** los enemigos reaccionan a obstáculos, aliados y pérdida de visión.
- **Checkpoints, pausa y tres dificultades:** Fácil, Normal y Difícil.
- **Entrenamiento opcional de 28 pasos**, que explica HUD, controles, interacción, combate y coberturas.
- **Feedback audiovisual de combate y movimiento**, con balanceo de cámara, vibración de explosiones, señales de impacto, colores por arma y sonidos reactivos.

Las bajas ayudan a asegurar sectores, pero **cada nivel se completa cumpliendo sus objetivos**, no únicamente eliminando enemigos.

## Requisitos

| Componente | Requisito |
|---|---|
| Juego desde el proyecto | Godot **4.7.2**, versión con la que se verificó el proyecto. |
| Plataformas incluidas | **Windows de 64 bits** y Android arm64/x86_64, con bibliotecas nativas de SQLite incluidas. |
| Web local | **Node.js 24 o superior** y un navegador actual. |
| Base de datos | SQLite integrado mediante el complemento incluido; no requiere instalar un servidor SQL. |

**Para jugar y guardar no se necesita Node.js ni tener la web abierta.** Node.js se utiliza únicamente para el servidor de consulta local. Otras plataformas necesitan las bibliotecas correspondientes de Godot-SQLite; este repositorio incluye las de Windows x86_64.

## Ejecutar el juego

1. Clona el repositorio o descarga y extrae su ZIP.
2. En Godot, importa el archivo [`project.godot`](project.godot).
3. Deja que el editor importe los recursos y ejecuta el proyecto con **F5**.
4. Crea o selecciona un perfil. Puedes comenzar por el entrenamiento opcional.

La escena inicial es `scenes/start.tscn`. No es necesario crear tablas, configurar credenciales ni ejecutar scripts SQL manualmente.

### Controles principales

| Acción | Control predeterminado |
|---|---|
| Moverse / mirar | WASD / ratón; mando: stick izquierdo o cruceta / stick derecho |
| Disparar / apuntar | Clic izquierdo / derecho; mando: gatillos derecho / izquierdo |
| Correr / saltar | Shift / Espacio; mando: stick izquierdo pulsado / A |
| Interactuar | E; mando: A |
| Recargar / cuchillo | R / F; mando: X / B |
| Cambiar arma | 1, 2 o rueda; mando: Y, RB / LB |
| Lanzar / cambiar granada | G / Q; mando: stick derecho pulsado / botón Atrás |
| Pausa | Esc; mando: Start |

La configuración permite reasignar teclas y ajustar audio, sensibilidad, dificultad, pantalla y opciones visuales. Teclado, ratón y mando activan las mismas acciones del Input Map; el stick usa zona muerta predeterminada de 0,2.

En Android/iOS aparecen un joystick fijo en la esquina inferior izquierda y un grupo de acciones en la esquina inferior derecha: **FUEGO** queda al centro y salto, cuchillo, granada, recarga, correr, cambio de arma y mira se distribuyen alrededor con botones secundarios compactos. Correr y la mira del arma de precisión se activan/desactivan al tocar. Cambio de arma aparece cuando hay dos armas en el equipo; mira aparece solo con el arma de precisión equipada. Al acercarte a un objetivo o suministro visible y mirarlo, aparece **PULSA PARA TOMAR**. El multitouch permite mover y usar varias acciones a la vez; arrastrar a la derecha permite mirar. El joystick solo se activa al tocar dentro de un radio de 1,2 veces su radio visual; tocar el centro de la pantalla ya no inicia el movimiento. La mirada táctil aplica 1,8× la sensibilidad general y hasta 3,5 rad/s; el ajuste general sigue determinando la sensibilidad base. Las muestras de arrastre se acumulan antes del paso de física para que no se descarten entre sí. La orientación es horizontal y el HUD deja libre el área de acción.

### Pantalla movil

En **Configuración → Controles y pantalla táctil** puedes ajustar opacidad (0,40–0,70; inicio 0,55), tamaño (90–120 %), zona muerta del joystick (0,15–0,25; inicio 0,20) y vibración. También se pueden forzar los controles en PC; `project.godot` activa **Emular toque desde ratón** para probarlos. La vibración usa 60 ms al recibir daño y 40 ms al recoger suministros. El preset Android incluye permisos `VIBRATE` e `INTERNET`.

Parámetros de referencia de la interfaz táctil:

| Parámetro | Valor usado |
|---|---|
| Radio del joystick | 88 px (base circular de 176 px); activación flotante en el lado izquierdo |
| Zona muerta | 0,20; ajustable de 0,15 a 0,25 |
| Tamaño de controles táctiles | Fuego 104 × 104 px; acciones secundarias 76 × 76 px (ajustables visualmente de 90 a 120 %; Fuego conserva al menos 96 px) |
| Activación del joystick | Dentro de 1,2 × su radio visual desde el centro; radio efectivo inicial ≈ 120 px |
| Sensibilidad de mirada móvil | 1,8 × la sensibilidad general; giro limitado a 3,5 rad/s (ratón de PC no cambia) |
| Opacidad | 0,55 inicial; ajustable de 0,40 a 0,70 |
| Vibración | 60 ms por daño; 40 ms al recoger suministros |
| Orientación y stretch | Horizontal (Landscape), `canvas_items` + `expand` |
| Interacción de objetivo/suministro | Hasta 3,5 m, con el objeto visible y dentro del campo de mirada; el botón contextual se oculta al alejarse |

El complemento SQLite incluye bibliotecas Android `arm64-v8a` para teléfonos de 64 bits y `x86_64` para emuladores; activa la arquitectura correspondiente en el preset de exportación. Consulta [la guía de SQLite](docs/README_SQLITE.md).

## Game feel y retroalimentación

#### Input buffering

- El salto conserva la pulsación durante **0,12 segundos**. Si se pulsa justo antes de aterrizar, se ejecuta al tocar el suelo.
- El buffer solo se aplica al salto; los ataques no guardan entradas pendientes.

#### Coyote time

- El salto puede iniciarse hasta **0,10 segundos** después de abandonar un borde. Se combina con el buffer de 0,12 segundos y usa la misma acción `jump` para teclado, gamepad y controles táctiles.

#### Screenshake y movimiento de cámara

- La cámara tiene un balanceo leve al caminar, algo más marcado al correr. Es un movimiento rítmico de pasos, separado de las vibraciones por impactos.
- Las granadas hacen vibrar la cámara según la distancia: la de fragmentación usa la intensidad mayor; la básica y la de estasis tienen vibraciones más suaves. La opción **Movimiento reducido** desactiva ambos efectos de cámara.
- Actualmente no se añade screenshake al recibir daño ni al aterrizar.

#### Feedback visual, sonoro y de interfaz

- **HUD:** muestra vida, escudo, arma, cargador, reserva, granadas, bajas, tiempo y objetivo activo. También indica recarga, munición agotada y estado de regeneración; los cambios de objetivo aparecen en una notificación temporal.
- **Señales visuales de combate:** el disparo produce destello y retroceso del arma/cámara; el impacto en un enemigo convierte brevemente la mira en una “×” ámbar. Los rayos identifican el arma: violeta para plasma, naranja para precisión y cian para las demás.
- **Daño y estados:** recibir daño produce un destello rojo. Bajo el 50 % de la vida máxima aparece una nube roja en los bordes, que crece al bajar la salud; el HUD resalta vida crítica bajo el 30 %. La granada de estasis ralentiza al jugador si explota cerca y muestra una bruma azul mientras dura el efecto.
- **Avisos de salud:** bajo el 40 % suena un latido que se acelera y aumenta de intensidad cuanto menor es la vida. Al recuperarla, se reproduce un zumbido grave, ascendente y de volumen bajo, con pausas entre repeticiones.
- **Audio de acciones:** hay sonidos de disparo y recarga por arma, lanzamiento y explosión por tipo de granada, recogida de suministros/objetos y avisos distintos al quedarse sin balas o sin granadas.

## Base de datos SQLite

El juego crea automáticamente **`sector07.sqlite`** en la carpeta de datos del usuario. En Windows:

```text
%APPDATA%\Godot\app_userdata\Sector 07 - Contencion\sector07.sqlite
```

En Godot, esa ubicación se identifica como `user://sector07.sqlite`. **La base personal no se guarda dentro del repositorio. Cada equipo y usuario del sistema tiene su propio archivo**, que puede contener varios perfiles del juego.

### Qué se guarda

| Datos | Información registrada |
|---|---|
| Perfiles | Nombre, identificador estable, perfil seleccionado y entrenamiento completado. |
| Progreso | Niveles completados, mejores puntuaciones, récord, mejoras y desbloqueos. |
| Checkpoints | Estado del jugador, inventario, posición, enemigos y avance de misión. |
| Configuración | Opciones generales, audio y controles. |
| Intentos | Nivel, dificultad, resultado, puntos, bajas y tiempo activo. |
| Eventos | Disparos, recargas, daño, recogidas, objetivos, granadas, pausas y acciones de perfiles/configuración. |

La misma base contiene el guardado y el registro de actividad. Utiliza tablas relacionales para consultas, JSON para detalles variables y BLOB para conservar los tipos de Godot del estado guardado.

- Los eventos se guardan por lotes aproximadamente cada **2 segundos**, y también al guardar progreso o pausar.
- Se utilizan transacciones y un respaldo `.bak`, actualizado con los guardados de progreso/configuración.
- Al reanudar un checkpoint, el nuevo intento cuenta únicamente el tiempo y las bajas adicionales, evitando duplicarlos en las estadísticas.
- Reiniciar una campaña conserva el récord y el historial. Eliminar un perfil elimina sus registros relacionados.
- Un cierre forzado puede perder el último lote pendiente; una sesión sin cierre normal se identifica como interrumpida cuando el juego vuelve a arrancar.
- Los eventos e intentos anteriores a la incorporación de su registro no se reconstruyen artificialmente.

El **tiempo activo** de la web es la suma del tiempo de los intentos registrados; excluye pausas y menús. No representa necesariamente todo el tiempo jugado antes de que existiera el historial.

Los guardados CFG de versiones anteriores se migran automáticamente cuando corresponde. Consulta [la documentación de SQLite](docs/README_SQLITE.md) y [el registro de eventos](docs/README_EVENTS.md) para conocer tablas, recuperación y límites.

### Límites del historial

Se conservan **2.400 eventos (300 páginas) y 400 intentos (50 páginas) por perfil**, con 8 filas por página. Al superar un límite se eliminan primero los registros más antiguos. Las acciones del juego y del menú comparten el cupo de eventos; la configuración general tiene un cupo independiente de 2.400 eventos.

La limpieza se aplica al abrir el juego y en las transacciones de guardado. Desde el esquema 3 se guardan acumulados de los intentos eliminados, por lo que **el tiempo activo total, las bajas y los totales de resultados se mantienen**, además del progreso, equipo y récord. El historial detallado y el CSV solo contienen los registros conservados. Eliminar una partida antigua también elimina sus eventos asociados; por eso puede haber menos de 2.400 eventos.

## Leaderboard y puntuaciones

La clasificación utiliza **los datos reales de los perfiles guardados en SQLite**. Permite ordenar por:

- **Récord de campaña:** la mejor puntuación total alcanzada; se conserva al reiniciar la campaña.
- **Puntos actuales:** suma de la mejor puntuación de cada nivel de la campaña actual.
- **Progreso:** cantidad de niveles completados.

La puntuación de una victoria considera bajas, tiempo de misión y vida restante. Repetir un nivel puede mejorar su mejor resultado, pero no suma indefinidamente los puntos de cada repetición.

Por defecto, el leaderboard es local y reúne los perfiles de esa base. La sincronización opcional de móvil agrega copias de sus perfiles al archivo web del PC sin modificar la base usada por el juego de PC ni publicar datos en Internet.

## Iniciar la web local

1. Abre el juego al menos una vez y crea o selecciona un perfil para generar su base.
2. Instala Node.js 24 o superior si no está disponible. Comprueba la versión con `node --version`.
3. Haz doble clic en [`iniciar_web.cmd`](iniciar_web.cmd).
4. El navegador se abrirá en **http://localhost:3000**.
5. Mantén abierta la consola del servidor y pulsa **Actualizar** en la página para volver a consultar los datos guardados.

También puedes iniciar el servidor desde una terminal en la raíz del proyecto:

```powershell
node web/server.mjs
```

**No hace falta ejecutar `npm install`.** El servidor utiliza módulos incluidos en Node.js.

La web funciona **mientras juegas o con el juego cerrado**. Necesita que su servidor local siga ejecutándose. No tiene refresco automático: espera el guardado del juego y pulsa **Actualizar**. Para detener el servidor, pulsa **Ctrl+C** en su consola; cerrar solamente la pestaña no lo detiene.

Si el puerto 3000 está ocupado:

```powershell
node web/server.mjs --port 3001 --open
```

El servidor encuentra automáticamente la base en la ubicación del juego. Para consultar otro archivo:

```powershell
node web/server.mjs --db "C:/ruta/sector07.sqlite"
```

### Sincronizar el móvil con la web del PC

La sincronización envía una copia del perfil móvil, progreso, intentos y eventos al PC. No reemplaza ni escribe la base principal del juego de PC: las copias móviles quedan en `sector07.sqlite.mobile-sync.sqlite`, junto a ella, y la web combina ambos archivos al consultar. El recorrido de mapa/replay no se transfiere; permanece en el celular. Los datos se mandan al seleccionar un perfil, guardar un checkpoint y cerrar una misión, o al pulsar el botón manual de sincronización. Después, pulsa **Actualizar** en la web.

1. Conecta el teléfono y el PC a la misma Wi‑Fi.
2. Abre PowerShell en la carpeta del proyecto y crea un token privado para esta sesión:

   ```powershell
   $syncToken = [Guid]::NewGuid().ToString('N') + [Guid]::NewGuid().ToString('N')
   $env:SECTOR07_SYNC_TOKEN = $syncToken
   $syncToken
   .\iniciar_web.cmd --lan --open
   ```

3. Si Windows pregunta, permite Node.js en redes **privadas**. La consola mostrará una dirección `http://<IP-del-PC>:3000`; no uses `localhost` en el celular.
4. Exporta una APK nueva desde este preset: usa la plantilla Gradle incluida (`android/build`), con `INTERNET` y HTTP habilitados para la conexión local. Instala esa APK y abre **Configuración → Sincronización con el PC**; introduce la dirección y el token mostrado en PowerShell y pulsa **Guardar y sincronizar con el PC**. Si Godot pide Android SDK/JDK/NDK, configúralos en **Editor → Editor Settings → Export → Android** antes de exportar; el template de este proyecto usa Android SDK 36, JDK 17+ y NDK `29.0.14206865`.
5. Mantén el servidor abierto. Si el teléfono está desconectado, sus datos siguen guardados localmente y volverán a sincronizarse al guardar o al pulsar el botón manual.

`--lan` permite acceso desde la red local; no configures reenvío de puertos en el router ni compartas el token. El token viaja por HTTP sin cifrar: usa solo una Wi‑Fi privada de confianza y detén el servidor cuando termines. El token se guarda en la configuración local del celular y no se sube a GitHub. La web muestra cada perfil móvil como un perfil independiente por dispositivo, aunque tenga el mismo nombre que uno del PC. El preset habilita `INTERNET` y construye la APK con la plantilla Gradle que permite las solicitudes HTTP al servidor local.

Abrir `web/index.html` directamente solo muestra la interfaz estática; para consultar SQLite se debe utilizar la dirección del servidor.

### Secciones de la página

| Sección | Función |
|---|---|
| **Resumen** | Perfiles, intentos, tiempo activo, mejor récord, resultados recientes y actividad por nivel. |
| **Jugadores** | Búsqueda y ficha de cada perfil, con equipación favorita y acceso a sus partidas y descubrimientos. |
| **Clasificación** | Leaderboard ordenable por récord, puntuación actual o progreso. |
| **Historial** | Intentos ganados, perdidos, abandonados, en curso o interrumpidos; filtros, detalle y exportación CSV. |
| **Descubrimientos** | Armas, granadas, mejoras, niveles y enemigos descubiertos por el perfil seleccionado. |
| **Registro de eventos** | Acciones del juego y del menú, filtros por jugador/acción/texto, detalles y exportación CSV. Incluye cambios de configuración general. |
| **Partidas y recorridos** | Muestra el registro de partdias y añade un mapa donde se puede ver los movimientos de los enemigos y del del jugador(que es marcado con un trazo). |

La exportación CSV incluye todos los resultados de los filtros, no solo la página visible. **Ver demostración** permite explorar datos ficticios claramente identificados; no los mezcla con las partidas reales ni los escribe en la base.

### Cómo se conectan el juego, la base y la web

```text
Godot guarda progreso y eventos
              ↓
       sector07.sqlite
              ↓
Node.js consulta la base en lectura
              ↓
       GET /api/dashboard
              ↓
El navegador presenta estadísticas, leaderboard y eventos

Android --POST /api/mobile-sync--> copia móvil en SQLite independiente
                                             ↓
                            GET /api/dashboard combina ambos archivos
```

La base principal del juego de PC permanece **solo en lectura** para el servidor. La sincronización guarda los snapshots móviles en otro archivo SQLite y la web combina los datos por perfil/dispositivo. No edita perfiles ni altera el guardado del juego de PC. Une historial y sesiones por identificador para no contar dos veces una misma partida.

Todo funciona en el equipo local. **Subir este repositorio a GitHub no inicia el servidor**, y GitHub Pages no puede ejecutar esta conexión a la base de AppData. Para usarla, cada persona inicia su servidor y consulta su propio archivo.

Más información en [la guía de la web](web/README.md).

## Organización del repositorio

```text
scenes/       Inicio, niveles, actores e interfaz de Godot
scripts/      Código separado por responsabilidad
assets/       Modelos, texturas, audio, shaders y previews
addons/       Integración nativa de SQLite
web/          Página y servidor de consulta local
tests/        Pruebas y herramientas organizadas por área
docs/         Guías del juego, base de datos y eventos
```

El paquete `Modular SciFi MegaKit[Standard]/` conserva los recursos originales y su licencia; algunas de sus texturas son dependencias directas del juego. Los archivos `.uid`, `.import` de recursos y las DLL originales de SQLite forman parte del proyecto.

El [`.gitignore`](.gitignore) excluye cachés, resultados generados, revisiones, dependencias y bases personales. Descargar el repositorio no incluye los perfiles de otra persona: el juego crea la base del nuevo usuario.

## Verificación y documentación

Las pruebas de Godot deben ejecutarse con **`-- --campaign-test`** para usar guardados privados. Ejemplos desde la raíz:

```powershell
& "C:/Program Files/Godot/Godot.exe" --headless --path . --script tests/persistence/sqlite_events.gd -- --campaign-test
node tests/web/web_server.mjs
```

Las pruebas de navegador requieren Playwright y Edge únicamente para desarrollo. Estas dependencias no son necesarias para usar la página.

- [Índice de documentación](docs/README.md)
- [Guía del juego](docs/GUIA_DEL_JUEGO.md)
- [Persistencia SQLite](docs/README_SQLITE.md)
- [Eventos y sesiones](docs/README_EVENTS.md)
- [Web local](web/README.md)
- [Pruebas y herramientas](tests/README.md)
- [Registro de desarrollo](DOCUMENTATION.md)

## Recursos y dependencias

- **Modular SciFi MegaKit**, de Quaternius: el paquete incluido declara CC0 1.0; conserva su archivo `License_Standard.txt`.
- **Godot-SQLite v4.8**, de 2shady4u: integración nativa con licencia [MIT incluida](addons/godot-sqlite/LICENSE.md). Véanse sus [notas de integración](addons/godot-sqlite/PROJECT_NOTES.md).

Las licencias de los recursos y dependencias se mantienen junto a sus archivos correspondientes.

### Plantillas Android y archivos .aar

Los archivos godot-lib.template_debug.aar y godot-lib.template_release.aar de android/build/libs/ no se incluyen en GitHub porque superan el límite de tamaño de archivo. Para exportar el juego a Android desde una copia del repositorio, instala en Godot las plantillas de exportación que correspondan exactamente a la versión de Godot usada por el proyecto y configura Android SDK, JDK y NDK. La plantilla Gradle personalizada de android/build/ se conserva en el repositorio.

## Mapas de partidas y estadísticas

La sección **Partidas y recorridos** muestra cada intento y su equipación, con un
mapa cenital animado: trazo del jugador y movimiento de enemigos identificados por
subtipo. Permite reproducir, pausar, reiniciar, cambiar velocidad y buscar un momento.
Los recorridos se registran desde esta versión; los intentos anteriores indican que
no disponen de muestras. Cada reanudación desde checkpoint registra su propio tramo.

El **Resumen** incorpora gráficas de jugadores únicos/partidas por día, armas más
presentes en las equipaciones y mejoras más elegidas. La ficha de jugador indica su
equipación favorita entre los intentos conservados con datos conocidos.

El esquema SQLite actual es **4**: mapa y muestras se guardan aparte de los eventos
en la misma base y se eliminan con sus intentos, respetando el límite de 400 partidas
por jugador. Actualiza y reinicia tanto el juego como el servidor web; no hay nuevas
dependencias de ejecución. Los datos y reglas de juego anteriores se conservan.


Las misiones finales incluyen defensa del hangar durante **120 s** con una carga
atacable de **150 PV**, refuerzos agrupados y cuatro cajas de munición (nivel 8),
y transporte de carga desde la sala inicial hasta la última, con tres cajas de
munición y refuerzos durante el regreso/traslado (nivel 9).

## INTEGRANTES

- **Aguilera Correa Alexis Kaleb**
- **Luquin Gonzalez Jose Ernesto**
- **Hernandez Huizar Brian Abraham**
