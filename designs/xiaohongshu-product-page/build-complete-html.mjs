import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const designRoot = path.dirname(fileURLToPath(import.meta.url));
const manifest = JSON.parse(await readFile(path.join(designRoot, "versions.json"), "utf8"));
const version = process.argv[2] || manifest.currentVersion;

if (!manifest.versions.some((item) => item.id === version)) {
  throw new Error(`未知版本 ${version}。可用版本：${manifest.versions.map((item) => item.id).join(", ")}`);
}

const versionDir = path.join(designRoot, "versions", version);
const [html, css, icon] = await Promise.all([
  readFile(path.join(versionDir, "index.html"), "utf8"),
  readFile(path.join(versionDir, "styles.css"), "utf8"),
  readFile(path.join(designRoot, "assets", "shotlens-icon.png")),
]);

const iconDataURL = `data:image/png;base64,${icon.toString("base64")}`;
const completeHTML = html
  .replace('<link rel="stylesheet" href="styles.css">', `<style>\n${css}\n</style>`)
  .replaceAll("../../assets/shotlens-icon.png", iconDataURL);

const unresolvedLocalAsset = completeHTML.match(/(?:src|href)="(?!data:|https?:|#)([^"]+)"/);
if (unresolvedLocalAsset) {
  throw new Error(`完整 HTML 仍引用本地文件：${unresolvedLocalAsset[1]}`);
}

const outputPath = path.join(versionDir, `shotlens-xhs-${version}-complete.html`);
await writeFile(outputPath, completeHTML);
console.log(outputPath);
