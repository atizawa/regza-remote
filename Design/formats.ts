import StyleDictionary from "style-dictionary";
import { header } from "./config";

// 色の値はOS標準リソースに置く。コードには名前による参照だけを生成する。
const comment = header.map(line => `// ${line}`).join("\n");
StyleDictionary.registerFormat({
  name: "native/swift-colors",
  format: ({ dictionary }) => `${comment}
#if os(iOS)
import SwiftUI

public enum DesignColors {
${dictionary.allTokens.map(token => `    public static let ${token.name} = Color("${token.name}", bundle: .module)`).join("\n")}
}
#endif
`,
});
StyleDictionary.registerFormat({
  name: "native/compose-colors",
  format: async ({ dictionary }) => {
    const declarations = await Promise.all(dictionary.allTokens.map(async token => {
      const resourceName = await StyleDictionary.hooks.transforms["name/snake"].transform(token, {}, {});
      return `    val ${token.name}: Color
        @Composable get() = colorResource(R.color.${resourceName})`;
    }));
    return `${comment}
package com.example.regzaremote.design

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.colorResource
import com.example.regzaremote.R

object DesignColors {
${declarations.join("\n\n")}
}
`;
  },
});
