import { createInitialState, updateGame, LEVEL } from './gameCore.js';

const canvas = document.querySelector('#game');
const context = canvas.getContext('2d');
const hud = {
  acorns: document.querySelector('[data-acorns]'),
  state: document.querySelector('[data-state]'),
  restart: document.querySelector('[data-restart]'),
  pause: document.querySelector('[data-pause]'),
};

const input = {
  left: false,
  right: false,
  jump: false,
  restart: false,
};

const backgroundPlate = new Image();
let backgroundPlateReady = false;
backgroundPlate.addEventListener('load', () => {
  backgroundPlateReady = true;
});
backgroundPlate.src = './images/background-city.png';

const playerSprite = new Image();
let playerSpriteReady = false;
playerSprite.addEventListener('load', () => {
  playerSpriteReady = true;
});
playerSprite.src = './images/player-body.png';

const playerWalkSheet = new Image();
let playerWalkSheetReady = false;
playerWalkSheet.addEventListener('load', () => {
  playerWalkSheetReady = true;
});
playerWalkSheet.src = './images/player-body-walk-sheet-12.png';

const WALK_FRAME_COUNT = 12;
const SPRITE_GUIDES = true;

const palette = {
  skyTop: '#03050a',
  skyMid: '#111722',
  skyBottom: '#07080b',
  storm: '#252d35',
  moon: '#d9d6cd',
  moonShade: '#111722',
  fog: 'rgba(199, 202, 198, 0.12)',
  gothicNear: '#07090d',
  gothicMid: '#111821',
  gothicFar: '#1b2430',
  window: '#d8a85f',
  windowDim: '#8a6239',
  iron: '#5f6674',
  ironBright: '#b9b7ad',
  armor: '#101219',
  armorLight: '#343a45',
  veil: '#050609',
  hair: '#d8cfbd',
  blood: '#8c1624',
  bloodLight: '#df4c4a',
  bone: '#d8cfbd',
  stone: '#202128',
  stoneTop: '#3a3b42',
};

let state = createInitialState();
let paused = false;
let lastTime = performance.now();
let pixelRatio = 1;
let view = { width: 960, height: 540, scale: 1 };

const keys = new Map([
  ['ArrowLeft', 'left'],
  ['KeyA', 'left'],
  ['ArrowRight', 'right'],
  ['KeyD', 'right'],
  ['ArrowUp', 'jump'],
  ['Space', 'jump'],
  ['KeyW', 'jump'],
]);

window.addEventListener('keydown', (event) => {
  if (event.code === 'KeyR') {
    state = createInitialState();
  }

  if (event.code === 'Escape') {
    togglePause();
  }

  const action = keys.get(event.code);
  if (action) {
    event.preventDefault();
    input[action] = true;
  }
});

window.addEventListener('keyup', (event) => {
  const action = keys.get(event.code);
  if (action) {
    event.preventDefault();
    input[action] = false;
  }
});

hud.restart.addEventListener('click', () => {
  state = createInitialState();
  paused = false;
  syncHud();
});

hud.pause.addEventListener('click', togglePause);
window.addEventListener('resize', resize);

for (const button of document.querySelectorAll('[data-touch]')) {
  const action = button.dataset.touch;
  const setPressed = (pressed) => {
    input[action] = pressed;
    button.classList.toggle('is-pressed', pressed);
  };

  button.addEventListener('pointerdown', (event) => {
    event.preventDefault();
    button.setPointerCapture(event.pointerId);
    setPressed(true);
  });
  button.addEventListener('pointerup', () => setPressed(false));
  button.addEventListener('pointercancel', () => setPressed(false));
  button.addEventListener('lostpointercapture', () => setPressed(false));
}

resize();
requestAnimationFrame(loop);

function loop(now) {
  const dt = Math.min((now - lastTime) / 1000, 0.05);
  lastTime = now;

  if (!paused) {
    state = updateGame(state, input, dt);
  }

  render();
  syncHud();
  input.restart = false;
  requestAnimationFrame(loop);
}

