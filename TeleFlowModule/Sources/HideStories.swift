import Foundation

@objc public class TeleFlowHideStories: NSObject {
    @objc public static func shouldHide() -> Bool {
        return TeleFlowManager.shared.hideStories
    }
}
