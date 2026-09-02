#!/usr/bin/env node
import { cpSync, existsSync, mkdirSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { homedir, platform } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, "..");
const extensionZip = join(root, "dist", "svg-importer.aseprite-extension");
const extractedDir = join(root, "extracted");

function extensionsDir() {
  const home = homedir();
  if (platform() === "darwin") {
    return join(home, "Library", "Application Support", "Aseprite", "extensions");
  }
  if (platform() === "win32") {
    const appData = process.env.APPDATA || join(home, "AppData", "Roaming");
    return join(appData, "Aseprite", "extensions");
  }
  return join(home, ".config", "aseprite", "extensions");
}

function installFromExtracted(targetDir) {
  const files = [
    "package.json",
    "svg-importer.lua",
    "svg-animation.lua",
    "svg-parser.lua",
    "svg-renderer-professional.lua",
  ];
  mkdirSync(targetDir, { recursive: true });
  for (const file of files) {
    cpSync(join(extractedDir, file), join(targetDir, file));
  }
  writeFileSync(
    join(targetDir, "__info.json"),
    JSON.stringify({ installedFiles: files }),
  );
}

function usage() {
  console.log(`SVG Importer for Aseprite

Usage:
  npx @userdefault/svg-importer install     Install extension into Aseprite
  npx @userdefault/svg-importer path        Print Aseprite extensions directory
  npx @userdefault/svg-importer artifact    Print path to .aseprite-extension zip

After install, restart Aseprite and use File → Import SVG.
`);
}

const command = process.argv[2] || "install";

if (command === "help" || command === "--help" || command === "-h") {
  usage();
  process.exit(0);
}

if (command === "path") {
  console.log(extensionsDir());
  process.exit(0);
}

if (command === "artifact") {
  if (!existsSync(extensionZip)) {
    console.error("Extension artifact not found. Run: npm run build");
    process.exit(1);
  }
  console.log(extensionZip);
  process.exit(0);
}

if (command !== "install") {
  usage();
  process.exit(1);
}

if (!existsSync(join(extractedDir, "svg-importer.lua"))) {
  console.error("Extension source files missing in package.");
  process.exit(1);
}

const target = join(extensionsDir(), "svg-importer");
if (existsSync(target)) {
  rmSync(target, { recursive: true, force: true });
}
installFromExtracted(target);

console.log("Installed SVG Importer extension to:");
console.log(`  ${target}`);
console.log("");
console.log("Restart Aseprite, then use File → Import SVG.");
if (existsSync(extensionZip)) {
  console.log("");
  console.log("Manual install artifact:");
  console.log(`  ${extensionZip}`);
}
