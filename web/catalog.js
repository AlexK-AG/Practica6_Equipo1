window.S07_CATALOG = {
  "levels": [
    "Laboratorio",
    "Almacén",
    "Reactor",
    "Fundición",
    "Biocontención",
    "Fortaleza",
    "Comunicaciones",
    "Hangar de evacuación",
    "Arsenal orbital",
    "Núcleo Áureo"
  ],
  "weapons": [
    {
      "id": "pistol",
      "name": "Pistola",
      "level": 0,
      "image": "assets/weapons/pistol.png"
    },
    {
      "id": "knife",
      "name": "Cuchillo",
      "level": 0,
      "image": "assets/weapons/knife.png"
    },
    {
      "id": "rifle",
      "name": "Fusil",
      "level": 1,
      "image": "assets/weapons/rifle.png"
    },
    {
      "id": "shotgun",
      "name": "Escopeta",
      "level": 3,
      "image": "assets/weapons/shotgun.png"
    },
    {
      "id": "precision",
      "name": "Precisión",
      "level": 6,
      "image": "assets/weapons/precision.png"
    },
    {
      "id": "plasma",
      "name": "Plasma",
      "level": 9,
      "image": "assets/weapons/plasma.png"
    }
  ],
  "enemies": [
    {
      "id": 0,
      "name": "Explorador",
      "role": "Asalto",
      "description": "Busca ángulos de tiro libres y cambia de posición al acercarse; rodea las coberturas y a sus aliados.",
      "tactic": "Alterna coberturas y aprovecha sus desplazamientos.",
      "height": 1.2,
      "image": "assets/enemies/enemy_00.png"
    },
    {
      "id": 1,
      "name": "Acechador",
      "role": "Francotirador",
      "description": "Mantiene distancia, avisa antes de disparar y cambia de posición tras dos tiros. Su daño aumenta con la distancia hasta 38 m.",
      "tactic": "Acércate con cobertura durante su aviso o reposicionamiento.",
      "height": 1.4,
      "image": "assets/enemies/enemy_01.png"
    },
    {
      "id": 2,
      "name": "Centinela",
      "role": "Tanque",
      "description": "Se interpone entre el jugador y un soporte cercano. Tiene un 60 % más de vida y reduce el daño frontal a la mitad.",
      "tactic": "Flanquéalo y ataca su espalda mientras protege a otro enemigo.",
      "height": 1.6,
      "image": "assets/enemies/enemy_02.png"
    },
    {
      "id": 3,
      "name": "Asaltante",
      "role": "Kamikaze",
      "description": "Anuncia un sprint lateral antes de acercarse y detonar. Puede adelantar a sus aliados.",
      "tactic": "Interrumpe su preparación o elimínalo antes de que llegue.",
      "height": 1.8,
      "image": "assets/enemies/enemy_03.png"
    },
    {
      "id": 4,
      "name": "Devastador",
      "role": "Sanador",
      "description": "Se mantiene detrás de sus aliados, prioriza al más herido y prepara una curación con un enlace verde visible. Daño o pérdida de visión interrumpen la canalización.",
      "tactic": "Ataca al sanador durante el enlace o separa a sus aliados con cobertura.",
      "height": 2.0,
      "image": "assets/enemies/enemy_04.png"
    },
    {
      "id": 5,
      "name": "Comandante",
      "role": "Invocador",
      "description": "Anuncia refuerzos de asalto, presión cercana o flanqueo según la situación, con un límite de invocaciones propias. Libera dos refuerzos junto a su cuerpo al morir.",
      "tactic": "Interrumpe su canalización y conserva munición para sus últimos refuerzos.",
      "height": 2.3,
      "image": "assets/enemies/enemy_05.png"
    },
    {
      "id": 6,
      "name": "Depredador",
      "role": "Asalto rápido",
      "description": "Busca un flanco cuando otro enemigo mantiene ocupado al jugador; evita quedar atrapado detrás de aliados lentos.",
      "tactic": "Vigila los caminos laterales y castígalo cuando se separe del grupo.",
      "height": 1.65,
      "image": "assets/enemies/enemy_06.png"
    },
    {
      "id": 7,
      "name": "Vigía",
      "role": "Francotirador móvil",
      "description": "Busca líneas de tiro laterales, evita aliados que le tapan y cambia de posición después de disparar. El daño aumenta con la distancia.",
      "tactic": "Acorta distancia y cambia de ángulo durante su aviso.",
      "height": 1.3,
      "image": "assets/enemies/enemy_07.png"
    },
    {
      "id": 8,
      "name": "Guardián",
      "role": "Tanque pesado",
      "description": "Ocupa la primera línea del grupo y mantiene una posición defensiva. Tiene un 85 % más de vida, blindaje frontal y giro lento.",
      "tactic": "Oblígalo a girar y ataca desde un lateral o por detrás.",
      "height": 1.9,
      "image": "assets/enemies/enemy_08.png"
    },
    {
      "id": 9,
      "name": "Cazador",
      "role": "Kamikaze veloz",
      "description": "Anuncia una carga rápida en línea recta y se compromete con esa dirección antes de detonar.",
      "tactic": "Esquiva hacia un lado durante el aviso; no puede corregir la carga para seguirte.",
      "height": 1.5,
      "image": "assets/enemies/enemy_09.png"
    },
    {
      "id": 10,
      "name": "Espectro",
      "role": "Soporte móvil",
      "description": "Se mantiene detrás de sus aliados, alterna pacientes y canaliza curaciones visibles e interrumpibles.",
      "tactic": "Intercepta sus desplazamientos o rompe el enlace de curación.",
      "height": 1.6,
      "image": "assets/enemies/enemy_10.png"
    },
    {
      "id": 11,
      "name": "Coloso",
      "role": "Invocador pesado",
      "description": "Prepara un relé visible y destructible para desplegar un refuerzo pesado, con límites de unidades. Libera dos refuerzos junto a su cuerpo al morir.",
      "tactic": "Destruye el relé antes del despliegue o interrumpe al invocador.",
      "height": 2.5,
      "image": "assets/enemies/enemy_11.png"
    },
    {
      "id": 12,
      "name": "Núcleo",
      "role": "Asalto pesado",
      "description": "Dispara ráfagas de supresión hacia la última posición que vio y deja pausas entre ellas. Las paredes y aliados bloquean sus disparos.",
      "tactic": "Cambia de cobertura durante la pausa: no conoce tus movimientos cuando estás oculto.",
      "height": 2.4,
      "image": "assets/enemies/enemy_12.png"
    },
    {
      "id": 13,
      "name": "Escudero",
      "role": "Escudo direccional",
      "description": "Escolta a sanadores e invocadores y orienta su escudo hacia la amenaza. El escudo absorbe 70 puntos y no se regenera.",
      "tactic": "Flanquéalo para ignorar el escudo o sepáralo del aliado que protege.",
      "height": 1.6,
      "image": "assets/enemies/enemy_13.png"
    },
    {
      "id": 14,
      "name": "Corredor",
      "role": "Ráfaga de asalto",
      "description": "Dispara tres tiros cortos y se desplaza lateralmente durante la pausa para buscar otro ángulo.",
      "tactic": "Contraataca al terminar su ráfaga y vigila su siguiente posición.",
      "height": 1.2,
      "image": "assets/enemies/enemy_14.png"
    },
    {
      "id": 15,
      "name": "Bastión",
      "role": "Proyector",
      "description": "Busca permanecer cerca del grupo y muestra conexiones violetas hacia los aliados visibles que protege a menos de nueve metros.",
      "tactic": "Rompe la formación y elimina primero al proyector.",
      "height": 2.0,
      "image": "assets/enemies/enemy_15.png"
    },
    {
      "id": 16,
      "name": "Reanimado",
      "role": "Resurrección",
      "description": "Prepara una única resurrección de cuatro segundos y recupera el 60 % de vida. Después entra en una sobrecarga agresiva de siete segundos.",
      "tactic": "Destruye el núcleo expuesto o mantén distancia hasta que termine la sobrecarga.",
      "height": 1.2,
      "image": "assets/enemies/enemy_16.png"
    },
    {
      "id": 17,
      "name": "Intermitente",
      "role": "Desfase",
      "description": "Anuncia una posición lateral antes de desaparecer y reaparece allí tras un breve desfase intangible.",
      "tactic": "Sigue la señal de destino y prepara el ataque para su reaparición.",
      "height": 2.0,
      "image": "assets/enemies/enemy_17.png"
    }
  ]
};
