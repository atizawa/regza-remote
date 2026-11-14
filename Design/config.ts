import type { Config } from "style-dictionary/types";

export const header = [
  "Design/tokens/ から Style Dictionary で生成。直接編集しないでください。",
  "更新: mise run generate-design-tokens",
];
const options = { className: "DesignDimensions", fileHeader: () => header };
const log = { warnings: "error" as const };

export default {
  source: ["tokens/dimensions.json"],
  usesDtcg: true,
  log,
  platforms: {
    ios: {
      transforms: ["name/camel", "size/swift/remToCGFloat"],
      // トークンの px を、同じ数値の pt として出力する。
      basePxFontSize: 1,
      files: [{
        destination: "../iOS/RegzaKit/Sources/Design/Generated/DesignDimensions.swift",
        format: "ios-swift/enum.swift",
        options: { ...options, import: ["CoreGraphics"] },
      }],
    },
    android: {
      transforms: ["name/camel", "size/compose/dp"],
      files: [{
        destination: "../Android/app/src/main/java/com/example/regzaremote/design/Generated/DesignDimensions.kt",
        format: "compose/object",
        options: { ...options, packageName: "com.example.regzaremote.design", import: ["androidx.compose.ui.unit.dp"] },
      }],
    },
  },
} satisfies Config;

export function colors(mode: "light" | "dark"): Config {
  return {
    source: ["tokens/colors/common.json", `tokens/colors/${mode}.json`],
    usesDtcg: true,
    log,
    platforms: {
      android: {
        transforms: ["name/snake", "color/hex8android"],
        files: [{
          destination: `../Android/app/src/main/res/values${mode === "dark" ? "-night" : ""}/design_colors.xml`,
          format: "android/colors",
          options: { fileHeader: () => header },
        }],
      },
      assets: { transforms: ["name/camel"] },
      ...(mode === "light" ? {
        swift: {
          transforms: ["name/camel"],
          files: [{ destination: "../iOS/RegzaKit/Sources/Design/Generated/DesignColors.swift", format: "native/swift-colors" }],
        },
        compose: {
          transforms: ["name/camel"],
          files: [{
            destination: "../Android/app/src/main/java/com/example/regzaremote/design/Generated/DesignColors.kt",
            format: "native/compose-colors",
          }],
        },
      } : {}),
    },
  };
}
