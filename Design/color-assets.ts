export interface SRGBColor {
  colorSpace: string;
  components: number[];
  alpha: number;
}

export const assetInfo = { author: "xcode", version: 1 };

export function colorSet(light: SRGBColor, dark: SRGBColor) {
  return {
    colors: [light, dark].map((value, index) => {
      if (value.colorSpace !== "srgb" || value.components.length !== 3 ||
          [...value.components, value.alpha].some(n => !Number.isFinite(n) || n < 0 || n > 1)) {
        throw new Error("Color AssetのsRGB成分・透明度は0〜1で指定してください。");
      }
      return {
        idiom: "universal",
        ...(index === 1 ? { appearances: [{ appearance: "luminosity", value: "dark" }] } : {}),
        color: { "color-space": "srgb", components: {
          // 整数文字列 "1" はactoolに1/255と解釈されるため、必ず小数表記で渡す。
          red: value.components[0].toFixed(8), green: value.components[1].toFixed(8),
          blue: value.components[2].toFixed(8), alpha: value.alpha.toFixed(8),
        } },
      };
    }),
    info: assetInfo,
  };
}
