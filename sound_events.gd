extends Node

# Procedural audio placeholders approved for M6; replace streams here with
# Chris's files later, leaving callers and cue names unchanged.
signal cue_played(cue: StringName)
const CUES := {
	&"paddle_bounce": Vector2(660, 0.07),
	&"wall_bounce": Vector2(330, 0.045),
	&"brick_break": Vector2(880, 0.09),
	&"power_up_catch": Vector2(1100, 0.16),
	&"hazard_catch": Vector2(150, 0.22),
	&"life_lost": Vector2(220, 0.30),
	&"level_complete": Vector2(990, 0.40),
	&"game_over": Vector2(110, 0.60),
	&"win": Vector2(1320, 0.65),
}
const SAMPLE_RATE := 22050
const VOICES := 12
@export_range(0.0, 1.0) var volume := 0.5:
	set(value):
		if not is_finite(value):
			push_warning("Sound volume must be finite; keeping the previous volume.")
			return
		volume = clampf(value, 0.0, 1.0)
		for player in players:
			player.volume_linear = volume
# Share immutable cue resources across scene reloads; players stay scene-owned.
static var streams: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var next_voice := 0

func _ready() -> void:
	if streams.is_empty():
		for cue in CUES:
			streams[cue] = _tone(CUES[cue])
	for index in VOICES:
		var player := AudioStreamPlayer.new()
		player.volume_linear = volume
		add_child(player)
		players.append(player)

func _exit_tree() -> void:
	for player in players:
		player.stop()
		player.stream = null

func play_cue(cue: StringName) -> bool:
	if not streams.has(cue):
		push_warning("Unknown or uninitialized sound cue: %s" % cue)
		return false
	cue_played.emit(cue)
	# The headless Dummy driver has no output or useful playback to schedule.
	if volume == 0.0 or AudioServer.get_driver_name() == "Dummy":
		return true
	# Prefer idle voices. At capacity, replace one voice instead of growing nodes
	# indefinitely during multi-ball or a burst of brick breaks.
	var player := players[next_voice]
	for candidate in players:
		if not candidate.playing:
			player = candidate
			break
	next_voice = (players.find(player) + 1) % VOICES
	player.stream = streams[cue]
	player.play()
	return true

func _tone(tuning: Vector2) -> AudioStreamWAV:
	var frames := int(tuning.y * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for frame in frames:
		var time := float(frame) / SAMPLE_RATE
		# Short attack and release avoid clicks; leave headroom for overlapping cues.
		var envelope := minf(time / 0.005, (tuning.y - time) / 0.025)
		var sample := sin(TAU * tuning.x * time) * clampf(envelope, 0.0, 1.0) * 0.12
		data.encode_s16(frame * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	return stream
