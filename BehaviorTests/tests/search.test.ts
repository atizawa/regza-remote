// 番組表の検索
import { expect, test } from "bun:test";
import { describeOnBothPlatforms } from "../sdk/app";

describeOnBothPlatforms("番組表の検索", (app) => {
  test("言葉で番組を探す", async () => {
    await app().do("app/channelList", "appear", {}, (node) => node.state.rows.length > 0);
    await app().do("app/guideGrid", "load", {}, (node) => node.state.columns.length > 0);
    const search = await app().do("app/guideGrid/search", "setText", { text: "料理" }, (node) => node.state.results.length > 0);
    expect(search!.state.results.every((row: any) => row.name.includes("料理"))).toBe(true);
  });

  test("日付と時間帯を条件として読み、外せる", async () => {
    const search = await app().do("app/guideGrid/search", "setText", { text: "明日の夜" }, (node) => node.state.conditions.length === 2);
    expect(search!.state.conditions).toEqual(["明日", "18時〜28時"]);
    await app().do("app/guideGrid/search", "removeCondition", { index: 0 }, (node) => node.state.conditions.join() === "18時〜28時");
  });
});
