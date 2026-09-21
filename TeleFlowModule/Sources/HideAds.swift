import Foundation

@objc public class TeleFlowHideAds: NSObject {
    @objc public static func shouldHide() -> Bool {
        return TeleFlowManager.shared.hideAds
    }
}