function resize() {
  const rect = canvas.getBoundingClientRect();
  pixelRatio = Math.min(window.devicePixelRatio || 1, 2);
  canvas.width = Math.floor(rect.width * pixelRatio);
  canvas.height = Math.floor(rect.height * pixelRatio);
  context.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);

  view = {
    width: rect.width,
    height: rect.height,
    scale: Math.min(rect.width / 960, rect.height / 540),
  };
}

function render() {
  const width = view.width;
  const height = view.height;
  const scale = view.scale;
  const worldHeight = LEVEL.height;
  const cameraMax = LEVEL.width - width / scale;
  const cameraX = clamp(state.player.x - width / scale * 0.38, 0, Math.max(0, cameraMax));

  context.clearRect(0, 0, width, height);
  context.save();
  context.scale(scale, scale);

  const visibleWidth = width / scale;
  const visibleHeight = height / scale;
  const worldOffsetY = Math.max(0, (visibleHeight - worldHeight) * 0.5);

  drawSky(cameraX, visibleWidth, visibleHeight);
  drawBackgroundPlate(cameraX, visibleWidth, visibleHeight);
  drawFog(cameraX, visibleWidth, visibleHeight, 0.26);

  context.translate(-cameraX, worldOffsetY);
  drawLanterns();
  drawPlatforms();
  drawBloodSigils();
  drawGate();
  drawPlayer();
  drawForeground(cameraX, visibleWidth);

  context.restore();

  drawVignette(width, height);

  if (state.status === 'won') {
    drawWinOverlay(width, height);
  }

  if (paused) {
    drawPauseOverlay(width, height);
  }
}

function drawSky(cameraX, visibleWidth, visibleHeight) {
  const gradient = context.createLinearGradient(0, 0, 0, visibleHeight);
  gradient.addColorStop(0, palette.skyTop);
  gradient.addColorStop(0.45, palette.skyMid);
  gradient.addColorStop(1, palette.skyBottom);
  context.fillStyle = gradient;
  context.fillRect(0, 0, visibleWidth, visibleHeight);

  const moonX = visibleWidth * 0.72 - cameraX * 0.006;
  context.fillStyle = palette.moon;
  context.beginPath();
  context.arc(moonX, 102, 39, 0, Math.PI * 2);
  context.fill();
  context.fillStyle = 'rgba(3, 5, 10, 0.56)';
  context.beginPath();
  context.arc(moonX + 16, 91, 37, 0, Math.PI * 2);
  context.fill();

  for (let i = 0; i < 7; i += 1) {
    const cloudX = ((i * 180 - cameraX * 0.012 + state.time * 0.8) % (visibleWidth + 260)) - 130;
    drawCloud(cloudX, 74 + (i % 3) * 34, 120 + (i % 2) * 48);
  }
}

function drawBackgroundPlate(cameraX, visibleWidth, visibleHeight) {
  if (!backgroundPlateReady) {
    return;
  }

  const sourceX = 0;
  const sourceY = 0;
  const sourceWidth = backgroundPlate.width;
  const sourceHeight = backgroundPlate.height;
  const coverScale = Math.max(visibleWidth / sourceWidth, visibleHeight / sourceHeight);
  const drawWidth = sourceWidth * coverScale;
  const drawHeight = sourceHeight * coverScale;
  const parallaxX = -((cameraX * 0.006) % 18);
  const drawX = (visibleWidth - drawWidth) / 2 + parallaxX;
  const drawY = (visibleHeight - drawHeight) / 2;

  context.save();
  context.globalAlpha = 0.82;
  context.filter = 'saturate(0.9) contrast(1.08) brightness(0.82)';
  context.drawImage(
    backgroundPlate,
    sourceX,
    sourceY,
    sourceWidth,
    sourceHeight,
    drawX,
    drawY,
    drawWidth,
    drawHeight,
  );
  context.filter = 'none';

  const gradient = context.createLinearGradient(0, 0, 0, visibleHeight);
  gradient.addColorStop(0, 'rgba(3, 5, 10, 0.28)');
  gradient.addColorStop(0.48, 'rgba(3, 5, 10, 0.1)');
  gradient.addColorStop(1, 'rgba(3, 5, 10, 0.72)');
  context.fillStyle = gradient;
  context.fillRect(0, 0, visibleWidth, visibleHeight);
  context.restore();
}

