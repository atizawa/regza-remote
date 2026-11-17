#if os(iOS)
import PresentationCore
import SwiftUI

extension AppAppearance {
    public var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
#endif
