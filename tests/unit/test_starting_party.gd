extends GutTest

func test_two_distinct_companions() -> void:
	var party := StartingParty.create()
	assert_eq(party.size(), 2)
	assert_ne(party[0].id, party[1].id)
	assert_ne(party[0].species, party[1].species)
	assert_ne(party[0].art, party[1].art)
	assert_ne(party[0].flies, party[1].flies, "one flies, one walks: distinct silhouettes and motion")
	assert_ne(party[0].follow_distance, party[1].follow_distance, "they never stack on one spot")
