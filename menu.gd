extends Control

const UPDATE_MANIFEST_URL := "https://github.com/TeKatz/casino-anomaly/releases/download/development/update-manifest.json"

@onready var status_label: Label = $CenterPanel/Content/Stack/StatusLabel
@onready var version_label: Label = $CenterPanel/Content/Stack/VersionLabel
@onready var update_button: Button = $CenterPanel/Content/Stack/UpdateButton
@onready var install_button: Button = $CenterPanel/Content/Stack/InstallButton
@onready var request: HTTPRequest = $UpdateRequest

var current_version_code: int = 0
var latest_manifest: Dictionary = {}

func _ready() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    var version_text := FileAccess.get_file_as_string("res://version.json")
    var parsed = JSON.parse_string(version_text)
    if parsed is Dictionary:
        current_version_code = int(parsed.get("versionCode", 0))
        version_label.text = "Version " + str(parsed.get("version", "0.1.0-dev.0"))
    $CenterPanel/Content/Stack/PlayButton.pressed.connect(_on_play)
    $CenterPanel/Content/Stack/QuitButton.pressed.connect(_on_quit)
    update_button.pressed.connect(_check_update)
    install_button.pressed.connect(_install_update)
    request.request_completed.connect(_on_request_completed)
    call_deferred("_check_update")

func _on_play() -> void:
    get_tree().change_scene_to_file("res://main.tscn")

func _on_quit() -> void:
    get_tree().quit()

func _check_update() -> void:
    if request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
        return
    latest_manifest.clear()
    install_button.visible = false
    install_button.disabled = true
    update_button.disabled = true
    status_label.text = "Prüfe Development-Updates ..."
    var url := UPDATE_MANIFEST_URL + "?nocache=" + str(int(Time.get_unix_time_from_system()))
    var error := request.request(url, PackedStringArray(["Cache-Control: no-cache"]))
    if error != OK:
        update_button.disabled = false
        status_label.text = "Updateprüfung nicht möglich – offline spielbar."

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    update_button.disabled = false
    if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
        status_label.text = "Kein Update-Server erreichbar – offline spielbar."
        return
    var parsed = JSON.parse_string(body.get_string_from_utf8())
    if not (parsed is Dictionary):
        status_label.text = "Ungültige Updateinformationen."
        return
    if int(parsed.get("schemaVersion", 0)) != 1 or str(parsed.get("channel", "")) != "development":
        status_label.text = "Unbekannter Updatekanal."
        return
    var package = parsed.get("package", {})
    if not (package is Dictionary):
        status_label.text = "Ungültige Paketinformationen."
        return
    if not str(package.get("url", "")).begins_with("https://github.com/TeKatz/casino-anomaly/releases/download/development/"):
        status_label.text = "Ungültige Updatequelle."
        return
    var published_code := int(parsed.get("versionCode", -1))
    if published_code <= current_version_code:
        status_label.text = "Du verwendest die aktuelle Development-Version."
        return
    latest_manifest = parsed
    install_button.visible = true
    install_button.disabled = false
    status_label.text = "Update " + str(parsed.get("version", "")) + " verfügbar."

func _install_update() -> void:
    if latest_manifest.is_empty():
        return
    if OS.get_name() != "Windows" or OS.has_feature("editor"):
        status_label.text = "Der Updater ist nur im Windows-Testbuild verfügbar."
        return
    var install_dir := OS.get_executable_path().get_base_dir()
    var updater_source := install_dir.path_join("tools/updater/CasinoAnomaly.Updater.exe")
    if not FileAccess.file_exists(updater_source):
        status_label.text = "Updater fehlt. Bitte das vollständige ZIP entpacken."
        return
    var helper_dir := OS.get_user_data_dir().path_join("update-helper")
    var make_result := DirAccess.make_dir_recursive_absolute(helper_dir)
    if make_result != OK:
        status_label.text = "Updater-Ordner konnte nicht angelegt werden."
        return
    var updater_copy := helper_dir.path_join("CasinoAnomaly.Updater.exe")
    if DirAccess.copy_absolute(updater_source, updater_copy) != OK:
        status_label.text = "Updater konnte nicht vorbereitet werden."
        return
    var arguments := PackedStringArray([
        "--manifest=" + UPDATE_MANIFEST_URL,
        "--install-dir=" + install_dir,
        "--wait-pid=" + str(OS.get_process_id()),
        "--current-version-code=" + str(current_version_code)
    ])
    var child_pid := OS.create_process(updater_copy, arguments, false)
    if child_pid <= 0:
        status_label.text = "Updater konnte nicht gestartet werden."
        return
    get_tree().quit()
