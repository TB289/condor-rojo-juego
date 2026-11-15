class_name InteriorProp
extends StaticBody2D
## A bed, console, crate or plant row inside a base module. Origin at the base, for Y-sort.
## If target_id is set, "interact" while standing close goes to MissionSystem.

enum Kind { BUNK, CONSOLE, CRATE, PLANTS, TANK, STRIAE, CENTRIFUGE, ROBOT_ARM, SHELF }

const CRATE_TEX := preload("res://assets/art/base/crates.png")
const BUNK_TEX := preload("res://assets/art/base/interior_bed.png")
const CONSOLE_TEX := preload("res://assets/art/base/interior_console.png")
const FILES_TEX := preload("res://assets/art/base/interior_files.png")
const TANK_TEX := preload("res://assets/art/base/interior_tank.png")

@export var kind: Kind = Kind.BUNK
@export var target_id: StringName = &""
## 0 sprout, 1 growing, 2 ready to pick. Only plants use this.
@export var stage: int = 1

var _player: Player
var _ticks := -1.0
var _art_sprite: Sprite2D


func _ready() -> void:
	# A decorative wall mark has no hitbox, so it cannot trap anyone in the cave.
	if kind != Kind.STRIAE or target_id != &"":
		_add_hitbox(_hit_size())
	if kind == Kind.CRATE:
		var sprite := Sprite2D.new()
		sprite.texture = CRATE_TEX
		sprite.offset = Vector2(0, -CRATE_TEX.get_height() / 2.0)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
	_add_art_sprite()
	if target_id != &"" or kind == Kind.BUNK or kind == Kind.TANK:
		_add_use_area()
	if target_id != &"":
		add_to_group(MissionSystem.TARGET_GROUP)
	add_to_group(&"interior_prop")
	if kind == Kind.PLANTS and target_id == &"greenhouse_bed":
		stage = GameState.bed_stage
		MissionSystem.work_progress.connect(_on_bed_work)
	queue_redraw()
	set_process(kind == Kind.CONSOLE or kind == Kind.TANK or target_id == &"greenhouse_bed")


func _exit_tree() -> void:
	if MissionSystem.work_progress.is_connected(_on_bed_work):
		MissionSystem.work_progress.disconnect(_on_bed_work)


func _process(_delta: float) -> void:
	if target_id == &"greenhouse_bed" or kind == Kind.TANK:
		_refresh_plant()
		return
	queue_redraw()


func get_target_id() -> StringName:
	return target_id


func sync_growth() -> void:
	if kind != Kind.PLANTS:
		return
	if target_id == &"greenhouse_bed":
		stage = _farm_stage() if GameState.farm_started else GameState.bed_stage
	queue_redraw()


func sign_top() -> Vector2:
	var top := -16.0
	match kind:
		Kind.BUNK:
			top = -22.0
		Kind.CONSOLE:
			top = -24.0
		Kind.PLANTS:
			top = -26.0 if stage >= 2 else -16.0
		Kind.TANK:
			top = -24.0
		Kind.STRIAE:
			top = -28.0
		Kind.CENTRIFUGE:
			top = -26.0
		Kind.ROBOT_ARM:
			top = -28.0
		Kind.SHELF:
			top = -26.0
		Kind.CRATE:
			top = -float(CRATE_TEX.get_height())
	return to_global(Vector2(0.0, top))


func is_player_near() -> bool:
	return _player != null


func release_player() -> void:
	if _player != null and _player.interacted.is_connected(_on_interact):
		_player.interacted.disconnect(_on_interact)
	_player = null


func _art_texture() -> Texture2D:
	match kind:
		Kind.BUNK:
			return BUNK_TEX
		Kind.CONSOLE:
			return CONSOLE_TEX
		Kind.SHELF:
			return FILES_TEX
		Kind.TANK:
			return TANK_TEX
		Kind.CRATE:
			return FILES_TEX if target_id == &"habitat_supplies" else null
		_:
			return null


func _add_art_sprite() -> void:
	var tex := _art_texture()
	if tex == null:
		return
	_art_sprite = Sprite2D.new()
	_art_sprite.texture = tex
	_art_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art_sprite.offset = Vector2(0, -tex.get_height() / 2.0)
	if kind == Kind.TANK:
		_art_sprite.position = Vector2(0, 2)
	add_child(_art_sprite)


