// UI テストから通常の APIClient で接続する、端末外の HTTP スタブ。
// アプリにはデータを注入せず、生成クライアント・通信・Repository を通す。
const now = Math.floor(Date.now() / 1000);
const channels = [1, 2].map((service) => ({
  channel: `JP-G0000000${service}`, channel_number: 10 + service,
  rcu_channel_number: service, name: `Maestro ${service}`,
  ex_channel_number: `DUV_${10 + service}`, show_setting: "SHOW_REPRESENT",
}));
const programs = [1, 2].map((service) => ({
  id: service * 1000 + 1, eventId: 1, networkId: 0, serviceId: service,
  startAt: (now - 600) * 1000, duration: 7_200_000,
  name: service === 1 ? "Maestro News" : "Maestro Sports", genres: [],
}));
const server = Bun.serve({
  hostname: "127.0.0.1", port: 0,
  fetch(request) {
    const path = new URL(request.url).pathname;
    console.log(`${request.method} ${path}`);
    switch (path) {
      case "/remote/status.htm": return new Response("action=0\nch_code=JP-G00000001\nch_name=Maestro 1\n");
      case "/v2/remote/settings/timeshift": return Response.json({ status: 0, timeshift_enabled: "false", target_channel: [], active_time_list: [] });
      case "/v2/remote/settings/channel_list": return Response.json({ status: 0, channel_list: channels });
      case "/v2/remote/play/status": return Response.json({
        status: 0, content_type: "broadcast", epg_info_current: {
          channel: channels[0].channel, channel_name: channels[0].name,
          channel_number: 11, rcu_channel_number: 1,
          start_time: now - 600, duration: 7200, title: "Maestro News",
        },
      });
      case "/v2/remote/pvr/reserves/list": return Response.json({ status: 0, rsv_list: [] });
      case "/api/programs": return Response.json(programs);
      case "/api/streams": return Response.json({ items: [] });
      case "/remote/remote.htm": return new Response("0");
      default: return new Response("Unknown UI test endpoint", { status: 404 });
    }
  },
});
await Bun.write(process.env.UI_TEST_READY_FILE!, String(server.port));
