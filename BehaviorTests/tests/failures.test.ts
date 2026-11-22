// うまくいかない場面 (偽物の名前の場面で作る)
import { expect, test } from "bun:test";
import { describeOnBothPlatforms } from "../sdk/app";

describeOnBothPlatforms(
  "テレビにつながらない",
  (app) => {
    test("リモコンに、接続できない説明を出す", async () => {
      await app().do("app/remote", "startPolling");
      const remote = await app().precondition("app/remote", (node) => node.state.errorMessage !== null);
      expect(remote.state.errorMessage).toContain("つながりませんでした");
      expect(remote.state.nowPlaying).toBeNull();
      await app().do("app/remote", "stopPolling");
    });

    test("チャンネル一覧は、取得できない説明を出す", async () => {
      const list = await app().do("app/channelList", "appear", {}, (node) => node.state.loadErrorMessage !== null);
      expect(list!.state.rows).toEqual([]);
    });
  },
  { base: "tvUnreachable" },
);

describeOnBothPlatforms(
  "チャンネルが登録されていない",
  (app) => {
    test("チャンネル一覧は、空であることを出す", async () => {
      const list = await app().do("app/channelList", "appear", {}, (node) => node.state.hasNoChannels);
      expect(list!.state.rows).toEqual([]);
      expect(list!.state.loadErrorMessage).toBeNull();
    });
  },
  { base: "emptyChannels" },
);

describeOnBothPlatforms(
  "番組表のサーバー (Mirakurun) につながらない",
  (app) => {
    test("番組表は、読み込めても局が並ばない", async () => {
      await app().do("app", "selectTab", { tab: "guide" });
      const guide = await app().do("app/guideGrid", "load", {}, (node) => node.state.hasLoaded);
      expect(guide!.state.hasGuide).toBe(true);
      expect(guide!.state.columns).toEqual([]);
    });
  },
  { base: "guideUnreachable" },
);
