import { mkdir } from "node:fs/promises";
import path from "node:path";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { chromium } = require("playwright");

const baseURL = process.env.SHOTLENS_DESIGN_URL || "http://127.0.0.1:4311/xiaohongshu-product-page/index.html";
const outputDir = path.resolve("exports");

await mkdir(outputDir, { recursive: true });

const executablePath = process.env.PLAYWRIGHT_CHROME_PATH || "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const browser = await chromium.launch({ headless: true, executablePath });
const page = await browser.newPage({ viewport: { width: 1700, height: 1100 }, deviceScaleFactor: 2 });
await page.goto(baseURL, { waitUntil: "networkidle" });
await page.evaluate(() => document.fonts.ready);

const boards = page.locator("[data-export]");
for (let index = 0; index < await boards.count(); index += 1) {
  const board = boards.nth(index);
  const name = await board.getAttribute("data-export");
  await board.screenshot({ path: path.join(outputDir, `${name}.png`) });
}

await browser.close();
