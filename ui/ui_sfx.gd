extends Node
## Original short, tactile UI click generated at startup (no asset licensing).
## Audio bus UI is managed by GameSettings and its independent volume slider.

const SAMPLE_RATE := 44100
const CLICK_DURATION := 0.095

var player: AudioStreamPlayer
var play_count := 0


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


func play_click() -> void:
    if player == null or player.stream == null:
        return
    play_count += 1
    player.play()


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
        var hash_value := sin(float(i) * 91.17) * 43758.5453
        var noise := (hash_value - floor(hash_value)) * 2.0 - 1.0
        var transient := noise * exp(-t * 135.0) * 0.12
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
