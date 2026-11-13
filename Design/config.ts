import type { Config } from "style-dictionary/types";

const options = {
  className: "DesignDimensions",
  fileHeader: () => [
    "Design/tokens/*.json から Style Dictionary で生成。直接編集しないでください。",
    "更新: mise run generate-design-tokens",
  ],
};

export default {
  source: ["tokens/*.json"],
  usesDtcg: true,
  log: { warnings: "error" },
  platforms: {
    ios: {
      transforms: ["name/camel", "size/swift/remToCGFloat", "color/ColorSwiftUI"],
      // トークンの px を、同じ数値の pt として出力する。
      basePxFontSize: 1,
      files: [{
        destination: "../iOS/RegzaKit/Sources/Design/Generated/DesignDimensions.swift",
        format: "ios-swift/enum.swift",
        filter: { $type: "dimension" },
        options: { ...options, import: ["CoreGraphics"] },
      }, {
        destination: "../iOS/RegzaKit/Sources/Design/Generated/DesignColors.swift",
        format: "ios-swift/enum.swift",
        filter: { $type: "color" },
        options: { ...options, className: "DesignColors", import: ["SwiftUI"] },
      }],
    },
    android: {
      transforms: ["name/camel", "size/compose/dp", "color/composeColor"],
      files: [{
        destination: "../Android/app/src/main/java/com/example/regzaremote/design/Generated/DesignDimensions.kt",
        format: "compose/object",
        filter: { $type: "dimension" },
        options: {
          ...options,
          packageName: "com.example.regzaremote.design",
          import: ["androidx.compose.ui.unit.dp"],
        },
      }, {
        destination: "../Android/app/src/main/java/com/example/regzaremote/design/Generated/DesignColors.kt",
        format: "compose/object",
        filter: { $type: "color" },
        options: {
          ...options,
          className: "DesignColors",
          packageName: "com.example.regzaremote.design",
          import: ["androidx.compose.ui.graphics.Color"],
        },
      }],
    },
  },
} satisfies Config;
