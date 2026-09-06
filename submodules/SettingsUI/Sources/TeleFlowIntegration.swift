// MARK: - ТОЧКИ ВСТАВКИ ДЛЯ TELEFLOW
// ================================================================
//
// Этот файл документирует все точки, куда необходимо внести изменения
// для интеграции TeleFlow-модуля в основной код приложения.
//
// Рекомендуемый порядок интеграции:
// 1. Добавить TeleFlowSettingsController.swift и TeleFlowSettings.swift
//    в Bazel BUILD-файл подмодуля SettingsUI (TeleFlowSources)
// 2. Добавить вызов makeTeleFlowController в меню главных настроек
// 3. Инициализировать TeleFlowAntiDeleteService при запуске приложения
// 4. Подключить TeleFlowAdFilterService в цепочку получения сообщений
// 5. Подключить TeleFlowStoriesFilterService в ChatListHeaderComponent
//
// ================================================================

import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import AccountContext
import ItemListUI
import PresentationDataUtils

// ================================================================
// ИНТЕГРАЦИЯ #1: Пункт меню «TeleFlow» в главном экране настроек
// ================================================================
//
// ТОЧКА ВСТАВКИ: Файл PrivacyAndSecurityController.swift (или аналогичный
// корневой контроллер настроек), в методе создания entries.
//
// В enum PrivacyAndSecurityEntry добавить новую и case:
//
private enum PrivacyAndSecurityEntry: ItemListNodeEntry {
    // ... существующие кейсы ...

    case teleFlow(PresentationTheme, String, String) // title, subtitle, isEnabledValue

    // ... остальное ...
}

// В func item(presentationData:arguments:) добавить:
//
case let .teleFlow(_, title, subtitle, isEnabled):
    return ItemListDisclosureItem(
        presentationData: presentationData,
        systemStyle: .glass,
        title: title,
        subtitle: subtitle,
        sectionId: self.section,
        style: .blocks,
        action: {
            arguments.openTeleFlowSettings?()
        }
    )
//
// В инициализатор PrivacyAndSecurityControllerArguments добавить:
//
let openTeleFlowSettings: () -> Void
//
// И в init:
// self.openTeleFlowSettings = { [weak self] in
//     let controller = makeTeleFlowSettingsController(context: self!.context)
//     self?.navigationController?.pushViewController(controller, animated: true)
// }
//
//
// Точка вызова в приватной функции создания entries:
//
let teleFlowEntry = .teleFlow(theme, "TeleFlow", "Пункт меню TeleFlow Settings", true)
// Добавить в массив entries перед возвратом:
// entries.append(teleFlowEntry)

