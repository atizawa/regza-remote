// アプリで見る (ライブ視聴)
import { expect, test } from "bun:test";
import { describeOnBothPlatforms } from "../sdk/app";

describeOnBothPlatforms("ライブ視聴", (app) => {
  test("局を選ぶと配信を頼み、準備できたら再生する URL を出す。閉じると止める", async () => {
    await app().do("app/channelList", "appear", {}, (node) => node.state.rows.length > 0);
    await app().do("app", "play", { channel: "JP-G00000001" });
    await app().do("app/player", "appear");
    const player = await app().do("app/player", "start", {}, (node) => node.state.phase.ready !== undefined);
    expect(player!.state.channelName).toBe("テスト局１");
    expect(player!.state.phase.ready.url).toContain("stream1.m3u8");

    await app().do("app", "closePlayer");
    expect(await app().absent("app/player")).toBe(true);
  });
});
