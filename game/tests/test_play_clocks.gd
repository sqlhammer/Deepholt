extends GutTest

# The two playtime clocks (D-120): active play stops while the game is
# paused, total play counts whenever the game is open. Both are saved
# under the header's `stats`, and a load seeds them so they add up
# across sessions.

const SaveDirs = preload("res://tests/save_dirs.gd")
const SAVES_ROOT: String = SaveDirs.TEST_ROOT + "/play_clocks"

var _game: Node


func before_each() -> void:
	_game = load("res://scenes/game.tscn").instantiate()
	_game.saves_root = SAVES_ROOT
	add_child_autofree(_game)


func after_each() -> void:
	SaveDirs.remove_tree(SAVES_ROOT)


func _active() -> Timer:
	return _game.get_node("ActivePlayTimer")


func _total() -> Timer:
	return _game.get_node("TotalPlayTimer")


func _saved_stats() -> Variant:
	var data: Dictionary = SaveGame.get_save_data(_game.current_save_slot)
	return data.get("stats")


# --- counting ---

func test_both_clocks_run_from_launch() -> void:
	assert_false(_active().is_stopped(), "active play is counting")
	assert_false(_total().is_stopped(), "total play is counting")


func test_active_play_stops_when_paused_and_total_does_not() -> void:
	assert_eq(_active().process_mode, Node.PROCESS_MODE_PAUSABLE, "active pauses")
	assert_eq(_total().process_mode, Node.PROCESS_MODE_ALWAYS, "total never does")


func test_each_tick_adds_the_timers_interval() -> void:
	for clock: Timer in [_active(), _total()]:
		clock.setup(0.0)
		clock._on_timeout()
		clock._on_timeout()
		assert_eq(clock.seconds, clock.wait_time * 2, "%s: two ticks" % clock.name)


func test_setup_seeds_the_count_and_ticks_add_to_it() -> void:
	_active().setup(100.0)
	_active()._on_timeout()
	assert_eq(_active().seconds, 100.0 + _active().wait_time, "counts on from the seed")


func test_f3_text_is_the_formatted_count() -> void:
	_active().setup(65.0)
	_total().setup(3600.0)
	assert_eq(_game.get_active_play_time(), Global.format_duration(65.0), "active")
	assert_eq(_game.get_total_play_time(), Global.format_duration(3600.0), "total")


# --- saving ---

func test_a_save_writes_both_clocks_under_stats() -> void:
	_active().setup(12.0)
	_total().setup(30.0)
	assert_true(_game.save_game(), "saved")
	assert_eq(_saved_stats(), {"active_play_time": 12.0, "total_play_time": 30.0},
		"both clocks, as counted")


# A zero isn't written (D-120), so a clock that never ticked leaves
# its key out rather than saving a 0 over nothing.
func test_a_clock_at_zero_is_not_written() -> void:
	_active().setup(0.0)
	_total().setup(30.0)
	assert_true(_game.save_game(), "saved")
	assert_eq(_saved_stats(), {"total_play_time": 30.0}, "only the clock that counted")


# --- loading ---

func test_a_load_seeds_both_clocks_from_the_save() -> void:
	_active().setup(12.0)
	_total().setup(30.0)
	assert_true(_game.save_game(), "saved")
	_active().setup(500.0)
	_total().setup(900.0)
	assert_eq(_game.load_game(), _game.REFUSAL_REASON.NONE, "loaded")
	assert_eq(_active().seconds, 12.0, "active comes back")
	assert_eq(_total().seconds, 30.0, "total comes back")


# A missing value leaves the clock where it was (D-120): playtime is
# never lost to a save that didn't record it.
func test_a_clock_the_save_left_out_keeps_its_count() -> void:
	_active().setup(0.0)
	_total().setup(30.0)
	assert_true(_game.save_game(), "saved without active play")
	_active().setup(500.0)
	assert_eq(_game.load_game(), _game.REFUSAL_REASON.NONE, "loaded")
	assert_eq(_active().seconds, 500.0, "active keeps counting from where it was")
	assert_eq(_total().seconds, 30.0, "total comes back")


# Seeded, then counting on: played time adds up across sessions.
func test_a_loaded_clock_counts_on_from_the_saved_value() -> void:
	_total().setup(30.0)
	assert_true(_game.save_game(), "saved")
	assert_eq(_game.load_game(), _game.REFUSAL_REASON.NONE, "loaded")
	_total()._on_timeout()
	assert_eq(_total().seconds, 30.0 + _total().wait_time, "adds to the saved total")
