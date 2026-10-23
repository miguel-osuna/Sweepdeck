import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { runSelfTest } from "./verify-sparkle-key.mjs";

runSelfTest();

const release = JSON.parse(await readFile(".releaserc.json", "utf8"));
const manifest = JSON.parse(await readFile("package.json", "utf8"));
const lock = JSON.parse(await readFile("package-lock.json", "utf8"));
const releaseWorkflow = await readFile(".github/workflows/release.yml", "utf8");
const updateHarness = await readFile("scripts/test-local-updates.sh", "utf8");

assert.equal(release.repositoryUrl, "https://github.com/miguel-osuna/Sweepdeck.git");
assert.deepEqual(release.branches, ["main"]);
assert.equal(release.tagFormat, "v${version}");

const plugins = release.plugins.map((plugin) => Array.isArray(plugin) ? plugin[0] : plugin);
assert.deepEqual(plugins, [
  "@semantic-release/commit-analyzer",
  "@semantic-release/release-notes-generator",
  "@semantic-release/exec",
  "@semantic-release/github"
]);
assert(!plugins.includes("@semantic-release/npm"), "This macOS project must not publish an npm package.");

const execPlugin = release.plugins.find((plugin) => Array.isArray(plugin) && plugin[0] === "@semantic-release/exec");
assert.match(execPlugin[1].verifyReleaseCmd, /validate-release-version\.sh/);

const githubPlugin = release.plugins.find((plugin) => Array.isArray(plugin) && plugin[0] === "@semantic-release/github");
assert.equal(githubPlugin[1].successComment, false);
assert.equal(githubPlugin[1].failComment, false);

assert.equal(manifest.devDependencies["semantic-release"], "25.0.9");
assert.equal(manifest.devDependencies["@semantic-release/exec"], "7.1.0");
assert.equal(manifest.devDependencies["@semantic-release/github"], "12.0.10");
assert.deepEqual(lock.packages[""].devDependencies, manifest.devDependencies);
assert.match(manifest.scripts["test:release-tools"], /test-release-baseline\.sh/);
assert.match(releaseWorkflow, /actions:\s*read/);
assert.match(releaseWorkflow, /bash scripts\/check-release-environment\.sh/);
assert.match(releaseWorkflow, /environment: release/);
assert.match(releaseWorkflow, /node scripts\/verify-sparkle-key\.mjs/);
assert.match(releaseWorkflow, /--full-release-notes-url/);
assert.match(releaseWorkflow, /fullReleaseNotesLink/);
assert.match(releaseWorkflow, /sparkle_candidate:[\s\S]*?bash scripts\/test-local-updates\.sh automatic/);
assert.match(releaseWorkflow, /published_sparkle_smoke:[\s\S]*?needs: \[candidate, deploy_appcast\][\s\S]*?SWEEPDECK_TEST_FEED_URL: https:\/\/miguel-osuna\.github\.io\/Sweepdeck\/appcast\.xml[\s\S]*?bash scripts\/test-local-updates\.sh published/);
assert.match(updateHarness, /GITHUB_ACTIONS.*SWEEPDECK_DISPOSABLE_RUNNER/);
assert.match(updateHarness, /RUNNER_TEMP/);
assert.match(updateHarness, /Refusing the published-feed test because \/Applications\/Sweepdeck\.app exists/);
assert.match(updateHarness, /Application Support directory already exists/);
assert.match(updateHarness, /unexpected \/Applications\/Sweepdeck\.app copy/);
assert.match(updateHarness, /localhost update feed remains available/);
assert.match(updateHarness, /Quit the isolated test app when you are done[\s\S]*while \[\[ -n "\$\(test_app_pids\)" \]\]; do sleep 1; done/);
assert.match(releaseWorkflow, /publish:\n\s+needs: \[candidate, homebrew_candidate, sparkle_candidate\]/);
assert.match(releaseWorkflow, /openssl rand -base64 32/);

await import("semantic-release");
await import("@semantic-release/exec");
await import("@semantic-release/github");

console.log("Release configuration and pinned plugin tests passed.");
