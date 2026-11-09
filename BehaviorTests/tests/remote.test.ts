// リモコン
import { expect, test } from "bun:test";
import { describeOnBothPlatforms } from "../sdk/app";

describeOnBothPlatforms("リモコン", (app) => {
  test("見本のテレビが登録されていて、リモコンのタブから始まる", async () => {
    const state = (await app().ls("app")).state;
    expect(state.tab).toBe("remote");
    expect(state.isShowingSettings).toBe(false);
  });

  test("画面が見えている間は、いま映っているものを取り直す", async () => {
    await app().do("app/remote", "startPolling");
    const remote = await app().precondition("app/remote", (node) => node.state.nowPlaying !== null);
    expect(remote.state.nowPlaying.title).toBe("見本の番組");
    await app().do("app/remote", "stopPolling");
  });

  test("キーを押すと、押した回数が増える", async () => {
    const before = (await app().ls("app/remote")).state.tapCount;
    await app().do("app/remote", "press", { key: "power" }, (node) => node.state.tapCount > before);
  });

  test("テレビとのやり取りの外で起きたエラーを知らせると、説明を出す", async () => {
    const remote = await app().do("app/remote", "report", { message: "Live Activity を始められませんでした" }, (node) => node.state.errorMessage !== null);
    expect(remote!.state.errorMessage).toBe("Live Activity を始められませんでした");
  });
});
