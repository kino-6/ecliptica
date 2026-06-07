import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { availableParallelism, freemem, totalmem } from 'node:os';
import { performance } from 'node:perf_hooks';

const profiles = ['novice', 'casual', 'adept', 'expert', 'master'];
const godotCandidates = [
  process.env.GODOT_BIN,
  'godot',
  'godot4',
  '/Applications/Godot.app/Contents/MacOS/Godot',
].filter(Boolean);

const godot = godotCandidates.find((candidate) => existsSync(candidate) || !candidate.includes('/'));

if (!godot) {
  console.error('Godot executable should be available. Set GODOT_BIN if needed.');
  process.exit(1);
}

const allocation = chooseAllocation(profiles.length);
const startedAt = performance.now();
const { results, failures } = await runProfileQueue(profiles, allocation.selected_workers);
const totalElapsedMs = Math.round(performance.now() - startedAt);
const orderedProfiles = results
  .sort((a, b) => profiles.indexOf(a.name) - profiles.indexOf(b.name))
  .map((profile) => ({
    ...profile,
    elapsed_ms: Math.round(profile.elapsed_ms),
  }));
const stage = orderedProfiles[0]?.stage ?? {};
const recommendation = recommend(orderedProfiles);
const summary = {
  mode: 'ai_headless_playtest',
  status: failures.length === 0 ? 'pass' : 'fail',
  stage,
  parallel: {
    strategy: 'auto_machine_fit',
    enabled: allocation.selected_workers > 1,
    available_parallelism: allocation.available_parallelism,
    total_memory_gb: allocation.total_memory_gb,
    free_memory_gb: allocation.free_memory_gb,
    reserved_cores: allocation.reserved_cores,
    memory_per_worker_gb: allocation.memory_per_worker_gb,
    selected_workers: allocation.selected_workers,
    profile_count: profiles.length,
    total_elapsed_ms: totalElapsedMs,
    profile_elapsed_ms: orderedProfiles.map((profile) => ({
      name: profile.name,
      elapsed_ms: profile.elapsed_ms,
      worker_index: profile.worker_index,
    })),
  },
  profiles: orderedProfiles,
  recommendation,
  failures,
};

console.log(`AI_PLAYTEST_JSON ${JSON.stringify(summary)}`);
process.exit(summary.status === 'pass' ? 0 : 1);

function chooseAllocation(profileCount) {
  const available = Math.max(1, Number(availableParallelism?.() ?? 1));
  const totalMemoryGb = totalmem() / 1024 ** 3;
  const freeMemoryGb = freemem() / 1024 ** 3;
  const reservedCores = available >= 8 ? 2 : 1;
  const memoryPerWorkerGb = 1.2;
  const cpuLimit = Math.max(1, available - reservedCores);
  const memoryLimit = Math.max(1, Math.floor(Math.max(freeMemoryGb - 1.0, totalMemoryGb * 0.25) / memoryPerWorkerGb));
  const autoWorkers = clamp(Math.min(profileCount, cpuLimit, memoryLimit), 1, profileCount);
  const requested = process.env.AI_PLAYTEST_WORKERS;
  const selectedWorkers = requested && requested !== 'auto'
    ? clamp(Number.parseInt(requested, 10) || autoWorkers, 1, profileCount)
    : autoWorkers;

  return {
    available_parallelism: available,
    total_memory_gb: round(totalMemoryGb, 2),
    free_memory_gb: round(freeMemoryGb, 2),
    reserved_cores: reservedCores,
    memory_per_worker_gb: memoryPerWorkerGb,
    selected_workers: selectedWorkers,
  };
}

async function runProfileQueue(profileNames, workerCount) {
  const queue = profileNames.map((name, index) => ({ name, index }));
  const results = [];
  const failures = [];
  let next = 0;

  async function worker(workerIndex) {
    while (next < queue.length) {
      const item = queue[next];
      next += 1;
      try {
        const result = await runProfile(item.name, workerIndex);
        result.worker_index = workerIndex;
        result.profile_index = item.index;
        results.push(result);
      } catch (error) {
        failures.push(`${item.name}: ${error.message}`);
      }
    }
  }

  await Promise.all(Array.from({ length: workerCount }, (_, workerIndex) => worker(workerIndex)));
  for (const result of results) {
    if (Array.isArray(result.failures)) {
      failures.push(...result.failures.map((failure) => `${result.name}: ${failure}`));
    }
  }
  return { results, failures };
}

function runProfile(profileName, workerIndex) {
  const startedAt = performance.now();
  const child = spawn(godot, [
    '--headless',
    '--path',
    '.',
    '--log-file',
    `/private/tmp/ecliptica-ai-playtest-${profileName}.log`,
    '--script',
    'scripts/ai_playtest.gd',
  ], {
    cwd: process.cwd(),
    env: {
      ...process.env,
      AI_PLAYTEST_PROFILE: profileName,
      AI_PLAYTEST_WORKER_INDEX: String(workerIndex),
    },
  });

  let stdout = '';
  let stderr = '';

  child.stdout.on('data', (chunk) => {
    stdout += chunk;
  });
  child.stderr.on('data', (chunk) => {
    stderr += chunk;
  });

  return new Promise((resolve, reject) => {
    child.on('error', (error) => {
      reject(error);
    });
    child.on('close', (code) => {
      const filteredStderr = filterGodotNoise(stderr);
      const summary = parseProfileSummary(stdout);
      if (!summary) {
        reject(new Error(`missing AI_PROFILE_JSON; stderr=${filteredStderr.trim()} stdout=${stdout.trim()}`));
        return;
      }
      const profile = summary.profile;
      profile.elapsed_ms = performance.now() - startedAt;
      profile.failures = summary.failures ?? [];
      if (code !== 0 || summary.status !== 'pass') {
        profile.failures.push(filteredStderr.trim() || `profile exited with code ${code}`);
      }
      resolve(profile);
    });
  });
}

function parseProfileSummary(stdout) {
  const line = stdout.split('\n').find((entry) => entry.startsWith('AI_PROFILE_JSON '));
  if (!line) return null;
  return JSON.parse(line.slice('AI_PROFILE_JSON '.length));
}

function recommend(profileResults) {
  const novice = profileResults.find((profile) => profile.name === 'novice');
  const adept = profileResults.find((profile) => profile.name === 'adept');
  const expert = profileResults.find((profile) => profile.name === 'expert');
  if (novice && adept && expert && !novice.cleared && adept.cleared && adept.predicted_attempts_to_clear === 2 && expert.cleared) {
    return 'stage matches the two-try target for an adept action player';
  }
  return 'stage balance needs another pass';
}

function filterGodotNoise(stderr) {
  return stderr.replace(
    /ERROR: Condition "ret != noErr" is true\. Returning: ""\n\s+at: get_system_ca_certificates \(platform\/macos\/os_macos\.mm:\d+\)\n?/g,
    '',
  );
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

function round(value, digits) {
  const scale = 10 ** digits;
  return Math.round(value * scale) / scale;
}
