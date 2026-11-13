import { readFile } from "node:fs/promises";
import StyleDictionary from "style-dictionary";
import config from "./config";

const args = process.argv.slice(2);
if (args.length > 0 && (args.length !== 1 || args[0] !== "--check")) {
  throw new Error("使い方: bun generate.ts [--check]");
}

const dictionary = new StyleDictionary(config);
if (args[0] === "--check") {
  // 書き出さずに比較する。未追跡の生成ファイルも含めて更新漏れを検出する。
  for (const platform of Object.keys(config.platforms)) {
    for (const { destination, output } of await dictionary.formatPlatform(platform)) {
      const current = await readFile(destination!, "utf8").catch(() => null);
      if (current !== output) {
        throw new Error(`${destination}: mise run generate-design-tokens を実行してください。`);
      }
    }
  }
} else {
  await dictionary.buildAllPlatforms();
}
