class_name AudioAssetGenerator
extends RefCounted

# Procedural fallback: synthesizes short AudioStreamWAV cues at runtime so the
# game has sound even when committed .ogg assets are absent. Drop real .ogg
# files into assets/audio/ (see README.md) to override these.
static func synthesized(cue_name: String) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	match cue_name:
		"goal_roar":
			stream.data = _tone(392.0, 0.9, 0.9, true)
		"whistle", "referee_whistle", "whistle_card":
			stream.data = _tone(1850.0, 0.5, 0.7, false)
		"substitution":
			stream.data = _tone(660.0, 0.4, 0.5, false)
		"shot_contact", "contact":
			stream.data = _tone(180.0, 0.18, 0.8, true)
		"injury_stop":
			stream.data = _tone(440.0, 0.6, 0.5, false)
		_:
			stream.data = _tone(880.0, 0.12, 0.4, false)
	return stream

static func _tone(freq: float, seconds: float, gain: float, noise: bool) -> PackedByteArray:
	var rate := 22050
	var frames := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(frames)
	for i in range(frames):
		var t := float(i) / float(rate)
		var envelope := 1.0 - float(i) / float(maxi(1, frames))
		var sample := sin(TAU * freq * t) * envelope * gain
		if noise:
			sample = (sample + (randf() - 0.5) * 0.7 * envelope * gain) * 0.8
		data[i] = clampi(int(128 + sample * 127.0), 0, 255)
	return data
