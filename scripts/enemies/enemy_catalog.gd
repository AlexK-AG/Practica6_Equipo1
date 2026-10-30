extends RefCounted
## Shared by the bestiary and combat. Indices match the authored enemy scenes.
const ENTRIES := [
	{"name": "Explorador", "role": "Asalto", "behavior": "Busca ángulos de tiro libres y cambia de posición al acercarse; rodea las coberturas y a sus aliados.", "weakness": "Alterna coberturas y aprovecha sus desplazamientos.", "color": Color("5ce5bf")},
	{"name": "Acechador", "role": "Francotirador", "behavior": "Mantiene distancia, avisa antes de disparar y cambia de posición tras dos tiros. Su daño aumenta con la distancia hasta 38 m.", "weakness": "Acércate con cobertura durante su aviso o reposicionamiento.", "color": Color("ebc65d")},
	{"name": "Centinela", "role": "Tanque", "behavior": "Se interpone entre el jugador y un soporte cercano. Tiene un 60 % más de vida y reduce el daño frontal a la mitad.", "weakness": "Flanquéalo y ataca su espalda mientras protege a otro enemigo.", "color": Color("75baff")},
	{"name": "Asaltante", "role": "Kamikaze", "behavior": "Anuncia un sprint lateral antes de acercarse y detonar. Puede adelantar a sus aliados.", "weakness": "Interrumpe su preparación o elimínalo antes de que llegue.", "color": Color("f38757")},
	{"name": "Devastador", "role": "Sanador", "behavior": "Se mantiene detrás de sus aliados, prioriza al más herido y prepara una curación con un enlace verde visible. Daño o pérdida de visión interrumpen la canalización.", "weakness": "Ataca al sanador durante el enlace o separa a sus aliados con cobertura.", "color": Color("d981f1")},
	{"name": "Comandante", "role": "Invocador", "behavior": "Anuncia refuerzos de asalto, presión cercana o flanqueo según la situación, con un límite de invocaciones propias. Libera dos refuerzos junto a su cuerpo al morir.", "weakness": "Interrumpe su canalización y conserva munición para sus últimos refuerzos.", "color": Color("f36483")},
	{"name": "Depredador", "role": "Asalto rápido", "behavior": "Busca un flanco cuando otro enemigo mantiene ocupado al jugador; evita quedar atrapado detrás de aliados lentos.", "weakness": "Vigila los caminos laterales y castígalo cuando se separe del grupo.", "color": Color("c4ff52")},
	{"name": "Vigía", "role": "Francotirador móvil", "behavior": "Busca líneas de tiro laterales, evita aliados que le tapan y cambia de posición después de disparar. El daño aumenta con la distancia.", "weakness": "Acorta distancia y cambia de ángulo durante su aviso.", "color": Color("40d9ff")},
	{"name": "Guardián", "role": "Tanque pesado", "behavior": "Ocupa la primera línea del grupo y mantiene una posición defensiva. Tiene un 85 % más de vida, blindaje frontal y giro lento.", "weakness": "Oblígalo a girar y ataca desde un lateral o por detrás.", "color": Color("ffa344")},
	{"name": "Cazador", "role": "Kamikaze veloz", "behavior": "Anuncia una carga rápida en línea recta y se compromete con esa dirección antes de detonar.", "weakness": "Esquiva hacia un lado durante el aviso; no puede corregir la carga para seguirte.", "color": Color("afff64")},
	{"name": "Espectro", "role": "Soporte móvil", "behavior": "Se mantiene detrás de sus aliados, alterna pacientes y canaliza curaciones visibles e interrumpibles.", "weakness": "Intercepta sus desplazamientos o rompe el enlace de curación.", "color": Color("ad8dff")},
	{"name": "Coloso", "role": "Invocador pesado", "behavior": "Prepara un relé visible y destructible para desplegar un refuerzo pesado, con límites de unidades. Libera dos refuerzos junto a su cuerpo al morir.", "weakness": "Destruye el relé antes del despliegue o interrumpe al invocador.", "color": Color("ff6475")},
	{"name": "Núcleo", "role": "Asalto pesado", "behavior": "Dispara ráfagas de supresión hacia la última posición que vio y deja pausas entre ellas. Las paredes y aliados bloquean sus disparos.", "weakness": "Cambia de cobertura durante la pausa: no conoce tus movimientos cuando estás oculto.", "color": Color("fff085")},
	{"name": "Escudero", "role": "Escudo direccional", "behavior": "Escolta a sanadores e invocadores y orienta su escudo hacia la amenaza. El escudo absorbe 70 puntos y no se regenera.", "weakness": "Flanquéalo para ignorar el escudo o sepáralo del aliado que protege.", "color": Color("54e6ff")},
	{"name": "Corredor", "role": "Ráfaga de asalto", "behavior": "Dispara tres tiros cortos y se desplaza lateralmente durante la pausa para buscar otro ángulo.", "weakness": "Contraataca al terminar su ráfaga y vigila su siguiente posición.", "color": Color("ffb65c")},
	{"name": "Bastión", "role": "Proyector", "behavior": "Busca permanecer cerca del grupo y muestra conexiones violetas hacia los aliados visibles que protege a menos de nueve metros.", "weakness": "Rompe la formación y elimina primero al proyector.", "color": Color("d49bff")},
	{"name": "Reanimado", "role": "Resurrección", "behavior": "Prepara una única resurrección de cuatro segundos y recupera el 60 % de vida. Después entra en una sobrecarga agresiva de siete segundos.", "weakness": "Destruye el núcleo expuesto o mantén distancia hasta que termine la sobrecarga.", "color": Color("89d9a3")},
	{"name": "Intermitente", "role": "Desfase", "behavior": "Anuncia una posición lateral antes de desaparecer y reaparece allí tras un breve desfase intangible.", "weakness": "Sigue la señal de destino y prepara el ataque para su reaparición.", "color": Color("85aaff")}
]
const DIFFICULTY := [
	{"damage": 0.7, "attack": 0.85, "movement": 0.85, "health": 0.85},
	{"damage": 1.0, "attack": 1.0, "movement": 1.0, "health": 1.0},
	{"damage": 1.3, "attack": 1.25, "movement": 1.2, "health": 1.25}
]
## Damage multiplier, movement target (m/s), attack-frequency multiplier.
## A slow heavy enemy stays distinct from a flanker at every campaign stage.
const TUNING := [
	Vector3(1.0,2.6,1.12), Vector3(1.18,2.6,1.05),
	Vector3(1.18,1.8,1.10), Vector3(1.0,3.0,1.16),
	Vector3(1.02,1.7,1.08), Vector3(1.18,1.35,1.12),
	Vector3(1.08,3.25,1.23), Vector3(1.18,2.85,1.16),
	Vector3(1.28,1.65,1.12), Vector3(1.08,3.5,1.20),
	Vector3(1.10,3.1,1.15), Vector3(1.40,1.25,1.10),
	Vector3(1.42,1.5,1.25), Vector3(1.08,2.0,1.10),
	Vector3(.9,3.55,1.28), Vector3(1.04,1.8,1.12),
	Vector3(1.12,2.7,1.12),Vector3(1.12,3.1,1.18)
]
const MIN_LEVEL := [1,1,2,2,3,4,3,4,5,5,6,7,8,3,4,6,5,7]

