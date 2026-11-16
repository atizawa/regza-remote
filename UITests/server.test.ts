// UI テストの HTTP スタブ (server.ts) の返事が、OpenAPI の定義 (../OpenAPI) に合っていること。
// スタブの返事がテレビ・録画サーバーの本物の API とずれると、UI テストがアプリの本当の振る舞いを確かめなくなるので、
// スタブが答えるどの操作も、定義にあり、返事の形が定義の型に合うことを確かめる
import { expect, test } from "bun:test";
import Ajv2020 from "ajv/dist/2020";
import { handle, routes } from "./server";

const openAPI = new URL("../OpenAPI/", import.meta.url);

/** API の定義。prefix はスタブの宛先のパスから、定義のパスにするときに外す部分 */
const specs = {
  regza: { document: Bun.YAML.parse(await Bun.file(new URL("regza-tv.yaml", openAPI)).text()) as any, prefix: "" },
  mirakurun: { document: await Bun.file(new URL("mirakurun.json", openAPI)).json(), prefix: "/api" },
  epgstation: { document: await Bun.file(new URL("epgstation.json", openAPI)).json(), prefix: "/api" },
};
type SpecName = keyof typeof specs;

/** 録画サーバーの宛先 (/api/…) はどちらの API か。テレビの宛先は /api で始まらない */
const recordingServers: Record<string, SpecName> = {
  "GET /api/programs": "mirakurun",
  "GET /api/streams": "epgstation",
};

// 定義どうしで同じ形の補足 (x-…・nullable など) は型の確かめに関わらないので、知らない書き方として止めない
const ajv = new Ajv2020({ strict: false, validateSchema: false, validateFormats: false });
for (const [name, spec] of Object.entries(specs)) ajv.addSchema(spec.document, name);

/** JSON Pointer の 1 つ分 */
const pointer = (key: string) => key.replaceAll("~", "~0").replaceAll("/", "~1");

for (const route of Object.keys(routes)) {
  test(`${route} の返事が API の定義に合う`, async () => {
    const [method, path] = route.split(" ");
    const name: SpecName = recordingServers[route] ?? "regza";
    if (path.startsWith("/api/")) expect(recordingServers[route]).toBeDefined();
    const { document, prefix } = specs[name];
    const specPath = path.slice(prefix.length);
    const operation = document.paths?.[specPath]?.[method.toLowerCase()];
    expect(operation, `${name} の定義に ${method} ${specPath} がない`).toBeDefined();

    const response = handle(new Request(`http://127.0.0.1${path}`, { method }));
    expect(response.status).toBe(200);
    const success = operation.responses["200"];
    expect(success, `${name} の定義の ${method} ${specPath} に 200 の返事がない`).toBeDefined();

    // Swagger 2.0 (Mirakurun) は schema を直に、OpenAPI 3 は content の種類ごとに持つ
    const base = `${name}#/paths/${pointer(specPath)}/${method.toLowerCase()}/responses/200`;
    if (success.schema) {
      const validate = ajv.compile({ $ref: `${base}/schema` });
      expect(validate(await response.json()), JSON.stringify(validate.errors)).toBe(true);
    } else if (success.content?.["application/json"]) {
      const validate = ajv.compile({ $ref: `${base}/content/application~1json/schema` });
      expect(validate(await response.json()), JSON.stringify(validate.errors)).toBe(true);
    } else {
      // 旧 API の文字の返事
      expect(success.content?.["text/plain"], `${name} の定義の ${method} ${specPath} の返事の種類が合わない`).toBeDefined();
      expect(await response.text()).not.toBe("");
    }
  });
}

test("定義に合わない返事は見つけられる (確かめ方が効いていること)", () => {
  const validate = ajv.compile({ $ref: "regza#/components/schemas/ChannelList" });
  expect(validate({ status: 0, channel_list: [{ name: "チャンネルの ID がない" }] })).toBe(false);
  expect(validate({ status: "0" })).toBe(false);
});
