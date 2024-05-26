extends Node

signal token_received
signal authentication_failed(String)

var public_key: CryptoKey

var basic = load("res://addons/keycloak/src/auth_types/basic.gd")
var google = load("res://addons/keycloak/src/auth_types/google.gd")

var realm_id: String :
	get:
		return ProjectSettings.get_setting("keycloak/realm_id")
var client_id: String :
	get:
		return ProjectSettings.get_setting("keycloak/client_id")
var client_secret: String :
	get:
		return ProjectSettings.get_setting("keycloak/client_secret")
var server_addr: String :
	get:
		return ProjectSettings.get_setting("keycloak/server_addr")
var server_port: int :
	get:
		return ProjectSettings.get_setting("keycloak/server_port")
var token_url: String :
	get:
		return "/realms/%s/protocol/openid-connect/token" % realm_id
var auth_url:
	get:
		return "/realms/%s/protocol/openid-connect/auth" % realm_id

# Used to receive access code using external auth providers (e.g. Google)
const LOCAL_CLIENT_PORT := 30581
const LOCAL_CLIENT_ADDR := "127.0.0.1"

var redirect_server := TCPServer.new()
var redirect_uri: String = "http://%s:%s" % [LOCAL_CLIENT_ADDR, LOCAL_CLIENT_PORT]

var _access_token: String
var _refresh_token: String

func is_token_valid(token: String) -> bool:
	if not public_key:
		await get_pub_key()

	var jwt_algorithm: JWTAlgorithm = JWTAlgorithmBuilder.RS256(public_key, public_key)
	var jwt_verifier: JWTVerifier = JWT.require(jwt_algorithm) \
		.build(int(Time.get_unix_time_from_system() + 300))

	if jwt_verifier.verify(token) == JWTVerifier.JWTExceptions.OK:
		return true
	else:
		push_error(jwt_verifier.exception)
		return false

func get_token() -> String:
	var jwt_decoder = JWTDecoder.new(_access_token)
	
	if Time.get_unix_time_from_system() <= jwt_decoder.get_expires_at():
		print("Token still good!")
		return _access_token
	else:
		print("Expired")
		return await refresh_token()

func _process(_delta):
	if redirect_server.is_connection_available():
		var connection = redirect_server.take_connection()
		var request = connection.get_string(connection.get_available_bytes())
		if request:
			set_process(false)

			connection.put_data(("HTTP/1.1 %d\r\n" % 200).to_ascii_buffer())
			connection.put_data(load_html("res://addons/keycloak/src/display_page.html").to_ascii_buffer())
			redirect_server.stop()

			var parameters = _parse_url_parameters(request)
			var code = parameters.get("code")

			var data = [
				"code=%s" % code,
				"grant_type=authorization_code",
				"client_id=%s" % client_id,
				"client_secret=%s" % client_secret,
				"redirect_uri=%s" % redirect_uri,
			]
			
			var headers: Array[String] = ["Content-Type: application/x-www-form-urlencoded"]

			request_token(headers, "&".join(data))

func load_html(path):
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var html = file.get_as_text().replace("    ", "\t").insert(0, "\n")
		file.close()
		return html

func _parse_url_parameters(request: String) -> Dictionary:
	var parameters = {}
	var query = request.split("\n")[0]
	query = query.substr(request.find("?") + 1).split(" ")[0]
	var query_params = query.split("&")
	
	for param in query_params:
		var parts = param.split("=")
		if parts.size() == 2:
			parameters[parts[0]] = parts[1]
	
	return parameters

func random_string(length):
	var chars = 'abcdefghijklmnopqrstuvwxyz0123456789'
	var word = ""
	var n_char = len(chars)
	for i in range(length):
		word += chars[randi() % n_char]
	return word

func get_pub_key():
	var url = "http://%s:%d/realms/%s" % [
		server_addr,
		server_port,
		realm_id,
	]
	var http_request = HTTPRequest.new()
	http_request.name = "token_request"
	add_child(http_request)
	var error = http_request.request(url, [], HTTPClient.METHOD_GET)
	if error != OK:
		push_error("An error occurred while getting token: %s" % error)
		return ""
	var response = await http_request.request_completed
	http_request.queue_free()
	var response_body = JSON.parse_string(response[3].get_string_from_utf8())
	if response_body.get("public_key"):
		public_key = CryptoKey.new()
		public_key.load_from_string(
			"%s\n%s\n%s" % [
				"-----BEGIN PUBLIC KEY-----",
				response_body.get("public_key"),
				"-----END PUBLIC KEY-----"],
			true
		)
	else:
		push_error("Unable to get auth server public key.")

func refresh_token() -> String:
	var url = "http://%s:%d%s" % [
		server_addr,
		server_port,
		token_url,
	]
	var data = [
		"grant_type=refresh_token",
		"refresh_token=%s" % _refresh_token,
		"client_id=%s" % client_id,
		"client_secret=%s" % client_secret,
	]
	
	var headers: Array[String] = ["Content-Type: application/x-www-form-urlencoded"]

	var http_request = HTTPRequest.new()
	http_request.name = "token_request"
	add_child(http_request)
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, "&".join(data))
	if error != OK:
		push_error("An error occurred while getting token: %s" % error)
		return ""
	var response = await http_request.request_completed
	http_request.queue_free()
	var response_body = JSON.parse_string(response[3].get_string_from_utf8())

	_access_token = response_body.get("access_token")
	_refresh_token = response_body.get("refresh_token")

	if not _access_token:
		authentication_failed.emit("Session expired.")
		return ""

	token_received.emit()
	return _access_token

func request_token(headers: Array[String], data: String) -> void:
	var http_request = HTTPRequest.new()
	http_request.name = "token_request"
	add_child(http_request)
	http_request.request_completed.connect(_on_token_received)
	http_request.request_completed.connect(
		func(_result, _response_code, _headers, _body) -> void:
			http_request.queue_free()
	)
	var url = "http://%s:%d%s" % [
		server_addr,
		server_port,
		token_url,
	]
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, data)
	if error != OK:
		push_error("An error occurred while getting token: %s" % error)

func _on_token_received(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var response_body = JSON.parse_string(body.get_string_from_utf8())
	if response_code == 200:
		_access_token = response_body.get("access_token")
		_refresh_token = response_body.get("refresh_token")

		token_received.emit()
	else:
		authentication_failed.emit(response_body.get("error_description"))
