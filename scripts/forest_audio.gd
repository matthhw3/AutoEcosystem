extends AudioStreamPlayer
## Original synthesized ambience; no recordings, downloads or runtime services.
func _ready() -> void:
	var sample_rate := 22050
	var duration := 6
	var bytes := PackedByteArray()
	bytes.resize(sample_rate * duration * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 57139
	var low := 0.0
	for i in range(sample_rate * duration):
		var t: float = float(i) / sample_rate
		low = low * 0.985 + noise.randf_range(-1, 1) * 0.015
		var wind: float = low * (0.5 + 0.2 * sin(TAU * t / duration))
		var chirp := 0.0
		for start in [0.7, 1.0, 3.1, 3.35, 4.8]:
			var age: float = t - start
			if age >= 0 and age < 0.15:
				chirp += sin(TAU * (2200 * age + 1900 * age * age)) * sin(PI * age / 0.15) * 0.08
		var fade: float = minf(1, minf(t, duration - t) * 10)
		var value := int(clampf((wind + chirp) * fade, -1, 1) * 32767)
		bytes.encode_s16(i * 2, value)
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = sample_rate
	audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
	audio.loop_end = sample_rate * duration
	audio.data = bytes
	stream = audio
	volume_db = -15
	if DisplayServer.get_name() != "headless": play()

func _exit_tree() -> void:
	stop()
	stream = null
