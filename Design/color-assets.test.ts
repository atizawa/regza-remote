import { expect, test } from "bun:test";
import { colorSet } from "./color-assets";

test("actoolが整数値を8bit値として解釈しないよう、成分・透明度を小数表記で出力する", () => {
  const asset = colorSet(
    { colorSpace: "srgb", components: [0, 0.5, 1], alpha: 1 },
    { colorSpace: "srgb", components: [1, 0, 0.5], alpha: 0.12 },
  );
  expect(asset.colors[0].appearances).toBeUndefined();
  expect(asset.colors[1].appearances).toEqual([{ appearance: "luminosity", value: "dark" }]);
  expect(asset.colors[0].color.components.alpha).toBe("1.00000000");
  expect(asset.colors[1].color.components.alpha).toBe("0.12000000");
  for (const entry of asset.colors) {
    for (const component of Object.values(entry.color.components)) {
      expect(component).toMatch(/^[01]\.\d+$/);
    }
  }
});

test("Color Assetに未対応の色空間や範囲外の成分を出力しない", () => {
  const valid = { colorSpace: "srgb", components: [0, 0.5, 1], alpha: 1 };
  expect(() => colorSet(valid, { ...valid, colorSpace: "display-p3" })).toThrow();
  expect(() => colorSet(valid, { ...valid, alpha: 1.5 })).toThrow();
});