func _hit_size() -> Vector2:
	match kind:
		Kind.BUNK:
			return Vector2(42, 14)
		Kind.CONSOLE:
			return Vector2(32, 12)
		Kind.PLANTS:
			return Vector2(56, 14)
		Kind.TANK:
			return Vector2(26, 12)
		Kind.STRIAE:
			return Vector2(30, 12)
		Kind.CENTRIFUGE:
			return Vector2(24, 14)
		Kind.ROBOT_ARM:
			return Vector2(24, 16)
		Kind.SHELF:
			return Vector2(34, 12)
		_:
			return Vector2(20, 12)


func _add_hitbox(size: Vector2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, -size.y / 2.0)
	add_child(collision)


func _add_use_area() -> void:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := CircleShape2D.new()
	shape.radius = 24.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, 2)
	area.add_child(collision)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)


func _draw() -> void:
	draw_rect(Rect2(-12, -3, 24, 4), Color(0.102, 0.047, 0.078, 0.45))
	if _art_sprite != null and kind not in [Kind.PLANTS, Kind.STRIAE]:
		return
	match kind:
		Kind.BUNK:
			_draw_bunk()
		Kind.CONSOLE:
			_draw_console()
		Kind.PLANTS:
			_draw_plants()
		Kind.TANK:
			_draw_tank()
		Kind.STRIAE:
			_draw_striae()
		Kind.CENTRIFUGE:
			_draw_centrifuge()
		Kind.ROBOT_ARM:
			_draw_robot_arm()
		Kind.SHELF:
			_draw_shelf()


func _panel(rect: Rect2, fill: Color) -> void:
	draw_rect(Rect2(rect.position - Vector2.ONE, rect.size + Vector2(2, 2)), Color("3a1a28"))
	draw_rect(rect, fill)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1)), Color("f0f4f8"))


func _draw_bunk() -> void:
	_panel(Rect2(-18, -18, 36, 16), Color("3a4854"))
	draw_rect(Rect2(-16, -16, 22, 12), Color("fff8ec"))
	draw_rect(Rect2(6, -16, 10, 12), Color("8a3058"))
	draw_rect(Rect2(-15, -15, 8, 6), Color("fffce8"))
	draw_rect(Rect2(-16, -8, 32, 2), Color("ff6a20"))


func _draw_console() -> void:
	_panel(Rect2(-14, -22, 28, 18), Color("3a4854"))
	draw_rect(Rect2(-11, -18, 16, 10), Color("142030"))
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 5.0)
	draw_rect(Rect2(-9, -16, 12, 6), Color("142030").lerp(Color("3ed4e8"), 0.35 + pulse * 0.65))
	if pulse > 0.55:
		draw_rect(Rect2(-8, -15, 3, 2), Color("b8f4ff"))
	draw_rect(Rect2(7, -16, 5, 8), Color("1a0c14"))
	draw_rect(Rect2(-4, -6, 4, 3), Color("ff6a20"))
	draw_rect(Rect2(2, -6, 3, 3), Color("ffe000"))

func _draw_centrifuge() -> void:
	_panel(Rect2(-12, -18, 24, 14), Color("3a4854"))
	draw_rect(Rect2(-10, -16, 20, 10), Color("7a8c9a"))
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 4.0)
	draw_rect(Rect2(-5, -14, 10, 6), Color("3ed4e8").lerp(Color("b8f4ff"), pulse))
	draw_rect(Rect2(-2, -24, 4, 6), Color("f0f4f8"))
	draw_rect(Rect2(-6, -26, 12, 2), Color("3a4854"))
	draw_rect(Rect2(-12, -5, 24, 2), Color("ff6a20"))


func _draw_robot_arm() -> void:
	_panel(Rect2(-12, -10, 24, 8), Color("43546a"))
	draw_rect(Rect2(-1, -24, 2, 14), Color("9cb0bc"))
	draw_rect(Rect2(-1, -22, 10, 2), Color("9cb0bc"))
	draw_rect(Rect2(8, -22, 2, 8), Color("9cb0bc"))
	draw_rect(Rect2(10, -16, 4, 2), Color("ff6a20"))
	draw_rect(Rect2(12, -18, 2, 2), Color("ff6a20"))
	draw_rect(Rect2(-8, -8, 16, 4), Color("1a0c14"))
	draw_rect(Rect2(-6, -7, 12, 2), Color("3ed4e8"))


