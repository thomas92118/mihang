/** Build a fixed-camera QA Web export in an isolated source copy.
 * Example: node tools/build_art_web_probe.mjs --project . --output .tools/abzu-refinement/web-candidate
 * Uses the normal Web texture/compression pipeline; production project settings
 * and build/web are never changed by this command.
 */
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const options = new Map();
for (let i = 2; i < process.argv.length; i += 2) {
  if (!process.argv[i]?.startsWith("--") || process.argv[i + 1] == null) {
    throw new Error("Expected --project <source> --output <isolated-output> [--godot <binary>]");
  }
  options.set(process.argv[i], process.argv[i + 1]);
}
if (!options.has("--project") || !options.has("--output")) {
  throw new Error("Both --project and --output are required");
}
const source = path.resolve(options.get("--project"));
const output = path.resolve(options.get("--output"));
const toolsRoot = path.join(ROOT, ".tools");
// Validate the exact absolute deletion target before replacing any old QA build.
if (!output.startsWith(toolsRoot + path.sep) || source.startsWith(output + path.sep) || source === output) {
  throw new Error(`QA output must be an independent child of ${toolsRoot}: ${output}`);
}
for (const name of ["project.godot", "export_presets.cfg"]) {
  if (!fs.existsSync(path.join(source, name))) throw new Error(`Missing source file: ${source}/${name}`);
}
if (fs.existsSync(output)) fs.rmSync(output, { recursive: true, force: true });
const stage = path.join(output, "project");
fs.mkdirSync(stage, { recursive: true });
for (const name of ["project.godot", "export_presets.cfg", "icon.svg", "icon.svg.import"]) {
  const file = path.join(source, name);
  if (fs.existsSync(file)) fs.copyFileSync(file, path.join(stage, name));
}
for (const name of ["scripts", "scenes", "shaders", "assets/audio", "assets/collision", "assets/fonts", "assets/models", "assets/web"]) {
  const folder = path.join(source, name);
  if (!fs.existsSync(folder)) continue;
  const target = path.join(stage, name);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.cpSync(folder, target, { recursive: true });
}
const sourceImported = path.join(source, ".godot", "imported");
if (fs.existsSync(sourceImported)) {
  const stageImported = path.join(stage, ".godot", "imported");
  fs.mkdirSync(stageImported, { recursive: true });
  for (const entry of fs.readdirSync(sourceImported)) {
    if (!entry.endsWith(".fontdata")) continue;
    fs.copyFileSync(path.join(sourceImported, entry), path.join(stageImported, entry));
    const companionMd5 = `${entry.slice(0, -".fontdata".length)}.md5`;
    const srcMd5 = path.join(sourceImported, companionMd5);
    if (fs.existsSync(srcMd5)) {
      fs.copyFileSync(srcMd5, path.join(stageImported, companionMd5));
    }
  }
}

const hashes = {};
function recordSource(folder) {
  for (const entry of fs.readdirSync(folder, { withFileTypes: true })) {
    const file = path.join(folder, entry.name);
    if (entry.isDirectory()) recordSource(file);
    else if (/\.(gd|gdshader|tscn)$/.test(entry.name)) {
      hashes[path.relative(stage, file).replaceAll(path.sep, "/")] = crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
    }
  }
}
for (const name of ["scripts", "scenes", "shaders"]) recordSource(path.join(stage, name));
const probe = fs.readFileSync(path.join(ROOT, "tests", "art_web_probe.gd"), "utf8");
fs.writeFileSync(path.join(stage, "scripts", "art_web_probe.gd"), probe, "utf8");
fs.writeFileSync(path.join(stage, "scenes", "art_web_probe.tscn"), `[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/art_web_probe.gd" id="1_probe"]

[node name="ArtWebProbe" type="Node"]
script = ExtResource("1_probe")
`, "utf8");
const settingsFile = path.join(stage, "project.godot");
const settings = fs.readFileSync(settingsFile, "utf8");
if (!/^run\/main_scene=.*$/m.test(settings)) throw new Error("Project has no main_scene setting");
fs.writeFileSync(settingsFile, settings.replace(/^run\/main_scene=.*$/m, 'run/main_scene="res://scenes/art_web_probe.tscn"'), "utf8");
fs.mkdirSync(path.join(stage, "tools"), { recursive: true });
fs.copyFileSync(path.join(ROOT, "tools", "build_web.mjs"), path.join(stage, "tools", "build_web.mjs"));
const metadata = {
  source_project: source, isolated_project: stage, created_at: new Date().toISOString(),
  probe_sha256: crypto.createHash("sha256").update(probe).digest("hex"),
  pipeline: "tools/build_web.mjs (normal 256/512px lossy Web textures and chunked gzip delivery)",
  source_hashes: hashes,
};
fs.writeFileSync(path.join(output, "build-metadata.json"), JSON.stringify(metadata, null, 2) + "\n", "utf8");
const env = { ...process.env };
if (options.has("--godot")) env.GODOT_BIN = path.resolve(options.get("--godot"));
console.log(`[art_web_probe] Isolated ${source} -> ${stage}`);
const result = spawnSync(process.execPath, [path.join(stage, "tools", "build_web.mjs")], {
  cwd: stage, env, stdio: "inherit",
});
if (result.error) throw result.error;
if (result.status !== 0) throw new Error(`QA Web build failed with code ${result.status}`);
console.log(`[art_web_probe] READY ${path.join(stage, "build", "web")}`);
