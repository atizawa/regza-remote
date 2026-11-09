// チャンネル一覧と、そこから開く 1 チャンネルの番組表
import { expect, test } from "bun:test";
import { describeOnBothPlatforms } from "../sdk/app";

describeOnBothPlatforms("チャンネル一覧", (app) => {
  test("チャンネルのタブを開くと、見本の局が並ぶ", async () => {
    await app().do("app", "selectTab", { tab: "channels" }, (node) => node.state.tab === "channels");
    const list = await app().do("app/channelList", "appear", {}, (node) => node.state.rows.length > 0);
    expect(list!.state.rows.map((row: any) => row.name)).toEqual(["テスト局１", "テスト局２"]);
  });

  test("テレビにないチャンネルは選べない", async () => {
    await app().do("app/channelList", "appear", {}, (node) => node.state.rows.length > 0);
    expect(await app().failure("app/channelList", "tune", { channel: "JP-G99999999" })).toContain("JP-G99999999");
  });

  test("局の番組表を開いて読み込み、戻る", async () => {
    await app().do("app", "selectTab", { tab: "channels" });
    const list = await app().do("app/channelList", "appear", {}, (node) => node.state.rows.length > 0);
    const channel = list!.state.rows[0].code;

    // タブの path に積んだ画面は「タブ-奥行き」の道で見える
    await app().do("app", "openPrograms", { channel });
    const programs = await app().do("app/channels-0", "appear", {}, (node) => node.state.days !== null);
    expect(programs!.state.channelName).toBe("テスト局１");
    expect(programs!.state.days.length).toBeGreaterThan(0);

    await app().do("app", "back");
    expect(await app().absent("app/channels-0")).toBe(true);
  });

  test("path をまとめて書き戻すと (iOS で戻るスワイプをしたときと同じ)、その画面まで戻る", async () => {
    await app().do("app", "selectTab", { tab: "channels" });
    await app().do("app/channelList", "appear", {}, (node) => node.state.rows.length > 0);
    await app().do("app/guideGrid", "load", {}, (node) => node.state.columns.length > 0);
    await app().do("app", "openPrograms", { channel: "JP-G00000001" });
    await app().do("app", "openProgram", { channel: "JP-G00000001", program: 1001 });
    const opened = (await app().ls("app")).state.paths.channels;
    expect(opened.length).toBe(2);

    // 番組表の画面まで戻す
    await app().do("app", "setPath", { tab: "channels", path: [opened[0]] }, (node) => node.state.paths.channels.length === 1);
    expect(await app().absent("app/channels-1")).toBe(true);
    expect((await app().ls("app/channels-0")).state.channelName).toBe("テスト局１");
  });
});
