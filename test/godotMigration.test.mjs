import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { spawnSync } from 'node:child_process';

const requiredFiles = [
  'project.godot',
  'scenes/main.tscn',
  'scenes/platform.tscn',
  'scenes/collectible.tscn',
  'scripts/game.gd',
  'scripts/stage_generator.gd',
  'scripts/player.gd',
  'scripts/e2e_runner.gd',
  'scripts/llm_verify.gd',
  'assets/background-city.png',
  'assets/player-idle-sheet-10.png',
  'assets/player-walk-sheet-24.png',
];

test('Godot migration includes the required project files and imported assets', () => {
  for (const file of requiredFiles) {
    assert.equal(existsSync(file), true, `${file} should exist`);
  }
});

test('Godot project opens the migrated main scene', async () => {
  const project = await readFile('project.godot', 'utf8');

  assert.match(project, /config\/name="Ecliptica"/);
  assert.match(project, /run\/main_scene="res:\/\/scenes\/main\.tscn"/);
  assert.match(project, /config\/features=PackedStringArray\("4\./);
});

test('Godot project launches and renders at 1920x1080', async () => {
  const project = await readFile('project.godot', 'utf8');
  const readme = await readFile('README.md', 'utf8');
  const readSetting = (name) => {
    const match = project.match(new RegExp(`^${name}=(\\d+)$`, 'm'));
    return match ? Number(match[1]) : null;
  };

  assert.equal(readSetting('window/size/viewport_width'), 1920);
  assert.equal(readSetting('window/size/viewport_height'), 1080);
  assert.equal(readSetting('window/size/window_width_override'), 1920);
  assert.equal(readSetting('window/size/window_height_override'), 1080);
  assert.match(readme, /```bash\ngodot --path \.\n```/);
  assert.doesNotMatch(readme, /--resolution 1920x1080/);
});

test('main scene wires gameplay, generated stage, player animation, and E2E runner', async () => {
  const scene = await readFile('scenes/main.tscn', 'utf8');

  assert.match(scene, /script = ExtResource\("1_game"\)/);
  assert.match(scene, /StageGenerator/);
  assert.match(scene, /\[node name="PlayerSprite" type="AnimatedSprite2D" parent="Player"\]/);
  assert.match(scene, /E2ERunner/);
  assert.match(scene, /Goal/);
  assert.doesNotMatch(scene, /\[node name="Ground1"/);
  assert.doesNotMatch(scene, /\[node name="Collectible1"/);
  assert.match(scene, /CollisionShape2D/);
  assert.match(scene, /zoom = Vector2\(2, 2\)/);
  assert.match(scene, /position = Vector2\(-2, -68\)/);
  assert.match(scene, /scale = Vector2\(0\.3, 0\.3\)/);
});

test('Godot scripts expose the expected gameplay and E2E hooks', async () => {
  const game = await readFile('scripts/game.gd', 'utf8');
  const generator = await readFile('scripts/stage_generator.gd', 'utf8');
  const player = await readFile('scripts/player.gd', 'utf8');
  const e2e = await readFile('scripts/e2e_runner.gd', 'utf8');
  const llmVerify = await readFile('scripts/llm_verify.gd', 'utf8');

  assert.match(game, /func collect_sigil/);
  assert.match(game, /func open_gate/);
  assert.match(game, /func win_game/);
  assert.match(game, /TARGET_WINDOW_SIZE := Vector2i\(1920, 1080\)/);
  assert.match(game, /DisplayServer\.window_set_size\(TARGET_WINDOW_SIZE\)/);
  assert.match(game, /generated_stage_summary/);
  assert.match(generator, /func generate_stage/);
  assert.match(generator, /ROOM_LIBRARY/);
  assert.match(generator, /DEFAULT_STAGE_SEED := 1337/);
  assert.match(generator, /platform_count/);
  assert.match(generator, /sigil_count/);
  assert.match(player, /func _physics_process/);
  assert.match(player, /func _update_animation/);
  assert.match(player, /IDLE_FRAME_COUNT := 10/);
  assert.match(player, /WALK_FRAME_COUNT := 24/);
  assert.match(player, /player-idle-sheet-10\.png/);
  assert.match(player, /player-walk-sheet-24\.png/);
  assert.match(e2e, /func run_e2e/);
  assert.match(e2e, /E2E_OK/);
  assert.match(llmVerify, /LLM_VERIFY_JSON/);
  assert.match(llmVerify, /llm_headless_verify/);
});

test('player visuals flip sprites instead of scaling the physics body', async () => {
  const player = await readFile('scripts/player.gd', 'utf8');

  assert.doesNotMatch(player, /scale\.x\s*=/);
  assert.match(player, /flip_h/);
});

test('walk atlas frames have transparent gutters for Godot hframes slicing', () => {
  const result = spawnSync(process.execPath, ['test/walkAtlasCheck.mjs'], {
    cwd: process.cwd(),
    encoding: 'utf8',
  });

  assert.equal(result.status, 0, result.stderr || result.stdout);
});
