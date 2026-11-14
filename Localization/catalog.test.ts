import { expect, test } from "bun:test";
import { androidXML, format, messages, xmlText, type Catalog } from "./catalog";

const unit = (value: string) => ({ stringUnit: { state: "translated", value } });
function catalog(value: object): Catalog {
  return { sourceLanguage: "ja", version: "1.0", strings: { sample_message: { localizations: { ja: value as never } } } };
}

test("Appleの引数をAndroidの番号付き書式へ変換する", () => {
  expect(format("%2$@ / %1$lld / %3$.2f %%")).toEqual({ args: ["int64", "string", "float"], android: "%2$s / %1$d / %3$.2f %%" });
  expect(format("%@ %d").android).toBe("%1$s %2$d");
});

test.each(["%q", "%2$@", "%1$@ %1$d", "%@ %2$d", "%0$@", "%.2@"])("不正・未対応の書式を拒否する: %s", value => {
  expect(() => format(value)).toThrow();
});

test("翻訳での引数の入れ替えを許し、型や個数の違いを拒否する", () => {
  const data = catalog(unit("%1$@ / %2$lld"));
  data.strings.sample_message.localizations.en = unit("%2$lld / %1$@");
  expect(messages(data)[0].args).toEqual(["string", "int64"]);
  data.strings.sample_message.localizations.en = unit("%1$lld");
  expect(() => messages(data)).toThrow("引数の数・型");
});

test("XMLとAndroidの引用規則で特殊文字・空白・改行を保持する", () => {
  expect(xmlText(' @? <>& "quoted" \'text\'\\path\nnext\t ')).toBe('" @? &lt;&gt;&amp; \\"quoted\\" \\\'text\\\'\\\\path\\nnext\\t "');
  const xml = androidXML(messages(catalog(unit(" 設定\n次の行 "))), "ja");
  expect(xml).toContain('formatted="false">" 設定\\n次の行 "');
});

test("単一整数の複数形をAndroidのpluralsへ出力する", () => {
  const data = catalog({ variations: { plural: { other: unit("%lld 件") } } });
  data.strings.sample_message.localizations.en = { variations: { plural: { one: unit("One item"), other: unit("%lld items") } } };
  const entry = messages(data)[0];
  expect(entry.plural).toBe(true);
  expect(androidXML([entry], "en")).toContain('<item quantity="other">"%1$d items"</item>');
  expect(androidXML([entry], "en")).toContain('<item quantity="one">"One item"</item>');
});

test("端末別や複雑な置換、otherのない複数形を黙って捨てない", () => {
  expect(() => messages(catalog({ variations: { device: { iphone: unit("iPhone") } } }))).toThrow();
  expect(() => messages(catalog({ substitutions: {} }))).toThrow();
  expect(() => messages(catalog({ variations: { plural: { one: unit("%lld item") } } }))).toThrow();
});

test("元言語・キー・翻訳状態を検査する", () => {
  const data = catalog(unit("設定"));
  data.strings.sample_message.localizations.ja.stringUnit!.state = "needs_review";
  expect(() => messages(data)).toThrow("未翻訳");
  data.strings = { "invalid.key": { localizations: { ja: unit("設定") } } };
  expect(() => messages(data)).toThrow("snake_case");
});

test("非翻訳指定と書式なしのパーセントを保持する", () => {
  const data = catalog(unit("100%"));
  data.strings.sample_message.shouldTranslate = false;
  const xml = androidXML(messages(data), "ja");
  expect(xml).toContain('translatable="false" formatted="false">"100%"');
  expect(() => xmlText("invalid\u0000text")).toThrow("制御文字");
});
