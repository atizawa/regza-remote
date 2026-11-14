// xcstringsの通常文字列・printf引数・単一整数の複数形を扱う。未対応の構造は黙って捨てない。
export type Argument = "string" | "int32" | "int64" | "float";
interface Unit { state: string; value: string }
interface Translation { stringUnit?: Unit; variations?: { plural: Record<string, { stringUnit: Unit }> } }
interface Entry { comment?: string; extractionState?: string; shouldTranslate?: boolean; localizations: Record<string, Translation> }
export interface Catalog { sourceLanguage: string; version: string; strings: Record<string, Entry> }
export interface Message { key: string; symbol: string; args: Argument[]; plural: boolean; translatable: boolean; translations: Map<string, Record<string, string>> }
const quantities = new Set(["zero", "one", "two", "few", "many", "other"]);

export function format(text: string): { args: Argument[]; android: string } {
  const args: Argument[] = [];
  let next = 1, explicit = false, implicit = false;
  const android = text;
  let result = "";
  for (let i = 0; i < android.length;) {
    if (android[i] !== "%") { result += android[i++]; continue; }
    const match = /^%(?:(\d+)\$)?(\.\d+)?(@|lld|d|f|%)/.exec(android.slice(i));
    if (!match) {
      if (i === android.length - 1 && args.length === 0) { result += "%"; i++; continue; }
      throw new Error(`未対応の書式指定: ${text}`);
    }
    i += match[0].length;
    if (match[3] === "%") { result += "%%"; continue; }
    if (match[1]) explicit = true; else implicit = true;
    if (explicit && implicit) throw new Error(`引数番号の有無を混在させないでください: ${text}`);
    const position = match[1] ? Number(match[1]) : next++;
    if (position < 1 || position > 20) throw new Error(`不正な引数番号: ${text}`);
    const type: Argument = match[3] === "@" ? "string" : match[3] === "f" ? "float" : match[3] === "d" ? "int32" : "int64";
    if (match[2] && type !== "float") throw new Error(`精度指定は小数だけに対応します: ${text}`);
    if (args[position - 1] && args[position - 1] !== type) throw new Error(`引数の型が一致しません: ${text}`);
    args[position - 1] = type;
    result += `%${position}$${match[2] ?? ""}${type === "string" ? "s" : type === "float" ? "f" : "d"}`;
  }
  if (Array.from(args).some(type => !type)) throw new Error(`引数番号が連続していません: ${text}`);
  return { args, android: result };
}

export function messages(catalog: Catalog): Message[] {
  if (catalog.version !== "1.0" || !catalog.sourceLanguage) throw new Error("未対応のString Catalogです。");
  const symbols = new Set<string>();
  return Object.entries(catalog.strings).sort(([a], [b]) => a.localeCompare(b, "en")).map(([key, entry]) => {
    if (!/^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$/.test(key)) throw new Error(`キーは小文字のsnake_caseにしてください: ${key}`);
    const symbol = key.replace(/_([a-z0-9])/g, (_, c) => c.toUpperCase());
    if (symbols.has(symbol)) throw new Error(`生成名が重複しています: ${symbol}`);
    symbols.add(symbol);
    const source = entry.localizations?.[catalog.sourceLanguage];
    if (!source) throw new Error(`元言語がありません: ${key}`);
    const translations = new Map<string, Record<string, string>>();
    let signature: Argument[] | undefined;
    let plural = false;
    // 元言語から型を確定し、翻訳の引数の入れ替え・省略・型違いを検査する。
    const additional = entry.shouldTranslate === false ? [] : Object.entries(entry.localizations).filter(([l]) => l !== catalog.sourceLanguage);
    for (const [locale, translation] of [[catalog.sourceLanguage, source], ...additional] as [string, Translation][]) {
      const allowed = new Set(["stringUnit", "variations"]);
      if (Object.keys(translation).some(k => !allowed.has(k))) throw new Error(`未対応の翻訳定義: ${key}/${locale}`);
      const hasPlural = !!translation.variations;
      if (locale === catalog.sourceLanguage) plural = hasPlural;
      if (plural !== hasPlural || (hasPlural && translation.stringUnit)) throw new Error(`翻訳の種類が一致しません: ${key}/${locale}`);
      if (hasPlural && Object.keys(translation.variations!).some(k => k !== "plural")) throw new Error(`端末別などのバリエーションは共通キーを分けてください: ${key}`);
      const forms = hasPlural ? translation.variations!.plural : { other: { stringUnit: translation.stringUnit! } };
      if (!forms?.other) throw new Error(`otherがありません: ${key}/${locale}`);
      const ordered = ["other", ...Object.keys(forms).filter(k => k !== "other")];
      const result: Record<string, string> = {};
      for (const quantity of ordered) {
        const form = forms[quantity];
        if (!quantities.has(quantity) || Object.keys(form).some(k => k !== "stringUnit")) throw new Error(`未対応の複数形: ${key}/${quantity}`);
        const unit = form.stringUnit;
        if (!unit || typeof unit.value !== "string" || unit.state !== "translated") throw new Error(`未翻訳または不正な値: ${key}/${locale}`);
        const parsed = format(unit.value);
        if (signature === undefined) signature = parsed.args;
        if (JSON.stringify(parsed.args) !== JSON.stringify(signature) && !(plural && parsed.args.length === 0)) throw new Error(`引数の数・型が一致しません: ${key}/${locale}`);
        result[quantity] = parsed.android;
      }
      translations.set(locale, result);
    }
    if (plural && (signature!.length !== 1 || !signature![0].startsWith("int"))) throw new Error(`複数形は単一の整数引数に限定します: ${key}`);
    return { key, symbol, args: signature!, plural, translatable: entry.shouldTranslate !== false, translations };
  });
}

export function xmlText(text: string): string {
  if (/[\x00-\x08\x0b\x0c\x0e-\x1f]/.test(text)) throw new Error("XMLに使えない制御文字があります。");
  const escaped = text.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/'/g, "\\'")
    .replace(/\n/g, "\\n").replace(/\r/g, "\\r").replace(/\t/g, "\\t")
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  // 全体を引用して先頭の@・?、連続空白、先頭末尾空白をAndroidにそのまま渡す。
  return `"${escaped}"`;
}

export function androidXML(entries: Message[], locale: string): string {
  const lines = entries.filter(entry => entry.translations.has(locale)).map(entry => {
    const forms = entry.translations.get(locale)!;
    const attributes = entry.translatable ? "" : ' translatable="false"';
    if (!entry.plural) return `    <string name="${entry.key}"${attributes}${entry.args.length ? "" : ' formatted="false"'}>${xmlText(forms.other)}</string>`;
    return `    <plurals name="${entry.key}"${attributes}>\n${Object.entries(forms).map(([quantity, text]) => `        <item quantity="${quantity}">${xmlText(text)}</item>`).join("\n")}\n    </plurals>`;
  });
  return `<?xml version="1.0" encoding="utf-8"?>\n<!-- Localizable.xcstringsから生成。直接編集せずmise run generate-localizationsを実行してください。 -->\n<resources>\n${lines.join("\n")}\n</resources>\n`;
}
