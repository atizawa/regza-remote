// UI テストから通常の APIClient で接続する、端末外の HTTP スタブ。
// アプリにはデータを注入せず、生成クライアント・通信・Repository を通す。
// 返事が OpenAPI の定義 (../OpenAPI) に合っていることは server.test.ts で確かめる
const now = Math.floor(Date.now() / 1000);
const channels = [1, 2].map((service) => ({
  channel: `JP-G0000000${service}`, channel_number: 10 + service,
  rcu_channel_number: service, name: `Maestro ${service}`,
  ex_channel_number: `DUV_${10 + service}`, show_setting: "SHOW_REPRESENT",
}));
const programs = [1, 2].map((service) => ({
  id: service * 1000 + 1, eventId: 1, networkId: 0, serviceId: service,
  startAt: (now - 600) * 1000, duration: 7_200_000,
  name: service === 1 ? "Maestro News" : "Maestro Sports", genres: [], isFree: true,
}));

/** 答える操作 (「メソッド パス」) と、その返事 */
export const routes: Record<string, () => Response> = {
  "GET /remote/status.htm": () => new Response("action=0\nch_code=JP-G00000001\nch_name=Maestro 1\n"),
  "GET /v2/remote/settings/timeshift": () =>
    Response.json({ status: 0, timeshift_enabled: "false", target_channel: [], active_time_list: [] }),
  "GET /v2/remote/settings/channel_list": () => Response.json({ status: 0, channel_list: channels }),
  "GET /v2/remote/play/status": () => Response.json({
    status: 0, content_type: "broadcast", epg_info_current: {
      channel: channels[0].channel, channel_name: channels[0].name,
      channel_number: 11, rcu_channel_number: 1,
      start_time: now - 600, duration: 7200, title: "Maestro News",
    },
  }),
  "GET /v2/remote/pvr/reserves/list": () => Response.json({ status: 0, rsv_list: [] }),
  "GET /api/programs": () => Response.json(programs),
  "GET /api/streams": () => Response.json({ items: [] }),
  "GET /remote/remote.htm": () => new Response("0"),
};

export function handle(request: Request): Response {
  const path = new URL(request.url).pathname;
  console.log(`${request.method} ${path}`);
  return routes[`${request.method} ${path}`]?.() ?? new Response("Unknown UI test endpoint", { status: 404 });
}

if (import.meta.main) {
  const server = Bun.serve({ hostname: "127.0.0.1", port: 0, fetch: handle });
  await Bun.write(process.env.UI_TEST_READY_FILE!, String(server.port));
}
