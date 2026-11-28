extends Node
## Kenney Interface Sounds (CC0); original synthesized click retained for Back.
## Audio bus UI is managed by GameSettings and its independent volume slider.

const SAMPLE_RATE := 44100
const CLICK_DURATION := 0.095

var player: AudioStreamPlayer
var play_count := 0
var last_event := ""
var event_counts: Dictionary = {}
var event_players: Dictionary = {}
const EVENT_FILES := {
    "navigation": "res://ui/audio/bong_001.ogg",
    "confirmation": "res://ui/audio/confirmation_002.ogg",
    "dropdown": "res://ui/audio/glass_006.ogg"
}


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    player = AudioStreamPlayer.new()
    player.name = "Click"
    player.bus = "UI"
    player.volume_db = -8.0
    player.max_polyphony = 6
    player.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(player)
    player.stream = _make_click()
    event_players["back"] = player
    for event in EVENT_FILES:
        var voice := AudioStreamPlayer.new()
        voice.name = str(event).capitalize()
        voice.bus = "UI"
        voice.volume_db = -8.0
        voice.max_polyphony = 4
        voice.process_mode = Node.PROCESS_MODE_ALWAYS
        add_child(voice)
        var path: String = EVENT_FILES[event]
        # Runtime load after editor import; no compile-time audio preload.
        if ResourceLoader.exists(path):
            voice.stream = load(path) as AudioStream
        event_players[event] = voice


func _exit_tree() -> void:
    # Release active UI voices and Ogg decoders before AudioServer shuts
    # down, just as the persistent world-audio director does.
    for value in event_players.values():
        var voice := value as AudioStreamPlayer
        if is_instance_valid(voice):
            voice.stop()
            voice.stream = null
    event_players.clear()
    player = null


func play_click() -> void:
    play_event("navigation")


func play_event(event: String) -> void:
    var voice := event_players.get(event) as AudioStreamPlayer
    if voice == null or voice.stream == null:
        voice = player
    if voice == null or voice.stream == null:
        return
    last_event = event
    event_counts[event] = int(event_counts.get(event, 0)) + 1
    play_count += 1
    voice.play()


func _make_click() -> AudioStreamWAV:
    var count := int(ceil(float(SAMPLE_RATE) * CLICK_DURATION))
    var pcm := PackedByteArray()
    pcm.resize(count * 2)
    var phase := 0.0
    for i in range(count):
        var t := float(i) / float(SAMPLE_RATE)
        var u := clampf(t / CLICK_DURATION, 0.0, 1.0)
        var envelope := pow(1.0 - u, 4.6) * minf(t * 2500.0, 1.0)
        # Two lightly detuned decaying components make a short, rounded
        # mechanical response instead of a generic sharp digital beep.
        var frequency := 270.0 + 670.0 * exp(-t * 38.0)
        phase += TAU * frequency / float(SAMPLE_RATE)
        var body := sin(phase) * 0.58 + sin(phase * 1.97) * 0.14
        var hash_value: float = sin(float(i) * 91.17) * 43758.5453
        var noise: float = (hash_value - floorf(hash_value)) * 2.0 - 1.0
        var transient: float = noise * exp(-t * 135.0) * 0.12
        var value := clampf((body + transient) * envelope * 0.7, -1.0, 1.0)
        var sample := int(round(value * 32767.0))
        pcm[i * 2] = sample & 255
        pcm[i * 2 + 1] = (sample >> 8) & 255

    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = SAMPLE_RATE
    stream.stereo = false
    stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
    stream.data = pcm
    return stream