// ================================================================
// ИНТЕГРАЦИЯ #2: Инициализация сервисов при запуске приложения
// ================================================================
//
// ТОЧКА ВСТАВКИ: Telegram/Telegram-iOS/Application.swift (или AppDelegate).
//
// В метод `didFinishLaunchingWithOptions` добавить:
//
// // TeleFlow инициализация
// _ = TeleFlowAntiDeleteService.shared  // перехват DeleteMessages
// _ = TeleFlowAdFilterService.shared    // фильтр SponsoredMessage
// _ = TeleFlowStoriesFilterService.shared  // скрытие Stories bar
//
// Пример:
//
// @UIApplicationMain
// class Application: UIApplication {
//     override func didFinishLaunching(_ options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
//         // TeleFlow modules init
//         _ = TeleFlowAntiDeleteService.shared
//         _ = TeleFlowAdFilterService.shared
//         _ = TeleFlowStoriesFilterService.shared
//
//         // ... остальной код
//         return true
//     }
// }
//
//
// ================================================================
// ИНТЕГРАЦИЯ #3: Перехват DeleteMessages в ChatController
// ================================================================
//
// ТОЧКА ВСТАВКИ: Файл подмодуля TelegramUI/ChatController.swift (там где
// обрабатывается удаление сообщений). Найти:
// `context.account.postbox.transaction { transaction in ... message.delete() }`
//
// Обернуть в TeleFlow-проверку:
//
// if TeleFlowSettings.shared.isAntiDeleteEnabled {
//     let _ = TeleFlowAntiDeleteService.shared.handleDeleteMessages(
//         messageIds: [messageId],
//         context: context
//     ).start()
// } else {
//     // стандартное удаление
//     transaction.deleteMessage(messageId, permanent: false)
// }
//
// ================================================================
// ИНТЕГРАЦИЯ #4: Фильтрация SponsoredMessage — уровень потребителя сигналов
// ================================================================
//
// Рекомендованный способ: фильтрация на уровне потребителя сигнала
// `AdMessagesHistoryContext.state` (в TelegramUI), чтобы не создавать
// циклическую зависимость TelegramCore → SettingsUI.
//
// ТОЧКА ВСТАВКИ: Consumer `AdMessagesHistoryContext.state`
// (например, в ChatInterface/AdMessagesPresenter или аналогичном слое TelegramUI).
//
// let filteredSignal = context.adMessagesContext.state
//     |> map { interPostInterval, messages, startDelay, betweenDelay -> (Int32?, [Message], Int32?, Int32?) in
//         let filtered = TeleFlowAdFilterService.shared.filterSponsoredMessages(messages)
//         return (interPostInterval, filtered, startDelay, betweenDelay)
//     }
//
// АЛЬТЕРНАТИВНО (прямой патч): в AdMessagesHistoryContextImpl.activate()
// (файл AdMessages.swift, строка ~573), после построения parsedMessages:
//
// let filteredMessages = TeleFlowAdFilterService.shared.filterSponsoredMessages(parsedMessages)
// return (postsBetween, startDelay, betweenDelay, filteredMessages.compactMap { message -> Message? in
//     return message.toMessage(peerId: peerId, transaction: transaction)
// })
// (Этот патч требует, чтобы TeleFlowAdFilterService был доступен из TelegramCore —
// разместите его в отдельном TeleFlowCore или применяйте на уровне потребителя.)
//
//
// ================================================================
// ИНТЕГРАЦИЯ #5: Скрытие Stories bar в ChatListHeaderComponent
// ================================================================
//
// ТОЧКА ВСТАВКИ: Файл ChatListHeaderComponent.swift, метод updateLayout или
// containerHeightForSection.
//
// Использовать TeleFlowStoriesFilterService:
//
// let storiesHeight = TeleFlowStoriesFilterService.shared.storiesContainerHeight(
//     currentHeight: originalHeight
// )
// return storiesHeight
//
// Или для видимости:
//
// if TeleFlowStoriesFilterService.shared.shouldShowStories(isVisible: true) {
//     // отрисовать Stories bar
// }
//
//
// ================================================================
// ИНТЕГРАЦИЯ #6: Bazel BUILD обновление
// ================================================================
//
// ТОЧКА ВСТАВКИ: submodules/SettingsUI/BUILD
//
// Добавить в teleflow_sources или srcs:
//
// srcs = [
//     "Sources/TeleFlowSettings.swift",
//     "Sources/TeleFlowSettingsController.swift",
//     "Sources/TeleFlowAntiDeleteService.swift",
//     "Sources/TeleFlowAdFilterService.swift",
//     "Sources/TeleFlowStoriesFilterService.swift",
//     "Sources/TeleFlowIntegration.swift",
// ],
//
// И обновить зависимость в BUILD.bazel target'а, добавив:
// deps = [
//     ":teleflow_settings", // и т.д.
// ],

// ================================================================
// ДОПОЛНИТЕЛЬНО: Функция для создания TeleFlow контроллера
// ================================================================
//
// Можно использовать из любого места:
//
// public func makeTeleFlowController(context: AccountContext) -> ViewController {
//     return TeleFlowSettingsController(context: context)
// }
//
// Или фабричная функция (уже реализована в TeleFlowSettingsController.swift):
// makeTeleFlowSettingsController(context:)

// ================================================================

public final class TeleFlowIntegration {}

// MARK: - Строки для локализации (добавить в Settings.strings или соответствующие файлы)

// title: "TeleFlow"
// subtitle для anti-delete: "Сохраняет входящие сообщения, даже если собеседник удалил их для всех"
// subtitle для hide-ads: "Убирает спонсированные публикации в публичных каналах"
// subtitle для hide-stories: "Скрывает верхний бар Stories над списком чатов и в профилях"

// Если используется собственные строки локализации, их нужно добавить в:
// Telegram/Telegram-iOS/Localization/{lang}.lproj/Settings.strings
// или файл strings, где хранятся прочие настройки.