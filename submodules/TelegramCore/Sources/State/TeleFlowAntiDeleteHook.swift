import Foundation

/// Hook-точка для анти-удаления. Реализация живёт в SettingsUI и
/// регистрируется на старте приложения. TelegramCore не знает о SettingsUI —
/// он видит только протокол.
public protocol TeleFlowAntiDeleteHook: AnyObject {
    /// Включено ли анти-удаление. Если false — TelegramCore удаляет штатно.
    var isAntiDeleteEnabled: Bool { get }

    /// Вызывается, когда анти-удаление включено. Сервис должен только
    /// пометить сообщения (например, для анимации корзины), НЕ удалять их.
    func handleIncomingMessageDeletions(account: Account, messageIds: [MessageId])
}

public final class TeleFlowAntiDeleteHookRegistry {
    public static let shared = TeleFlowAntiDeleteHookRegistry()
    public var hook: TeleFlowAntiDeleteHook?
    private init() {}
}
