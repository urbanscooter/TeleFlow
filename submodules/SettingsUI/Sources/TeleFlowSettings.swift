import Foundation
import SwiftSignalKit

/// Синглтон-менеджер настроек TeleFlow.
/// Персистентное хранение через UserDefaults с локальным именованным suitename.
/// Уведомляет подписчиков через NotificationCenter при изменении любого свойства.
public final class TeleFlowSettings {
    /// Стандартный shared-инстанс.
    public static let shared = TeleFlowSettings()

    /// Уникальный идентификатор для UserDefaults.
    private let suiteName = "group.ph.telegra.TeleFlow"

    /// Ключи для UserDefaults.
    private enum Keys: String {
        case isAntiDeleteEnabled
        case isHideAdsEnabled
        case isHideStoriesEnabled
    }

    /// Имя уведомления при изменении любого флага.
    public static let didChangeNotification = Notification.Name("TeleFlowSettingsDidChange")

    let userDefaults: UserDefaults

    // MARK: - Свойства

    /// Анти-удаление сообщений.
    /// Если `true`, входящие сообщения сохраняются даже если собеседник удалил их для всех.
    public var isAntiDeleteEnabled: Bool {
        get { userDefaults.bool(forKey: Keys.isAntiDeleteEnabled.rawValue) }
        set {
            guard newValue != isAntiDeleteEnabled else { return }
            userDefaults.set(newValue, forKey: Keys.isAntiDeleteEnabled.rawValue)
            UserDefaults.standard.set(newValue, forKey: "TeleFlow_isAntiDeleteEnabled")
            notifyChange()
        }
    }

    /// Скрытие рекламы и спонсированных постов.
    /// Если `true`, объекты SponsoredMessage фильтруются до отрисовки.
    public var isHideAdsEnabled: Bool {
        get { userDefaults.bool(forKey: Keys.isHideAdsEnabled.rawValue) }
        set {
            guard newValue != isHideAdsEnabled else { return }
            userDefaults.set(newValue, forKey: Keys.isHideAdsEnabled.rawValue)
            UserDefaults.standard.set(newValue, forKey: "TeleFlow_isHideAdsEnabled")
            notifyChange()
        }
    }

    /// Скрытие истории Stories.
    /// Если `true`, высота контейнера историй возвращается как 0 и рендеринг отключается.
    public var isHideStoriesEnabled: Bool {
        get { userDefaults.bool(forKey: Keys.isHideStoriesEnabled.rawValue) }
        set {
            guard newValue != isHideStoriesEnabled else { return }
            userDefaults.set(newValue, forKey: Keys.isHideStoriesEnabled.rawValue)
            UserDefaults.standard.set(newValue, forKey: "TeleFlow_isHideStoriesEnabled")
            notifyChange()
        }
    }

    // MARK: - Инициализация

    private init() {
        if let suite = UserDefaults(suiteName: suiteName) {
            self.userDefaults = suite
        } else {
            self.userDefaults = UserDefaults.standard
        }
    }

    // MARK: - Уведомления

    private func notifyChange() {
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    /// Подписка на изменения настроек. Возвращает disposable для отмены.
    public func observeChanges(_ handler: @escaping () -> Void) -> Disposable {
        let center = NotificationCenter.default
        let token = center.addObserver(forName: Self.didChangeNotification, object: nil, queue: .main) { _ in
            handler()
        }
        return ActionDisposable {
            center.removeObserver(token)
        }
    }

    /// Сброс всех флагов к значениям по умолчанию.
    public func resetAll() {
        userDefaults.removeObject(forKey: Keys.isAntiDeleteEnabled.rawValue)
        userDefaults.removeObject(forKey: Keys.isHideAdsEnabled.rawValue)
        userDefaults.removeObject(forKey: Keys.isHideStoriesEnabled.rawValue)
        notifyChange()
    }
}

// MARK: - Удобные обёртки для SignalKit

public extension TeleFlowSettings {
    /// Signal, эмитирующий текущее значение isAntiDeleteEnabled.
    var antiDeleteEnabledSignal: Signal<Bool, NoError> {
        return Signal<Bool, NoError> { subscriber in
            subscriber.putNext(self.isAntiDeleteEnabled)
            let disposable = self.observeChanges {
                subscriber.putNext(self.isAntiDeleteEnabled)
            }
            return disposable
        }
        |> runOn(.mainQueue())
    }

    /// Signal, эмитирующий текущее значение isHideAdsEnabled.
    var hideAdsEnabledSignal: Signal<Bool, NoError> {
        return Signal<Bool, NoError> { subscriber in
            subscriber.putNext(self.isHideAdsEnabled)
            let disposable = self.observeChanges {
                subscriber.putNext(self.isHideAdsEnabled)
            }
            return disposable
        }
        |> runOn(.mainQueue())
    }

    /// Signal, эмитирующий текущее значение isHideStoriesEnabled.
    var hideStoriesEnabledSignal: Signal<Bool, NoError> {
        return Signal<Bool, NoError> { subscriber in
            subscriber.putNext(self.isHideStoriesEnabled)
            let disposable = self.observeChanges {
                subscriber.putNext(self.isHideStoriesEnabled)
            }
            return disposable
        }
        |> runOn(.mainQueue())
    }
}