function drawCloud(x, y, width) {
  const gradient = context.createLinearGradient(x, y - 24, x, y + 32);
  gradient.addColorStop(0, 'rgba(89, 99, 112, 0.1)');
  gradient.addColorStop(0.5, 'rgba(122, 129, 135, 0.19)');
  gradient.addColorStop(1, 'rgba(12, 16, 22, 0)');
  context.fillStyle = gradient;
  context.beginPath();
  context.ellipse(x, y, width * 0.52, 24, 0, 0, Math.PI * 2);
  context.ellipse(x + width * 0.38, y + 8, width * 0.5, 20, 0, 0, Math.PI * 2);
  context.fill();
}

function drawGothicSkyline(cameraX, visibleWidth, worldHeight) {
  drawSkylineLayer(cameraX * 0.004, visibleWidth, worldHeight, palette.gothicFar, 332, 0.28);
  drawSkylineLayer(cameraX * 0.009, visibleWidth, worldHeight, palette.gothicMid, 386, 0.38);
  drawSkylineLayer(cameraX * 0.014, visibleWidth, worldHeight, palette.gothicNear, 448, 0.48);
}

function drawSkylineLayer(offset, visibleWidth, worldHeight, color, baseY, alpha) {
  context.save();
  context.globalAlpha = alpha;
  context.fillStyle = color;

  for (let x = -120 - (offset % 180); x < visibleWidth + 180; x += 120) {
    const towerWidth = 44 + (Math.abs(x) % 3) * 18;
    const towerHeight = 132 + (Math.abs(x) % 5) * 24;
    const towerX = x;
    const towerTop = baseY - towerHeight;

    drawSpire(towerX, towerTop - 66, towerWidth, 70, color);
    context.fillRect(towerX - towerWidth / 2, towerTop, towerWidth, worldHeight - towerTop);

    for (let wy = towerTop + 32; wy < baseY - 12; wy += 48) {
      drawArchedWindow(towerX, wy, towerWidth * 0.32, 24, alpha);
    }

    if (x % 240 === 0) {
      context.fillRect(towerX + towerWidth * 0.48, towerTop + 52, 88, worldHeight - towerTop);
      drawSpire(towerX + towerWidth * 0.48 + 44, towerTop - 36, 58, 56, color);
    }
  }

  context.restore();
}

function drawSpire(centerX, y, width, height, color) {
  context.fillStyle = color;
  context.beginPath();
  context.moveTo(centerX, y);
  context.lineTo(centerX - width / 2, y + height);
  context.lineTo(centerX + width / 2, y + height);
  context.closePath();
  context.fill();
  context.fillRect(centerX - 2, y - 18, 4, 22);
}

function drawArchedWindow(centerX, y, width, height, alpha = 1) {
  context.save();
  context.globalAlpha = 0.5 * alpha;
  context.fillStyle = palette.window;
  context.beginPath();
  context.moveTo(centerX - width / 2, y + height);
  context.lineTo(centerX - width / 2, y + width / 2);
  context.quadraticCurveTo(centerX, y - width / 2, centerX + width / 2, y + width / 2);
  context.lineTo(centerX + width / 2, y + height);
  context.closePath();
  context.fill();
  context.restore();
}

function drawFog(cameraX, visibleWidth, visibleHeight, opacity) {
  context.save();
  context.globalAlpha = opacity;
  for (let layer = 0; layer < 5; layer += 1) {
    const y = 286 + layer * 42;
    const drift = (state.time * (5 + layer * 2) + cameraX * (0.025 + layer * 0.008)) % 420;
    const gradient = context.createLinearGradient(0, y - 20, 0, y + 58);
    gradient.addColorStop(0, 'rgba(210, 210, 204, 0)');
    gradient.addColorStop(0.52, palette.fog);
    gradient.addColorStop(1, 'rgba(210, 210, 204, 0)');
    context.fillStyle = gradient;

    for (let x = -420 - drift; x < visibleWidth + 500; x += 420) {
      context.beginPath();
      context.ellipse(x, y, 190, 26, 0, 0, Math.PI * 2);
      context.ellipse(x + 145, y + 14, 150, 20, 0, 0, Math.PI * 2);
      context.fill();
    }
  }
  context.restore();
}

