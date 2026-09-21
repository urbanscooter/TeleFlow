import Foundation

@objc public class TeleFlowManager: NSObject {
    @objc public static let shared = TeleFlowManager()

    private override init() {
        super.init()
    }

    @objc public var hideAds: Bool {
        get { UserDefaults.standard.bool(forKey: "teleflow.hideAds") }
        set { UserDefaults.standard.set(newValue, forKey: "teleflow.hideAds") }
    }

    @objc public var hideStories: Bool {
        get { UserDefaults.standard.bool(forKey: "teleflow.hideStories") }
        set { UserDefaults.standard.set(newValue, forKey: "teleflow.hideStories") }
    }

    @objc public var antiDelete: Bool {
        get { UserDefaults.standard.bool(forKey: "teleflow.antiDelete") }
        set { UserDefaults.standard.set(newValue, forKey: "teleflow.antiDelete") }
    }
}
