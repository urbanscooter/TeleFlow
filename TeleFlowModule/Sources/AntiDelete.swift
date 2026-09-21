import Foundation

@objc public class TeleFlowAntiDelete: NSObject {
    @objc public static func isEnabled() -> Bool {
        return TeleFlowManager.shared.antiDelete
    }
}