function drawCathedralStreet() {
  drawStreetSide(-40, 1);
  drawStreetSide(LEVEL.width + 40, -1);

  context.fillStyle = 'rgba(6, 7, 10, 0.48)';
  for (let x = 80; x < LEVEL.width; x += 190) {
    context.fillRect(x, 406, 84, 92);
    drawSpire(x + 42, 326, 70, 84, palette.gothicNear);
    drawArchedWindow(x + 42, 438, 22, 34, 1);
  }
}

function drawStreetSide(originX, direction) {
  for (let i = 0; i < 10; i += 1) {
    const x = originX + direction * i * 170;
    const y = 270 + (i % 2) * 22;
    const width = 130 + (i % 3) * 18;
    const height = 240;

    context.fillStyle = i % 2 === 0 ? 'rgba(5, 6, 9, 0.68)' : 'rgba(9, 12, 17, 0.62)';
    context.fillRect(x - direction * width, y, direction * width, height);
    drawSpire(x - direction * width * 0.52, y - 84, 64, 88, context.fillStyle);

    context.strokeStyle = 'rgba(95, 102, 116, 0.14)';
    context.lineWidth = 2;
    for (let floor = y + 42; floor < 492; floor += 56) {
      const windowX = x - direction * (width * 0.52);
      drawArchedWindow(windowX, floor, 20, 30, 0.55);
      context.beginPath();
      context.moveTo(x, floor + 33);
      context.lineTo(x - direction * width, floor + 33);
      context.stroke();
    }
  }
}

function drawLanterns() {
  for (let x = 170; x < LEVEL.width; x += 360) {
    context.strokeStyle = 'rgba(28, 27, 27, 0.82)';
    context.lineWidth = 4;
    context.beginPath();
    context.moveTo(x, 480);
    context.lineTo(x, 314);
    context.stroke();

    context.fillStyle = '#06070a';
    context.beginPath();
    context.moveTo(x - 18, 324);
    context.lineTo(x, 304);
    context.lineTo(x + 18, 324);
    context.lineTo(x + 14, 354);
    context.lineTo(x - 14, 354);
    context.closePath();
    context.fill();
    context.fillStyle = 'rgba(216, 168, 95, 0.48)';
    context.fillRect(x - 8, 326, 16, 20);
    context.fillStyle = 'rgba(216, 168, 95, 0.06)';
    context.beginPath();
    context.arc(x, 336, 52, 0, Math.PI * 2);
    context.fill();
  }
}

function drawPlatforms() {
  for (const platform of LEVEL.platforms) {
    if (platform.kind === 'branch') {
      drawIronWalkway(platform);
    } else {
      drawCobblePlatform(platform);
    }
  }
}

function drawCobblePlatform(platform) {
  context.fillStyle = platform.kind === 'moss' ? '#25272c' : '#2f3038';
  roundRect(platform.x, platform.y, platform.width, 12, 3);
  context.fill();

  const gradient = context.createLinearGradient(0, platform.y, 0, platform.y + platform.height);
  gradient.addColorStop(0, '#171820');
  gradient.addColorStop(0.62, '#0c0c11');
  gradient.addColorStop(1, '#050509');
  context.fillStyle = gradient;
  context.fillRect(platform.x, platform.y + 10, platform.width, platform.height - 10);

  context.strokeStyle = 'rgba(185, 183, 173, 0.09)';
  context.lineWidth = 1;
  for (let y = platform.y + 24; y < platform.y + platform.height; y += 22) {
    context.beginPath();
    context.moveTo(platform.x, y);
    context.lineTo(platform.x + platform.width, y + ((y / 22) % 2) * 3);
    context.stroke();
  }
  for (let x = platform.x + 18; x < platform.x + platform.width; x += 38) {
    context.beginPath();
    context.moveTo(x, platform.y + 14);
    context.lineTo(x + 8, platform.y + platform.height - 8);
    context.stroke();
  }

  context.fillStyle = 'rgba(216, 168, 95, 0.08)';
  for (let x = platform.x + 26; x < platform.x + platform.width; x += 96) {
    context.beginPath();
    context.ellipse(x, platform.y + 12, 26, 4, 0, 0, Math.PI * 2);
    context.fill();
  }

  context.fillStyle = 'rgba(140, 22, 36, 0.22)';
  for (let x = platform.x + 42; x < platform.x + platform.width; x += 146) {
    context.beginPath();
    context.ellipse(x, platform.y + 14, 18, 3, 0, 0, Math.PI * 2);
    context.fill();
  }
}

