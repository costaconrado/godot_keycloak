extends RefCounted

static func auth(username: String, password: String):
	var headers: Array[String] = ["Content-Type: application/x-www-form-urlencoded"]
	var data = [
		"username=%s" % username,
		"password=%s" % password,
		"client_id=%s" % Keycloak.client_id,
		"client_secret=%s" % Keycloak.client_secret,
		"grant_type=password",
	]
	Keycloak.request_token(headers, "&".join(data))

static func generate_basic_form() -> VBoxContainer:
	var vbox = VBoxContainer.new()
	var grid = GridContainer.new()
	grid.columns = 2

	var username_label = Label.new()
	username_label.text = "Username"
	username_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(username_label)

	var username_input = LineEdit.new()
	username_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	username_input.custom_minimum_size = Vector2(150, 0)
	grid.add_child(username_input)

	var password_label = Label.new()
	password_label.text = "Password"
	password_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(password_label)

	var password_input = LineEdit.new()
	password_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	password_input.secret = true
	password_input.custom_minimum_size = Vector2(150, 0)
	grid.add_child(password_input)
	var submit_btn = Button.new()
	submit_btn.text = "Sign In"
	submit_btn.pressed.connect(func(): auth(username_input.text, password_input.text))

	vbox.add_child(grid)
	grid.add_child(username_label)
	grid.add_child(username_input)
	grid.add_child(password_label)
	grid.add_child(password_input)
	vbox.add_child(submit_btn)

	return vbox
