extends RefCounted
## Separate stocks; special grenades must be found and the sector completed.
const DATA := {
	"basic": {"title": "BÁSICA", "unlock": 1, "initial": 3, "maximum": 5, "damage": 160, "radius": 6.0, "falloff": 8.0, "fuse": 1.6, "color": Color("ffb94f")},
	"fragmentation": {"title": "FRAGMENTACIÓN", "unlock": 2, "initial": 2, "maximum": 3, "damage": 220, "radius": 7.0, "falloff": 9.0, "fuse": 1.8, "color": Color("ed7957")},
	"slow": {"title": "ESTASIS", "unlock": 5, "initial": 2, "maximum": 3, "damage": 45, "radius": 7.5, "falloff": 10.0, "fuse": 1.5, "duration": 5.0, "factor": 0.45, "color": Color("91d7cf")}
}
