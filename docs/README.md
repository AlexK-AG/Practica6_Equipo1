# Documentación de Sector 07

Revisión: 16 de octubre de 2026. Estas guías describen la campaña actual y su consulta local.

| Documento | Contenido |
|---|---|
| [Guía del juego](GUIA_DEL_JUEGO.md) | Diez niveles, controles, entrenamiento, armas, enemigos, dificultad, arquitectura y trabajo en Godot. |
| [SQLite](README_SQLITE.md) | Ubicación del guardado, migración, tablas, copias y recuperación. |
| [Eventos](README_EVENTS.md) | Sesiones, tipos de eventos, guardado por lotes, consultas y límites ante cierres forzados. |
| [Web local](../web/README.md) | Arranque del servidor, cada sección, API, configuración y errores. |
| [Pruebas](../tests/README.md) | Organización, comandos y aislamiento de datos personales. |
| [Registro de desarrollo](../DOCUMENTATION.md) | Resumen vigente y evolución histórica de las implementaciones. |

## Carpetas del proyecto

- `scenes/`: Inicio, niveles, actores e interfaz editables como nodos de Godot.
- `scripts/`: código por función en `core`, `player`, `combat`, `enemies`, `missions`, `persistence`, `ui`, `common` y `visuals`.
- `assets/`: audio, imágenes, materiales y recursos usados; los OBJ están en `models/enemies`, `models/props` y `models/structures`.
- `addons/godot-sqlite/`: extensión nativa de persistencia. Conserva su licencia y notas del proveedor.
- `web/`: interfaz, servidor local y recursos web; su README permanece junto a su código.
- `tests/`: pruebas y herramientas por área; resultados nuevos en `.godot/test-results/`.
- `revision/`: material histórico de revisión conservado, cuya gestión corresponde al propietario.
- `Modular SciFi MegaKit[Standard]/`: paquete original conservado y sus recursos/licencias.
- `.godot/`: archivos generados, caché y fixtures privados; el guardado personal está en AppData, no aquí.

`project.godot`, `iniciar_web.cmd`, `Agents.md` y `DOCUMENTATION.md` permanecen en la raíz. Las instrucciones de `Agents.md` no se han reescrito. Las licencias y documentos del paquete original, de terceros y de `revision/` se mantienen como material de origen; no describen necesariamente el estado actual del juego.

Para jugar no se requiere Node.js: Godot guarda directamente en SQLite. Node.js 24 o superior se utiliza únicamente al iniciar la web local. No hay publicación automática en internet ni refresco periódico del navegador.
