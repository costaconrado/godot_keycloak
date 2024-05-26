@tool
extends EditorPlugin

const AUTOLOAD_NAME = "Keycloak"

func _enter_tree():
	set_default("realm_id", "my_keycloak_realm")
	set_default("client_id", "game_client_id")
	set_default("client_secret", "super_secret")
	set_default("server_addr", "127.0.0.1")
	set_default("server_port", 8080)
	add_autoload_singleton(AUTOLOAD_NAME, "res://addons/keycloak/src/auth.gd")

func _exit_tree():
	remove_autoload_singleton(AUTOLOAD_NAME)

func set_default(key, value):
	if not ProjectSettings.has_setting(key):
		ProjectSettings.set_setting("keycloak/%s" % key, value)