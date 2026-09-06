import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore
import AccountContext

/// Сервис скрытия рекламных сообщений.
///
/// Фильтрует массив сообщений в ленте канала, удаляя объекты `SponsoredMessage`,
/// когда `TeleFlowSettings.shared.isHideAdsEnabled == true`.
/// Подключается в точке получения спонсорских сообщений (AdMessagesHistoryContext).
public final class TeleFlowAdFilterService {

    public static let shared = TeleFlowAdFilterService()

    private init() {}

    /// Фильтрует массив сообщений, убирая спонсированные (SponsoredMessage).
    /// Вызывается перед отрисовкой в ленте канала.
    ///
    /// - Parameter messages: Список сообщений, полученных из AdMessagesHistoryContext.
    /// - Returns: Очищенный массив без SponsoredMessage (если режим включён).
    public func filterSponsoredMessages(_ messages: [Message]) -> [Message] {
        guard TeleFlowSettings.shared.isHideAdsEnabled else {
            return messages
        }

        return messages.filter { message in
            !isSponsoredMessage(message)
        }
    }

    /// Определяет, является ли сообщение спонсированным (рекламным).
    private func isSponsoredMessage(_ message: Message) -> Bool {
        // Спонсированные сообщения имеют специальный атрибут AdMessageAttribute.
        // Это единственный надёжный способ определения sponsored messages в TelegramCore.
        if message.attributes.first(where: { $0 is AdMessageAttribute }) != nil {
            return true
        }
        return false
    }

    /// Проверяет, нужно ли скрыть конкретный объект `SponsoredMessage` перед рендером.
    /// Используется в точке, где Telegram получает sponsored messages из API.
    public func shouldHideSponsoredMessage(_ messageId: MessageId, peerId: PeerId) -> Bool {
        guard TeleFlowSettings.shared.isHideAdsEnabled else {
            return false
        }
        return true
    }
}
