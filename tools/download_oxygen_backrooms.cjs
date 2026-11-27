#!/usr/bin/env node
/* Fetch exact CC0 Oxygen source packages; refuse unpinned upstream versions. */
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const crypto = require("node:crypto");
const { downloadGame } = require(process.env.ITCH_DOWNLOADER_PATH || "itchio-downloader");

const sources = [
  {
    tag: "vol1",
    url: "https://oxygen3d.itch.io/game-ready-backrooms-asset-pack-vol-1",
    fileName: "backrooms.zip",
    sha: "b18663967868271c80bc1cea5d3c36351e19641a0bed5739dd69bf62c7c80a84"
  },
  {
    tag: "vol2",
    url: "https://oxygen3d.itch.io/game-ready-backrooms-asset-pack-vol-2",
    fileName: "Backrooms_Vol2_1k.zip",
    sha: "30ac9b69152feb9db7befd2fbdd61de9fcd9b94726f56794496878fb5635a1aa"
  }
];
const dest = process.argv[2] || path.join(process.cwd(), "oxygen_downloads");
fs.mkdirSync(dest, { recursive: true });

function sha(file) {
  return crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}

async function main() {
  for (const src of sources) {
    const temp = fs.mkdtempSync(path.join(os.tmpdir(), "oxygen-" + src.tag + "-"));
    console.log("Downloading " + src.url);
    const result = await downloadGame({
      itchGameUrl: src.url,
      downloadDirectory: temp,
      writeMetaData: false,
      noCookieCache: true,
      retries: 2,
      retryDelayMs: 1000
    });
    console.log("Downloader result: " + JSON.stringify({
      success: result?.success,
      filePath: result?.filePath,
      error: result?.error
    }));
    const candidates = fs.readdirSync(temp)
      .filter(name => name.toLowerCase().endsWith(".zip"))
      .map(name => path.join(temp, name));
    const match = candidates.find(file => sha(file) === src.sha);
    if (!match) {
      const found = candidates.map(file => path.basename(file) + " " + sha(file)).join(", ");
      throw new Error(src.tag + " checksum-pinned package missing. Found " + (found || "no ZIP"));
    }
    fs.copyFileSync(match, path.join(dest, src.fileName));
    console.log("Verified and saved " + src.fileName);
  }
}

main().catch(error => { console.error(error); process.exitCode = 1; });
