extends TextureRect
## Rotating in-game views. Each menu instance owns its timer and transition.
const SLIDES := [
	"res://assets/previews/menu/menu_station.png",
	"res://assets/previews/menu/menu_hangar.png",
	"res://assets/previews/menu/menu_fortress.png"
]
var slide_index: int = 0
var transition: Tween
@export var slides: Array[Texture2D] = [preload(SLIDES[0]),preload(SLIDES[1]),preload(SLIDES[2])]

func _ready() -> void:
	if slides.is_empty():
		return
	texture = slides[0]
	$SlideTimer.timeout.connect(next_slide)

func next_slide() -> void:
	if slides.is_empty():
		return
	slide_index = (slide_index + 1) % slides.size()
	if is_instance_valid(transition):
		transition.kill()
	if bool(get_node("/root/Campaign").options.reduced_motion):
		texture = slides[slide_index]
		modulate = Color.WHITE
		return
	transition = create_tween()
	transition.tween_property(self, "modulate", Color(0.22, 0.25, 0.3), 0.3)
	transition.tween_callback(func(): texture = slides[slide_index])
	transition.tween_property(self, "modulate", Color.WHITE, 0.7)
