// いま映っているものの詳細 (ミニプレーヤーから開くシート)
import { expect, test } from "bun:test";
import { describeOnBothPlatforms } from "../sdk/app";

describeOnBothPlatforms("いま映っているものの詳細", (app) => {
  test("放送を見ていれば、視聴中としてアプリで見られる局を出す。閉じられる", async () => {
    await app().do("app/remote", "startPolling");
    await app().precondition("app/remote", (node) => node.state.nowPlaying !== null);
    await app().do("app", "showNowPlaying");
    const detail = await app().do("app/nowPlaying", "appear", {}, (node) => node.state.playableChannelCode !== null);
    expect(detail!.state.title).toBe("視聴中");
    expect(detail!.state.playableChannelCode).toBe("JP-G00000001");
    await app().do("app/remote", "stopPolling");

    await app().do("app", "closeNowPlaying");
    expect(await app().absent("app/nowPlaying")).toBe(true);
  });
});