function drawIronWalkway(platform) {
  context.fillStyle = '#0d0f14';
  roundRect(platform.x, platform.y + 8, platform.width, 20, 4);
  context.fill();
  context.strokeStyle = 'rgba(185, 183, 173, 0.28)';
  context.lineWidth = 1.5;
  context.beginPath();
  context.moveTo(platform.x + 8, platform.y + 8);
  context.lineTo(platform.x + platform.width - 8, platform.y + 8);
  context.moveTo(platform.x + 8, platform.y + 27);
  context.lineTo(platform.x + platform.width - 8, platform.y + 27);
  context.stroke();
  for (let x = platform.x + 18; x < platform.x + platform.width; x += 28) {
    context.beginPath();
    context.moveTo(x, platform.y + 9);
    context.lineTo(x + 12, platform.y + 27);
    context.stroke();
  }
}

function drawBloodSigils() {
  for (const sigil of state.acorns) {
    if (sigil.collected) {
      continue;
    }

    const pulse = Math.sin(state.time * 5 + sigil.x);
    const y = sigil.y + pulse * 4;
    context.save();
    context.translate(sigil.x, y);
    context.shadowColor = palette.bloodLight;
    context.shadowBlur = 10 + pulse * 3;
    context.fillStyle = 'rgba(140, 22, 36, 0.9)';
    context.beginPath();
    context.moveTo(0, -14);
    context.bezierCurveTo(13, -5, 12, 13, 0, 18);
    context.bezierCurveTo(-12, 13, -13, -5, 0, -14);
    context.fill();

    context.shadowBlur = 0;
    context.strokeStyle = 'rgba(216, 207, 189, 0.64)';
    context.lineWidth = 1.4;
    context.beginPath();
    context.moveTo(0, -9);
    context.lineTo(0, 12);
    context.moveTo(-8, 2);
    context.lineTo(8, 2);
    context.stroke();
    context.restore();
  }
}

function drawGate() {
  const { x, y, width, height } = LEVEL.goal;
  const openGlow = state.gateOpen ? 26 : 0;

  context.save();
  context.shadowColor = state.gateOpen ? palette.bloodLight : 'transparent';
  context.shadowBlur = openGlow;
  context.fillStyle = state.gateOpen ? '#621827' : '#090b10';
  context.beginPath();
  context.moveTo(x - 22, y + height + 4);
  context.lineTo(x - 22, y + 36);
  context.quadraticCurveTo(x + width / 2, y - 48, x + width + 22, y + 36);
  context.lineTo(x + width + 22, y + height + 4);
  context.closePath();
  context.fill();
  context.shadowBlur = 0;

  context.strokeStyle = palette.iron;
  context.lineWidth = 4;
  for (let bar = 0; bar < 5; bar += 1) {
    const barX = x - 8 + bar * 15;
    context.beginPath();
    context.moveTo(barX, y + height);
    context.lineTo(barX, y + 22);
    context.stroke();
    context.fillStyle = palette.ironBright;
    context.beginPath();
    context.moveTo(barX - 5, y + 22);
    context.lineTo(barX, y + 6);
    context.lineTo(barX + 5, y + 22);
    context.closePath();
    context.fill();
  }

  context.fillStyle = state.gateOpen ? palette.bloodLight : '#171b22';
  context.fillRect(x - 18, y + 42, width + 36, 5);
  context.fillRect(x - 18, y + 70, width + 36, 5);
  context.restore();
}

