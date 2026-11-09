// 番組の詳細
import { expect, test } from "bun:test";
import { describeOnBothPlatforms } from "../sdk/app";

describeOnBothPlatforms("番組の詳細", (app) => {
  /** 番組表を読み込み、テスト局１の次の番組 (まだ始まっていない) の詳細を開く */
  async function openNextProgram() {
    await app().do("app/channelList", "appear", {}, (node) => node.state.rows.length > 0);
    const guide = await app().do("app/guideGrid", "load", {}, (node) => node.state.columns.length > 0);
    const onAir = guide!.state.columns[0].onAir.id;
    await app().do("app", "openProgram", { channel: "JP-G00000001", program: onAir + 1 });
    return app().do("app/remote-0", "appear");
  }

  test("まだ始まっていない番組は、予約できて、切り替えられない", async () => {
    const detail = await openNextProgram();
    expect(detail!.state.canReserve).toBe(true);
    expect(detail!.state.canTune).toBe(false);
    expect(await app().failure("app/remote-0", "tune", { startOver: false })).toContain("放送中の番組ではありません");
  });

  test("予約すると、予約したことを出す", async () => {
    await openNextProgram();
    const detail = await app().do("app/remote-0", "reserve", { series: false }, (node) => node.state.message !== null);
    expect(detail!.state.message).toContain("予約しました");
  });
});
