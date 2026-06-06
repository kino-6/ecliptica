extends SceneTree

func _init() -> void:
	call_deferred("run_e2e")

func run_e2e() -> void:
	if not _expect(ProjectSettings.get_setting("display/window/size/viewport_width") == 1920, "viewport width should be 1920"):
		return
	if not _expect(ProjectSettings.get_setting("display/window/size/viewport_height") == 1080, "viewport height should be 1080"):
		return

	var packed: PackedScene = load("res://scenes/main.tscn")
	if not _expect(packed != null, "main scene should load"):
		return
	var scene: Node = packed.instantiate()
	root.add_child(scene)

	await process_frame
	await process_frame

	var player: CharacterBody2D = scene.get_node("Player")
	var game: Node = scene
	if not _expect(player != null, "player should exist"):
		return
	if not _expect(scene.get_node_or_null("Background") != null, "background should exist"):
		return
	if not _expect(scene.get_node_or_null("Player/PlayerSprite") != null, "player sprite should exist"):
		return
	if not _expect(scene.get_node_or_null("StageGenerator") != null, "stage generator should exist"):
		return
	if not _expect(game.generated_stage_summary.has("seed"), "stage summary should exist"):
		return
	if not _expect(game.generated_stage_summary["seed"] == 1337, "stage seed should be deterministic"):
		return
	if not _expect(game.generated_stage_summary["platform_count"] >= 7, "stage should generate traversable platforms"):
		return
	if not _expect(game.generated_stage_summary["sigil_count"] == 6, "stage should generate six sigils"):
		return
	if not _expect(scene.get_node("Platforms").get_child_count() == game.generated_stage_summary["platform_count"], "platform container should match generated summary"):
		return
	if not _expect(get_nodes_in_group("sigils").size() == game.generated_stage_summary["sigil_count"], "sigil group should match generated summary"):
		return

	var start_x: float = player.global_position.x
	player.e2e_set_axis(1.0)
	for frame in 45:
		await process_frame
	if not _expect(player.global_position.x > start_x + 40.0, "player should move right"):
		return
	if not _expect(scene.get_node("Player/PlayerSprite").animation == "walk", "walk animation should become active"):
		return

	for sigil: Node in get_nodes_in_group("sigils"):
		game.collect_sigil(sigil)
	if not _expect(game.gate_open, "gate should open after all sigils are collected"):
		return

	player.global_position = scene.get_node("Goal").global_position
	game.win_game()
	if not _expect(game.won, "game should enter won state"):
		return

	print("E2E_OK")
	quit(0)

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