function drawPlayer() {
  const player = state.player;

  if (playerSpriteReady || playerWalkSheetReady) {
    drawPlayerSprite(player);
    return;
  }

  const cx = player.x + player.width / 2;
  const footY = player.y + player.height;
  const lean = player.vx * 0.00022;
  const capeWave = Math.sin(state.time * 8) * 4;

  context.save();
  context.translate(cx, footY);
  context.scale(player.facing, 1);
  context.rotate(lean);

  drawTatteredVeil(capeWave);
  drawCrescentAxe();
  drawRedSkirtPanels(capeWave);

  context.fillStyle = palette.armor;
  context.beginPath();
  context.moveTo(-15, -50);
  context.lineTo(16, -51);
  context.lineTo(13, -18);
  context.lineTo(-12, -17);
  context.closePath();
  context.fill();

  context.strokeStyle = palette.armorLight;
  context.lineWidth = 1.6;
  for (let y = -45; y < -20; y += 6) {
    context.beginPath();
    context.moveTo(-12, y);
    context.lineTo(12, y + 1);
    context.stroke();
  }

  drawArmoredArms();
  drawArmoredLegs();

  context.fillStyle = palette.hair;
  context.beginPath();
  context.arc(0, -62, 11, 0, Math.PI * 2);
  context.fill();

  context.strokeStyle = 'rgba(216, 207, 189, 0.72)';
  context.lineWidth = 1.2;
  for (let lock = 0; lock < 7; lock += 1) {
    const x = -9 + lock * 3;
    context.beginPath();
    context.moveTo(x, -68);
    context.quadraticCurveTo(x - 3, -54, x - 7 + lock, -40 - (lock % 2) * 7);
    context.stroke();
  }

  context.fillStyle = '#090a0e';
  context.beginPath();
  context.moveTo(-17, -73);
  context.quadraticCurveTo(0, -90, 20, -72);
  context.lineTo(14, -63);
  context.quadraticCurveTo(0, -78, -16, -62);
  context.closePath();
  context.fill();

  context.fillStyle = palette.bone;
  roundRect(-9, -75, 18, 5, 2);
  context.fill();
  context.fillStyle = '#111217';
  context.fillRect(-1, -76, 2, 5);
  context.fillRect(-4, -73, 8, 1);

  context.fillStyle = '#050609';
  context.fillRect(4, -64, 4, 3);
  context.fillStyle = palette.bloodLight;
  context.fillRect(-7, -58, 2, 8);

  context.restore();
}

function drawPlayerSprite(player) {
  const moving = Math.abs(player.vx) > 1 && player.grounded && playerWalkSheetReady;
  const useWalkSheet = moving || !playerSpriteReady;
  const sourceImage = useWalkSheet ? playerWalkSheet : playerSprite;
  const frameWidth = useWalkSheet ? playerWalkSheet.width / WALK_FRAME_COUNT : playerSprite.width;
  const frameHeight = sourceImage.height;
  const walkFrameRate = clamp(Math.abs(player.vx) / 15, 12, 18);
  const frameIndex = moving ? Math.floor(state.time * walkFrameRate) % WALK_FRAME_COUNT : 0;
  const sourceX = useWalkSheet ? frameWidth * frameIndex : 0;
  const spriteHeight = useWalkSheet ? 142 : 138;
  const spriteWidth = spriteHeight * (frameWidth / frameHeight);
  const anchorX = useWalkSheet ? spriteWidth * 0.52 : spriteWidth * 0.72;
  const footY = player.y + player.height + 4;
  const bodyX = player.x + player.width / 2;

  context.save();
  context.fillStyle = 'rgba(0, 0, 0, 0.42)';
  context.beginPath();
  context.ellipse(bodyX - 5, footY + 2, moving ? 50 : 46, 9, 0, 0, Math.PI * 2);
  context.fill();
  context.restore();

  context.save();
  context.translate(bodyX, footY);
  context.scale(player.facing, 1);
  context.shadowColor = 'rgba(0, 0, 0, 0.64)';
  context.shadowBlur = 10;
  context.shadowOffsetY = 5;
  context.drawImage(
    sourceImage,
    sourceX,
    0,
    frameWidth,
    frameHeight,
    -anchorX,
    -spriteHeight,
    spriteWidth,
    spriteHeight,
  );
  if (SPRITE_GUIDES) {
    drawSpriteGuides(-anchorX, -spriteHeight, spriteWidth, spriteHeight, frameIndex, moving);
  }
  context.restore();
}

