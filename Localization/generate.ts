import { mkdir, readFile, readdir, unlink, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { androidXML, messages, splitCore, type Argument, type Catalog } from "./catalog";

const args = process.argv.slice(2);
if (args.length && (args.length !== 1 || args[0] !== "--check")) throw new Error("使い方: bun generate.ts [--check]");
const check = args[0] === "--check";
const source = "../iOS/RegzaKit/Sources/Core/Localization/Resources/Localizable.xcstrings";
const catalog: Catalog = JSON.parse(await readFile(source, "utf8"));
const all = messages(catalog);
// core_ で始まるキーは、共有の Swift (RegzaCore) が引く文言。OS の画面の AppStrings には出さず、CoreStrings に出す
const { core, app: entries } = splitCore(all);
const catalogSource = (key: string) => catalog.strings[key].localizations[catalog.sourceLanguage].stringUnit!.value;
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

object AppStrings {
${entries.map(entry => {
  if (!entry.args.length) return `    val ${entry.symbol}: String\n        @Composable get() = stringResource(R.string.${entry.key})`;
  const params = entry.args.map((type, i) => `value${i + 1}: ${kotlinType(type)}`).join(", ");
  const values = entry.args.map((_, i) => `value${i + 1}`).join(", ");
  return `    @Composable\n    fun ${entry.symbol}(${params}): String = ${entry.plural ? `pluralStringResource(R.plurals.${entry.key}, value1, ${values})` : `stringResource(R.string.${entry.key}, ${values})`}`;
}).join("\n\n")}
}
`;
const coreSymbol = (entry: { symbol: string }) => entry.symbol.replace(/^core([A-Z])/, (_, c) => c.toLowerCase());
const coreArgument = (type: Argument, i: number) => type === "string" ? `.string(value${i + 1})` : type === "float" ? `.double(value${i + 1})` : `.int(value${i + 1})`;
const swiftLiteral = (text: string) => {
  if (text.includes("\\")) throw new Error(`共有の Swift の文言にバックスラッシュは使えません: ${text}`);
  return JSON.stringify(text);
};
const coreSwift = `${header}
// 共有の Swift (RegzaCore) が画面に出す文言。CoreStringTable が、OS が入れた文言か元言語の文言を引く。

public enum CoreStrings {
    /// 元言語の文言 (OS が文言を入れていないときと、入れた中にないキーに使う)
    static let sourceTemplates: [String: String] = [
${core.map(entry => `        "${entry.key}": ${swiftLiteral(catalogSource(entry.key))},`).join("\n")}
    ]

${core.map(entry => {
  if (!entry.args.length) return `    public static var ${coreSymbol(entry)}: String { CoreStringTable.text("${entry.key}") }`;
  const params = entry.args.map((type, i) => `_ value${i + 1}: ${swiftType(type)}`).join(", ");
  return `    public static func ${coreSymbol(entry)}(${params}) -> String {
        CoreStringTable.text("${entry.key}", [${entry.args.map(coreArgument).join(", ")}])
    }`;
}).join("\n\n")}
}
`;
const coreKotlin = `${header}
package com.example.regzaremote.localization


/** 共有の Swift (RegzaCore) が画面に出す文言のキーと、その Android の文字列リソース。起動時に Swift へまとめて渡す */
object CoreStringResources {
    val ids: Map<String, Int> = mapOf(
${core.map(entry => `        "${entry.key}" to R.string.${entry.key},`).join("\n")}
    )
}
`;
const outputs = new Map([
  ["../Packages/RegzaCore/Sources/RegzaStrings/Generated/CoreStrings.swift", coreSwift],
  ["../Android/core/localization/src/main/java/com/example/regzaremote/localization/Generated/CoreStringResources.kt", coreKotlin],
  ["../iOS/RegzaKit/Sources/Core/Localization/Generated/AppStrings.swift", swift],
  ["../Android/core/localization/src/main/java/com/example/regzaremote/localization/Generated/AppStrings.kt", kotlin],
]);
for (const locale of new Set(all.flatMap(entry => [...entry.translations.keys()]))) {
  const canonical = Intl.getCanonicalLocales(locale.replaceAll("_", "-"))[0];
  const directory = locale === catalog.sourceLanguage ? "values" : `values-b+${canonical.replaceAll("-", "+")}`;
  const path = `../Android/core/localization/src/main/res/${directory}/app_strings.xml`;
  if (outputs.has(path)) throw new Error(`言語の出力先が重複しています: ${locale}`);
  outputs.set(path, androidXML(all, locale));
}
// 言語を削除した場合も、今回の専用生成ファイルだけを除去する。
const res = "../Android/core/localization/src/main/res";
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
