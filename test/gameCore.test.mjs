import test from 'node:test';
import assert from 'node:assert/strict';
import {
  createInitialState,
  updateGame,
  LEVEL,
} from '../src/gameCore.js';

test('player can move right and land on forest platforms', () => {
  let state = createInitialState();
  const startX = state.player.x;

  for (let frame = 0; frame < 75; frame += 1) {
    state = updateGame(state, { right: true }, 1 / 60);
  }

  assert.equal(state.status, 'playing');
  assert.ok(state.player.x > startX + 120);
  assert.equal(state.player.grounded, true);
  assert.ok(state.player.y <= LEVEL.height - 72);
});

test('jump input only works while grounded', () => {
  let state = createInitialState();
  state = updateGame(state, { jump: true }, 1 / 60);
  const firstJumpVelocity = state.player.vy;

  state = updateGame(state, { jump: true }, 1 / 60);

  assert.ok(firstJumpVelocity < -450);
  assert.ok(state.player.vy > firstJumpVelocity);
});

test('collecting all acorns opens the finish gate and reaching it wins', () => {
  let state = createInitialState();

  for (const acorn of state.acorns) {
    state = {
      ...state,
      player: { ...state.player, x: acorn.x, y: acorn.y },
    };
    state = updateGame(state, {}, 1 / 60);
  }

  assert.equal(state.collected, state.acorns.length);
  assert.equal(state.gateOpen, true);

  state = {
    ...state,
    player: { ...state.player, x: LEVEL.goal.x, y: LEVEL.goal.y },
  };
  state = updateGame(state, {}, 1 / 60);

  assert.equal(state.status, 'won');
});

test('falling below the level resets player to the last safe spawn', () => {
  let state = createInitialState();
  state = {
    ...state,
    player: { ...state.player, x: 900, y: LEVEL.height + 150 },
  };

  state = updateGame(state, {}, 1 / 60);

  assert.equal(state.status, 'playing');
  assert.equal(state.player.x, state.spawn.x);
  assert.equal(state.player.y, state.spawn.y);
});
