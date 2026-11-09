// チャンネル一覧の振る舞い。同じテストを iOS 側と Android 側の両方で流す
import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { App, platforms } from "../sdk/app";

describe.each(platforms)("%s", (platform) => {
  let app: App;
  beforeEach(async () => {
    app = await App.start(platform);
  });
  afterEach(async () => {
    await app.close();
  });

  test("チャンネルのタブを開くと、見本の局が並ぶ", async () => {
    await app.do("app", "selectTab", { tab: "channels" }, (node) => node.state.tab === "channels");
    const list = await app.do("app/channelList", "appear", {}, (node) => node.state.rows.length > 0);
    expect(list.state.rows.map((row: any) => row.name)).toEqual(["テスト局１", "テスト局２"]);
  });

  test("テレビにないチャンネルは選べない", async () => {
    await app.do("app/channelList", "appear", {}, (node) => node.state.rows.length > 0);
    expect(await app.failure("app/channelList", "tune", { channel: "JP-G99999999" })).toContain("JP-G99999999");
  });
});
