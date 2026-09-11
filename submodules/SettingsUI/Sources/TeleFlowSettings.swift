import Foundation
import SwiftSignalKit

/// Синглтон-менеджер настроек TeleFlow.
public final class TeleFlowSettings {
    public static let shared = TeleFlowSettings()

    private let suiteName = "group.ph.telegra.TeleFlow"

    private enum Keys: String {
        case isAntiDeleteEnabled
        case isHideAdsEnabled
        case isHideStoriesEnabled
        case isGrayOutDeletedEnabled
        case isShowTrashIconEnabled
        case deletedOpacity
    }

    public static let didChangeNotification = Notification.Name("TeleFlowSettingsDidChange")

    let userDefaults: UserDefaults

    // MARK: - Свойства

    /// Анти-удаление сообщений.
    public var isAntiDeleteEnabled: Bool {
        get { userDefaults.bool(forKey: Keys.isAntiDeleteEnabled.rawValue) }
        set {
            guard newValue != isAntiDeleteEnabled else { return }
            userDefaults.set(newValue, forKey: Keys.isAntiDeleteEnabled.rawValue)
            UserDefaults.standard.set(newValue, forKey: "TeleFlow_isAntiDeleteEnabled")
            notifyChange()
        }
    }

    /// Скрытие рекламы.
    public var isHideAdsEnabled: Bool {
        get { userDefaults.bool(forKey: Keys.isHideAdsEnabled.rawValue) }
        set {
            guard newValue != isHideAdsEnabled else { return }
            userDefaults.set(newValue, forKey: Keys.isHideAdsEnabled.rawValue)
            UserDefaults.standard.set(newValue, forKey: "TeleFlow_isHideAdsEnabled")
            notifyChange()
        }
    }

    /// Скрытие историй.
    public var isHideStoriesEnabled: Bool {
        get { userDefaults.bool(forKey: Keys.isHideStoriesEnabled.rawValue) }
        set {
            guard newValue != isHideStoriesEnabled else { return }
            userDefaults.set(newValue, forKey: Keys.isHideStoriesEnabled.rawValue)
            UserDefaults.standard.set(newValue, forKey: "TeleFlow_isHideStoriesEnabled")
            notifyChange()
        }
    }

    /// Приглушать удалённые сообщения (прозрачность/серость). По умолчанию ВКЛ.
    public var isGrayOutDeletedEnabled: Bool {
        get {
            if userDefaults.object(forKey: Keys.isGrayOutDeletedEnabled.rawValue) == nil { return true }
            return userDefaults.bool(forKey: Keys.isGrayOutDeletedEnabled.rawValue)
        }
        set {
            guard newValue != isGrayOutDeletedEnabled else { return }
            userDefaults.set(newValue, forKey: Keys.isGrayOutDeletedEnabled.rawValue)
            notifyChange()
        }
    }

    /// Показывать иконку корзины возле времени. По умолчанию ВКЛ.
    public var isShowTrashIconEnabled: Bool {
        get {
            if userDefaults.object(forKey: Keys.isShowTrashIconEnabled.rawValue) == nil { return true }
            return userDefaults.bool(forKey: Keys.isShowTrashIconEnabled.rawValue)
        }
        set {
            guard newValue != isShowTrashIconEnabled else { return }
            userDefaults.set(newValue, forKey: Keys.isShowTrashIconEnabled.rawValue)
            notifyChange()
        }
    }

    /// Непрозрачность удалённого сообщения. 1.0 — как обычно, 0.3 — сильно приглушено.
    /// По умолчанию 0.55.
    public var deletedOpacity: Double {
        get {
            if userDefaults.object(forKey: Keys.deletedOpacity.rawValue) == nil { return 0.55 }
            let value = userDefaults.double(forKey: Keys.deletedOpacity.rawValue)
            return min(1.0, max(0.1, value))
        }
        set {
            let clamped = min(1.0, max(0.1, newValue))
            guard clamped != deletedOpacity else { return }
            userDefaults.set(clamped, forKey: Keys.deletedOpacity.rawValue)
            notifyChange()
        }
    }

    // MARK: - Init

    private init() {
        if let suite = UserDefaults(suiteName: suiteName) {
            self.userDefaults = suite
        } else {
            self.userDefaults = UserDefaults.standard
        }
    }

    // MARK: - Notifications

    private func notifyChange() {
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    public func observeChanges(_ handler: @escaping () -> Void) -> Disposable {
        let center = NotificationCenter.default
        let token = center.addObserver(forName: Self.didChangeNotification, object: nil, queue: .main) { _ in
            handler()
        }
        return ActionDisposable {
            center.removeObserver(token)
        }
    }

    public func resetAll() {
        for key in [Keys.isAntiDeleteEnabled, .isHideAdsEnabled, .isHideStoriesEnabled,
                    .isGrayOutDeletedEnabled, .isShowTrashIconEnabled, .deletedOpacity] {
            userDefaults.removeObject(forKey: key.rawValue)
        }
        notifyChange()
    }
}

// MARK: - SignalKit wrappers

public extension TeleFlowSettings {
    var antiDeleteEnabledSignal: Signal<Bool, NoError> {
        return Signal<Bool, NoError> { subscriber in
            subscriber.putNext(self.isAntiDeleteEnabled)
            let d = self.observeChanges { subscriber.putNext(self.isAntiDeleteEnabled) }
            return d
        } |> runOn(.mainQueue())
    }

    var hideAdsEnabledSignal: Signal<Bool, NoError> {
        return Signal<Bool, NoError> { subscriber in
            subscriber.putNext(self.isHideAdsEnabled)
            let d = self.observeChanges { subscriber.putNext(self.isHideAdsEnabled) }
            return d
        } |> runOn(.mainQueue())
    }

    var hideStoriesEnabledSignal: Signal<Bool, NoError> {
        return Signal<Bool, NoError> { subscriber in
            subscriber.putNext(self.isHideStoriesEnabled)
            let d = self.observeChanges { subscriber.putNext(self.isHideStoriesEnabled) }
            return d
        } |> runOn(.mainQueue())
    }

    var grayOutDeletedEnabledSignal: Signal<Bool, NoError> {
        return Signal<Bool, NoError> { subscriber in
            subscriber.putNext(self.isGrayOutDeletedEnabled)
            let d = self.observeChanges { subscriber.putNext(self.isGrayOutDeletedEnabled) }
            return d
        } |> runOn(.mainQueue())
    }

    var showTrashIconEnabledSignal: Signal<Bool, NoError> {
        return Signal<Bool, NoError> { subscriber in
            subscriber.putNext(self.isShowTrashIconEnabled)
            let d = self.observeChanges { subscriber.putNext(self.isShowTrashIconEnabled) }
            return d
        } |> runOn(.mainQueue())
    }

    var deletedOpacitySignal: Signal<Double, NoError> {
        return Signal<Double, NoError> { subscriber in
            subscriber.putNext(self.deletedOpacity)
            let d = self.observeChanges { subscriber.putNext(self.deletedOpacity) }
            return d
        } |> runOn(.mainQueue())
    }
}
