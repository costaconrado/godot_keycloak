extends Control


# Called when the node enters the scene tree for the first time.
func _ready():
	var container = get_child(0)
	var vbox = Keycloak.basic.generate_basic_form()
	vbox.add_child(Keycloak.google.generate_google_btn())
	container.add_child(vbox)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
