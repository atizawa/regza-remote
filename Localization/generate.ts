import { mkdir, readFile, readdir, unlink, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { androidXML, messages, type Argument, type Catalog } from "./catalog";

const args = process.argv.slice(2);
if (args.length && (args.length !== 1 || args[0] !== "--check")) throw new Error("使い方: bun generate.ts [--check]");
const check = args[0] === "--check";
const source = "../iOS/RegzaKit/Sources/Localization/Resources/Localizable.xcstrings";
const catalog: Catalog = JSON.parse(await readFile(source, "utf8"));
const entries = messages(catalog);
const header = "// Localizable.xcstringsから生成。直接編集せずmise run generate-localizationsを実行してください。";
const swiftType = (type: Argument) => type === "string" ? "String" : type === "float" ? "Double" : "Int";
const kotlinType = (type: Argument) => type === "string" ? "String" : type === "float" ? "Double" : "Int";
const swift = `${header}
import Foundation

public enum AppStrings {
${entries.map(entry => {
  if (!entry.args.length) return `    public static var ${entry.symbol}: String { String(localized: "${entry.key}", bundle: .module) }`;
  const params = entry.args.map((type, i) => `_ value${i + 1}: ${swiftType(type)}`).join(", ");
  const values = entry.args.map((type, i) => type === "int64" ? `Int64(value${i + 1})` : type === "int32" ? `Int32(value${i + 1})` : `value${i + 1}`).join(", ");
  return `    public static func ${entry.symbol}(${params}) -> String {
        String.localizedStringWithFormat(NSLocalizedString("${entry.key}", bundle: .module, comment: ""), ${values})
    }`;
}).join("\n\n")}
}
`;
const kotlin = `${header}
package com.example.regzaremote.localization

import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.res.pluralStringResource
import com.example.regzaremote.R

object AppStrings {
${entries.map(entry => {
  if (!entry.args.length) return `    val ${entry.symbol}: String\n        @Composable get() = stringResource(R.string.${entry.key})`;
  const params = entry.args.map((type, i) => `value${i + 1}: ${kotlinType(type)}`).join(", ");
  const values = entry.args.map((_, i) => `value${i + 1}`).join(", ");
  return `    @Composable\n    fun ${entry.symbol}(${params}): String = ${entry.plural ? `pluralStringResource(R.plurals.${entry.key}, value1, ${values})` : `stringResource(R.string.${entry.key}, ${values})`}`;
}).join("\n\n")}
}
`;
const outputs = new Map([
  ["../iOS/RegzaKit/Sources/Localization/Generated/AppStrings.swift", swift],
  ["../Android/app/src/main/java/com/example/regzaremote/localization/Generated/AppStrings.kt", kotlin],
]);
for (const locale of new Set(entries.flatMap(entry => [...entry.translations.keys()]))) {
  const canonical = Intl.getCanonicalLocales(locale.replaceAll("_", "-"))[0];
  const directory = locale === catalog.sourceLanguage ? "values" : `values-b+${canonical.replaceAll("-", "+")}`;
  const path = `../Android/app/src/main/res/${directory}/app_strings.xml`;
  if (outputs.has(path)) throw new Error(`言語の出力先が重複しています: ${locale}`);
  outputs.set(path, androidXML(entries, locale));
}
// 言語を削除した場合も、今回の専用生成ファイルだけを除去する。
const res = "../Android/app/src/main/res";
for (const directory of await readdir(res)) {
  const path = join(res, directory, "app_strings.xml");
  if (directory.startsWith("values") && !outputs.has(path) && await readFile(path).then(() => true, () => false)) {
    if (check) throw new Error(`${path}: 古い生成物があります。mise run generate-localizationsを実行してください。`);
    await unlink(path);
  }
}
for (const [path, contents] of outputs) {
  if (check) {
    if (await readFile(path, "utf8").catch(() => null) !== contents) throw new Error(`${path}: mise run generate-localizationsを実行してください。`);
  } else {
    await mkdir(dirname(path), { recursive: true });
    await writeFile(path, contents);
  }
}
