export const LEVEL = {
  width: 2600,
  height: 540,
  gravity: 1900,
  goal: { x: 2460, y: 392, width: 44, height: 88 },
  platforms: [
    { x: 0, y: 480, width: 520, height: 60, kind: 'soil' },
    { x: 610, y: 458, width: 300, height: 82, kind: 'soil' },
    { x: 980, y: 430, width: 250, height: 110, kind: 'moss' },
    { x: 1280, y: 374, width: 190, height: 34, kind: 'branch' },
    { x: 1540, y: 432, width: 320, height: 108, kind: 'soil' },
    { x: 1930, y: 390, width: 180, height: 34, kind: 'branch' },
    { x: 2180, y: 452, width: 420, height: 88, kind: 'soil' },
  ],
  acorns: [
    { x: 330, y: 424 },
    { x: 700, y: 402 },
    { x: 1090, y: 374 },
    { x: 1355, y: 318 },
    { x: 1655, y: 376 },
    { x: 2000, y: 334 },
  ],
};

const PLAYER = {
  width: 34,
  height: 46,
  speed: 245,
  jumpVelocity: -660,
  maxFall: 980,
};

const SPAWN = { x: 70, y: 434 };

export function createInitialState() {
  return {
    status: 'playing',
    time: 0,
    spawn: { ...SPAWN },
    player: {
      x: SPAWN.x,
      y: SPAWN.y,
      vx: 0,
      vy: 0,
      width: PLAYER.width,
      height: PLAYER.height,
      grounded: true,
      facing: 1,
    },
    acorns: LEVEL.acorns.map((acorn) => ({ ...acorn, collected: false })),
    collected: 0,
    gateOpen: false,
  };
}

export function updateGame(state, input = {}, dt = 1 / 60) {
  if (input.restart) {
    return createInitialState();
  }

  if (state.status !== 'playing') {
    return { ...state, time: state.time + dt };
  }

  const step = Math.min(dt, 1 / 30);
  const player = { ...state.player };
  const direction = Number(Boolean(input.right)) - Number(Boolean(input.left));

  player.vx = direction * PLAYER.speed;
  if (direction !== 0) {
    player.facing = Math.sign(direction);
  }

  if (input.jump && player.grounded) {
    player.vy = PLAYER.jumpVelocity;
    player.grounded = false;
  }

  player.vy = Math.min(player.vy + LEVEL.gravity * step, PLAYER.maxFall);
  player.x += player.vx * step;
  player.x = clamp(player.x, 0, LEVEL.width - player.width);

  const previousBottom = player.y + player.height;
  player.y += player.vy * step;
  player.grounded = false;

  for (const platform of LEVEL.platforms) {
    const playerBottom = player.y + player.height;
    const crossesTop = previousBottom <= platform.y && playerBottom >= platform.y;

    if (player.vy >= 0 && crossesTop && overlapsX(player, platform)) {
      player.y = platform.y - player.height;
      player.vy = 0;
      player.grounded = true;
    }
  }

  let nextState = {
    ...state,
    time: state.time + step,
    player,
  };

  if (player.y > LEVEL.height + 80) {
    nextState = {
      ...nextState,
      player: {
        ...player,
        x: state.spawn.x,
        y: state.spawn.y,
        vx: 0,
        vy: 0,
        grounded: true,
      },
    };
  }

  const acorns = nextState.acorns.map((acorn) => {
    if (acorn.collected) {
      return acorn;
    }

    return distance(nextState.player.x + nextState.player.width / 2, nextState.player.y + 18, acorn.x, acorn.y) < 38
      ? { ...acorn, collected: true }
      : acorn;
  });
  const collected = acorns.filter((acorn) => acorn.collected).length;
  const gateOpen = collected === acorns.length;
  const status = gateOpen && rectanglesOverlap(nextState.player, LEVEL.goal) ? 'won' : 'playing';

  return {
    ...nextState,
    acorns,
    collected,
    gateOpen,
    status,
  };
}

function overlapsX(a, b) {
  return a.x + a.width > b.x && a.x < b.x + b.width;
}

function rectanglesOverlap(a, b) {
  return a.x < b.x + b.width
    && a.x + a.width > b.x
    && a.y < b.y + b.height
    && a.y + a.height > b.y;
}

function distance(ax, ay, bx, by) {
  return Math.hypot(ax - bx, ay - by);
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}
