// リモコン
import { expect, test } from "bun:test";
import { describeOnBothPlatforms } from "../sdk/app";

describeOnBothPlatforms("リモコン", (app) => {
  test("偽物のテレビが登録されていて、リモコンのタブから始まる", async () => {
    const state = (await app().ls("app")).state;
    expect(state.tab).toBe("remote");
    expect(state.isShowingSettings).toBe(false);
  });

  test("画面が見えている間は、いま映っているものを取り直す", async () => {
    await app().do("app/remote", "startPolling");
    const remote = await app().precondition("app/remote", (node) => node.state.nowPlaying !== null);
    // 偽物のテレビが映している局の、放送中の番組
    expect(remote.state.nowPlaying.title).toMatch(/^見本の.+ 第\d+回$/);
    // ロック画面 (iOS の Live Activity) も同じ state を読む
    expect(remote.state.isConnected).toBe(true);
    await app().do("app/remote", "stopPolling");
  });

  test("キーを押すと、押した回数が増える", async () => {
    const before = (await app().ls("app/remote")).state.tapCount;
    const remote = await app().do("app/remote", "press", { key: "power" }, (node) => node.state.tapCount > before && !node.isBusy);
    // 直前に押したボタン (ロック画面に出す)
    expect(remote!.state.lastCommandLabel).toBe("電源");
  });

  test("ロック画面の表示を始められなかったことを知らせると、説明を出す", async () => {
    const remote = await app().do("app/remote", "lockScreenStartFailed", {}, (node) => node.state.errorMessage !== null);
    expect(remote!.state.errorMessage).toBe("ロック画面の表示を始められませんでした");
  });
});
