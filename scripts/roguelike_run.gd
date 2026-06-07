extends RefCounted
class_name RoguelikeRun

const REWARD_LIBRARY := [
	{
		"id": "blood_vial",
		"label": "Blood Vial",
		"description": "最大 HP +1",
		"max_health_bonus": 1,
		"curse": 0,
	},
	{
		"id": "silver_bullet",
		"label": "Silver Bullet",
		"description": "FOCUS を全回復",
		"max_health_bonus": 0,
		"curse": 0,
	},
	{
		"id": "thorn_oath",
		"label": "Thorn Oath",
		"description": "最大 HP +1、呪い +1",
		"max_health_bonus": 1,
		"curse": 1,
	},
]

func reward_choices_for(stage_index: int, run_seed: int) -> Array:
	if stage_index <= 1:
		return [REWARD_LIBRARY[0], REWARD_LIBRARY[1]]
	var first_index: int = absi(run_seed + stage_index) % REWARD_LIBRARY.size()
	var second_index: int = (first_index + 1) % REWARD_LIBRARY.size()
	return [REWARD_LIBRARY[first_index], REWARD_LIBRARY[second_index]]

func select_reward(choices: Array) -> Dictionary:
	if choices.is_empty():
		return {}
	return choices[0]

func stage_seed_for(run_seed: int, stage_index: int) -> int:
	return run_seed + max(stage_index - 1, 0) * 101

func stage_variant_for(stage_index: int) -> String:
	if stage_index % 2 == 0:
		return "moonlit_cloister"
	return "cathedral_keep"