function drawSpriteGuides(x, y, width, height, frameIndex, moving) {
  context.save();
  context.shadowColor = 'transparent';
  context.shadowBlur = 0;
  context.shadowOffsetY = 0;
  context.lineWidth = 1;
  context.strokeStyle = moving ? 'rgba(255, 40, 78, 0.92)' : 'rgba(78, 190, 255, 0.88)';
  context.strokeRect(x, y, width, height);

  context.strokeStyle = 'rgba(255, 224, 80, 0.95)';
  context.beginPath();
  context.moveTo(x - 18, 0);
  context.lineTo(x + width + 18, 0);
  context.stroke();

  context.strokeStyle = 'rgba(78, 210, 255, 0.9)';
  context.beginPath();
  context.moveTo(0, -height - 10);
  context.lineTo(0, 14);
  context.stroke();

  context.fillStyle = 'rgba(3, 5, 10, 0.76)';
  context.fillRect(x, y - 20, 74, 18);
  context.fillStyle = '#ffe050';
  context.font = '10px ui-monospace, SFMono-Regular, Menlo, monospace';
  context.fillText(moving ? `walk ${frameIndex}` : 'idle', x + 5, y - 7);
  context.restore();
}

function drawTatteredVeil(capeWave) {
  context.fillStyle = 'rgba(3, 4, 7, 0.92)';
  for (let strip = 0; strip < 7; strip += 1) {
    const startY = -72 + strip * 8;
    const length = 84 + strip * 10;
    context.beginPath();
    context.moveTo(-6, startY);
    context.quadraticCurveTo(-36 - strip * 7, startY + 22 + capeWave, -70 - strip * 11, startY + length);
    context.quadraticCurveTo(-46 - strip * 7, startY + length - 18, -4, startY + 20);
    context.closePath();
    context.fill();
  }

  context.fillStyle = 'rgba(216, 207, 189, 0.42)';
  for (let fleck = 0; fleck < 18; fleck += 1) {
    context.fillRect(-62 - fleck * 3, -63 + (fleck * 17) % 92, 2, 2);
  }
}

function drawCrescentAxe() {
  context.strokeStyle = palette.ironBright;
  context.lineWidth = 3;
  context.beginPath();
  context.moveTo(15, -38);
  context.lineTo(42, -3);
  context.stroke();

  context.fillStyle = palette.iron;
  context.beginPath();
  context.arc(48, 2, 22, -1.25, 1.95);
  context.arc(60, 1, 22, 1.95, -1.25, true);
  context.closePath();
  context.fill();

  context.strokeStyle = palette.ironBright;
  context.lineWidth = 1;
  context.beginPath();
  context.arc(50, 2, 15, -1.1, 1.75);
  context.stroke();

  context.fillStyle = palette.blood;
  context.beginPath();
  context.ellipse(57, 17, 5, 13, -0.5, 0, Math.PI * 2);
  context.fill();
}

function drawRedSkirtPanels(capeWave) {
  context.fillStyle = 'rgba(140, 22, 36, 0.86)';
  context.beginPath();
  context.moveTo(-4, -20);
  context.quadraticCurveTo(-8, 4 + capeWave * 0.2, -16, 27);
  context.lineTo(-2, 22);
  context.lineTo(6, -19);
  context.closePath();
  context.fill();

  context.fillStyle = 'rgba(223, 76, 74, 0.32)';
  context.fillRect(-8, -17, 4, 34);
}

function drawArmoredArms() {
  context.strokeStyle = palette.armorLight;
  context.lineWidth = 7;
  context.lineCap = 'round';
  context.beginPath();
  context.moveTo(-13, -44);
  context.lineTo(-23, -24);
  context.stroke();
  context.beginPath();
  context.moveTo(13, -43);
  context.lineTo(20, -26);
  context.stroke();

  context.strokeStyle = '#0a0c12';
  context.lineWidth = 3;
  context.beginPath();
  context.moveTo(-19, -33);
  context.lineTo(-25, -20);
  context.moveTo(18, -34);
  context.lineTo(22, -22);
  context.stroke();
}

