import Foundation
import TelegramCore

public final class TeleFlowAntiDeleteService: TeleFlowAntiDeleteHook {
    public static let shared = TeleFlowAntiDeleteService()

    private init() {}

    public var isAntiDeleteEnabled: Bool {
        // TODO: читать реальный флаг из твоих настроек (UserDefaults и т.п.)
        return UserDefaults.standard.bool(forKey: "TeleFlowAntiDeleteEnabled")
    }

    public func handleIncomingMessageDeletions(account: Account, messageIds: [MessageId]) {
        // Вызывается ТОЛЬКО когда isAntiDeleteEnabled == true.
        // Здесь НЕ удаляем сообщения — просто помечаем для UI.
        // Например, шлём уведомление в UI, чтобы бабл стал прозрачным и появилась корзина.

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .init("TeleFlowAntiDeleteDidMarkMessages"),
                object: nil,
                userInfo: [
                    "accountId": account.id,
                    "messageIds": messageIds,
                ]
            )
        }
    }
}
