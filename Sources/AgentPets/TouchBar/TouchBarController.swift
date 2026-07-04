import AppKit
import SwiftUI

/// Builds the NSTouchBar and its single principal SwiftUI item.
@MainActor
final class TouchBarController: NSObject, NSTouchBarDelegate {
    static let itemID = NSTouchBarItem.Identifier("\(AppSupport.bundleIdentifier).principal")
    static let barID: String = "\(AppSupport.bundleIdentifier).bar"

    let model: PetModel
    let configProvider: () -> PetConfig
    let packProvider: () -> Pack?
    let onTap: () -> Void

    private(set) var touchBar: NSTouchBar!

    init(
        model: PetModel,
        configProvider: @escaping () -> PetConfig,
        packProvider: @escaping () -> Pack?,
        onTap: @escaping () -> Void
    ) {
        self.model = model
        self.configProvider = configProvider
        self.packProvider = packProvider
        self.onTap = onTap
        super.init()
        let bar = NSTouchBar()
        bar.delegate = self
        bar.defaultItemIdentifiers = [Self.itemID]
        bar.principalItemIdentifier = Self.itemID
        self.touchBar = bar
    }

    func touchBar(_ tb: NSTouchBar, makeItemForIdentifier id: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard id == Self.itemID else { return nil }
        let item = NSCustomTouchBarItem(identifier: id)
        let config = configProvider()
        let pack = packProvider() ?? Pack.empty
        let host = NSHostingView(rootView: PetView(model: model, config: config, pack: pack, onTap: onTap))
        host.frame = NSRect(x: 0, y: 0, width: 1009, height: 30)
        host.autoresizingMask = [.width, .height]
        item.view = host
        return item
    }
}