function drawArmoredLegs() {
  context.fillStyle = '#0b0d12';
  roundRect(-12, -18, 8, 38, 3);
  context.fill();
  roundRect(5, -18, 8, 38, 3);
  context.fill();

  context.strokeStyle = palette.armorLight;
  context.lineWidth = 1.4;
  for (let y = -12; y < 16; y += 8) {
    context.beginPath();
    context.moveTo(-12, y);
    context.lineTo(-4, y + 1);
    context.moveTo(5, y + 1);
    context.lineTo(13, y);
    context.stroke();
  }

  context.fillStyle = '#050609';
  context.fillRect(-16, 18, 15, 6);
  context.fillRect(2, 18, 15, 6);
}

function drawForeground(cameraX, visibleWidth) {
  drawWetCobblestones(cameraX, visibleWidth);

  context.fillStyle = 'rgba(5, 6, 8, 0.96)';
  for (let x = Math.floor(cameraX / 66) * 66; x < cameraX + visibleWidth + 80; x += 66) {
    context.beginPath();
    context.moveTo(x, LEVEL.height);
    context.lineTo(x + 12, LEVEL.height - 34 - (x % 5) * 5);
    context.lineTo(x + 24, LEVEL.height);
    context.fill();
  }
}

function drawWetCobblestones(cameraX, visibleWidth) {
  context.save();
  context.strokeStyle = 'rgba(185, 183, 173, 0.16)';
  context.lineWidth = 1;
  for (let y = 486; y < LEVEL.height; y += 18) {
    context.beginPath();
    context.moveTo(cameraX, y);
    context.lineTo(cameraX + visibleWidth, y + ((y / 18) % 2) * 3);
    context.stroke();
  }
  context.fillStyle = 'rgba(216, 168, 95, 0.12)';
  for (let x = Math.floor(cameraX / 120) * 120; x < cameraX + visibleWidth; x += 120) {
    context.beginPath();
    context.ellipse(x + 40, 508, 28, 4, 0, 0, Math.PI * 2);
    context.fill();
  }
  context.fillStyle = 'rgba(140, 22, 36, 0.28)';
  for (let x = Math.floor(cameraX / 280) * 280; x < cameraX + visibleWidth; x += 280) {
    context.beginPath();
    context.ellipse(x + 86, 514, 20, 5, 0, 0, Math.PI * 2);
    context.fill();
  }
  context.restore();
}

function drawVignette(width, height) {
  const gradient = context.createRadialGradient(
    width / 2,
    height * 0.48,
    width * 0.1,
    width / 2,
    height * 0.48,
    width * 0.76,
  );
  gradient.addColorStop(0, 'rgba(0, 0, 0, 0)');
  gradient.addColorStop(0.66, 'rgba(0, 0, 0, 0.2)');
  gradient.addColorStop(1, 'rgba(0, 0, 0, 0.8)');
  context.fillStyle = gradient;
  context.fillRect(0, 0, width, height);
}

function drawWinOverlay(width, height) {
  context.fillStyle = 'rgba(3, 5, 10, 0.72)';
  context.fillRect(0, 0, width, height);
  context.fillStyle = palette.bone;
  context.font = '700 46px Georgia, serif';
  context.textAlign = 'center';
  context.fillText('ECLIPTICA', width / 2, height / 2 - 24);
  context.fillStyle = palette.bloodLight;
  context.font = '700 18px system-ui, sans-serif';
  context.fillText('The cathedral gate opens', width / 2, height / 2 + 22);
}

function drawPauseOverlay(width, height) {
  context.fillStyle = 'rgba(3, 5, 10, 0.56)';
  context.fillRect(0, 0, width, height);
  context.fillStyle = palette.bone;
  context.font = '700 42px Georgia, serif';
  context.textAlign = 'center';
  context.fillText('PAUSED', width / 2, height / 2);
}

function syncHud() {
  hud.acorns.textContent = `${state.collected}/${state.acorns.length}`;
  hud.state.textContent = state.gateOpen ? 'OPEN' : 'SEALED';
  hud.pause.setAttribute('aria-pressed', String(paused));
  hud.pause.textContent = paused ? '▶' : 'II';
}

function togglePause() {
  paused = !paused;
  syncHud();
}

function roundRect(x, y, width, height, radius) {
  context.beginPath();
  context.roundRect(x, y, width, height, radius);
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}
