extends RefCounted

static func auth():
	Keycloak.set_process(true)
	var redir_err = Keycloak.redirect_server.listen(Keycloak.LOCAL_CLIENT_PORT, Keycloak.LOCAL_CLIENT_ADDR)
	if redir_err:
		printerr(redir_err)

	var data = [
		"response_type=code",
		"scope=openid",
		"client_id=%s" % Keycloak.client_id,
		"client_secret=%s" % Keycloak.client_secret,
		"redirect_uri=%s" % Keycloak.redirect_uri,
		"state=%s" % Keycloak.random_string(22),
		"nonce=%s" % Keycloak.random_string(22),
		"login_hint=google",
		"kc_idp_hint=google",
	]

	OS.shell_open("http://%s:%d%s?%s" % [
		Keycloak.server_addr,
		Keycloak.server_port,
		Keycloak.auth_url,
		"&".join(data)
	])

static func generate_google_btn() -> Button:
	var google_btn = Button.new()
	google_btn.icon = load("res://addons/keycloak/textures/google-logo.png")
	google_btn.expand_icon = true
	google_btn.text = "Sign in with Google"
	google_btn.pressed.connect(func(): auth())

	return google_btn