func _draw_shelf() -> void:
	_panel(Rect2(-15, -22, 30, 18), Color("3a4854"))
	draw_rect(Rect2(-13, -18, 26, 2), Color("9cb0bc"))
	draw_rect(Rect2(-13, -11, 26, 2), Color("9cb0bc"))
	draw_rect(Rect2(-12, -21, 4, 17), Color("1a0c14"))
	draw_rect(Rect2(8, -21, 4, 17), Color("1a0c14"))
	draw_rect(Rect2(-6, -20, 5, 4), Color("c47848"))
	draw_rect(Rect2(0, -20, 5, 4), Color("8ce846"))
	draw_rect(Rect2(-5, -13, 11, 3), Color("2a8ab8"))
	draw_rect(Rect2(-7, -9, 6, 4), Color("d4a05a"))
	draw_rect(Rect2(1, -9, 8, 4), Color("8a3058"))



func _draw_plants() -> void:
	for i in 4:
		var x := -26.0 + float(i) * 13.0
		_panel(Rect2(x, -8, 10, 6), Color("3a4854"))
		draw_rect(Rect2(x + 1, -7, 8, 4), Color("a84828"))
		_draw_plant(x, stage)
		if GameState.has_flag(&"plants_watered") and stage < 3:
			_draw_drops(x)
	if target_id == &"greenhouse_bed":
		_draw_ticks()


func _draw_plant(x: float, grown: int) -> void:
	if grown <= 0:
		draw_rect(Rect2(x + 4, -12, 2, 4), Color("2e8a28"))
		draw_rect(Rect2(x + 2, -14, 3, 2), Color("8ce846"))
		draw_rect(Rect2(x + 5, -15, 3, 2), Color("b4f86a"))
		return
	if grown == 1:
		draw_rect(Rect2(x + 4, -18, 2, 10), Color("2e8a28"))
		draw_rect(Rect2(x + 1, -16, 4, 3), Color("8ce846"))
		draw_rect(Rect2(x + 5, -18, 4, 3), Color("b4f86a"))
		return
	if grown == 2:
		draw_rect(Rect2(x + 4, -24, 2, 16), Color("2e8a28"))
		draw_rect(Rect2(x, -22, 5, 4), Color("8ce846"))
		draw_rect(Rect2(x + 5, -24, 5, 4), Color("b4f86a"))
		draw_rect(Rect2(x + 2, -12, 6, 4), Color("c47848"))
		draw_rect(Rect2(x + 3, -11, 2, 2), Color("f6c878"))
		return
	draw_rect(Rect2(x + 4, -12, 2, 4), Color("8a2e14"))
	draw_rect(Rect2(x + 3, -10, 4, 2), Color("2e8a28"))


func _draw_drops(x: float) -> void:
	draw_rect(Rect2(x + 1, -9, 2, 2), Palette.INTI)
	draw_rect(Rect2(x + 8, -12, 1, 2), Palette.INTI)


func _draw_ticks() -> void:
	if _ticks < 0.0:
		return
	var x := -25.0
	for i in 10:
		var on := float(i + 1) / 10.0 <= _ticks + 0.0001
		draw_rect(Rect2(x, -30, 4, 1), Palette.ORO if on else Palette.METAL)
		x += 5.0


func _draw_striae() -> void:
	_panel(Rect2(-16, -28, 32, 24), Color("3a1a28"))
	draw_rect(Rect2(-14, -26, 28, 20), Color("8a2e14"))
	draw_rect(Rect2(-14, -22, 28, 2), Color("5a2468"))
	draw_rect(Rect2(-14, -16, 28, 2), Color("1a0c14"))
	draw_rect(Rect2(-14, -11, 28, 2), Color("5a2468"))
	draw_rect(Rect2(-4, -26, 3, 20), Color("3ed4e8"))
	draw_rect(Rect2(-3, -24, 1, 8), Color("b8f4ff"))
	draw_rect(Rect2(6, -20, 6, 5), Color("d4a05a"))
	draw_rect(Rect2(-12, -8, 8, 3), Color("c47848"))


func _draw_tank() -> void:
	_panel(Rect2(-8, -22, 16, 18), Color("3a4854"))
	draw_rect(Rect2(-6, -20, 12, 14), Color("2a8ab8"))
	draw_rect(Rect2(-6, -20, 12, 3), Color("3ed4e8"))
	draw_rect(Rect2(-5, -16, 3, 6), Color("b8f4ff"))
	# A small can beside the tank.
	_panel(Rect2(8, -10, 8, 6), Color("7a8c9a"))
	draw_rect(Rect2(10, -14, 2, 5), Color("f0f4f8"))
	draw_rect(Rect2(9, -8, 6, 3), Color("3ed4e8"))


