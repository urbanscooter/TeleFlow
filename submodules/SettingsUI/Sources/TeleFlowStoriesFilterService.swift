import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext

/// Сервис скрытия бара Stories.
///
/// Когда `TeleFlowSettings.shared.isHideStoriesEnabled == true`, возвращает высоту
/// контейнера историй равной `0` и отключает рендеринг Stories bar над списком чатов.
/// Подключается в компонентах `ChatListHeaderComponent` и `PeerInfoScreen`.
public final class TeleFlowStoriesFilterService {

    public static let shared = TeleFlowStoriesFilterService()

    private init() {}

    /// Высота бара Stories, используемая при включённом режиме скрытия.
    public static let hiddenHeight: CGFloat = 0.0

    /// Стандартная высота бара Stories (если бы мы знали точное значение).
    /// В Telegram Stories bar обычно ~56–64 pt.
    public static let defaultStoriesBarHeight: CGFloat = 56.0

    /// Возвращает высоту контейнера Stories для layout-а.
    /// - Parameter currentHeight: Текущая запрошенная высота Stories bar.
    /// - Returns: `0` если режим скрытия включён, иначе `currentHeight`.
    public func storiesContainerHeight(currentHeight: CGFloat) -> CGFloat {
        guard TeleFlowSettings.shared.isHideStoriesEnabled else {
            return currentHeight
        }
        return Self.hiddenHeight
    }

    /// Определяет, нужно ли показывать Stories bar.
    /// - Parameter isVisible: Текущее состояние видимости.
    /// - Returns: `false` если режим скрытия включён, иначе исходное `isVisible`.
    public func shouldShowStories(isVisible: Bool) -> Bool {
        guard TeleFlowSettings.shared.isHideStoriesEnabled else {
            return isVisible
        }
        return false
    }

    /// Проверяет, скрыты ли Stories в данный момент.
    public var isHidden: Bool {
        return TeleFlowSettings.shared.isHideStoriesEnabled
    }

    /// Подписка на изменения настроек Stories-фильтра.
    /// Используется для обновления UI при переключении тумблера.
    public var didChange: Signal<Void, NoError> {
        return Signal { subscriber in
            let token = NotificationCenter.default.addObserver(
                forName: TeleFlowSettings.didChangeNotification,
                object: nil,
                queue: .main
            ) { _ in
                subscriber.putNext(())
            }
            return ActionDisposable {
                NotificationCenter.default.removeObserver(token)
            }
        }
    }

    /// Обновляет layoutStoriesBar с учётом режима скрытия.
    ///
    /// Вызывается в `updateLayout` компонента `ChatListHeaderComponent`.
    /// - Parameter containerHeight: Текущая высота контейнера.
    /// - Returns: Скорректированная высота (0 если скрыто).
    public func adjustedContainerHeight(containerHeight: CGFloat) -> CGFloat {
        guard TeleFlowSettings.shared.isHideStoriesEnabled else {
            return containerHeight
        }
        return Self.hiddenHeight
    }
}
