// 振る舞いのテストの小さな SDK (Shopify の Reflex と同じ作り)。
// 相手 (iOS 側の regza、Android 側の regza-android) を別のプロセスで起動し、同じ約束事 (1 行ずつの命令と JSON) で動かす。
// テストは相手がどちらかを知らず、ViewModel の state と操作だけを使う

import type { Subprocess } from "bun";

import { afterEach, beforeEach, describe } from "bun:test";

export type Platform = "ios" | "android";
export const platforms: Platform[] = ["ios", "android"];

/**
 * 同じテストを、iOS 側と Android 側の両方の相手で流す。テストごとに相手を見本の返事で起動し直す
 * (前のテストの操作が残らないように)
 */
export function describeOnBothPlatforms(title: string, body: (app: () => App) => void) {
  describe.each(platforms)(`%s: ${title}`, (platform) => {
    let current: App | undefined;
    beforeEach(async () => {
      current = await App.start(platform);
    });
    afterEach(async () => {
      await current?.close();
    });
    body(() => current!);
  });
}

/** ViewModel の状態と操作の一覧 (regza の ls・do が返すもの) */
export interface Node {
  name: string;
  path: string;
  isBusy: boolean;
  state: any;
  actions: { name: string; summary: string; parameters: Record<string, string> }[];
  children: string[];
}

const repository = new URL("../../", import.meta.url).pathname;
const commands: Record<Platform, string[]> = {
  // iOS と同じ共有の組み立てを Mac で動かす
  ios: [`${repository}Packages/RegzaCore/.build/debug/regza`, "--sample"],
  // Android と同じ道 (Kotlin → swift-java のつなぎ → 窓口) を Mac の JVM で動かす
  android: [`${repository}Android/behavior-tests/build/install/regza-android/bin/regza-android`, "--sample"],
};

/** 状態が期待どおりになるまで待つ時間 */
const timeout = 5_000;

export class App {
  private buffer = "";
  private reader: ReadableStreamDefaultReader<Uint8Array>;
  private decoder = new TextDecoder();

  private constructor(private process: Subprocess<"pipe", "pipe", "inherit">) {
    this.reader = process.stdout.getReader();
  }

  /** 見本の返事で相手を起動する (テレビにも録画サーバーにもつながない) */
  static async start(platform: Platform): Promise<App> {
    const app = new App(Bun.spawn(commands[platform], { stdin: "pipe", stdout: "pipe", stderr: "inherit" }));
    const ready = await app.read();
    if (!ready.ready) throw new Error(`${platform} の相手が起動しませんでした: ${JSON.stringify(ready)}`);
    return app;
  }

  /** 道の状態と操作の一覧 */
  async ls(path: string): Promise<Node> {
    return this.check(await this.command(`ls ${path}`));
  }

  /** 状態が条件を満たすまで待って返す (Reflex の precondition) */
  async precondition(path: string, condition: (node: Node) => boolean): Promise<Node> {
    const deadline = Date.now() + timeout;
    while (true) {
      const node = await this.ls(path);
      if (condition(node)) return node;
      if (Date.now() > deadline) throw new Error(`${path} が期待する状態になりません: ${JSON.stringify(node.state)}`);
      await Bun.sleep(50);
    }
  }

  /**
   * 操作を送り、状態が条件を満たすまで待って返す (Reflex の do)。条件を省けば、通信などが終わった状態を返す。
   * 閉じる操作などでその ViewModel がなくなったときは null
   */
  async do(path: string, action: string, args: Record<string, unknown> = {}, until?: (node: Node) => boolean): Promise<Node | null> {
    const result = await this.command(`do ${path} ${action} ${JSON.stringify(args)}`);
    if (result.closed) return null;
    const node = this.check(result);
    return until ? this.precondition(path, until) : node;
  }

  /** 道の ViewModel がない (閉じている) ことを確かめる */
  async absent(path: string): Promise<boolean> {
    const result = await this.command(`ls ${path}`);
    return typeof result.error === "string";
  }

  /** 操作を送り、失敗の説明を返す (できない操作を確かめるため) */
  async failure(path: string, action: string, args: Record<string, unknown> = {}): Promise<string> {
    const result = await this.command(`do ${path} ${action} ${JSON.stringify(args)}`);
    if (!result.error) throw new Error(`${path} の ${action} が失敗しませんでした`);
    return result.error;
  }

  async close() {
    this.process.stdin.write("quit\n");
    this.process.stdin.end();
    await this.process.exited;
  }

  private check(result: any): Node {
    if (result.error) throw new Error(result.error);
    return result;
  }

  private async command(line: string): Promise<any> {
    this.process.stdin.write(`${line}\n`);
    this.process.stdin.flush();
    return this.read();
  }

  /** 次の JSON を 1 つ読む (整形された JSON は複数行にわたる) */
  private async read(): Promise<any> {
    while (true) {
      const lines = this.buffer.split("\n");
      let text = "";
      for (let index = 0; index < lines.length - 1; index++) {
        text += lines[index] + "\n";
        try {
          const value = JSON.parse(text);
          this.buffer = lines.slice(index + 1).join("\n");
          return value;
        } catch {}
      }
      const { value, done } = await this.reader.read();
      if (done) throw new Error("相手が終了しました");
      this.buffer += this.decoder.decode(value, { stream: true });
    }
  }
}