func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	_player = body
	if not _player.interacted.is_connected(_on_interact):
		_player.interacted.connect(_on_interact)
	if kind == Kind.PLANTS or kind == Kind.TANK:
		_refresh_plant()


func _on_body_exited(body: Node2D) -> void:
	if body != _player:
		return
	if _player.interacted.is_connected(_on_interact):
		_player.interacted.disconnect(_on_interact)
	_player = null
	if kind == Kind.PLANTS or kind == Kind.TANK:
		_refresh_plant()


func _on_interact(_dir: StringName) -> void:
	if BasePlacer.active or GameState.run_over:
		return
	var travel := get_tree().get_first_node_in_group(&"interior_travel") as InteriorTravel
	if travel != null and travel.busy:
		return
	if MissionSystem.door_has_player():
		return
	if kind == Kind.BUNK:
		if MissionSystem.preferred_interact_target() != &"":
			return
		DayNightSystem.offer_sleep()
		return
	if kind == Kind.TANK:
		GameState.farm_water_stock = 4
		_show_farm_notice("Tanque lleno: 4 cargas de agua.", "Water tank refilled: 4 watering charges.")
		return
	if target_id == &"greenhouse_bed":
		if MissionSystem.wants(target_id):
			MissionSystem.try_interact(target_id)
			return
		_do_farming()
		return
	if not MissionSystem.accepts_interact(target_id):
		return
	MissionSystem.try_interact(target_id)


func local_prompt() -> String:
	if _player == null:
		return ""
	if kind == Kind.BUNK:
		if MissionSystem.has_tasks_left():
			return Settings.text("bed.busy")
		return Settings.text("bed.sleep")
	if kind == Kind.TANK:
		return Settings.text("farm.refill") % GameState.farm_water_stock
	if target_id == &"greenhouse_bed":
		if MissionSystem.wants(target_id):
			return MissionSystem.prompt_for(target_id)
		return _farming_prompt()
	return ""


func _refresh_plant(_lang: String = "") -> void:
	if kind == Kind.PLANTS and GameState.farm_started:
		var next_stage := _farm_stage()
		if stage != next_stage:
			stage = next_stage
			queue_redraw()


func _farm_stage() -> int:
	if GameState.farm_seeded_sol < 0:
		return 3
	if GameState.farm_watered and GameState.current_sol > GameState.farm_seeded_sol:
		return 2
	return 1 if GameState.farm_watered else 0


func _farming_prompt() -> String:
	if GameState.farm_seeded_sol < 0:
		return Settings.text("farm.plant") % GameState.farm_seed_stock
	if _farm_stage() == 2:
		return Settings.text("farm.harvest")
	if not GameState.farm_watered:
		return Settings.text("farm.water")
	return Settings.text("farm.growing")


func _do_farming() -> void:
	if GameState.farm_seeded_sol < 0:
		if GameState.farm_seed_stock <= 0:
			_show_farm_notice(Settings.text("farm.no_seed"), "")
			return
		GameState.farm_started = true
		GameState.farm_seed_stock -= 1
		GameState.farm_seeded_sol = GameState.current_sol
		GameState.farm_watered = false
		_show_farm_notice(Settings.text("farm.planted"), "")
	elif _farm_stage() == 2:
		ResourceSystem.add(&"food", 12.0)
		GameState.farm_seed_stock = mini(4, GameState.farm_seed_stock + 1)
		GameState.farm_seeded_sol = -1
		GameState.farm_watered = false
		_show_farm_notice(Settings.text("farm.harvested"), "")
	elif not GameState.farm_watered:
		if GameState.farm_water_stock <= 0:
			_show_farm_notice(Settings.text("farm.no_water"), "")
			return
		GameState.farm_water_stock -= 1
		GameState.farm_watered = true
		_show_farm_notice(Settings.text("farm.watered"), "")
	else:
		_show_farm_notice(Settings.text("farm.growing"), "")
	sync_growth()


func _show_farm_notice(es: String, en: String) -> void:
	var hud := get_tree().get_first_node_in_group(&"hud")
	if hud != null and hud.has_method(&"show_notice"):
		if en.is_empty():
			hud.call(&"show_notice", es)
		else:
			hud.call(&"show_notice", Settings.pack(es, en))


func _on_bed_work(ratio: float) -> void:
	var next := -1.0
	if ratio >= 0.0 and MissionSystem.work_target() == target_id:
		next = ratio
	if is_equal_approx(next, _ticks):
		return
	_ticks = next
	queue_redraw()

