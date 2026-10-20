import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const release = JSON.parse(await readFile(".releaserc.json", "utf8"));
const manifest = JSON.parse(await readFile("package.json", "utf8"));
const lock = JSON.parse(await readFile("package-lock.json", "utf8"));

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

assert.equal(manifest.devDependencies.semantic-release, "25.0.9");
assert.equal(manifest.devDependencies["@semantic-release/exec"], "7.1.0");
assert.equal(manifest.devDependencies["@semantic-release/github"], "12.0.9");
assert.deepEqual(lock.packages[""].devDependencies, manifest.devDependencies);

await import("semantic-release");
await import("@semantic-release/exec");
await import("@semantic-release/github");

console.log("Release configuration and pinned plugin tests passed.");