static func available(level: int) -> Array[int]:
	var result: Array[int] = []
	for kind in range(ENTRIES.size()):
		if MIN_LEVEL[kind] <= level:
			result.append(kind)
	return result

static func permitted(kind: int, level: int) -> int:
	if MIN_LEVEL[clampi(kind,0,ENTRIES.size() - 1)] <= level:
		return kind
	return [0,1][kind % 2]

## Read the authored collider without instantiating an enemy or running combat code.
static func body_height(kind: int) -> float:
	var scene := load("res://scenes/actors/enemy_%d.tscn" % clampi(kind,0,ENTRIES.size()-1)) as PackedScene
	var state := scene.get_state()
	var root_scale := 1.0
	for property in range(state.get_node_property_count(0)):
		if state.get_node_property_name(0,property) == &"transform":
			var root_transform: Transform3D = state.get_node_property_value(0,property)
			root_scale = root_transform.basis.get_scale().abs().y
	for node in range(state.get_node_count()):
		if state.get_node_type(node) != &"CollisionShape3D":
			continue
		var shape: Shape3D
		var shape_scale := 1.0
		for property in range(state.get_node_property_count(node)):
			match state.get_node_property_name(node,property):
				&"shape":
					shape = state.get_node_property_value(node,property)
				&"transform":
					var transform: Transform3D = state.get_node_property_value(node,property)
					shape_scale = transform.basis.get_scale().abs().y
		if shape is BoxShape3D:
			return shape.size.y*shape_scale*root_scale
	return 1.3

static func height_text(kind: int) -> String:
	return "ALTURA · %s m" % String.num(body_height(kind),2).replace(".",",")
