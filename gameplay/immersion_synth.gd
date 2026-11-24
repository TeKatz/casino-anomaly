extends RefCounted
## Original generated cues, cached by AudioDirector and safe for public repos.
const RATE := 22050

static func _wave(samples: PackedFloat32Array, looped: bool, rate: int = RATE, loop_frames: int = -1) -> AudioStreamWAV:
    var pcm := PackedByteArray()
    pcm.resize(samples.size() * 2)
    for i in range(samples.size()):
        var value := int(round(clampf(samples[i], -1.0, 1.0) * 32767.0))
        pcm[2 * i] = value & 255
        pcm[2 * i + 1] = (value >> 8) & 255
    var wave := AudioStreamWAV.new()
    wave.format = AudioStreamWAV.FORMAT_16_BITS
    wave.mix_rate = rate
    wave.stereo = false
    wave.loop_mode = AudioStreamWAV.LOOP_FORWARD if looped else AudioStreamWAV.LOOP_DISABLED
    wave.loop_begin = 0
    wave.loop_end = samples.size() if loop_frames < 0 else loop_frames
    wave.data = pcm
    return wave


static func footstep(surface: String, variant: int) -> AudioStreamWAV:
    var length := 0.25 if surface == "corridor" else 0.22
    var count := int(float(RATE) * length)
    var samples := PackedFloat32Array()
    samples.resize(count)
    var rng := RandomNumberGenerator.new()
    rng.seed = 71113 + variant * 197 + surface.length() * 1003
    var filtered_noise := 0.0
    for i in range(count):
        var t := float(i) / float(RATE)
        var envelope := pow(maxf(0.0, 1.0 - t / length), 4.0)
        filtered_noise = lerpf(filtered_noise, rng.randf_range(-1.0, 1.0), 0.18)
        var body := 0.0
        if surface == "carpet":
            body = 0.46 * sin(TAU * 72.0 * t) + 0.19 * filtered_noise
        elif surface == "corridor":
            body = 0.48 * sin(TAU * 125.0 * t) + 0.25 * filtered_noise
            body += 0.14 * sin(TAU * 410.0 * t) * exp(-t * 49.0)
        else:
            body = 0.57 * sin(TAU * 94.0 * t) + 0.23 * filtered_noise
            body += 0.12 * sin(TAU * 580.0 * t) * exp(-t * 64.0)
        samples[i] = body * envelope * minf(t * 2500.0, 1.0) * 0.72
    return _wave(samples, false)


static func ambience(kind: String) -> AudioStreamWAV:
    if kind == "backrooms_hum":
        return _fluorescent_hum()
    # Integer-hertz tones ensure seamless 2-second loops, without random
    # beeps/flickers that might be misread as a gameplay anomaly.
    var count := RATE * 2
    var samples := PackedFloat32Array()
    samples.resize(count)
    for i in range(count):
        var t := float(i) / float(RATE)
        var value := 0.0
        match kind:
            "cabinet":
                value = 0.23 * sin(TAU * 103.0 * t) + 0.13 * sin(TAU * 51.0 * t)
                value += 0.07 * sin(TAU * 219.0 * t + 0.4)
            "bar":
                value = 0.30 * sin(TAU * 46.0 * t) + 0.13 * sin(TAU * 91.0 * t)
                value += 0.08 * sin(TAU * 257.0 * t) * sin(TAU * 37.0 * t)
            "vent":
                value = 0.27 * sin(TAU * 39.0 * t) + 0.10 * sin(TAU * 84.0 * t)
                value += 0.09 * sin(TAU * 391.0 * t) * sin(TAU * 77.0 * t)
            "pressure":
                value = 0.26 * sin(TAU * 41.0 * t) + 0.17 * sin(TAU * 47.0 * t)
                value += 0.07 * sin(TAU * 83.0 * t)
        samples[i] = value * 0.68
    return _wave(samples, true)

## Native-rate, phase-closed PCM. A tiny smooth zero-level seam and guard
## frames make the wrap safe even if a mixer interpolates at the endpoint.
## No frame-driven audio generation, decoder restart or repeated play().
static func _fluorescent_hum() -> AudioStreamWAV:
    var rate := maxi(int(AudioServer.get_mix_rate()), 22050)
    var count := rate * 8
    var guard := 4
    var edge := maxi(int(rate * 0.002), 2)
    var samples := PackedFloat32Array()
    samples.resize(count + guard)
    for i in range(count):
        var t := float(i) / float(rate)
        var hum := 0.24 * sin(TAU * 50.0 * t) + 0.17 * sin(TAU * 100.0 * t)
        hum += 0.07 * sin(TAU * 150.0 * t) + 0.025 * sin(TAU * 197.0 * t)
        # Eight seconds is an integer number of cycles for both modulators.
        var drift := 0.97 + 0.022 * sin(TAU * 0.25 * t) + 0.008 * sin(TAU * 0.375 * t)
        var seam := smoothstep(0.0, float(edge), float(mini(i, count - 1 - i)))
        samples[i] = hum * drift * seam * 0.68
    for i in range(guard):
        samples[count + i] = samples[i]
    return _wave(samples, true, rate, count)
