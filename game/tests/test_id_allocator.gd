extends GutTest

# IdAllocator -- one of a world's id counters (D-104, D-114, D-118).


func test_ids_count_up_from_one() -> void:
	var ids: IdAllocator = IdAllocator.new()
	assert_eq(ids.allocate(), 1, "0 is no id, so the first is 1")
	assert_eq(ids.allocate(), 2, "and counts up")


func test_peek_takes_nothing() -> void:
	var ids: IdAllocator = IdAllocator.new()
	assert_eq(ids.peek(), 1, "the next id")
	assert_eq(ids.peek(), 1, "still the next id")
	assert_eq(ids.allocate(), 1, "and it's the one handed out")


func test_claim_moves_past_an_id_in_use() -> void:
	var ids: IdAllocator = IdAllocator.new()
	ids.claim(7)
	assert_eq(ids.allocate(), 8, "past the claimed id")


func test_claim_never_moves_back() -> void:
	var ids: IdAllocator = IdAllocator.new()
	ids.restore(20)
	ids.claim(3)
	assert_eq(ids.peek(), 20, "an id below the counter changes nothing")


func test_restore_sets_the_next_id() -> void:
	var ids: IdAllocator = IdAllocator.new()
	ids.allocate()
	ids.allocate()
	ids.restore(5)
	assert_eq(ids.peek(), 5, "restored outright, even below what was handed out")


func test_restore_never_goes_below_the_first_id() -> void:
	var ids: IdAllocator = IdAllocator.new()
	ids.restore(-4)
	assert_eq(ids.peek(), IdAllocator.FIRST_ID, "a hand-edited counter can't hand out 0")
