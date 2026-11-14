import { mkdir, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import StyleDictionary from "style-dictionary";
import config, { colors } from "./config";
import { assetInfo, colorSet } from "./color-assets";
import "./formats";

const args = process.argv.slice(2);
if (args.length > 0 && (args.length !== 1 || args[0] !== "--check")) {
  throw new Error("使い方: bun generate.ts [--check]");
}
const check = args[0] === "--check";
const outputs = new Map<string, string>();
const dimensions = new StyleDictionary(config);
const light = new StyleDictionary(colors("light"));
const dark = new StyleDictionary(colors("dark"));
for (const dictionary of [dimensions, light, dark]) {
  for (const platform of Object.keys(dictionary.platforms).filter(name => name !== "assets")) {
    for (const { destination, output } of await dictionary.formatPlatform(platform)) {
      outputs.set(destination!, output as string);
    }
  }
}

// Style DictionaryにColor Assetの標準出力がないため、DTCGのsRGB値をAny/Darkへ配置する。
const assetRoot = "../iOS/RegzaKit/Sources/Design/Generated/DesignColors.xcassets";
const lightTokens = (await light.getPlatformTokens("assets")).allTokens;
const darkTokens = (await dark.getPlatformTokens("assets")).allTokens;
const darkByName = new Map(darkTokens.map(token => [token.name, token]));
if (lightTokens.length !== darkTokens.length || lightTokens.some(token => !darkByName.has(token.name))) {
  throw new Error("ライトとダークのカラートークン名をそろえてください。");
}
const json = (value: unknown) => JSON.stringify(value, null, 2) + "\n";
outputs.set(join(assetRoot, "Contents.json"), json({ info: assetInfo }));
for (const token of lightTokens) {
  outputs.set(join(assetRoot, `${token.name}.colorset/Contents.json`), json(colorSet(token.$value, darkByName.get(token.name)!.$value)));
}

// 削除・改名したトークンのColor Assetも残さない。専用の生成フォルダだけを対象にする。
const existing = await readdir(assetRoot, { recursive: true }).catch((error) => {
  if (error.code !== "ENOENT") throw error;
  return [] as string[];
});
for (const file of existing.filter(path => path.endsWith("Contents.json"))) {
  const path = join(assetRoot, file);
  if (!outputs.has(path)) {
    if (check) throw new Error(`${path}: 不要な生成物があります。mise run generate-design-tokens を実行してください。`);
    await rm(dirname(path), { recursive: true });
  }
}
for (const [path, contents] of outputs) {
  if (check) {
    if (await readFile(path, "utf8").catch(() => null) !== contents) {
      throw new Error(`${path}: mise run generate-design-tokens を実行してください。`);
    }
  } else {
    await mkdir(dirname(path), { recursive: true });
    await writeFile(path, contents);
  }
}
