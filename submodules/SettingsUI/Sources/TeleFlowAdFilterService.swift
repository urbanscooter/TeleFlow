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
        if let _ = message.attributes.first(where: { attr in
            attr is AdMessageAttribute
        }) {
            return true
        }

        // Также проверяем по источнику — спонсированные приходят от AdsManager.
        // В TelegramAPI sponsored messages имеют `flags` с признаком рекламы.
        // Проверяем наличие флага исходящего (sponsored messages обычно Outgoing или с флагом).
        if message.flags.contains(.Outgoing) && message.id.namespace == Namespaces.Message.Cloud {
            // В TelegramCore sponsored messages имеют специфический namespace или атрибут.
            // Это эвристика — дополнительная проверка через timestamp.
            if message.timestamp == Int32.max - 1 {
                return true
            }
        }

        return false
    }

    /// Проверяет, нужно ли скрыть конкретный объект `SponsoredMessage` перед рендером.
    /// Используется в точке, где Telegram получает sponsored messages из API.
    public func shouldHideSponsoredMessage(_ messageId: MessageId, peerId: PeerId) -> Bool {
        guard TeleFlowSettings.shared.isHideAdsEnabled else {
            return false
        }
        // Дополнительная логика: скрывать на основе peerId и messageId.
        // В реальности это определяется по namespace/id pattern.
        return true
    }
}
