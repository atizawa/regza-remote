// 録画予約の一覧
import { expect, test } from "bun:test";
import { describeOnBothPlatforms } from "../sdk/app";

/** テレビに 1 件の予約がある (取り消しはテレビに断られる) */
const fixture = {
  responses: {
    "/v2/remote/pvr/reserves/list": {
      body: {
        status: 0,
        rsv_list: [
          { rsv_id: "1", title: "これからの番組", channel: "JP-G00000001", epg_content_id: "JP-0000000000010002", start_time: 4000000000, duration: 1800 },
        ],
      },
    },
    "/v2/remote/pvr/reserves/list/1": { status: 500 },
  },
};

describeOnBothPlatforms(
  "録画予約の一覧",
  (app) => {
    test("予約を読み込み、予定に並べる", async () => {
      const list = await app().do("app/reservationList", "load", {}, (node) => node.state.hasLoaded);
      expect(list!.state.scheduled.map((item: any) => item.title)).toEqual(["これからの番組"]);
      expect(list!.state.waiting).toEqual([]);
    });

    test("取り消せないと、取り消せなかった説明を出す", async () => {
      await app().do("app/reservationList", "load", {}, (node) => node.state.hasLoaded);
      const list = await app().do("app/reservationList", "cancel", { reservation: "1" }, (node) => node.state.cancelError !== null);
      expect(list!.state.cancelError).toContain("これからの番組");
    });

    test("ない予約は取り消せない", async () => {
      await app().do("app/reservationList", "load", {}, (node) => node.state.hasLoaded);
      expect(await app().failure("app/reservationList", "cancel", { reservation: "9" })).toContain("予約 9 はありません");
    });
  },
  fixture,
);
