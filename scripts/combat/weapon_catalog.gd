extends RefCounted
## Shared weapon definitions. Runtime ammunition belongs to each player.
const DATA := {
	"pistol": {"title": "PISTOLA", "unlock": 1, "capacity": 12, "reserve": 24, "max_reserve": 48, "pickup": 12, "damage": 25, "interval": 0.28, "reload": 1.1, "pellets": 1, "spread": 0.0, "range": 65.0, "automatic": false},
	"rifle": {"title": "FUSIL", "unlock": 1, "capacity": 24, "reserve": 48, "max_reserve": 96, "pickup": 24, "damage": 20, "interval": 0.15, "reload": 1.5, "pellets": 1, "spread": 0.018, "range": 70.0, "automatic": true},
	"shotgun": {"title": "ESCOPETA", "unlock": 3, "capacity": 6, "reserve": 8, "max_reserve": 18, "pickup": 6, "damage": 13, "interval": 0.85, "reload": 2.0, "pellets": 8, "spread": 0.085, "range": 22.0, "automatic": false},
	"precision": {"title": "PRECISIÓN", "unlock": 6, "capacity": 5, "reserve": 8, "max_reserve": 15, "pickup": 5, "damage": 150, "interval": 1.15, "reload": 2.1, "pellets": 1, "spread": 0.0, "range": 100.0, "automatic": false},
	"plasma": {"title": "PLASMA", "unlock": 9, "capacity": 10, "reserve": 12, "max_reserve": 30, "pickup": 8, "damage": 65, "interval": 0.45, "reload": 2.2, "pellets": 1, "spread": 0.009, "range": 48.0, "automatic": true}
}
