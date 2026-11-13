import type { Config } from "style-dictionary/types";

const options = {
  className: "Design",
  fileHeader: () => [
    "Design/tokens.json から Style Dictionary で生成。直接編集しないでください。",
    "更新: mise run generate-design-tokens",
  ],
};

export default {
  source: ["tokens.json"],
  usesDtcg: true,
  log: { warnings: "error" },
  platforms: {
    ios: {
      transforms: ["name/camel", "size/swift/remToCGFloat"],
      // トークンの px を、同じ数値の pt として出力する。
      basePxFontSize: 1,
      files: [{
        destination: "../iOS/RegzaKit/Sources/Design/Generated/Design.swift",
        format: "ios-swift/enum.swift",
        filter: { $type: "dimension" },
        options: { ...options, import: ["CoreGraphics"] },
      }],
    },
    android: {
      transforms: ["name/camel", "size/compose/dp"],
      files: [{
        destination: "../Android/app/src/main/java/com/example/regzaremote/design/Generated/Design.kt",
        format: "compose/object",
        filter: { $type: "dimension" },
        options: {
          ...options,
          packageName: "com.example.regzaremote.design",
          import: ["androidx.compose.ui.unit.dp"],
        },
      }],
    },
  },
} satisfies Config;
