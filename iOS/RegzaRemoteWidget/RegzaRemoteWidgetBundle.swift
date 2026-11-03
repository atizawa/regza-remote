import AppIntents
import RegzaLiveActivity
import SwiftUI  
import WidgetKit

@main
struct RegzaRemoteWidgetBundle: WidgetBundle {
    var body: some Widget {
        RegzaLiveActivityWidget()
    }
}

struct RegzaRemoteWidgetIntents: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [RegzaLiveActivityIntents.self]
    }
}
