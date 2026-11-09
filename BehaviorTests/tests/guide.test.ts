// 番組表
import { expect, test } from "bun:test";
import { describeOnBothPlatforms } from "../sdk/app";

describeOnBothPlatforms("番組表", (app) => {
  test("番組表を読み込み、別の日を選ぶ", async () => {
    await app().do("app", "selectTab", { tab: "guide" });
    const guide = await app().do("app/guideGrid", "load", {}, (node) => node.state.days.length > 1 && node.state.columns.length > 0);
    expect(guide!.state.selectedDay).toBeNull();

    const day = guide!.state.days[1].day;
    await app().do("app/guideGrid", "selectDay", { day }, (node) => node.state.selectedDay === day);
  });
});
