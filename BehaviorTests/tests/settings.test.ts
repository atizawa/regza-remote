// 設定
import { expect, test } from "bun:test";
import { describeOnBothPlatforms } from "../sdk/app";

describeOnBothPlatforms("設定", (app) => {
  test("外観を即時に切り替え、設定を閉じても選択を保持する", async () => {
    await app().do("app", "showSettings");
    for (const appearance of ["dark", "light", "system"]) {
      await app().do("app/settings", "setAppearance", { appearance }, (node) => node.state.appearance === appearance);
      expect((await app().ls("app")).state.appearance).toBe(appearance);
    }
    await app().do("app/settings", "close");
    await app().do("app", "showSettings");
    expect((await app().ls("app/settings")).state.appearance).toBe("system");
  });

  test("設定の中の画面を開いて戻り、閉じる", async () => {
    await app().do("app", "showSettings");
    expect((await app().ls("app/settings")).state.path).toEqual([]);

    await app().do("app/settings", "openPage", { page: "guide" }, (node) => node.state.path.join() === "guide");
    await app().do("app/settings", "back", {}, (node) => node.state.path.length === 0);

    await app().do("app/settings", "close");
    expect(await app().absent("app/settings")).toBe(true);
  });

  test("パスワードは見せない", async () => {
    await app().do("app", "showSettings");
    const settings = await app().do("app/settings", "tv.setPassword", { password: "secret" });
    expect(JSON.stringify(settings!.state)).not.toContain("secret");
  });

  test("設定の中の画面の並びをまとめて書き戻す", async () => {
    await app().do("app", "showSettings");
    await app().do("app/settings", "setPath", { path: ["guide"] }, (node) => node.state.path.join() === "guide");
    await app().do("app/settings", "setPath", { path: [] }, (node) => node.state.path.length === 0);
  });
});
