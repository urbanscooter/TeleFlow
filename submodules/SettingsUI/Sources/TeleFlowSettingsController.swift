import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext

private final class TeleFlowSettingsControllerArguments {
    let toggleAntiDelete: (Bool) -> Void
    let toggleGrayOut: (Bool) -> Void
    let toggleTrashIcon: (Bool) -> Void
    let updateOpacity: (Int32) -> Void
    let toggleHideAds: (Bool) -> Void
    let toggleHideStories: (Bool) -> Void

    init(
        toggleAntiDelete: @escaping (Bool) -> Void,
        toggleGrayOut: @escaping (Bool) -> Void,
        toggleTrashIcon: @escaping (Bool) -> Void,
        updateOpacity: @escaping (Int32) -> Void,
        toggleHideAds: @escaping (Bool) -> Void,
        toggleHideStories: @escaping (Bool) -> Void
    ) {
        self.toggleAntiDelete = toggleAntiDelete
        self.toggleGrayOut = toggleGrayOut
        self.toggleTrashIcon = toggleTrashIcon
        self.updateOpacity = updateOpacity
        self.toggleHideAds = toggleHideAds
        self.toggleHideStories = toggleHideStories
    }
}

private enum TeleFlowSettingsSection: Int32 {
    case antiDelete
    case antiDeleteOptions
    case other
}

private enum TeleFlowSettingsEntry: ItemListNodeEntry {
    case antiDeleteHeader(String)
    case antiDelete(String, String, Bool)
    case antiDeleteInfo(String)

    case optionsHeader(String)
    case grayOut(String, String, Bool)
    case opacity(String, Int32, Int32, Int32)
    case opacityInfo(String)
    case trashIcon(String, String, Bool)

    case otherHeader(String)
    case hideAds(String, String, Bool)
    case hideAdsInfo(String)
    case hideStories(String, String, Bool)
    case hideStoriesInfo(String)

    var section: ItemListSectionId {
        switch self {
        case .antiDeleteHeader, .antiDelete, .antiDeleteInfo:
            return TeleFlowSettingsSection.antiDelete.rawValue
        case .optionsHeader, .grayOut, .opacity, .opacityInfo, .trashIcon:
            return TeleFlowSettingsSection.antiDeleteOptions.rawValue
        case .otherHeader, .hideAds, .hideAdsInfo, .hideStories, .hideStoriesInfo:
            return TeleFlowSettingsSection.other.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .antiDeleteHeader: return 0
        case .antiDelete: return 1
        case .antiDeleteInfo: return 2
        case .optionsHeader: return 10
        case .grayOut: return 11
        case .opacity: return 12
        case .opacityInfo: return 13
        case .trashIcon: return 14
        case .otherHeader: return 20
        case .hideAds: return 21
        case .hideAdsInfo: return 22
        case .hideStories: return 23
        case .hideStoriesInfo: return 24
        }
    }

    static func ==(lhs: TeleFlowSettingsEntry, rhs: TeleFlowSettingsEntry) -> Bool {
        switch lhs {
        case let .antiDeleteHeader(l): if case let .antiDeleteHeader(r) = rhs { return l == r }; return false
        case let .antiDelete(lt, ls, lv): if case let .antiDelete(rt, rs, rv) = rhs { return lt == rt && ls == rs && lv == rv }; return false
        case let .antiDeleteInfo(l): if case let .antiDeleteInfo(r) = rhs { return l == r }; return false
        case let .optionsHeader(l): if case let .optionsHeader(r) = rhs { return l == r }; return false
        case let .grayOut(lt, ls, lv): if case let .grayOut(rt, rs, rv) = rhs { return lt == rt && ls == rs && lv == rv }; return false
        case let .opacity(lt, lv, lmin, lmax): if case let .opacity(rt, rv, rmin, rmax) = rhs { return lt == rt && lv == rv && lmin == rmin && lmax == rmax }; return false
        case let .opacityInfo(l): if case let .opacityInfo(r) = rhs { return l == r }; return false
        case let .trashIcon(lt, ls, lv): if case let .trashIcon(rt, rs, rv) = rhs { return lt == rt && ls == rs && lv == rv }; return false
        case let .otherHeader(l): if case let .otherHeader(r) = rhs { return l == r }; return false
        case let .hideAds(lt, ls, lv): if case let .hideAds(rt, rs, rv) = rhs { return lt == rt && ls == rs && lv == rv }; return false
        case let .hideAdsInfo(l): if case let .hideAdsInfo(r) = rhs { return l == r }; return false
        case let .hideStories(lt, ls, lv): if case let .hideStories(rt, rs, rv) = rhs { return lt == rt && ls == rs && lv == rv }; return false
        case let .hideStoriesInfo(l): if case let .hideStoriesInfo(r) = rhs { return l == r }; return false
        }
    }

    static func <(lhs: TeleFlowSettingsEntry, rhs: TeleFlowSettingsEntry) -> Bool {
        lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let a = arguments as! TeleFlowSettingsControllerArguments
        switch self {
        case let .antiDeleteHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)

        case let .antiDelete(title, subtitle, value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: title,
                text: subtitle,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { v in a.toggleAntiDelete(v) }
            )

        case let .antiDeleteInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)

        case let .optionsHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)

        case let .grayOut(title, subtitle, value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: title,
                text: subtitle,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { v in a.toggleGrayOut(v) }
            )

        case let .opacity(title, value, min, max):
            return ItemListSliderItem(
                presentationData: presentationData,
                title: title,
                value: value,
                minValue: min,
                maxValue: max,
                sectionId: self.section,
                style: .blocks,
                updated: { v in a.updateOpacity(v) }
            )

        case let .opacityInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)

        case let .trashIcon(title, subtitle, value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: title,
                text: subtitle,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { v in a.toggleTrashIcon(v) }
            )

        case let .otherHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)

        case let .hideAds(title, subtitle, value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: title,
                text: subtitle,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { v in a.toggleHideAds(v) }
            )

        case let .hideAdsInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)

        case let .hideStories(title, subtitle, value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: title,
                text: subtitle,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { v in a.toggleHideStories(v) }
            )

        case let .hideStoriesInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct TeleFlowSettingsState: Equatable {
    var isAntiDeleteEnabled: Bool
    var isGrayOutDeletedEnabled: Bool
    var isShowTrashIconEnabled: Bool
    var deletedOpacity: Double
    var isHideAdsEnabled: Bool
    var isHideStoriesEnabled: Bool
}

private func teleFlowSettingsEntries(
    state: TeleFlowSettingsState,
    presentationData: ItemListPresentationData
) -> [TeleFlowSettingsEntry] {
    var entries: [TeleFlowSettingsEntry] = []

    entries.append(.antiDeleteHeader("Анти-удаление"))
    entries.append(.antiDelete(
        "Включить анти-удаление",
        "Сохраняет сообщения, даже если собеседник удалил их для всех",
        state.isAntiDeleteEnabled))
    entries.append(.antiDeleteInfo("Удалённое сообщение останется в чате с пометкой"))

    if state.isAntiDeleteEnabled {
        entries.append(.optionsHeader("Отображение удалённых"))

        entries.append(.grayOut(
            "Приглушать удалённые",
            "Понижать непрозрачность удалённых сообщений",
            state.isGrayOutDeletedEnabled))

        entries.append(.opacity(
            "Непрозрачность",
            Int32(state.deletedOpacity * 100.0),
            10,
            100))
        entries.append(.opacityInfo("10% — почти прозрачно, 100% — без изменений"))

        entries.append(.trashIcon(
            "Иконка корзины",
            "Показывать корзину возле времени у удалённых сообщений",
            state.isShowTrashIconEnabled))
    }

    entries.append(.otherHeader("Прочее"))
    entries.append(.hideAds(
        "Скрыть рекламу",
        "Убирает спонсированные публикации в публичных каналах",
        state.isHideAdsEnabled))
    entries.append(.hideAdsInfo("Рекламные посты не будут отображаться в ленте"))

    entries.append(.hideStories(
        "Скрыть истории",
        "Скрывает верхний бар Stories над списком чатов",
        state.isHideStoriesEnabled))
    entries.append(.hideStoriesInfo("Панель Stories будет скрыта во всех чатах и профилях"))

    return entries
}

public func makeTeleFlowSettingsController(context: AccountContext) -> ViewController {
    let stateValue = Atomic<TeleFlowSettingsState>(value: TeleFlowSettingsState(
        isAntiDeleteEnabled: TeleFlowSettings.shared.isAntiDeleteEnabled,
        isGrayOutDeletedEnabled: TeleFlowSettings.shared.isGrayOutDeletedEnabled,
        isShowTrashIconEnabled: TeleFlowSettings.shared.isShowTrashIconEnabled,
        deletedOpacity: TeleFlowSettings.shared.deletedOpacity,
        isHideAdsEnabled: TeleFlowSettings.shared.isHideAdsEnabled,
        isHideStoriesEnabled: TeleFlowSettings.shared.isHideStoriesEnabled
    ))
    let statePromise: ValuePromise<TeleFlowSettingsState> = ValuePromise(ignoreRepeated: true)
    statePromise.set(stateValue.with { $0 })

    let updateState: ((TeleFlowSettingsState) -> TeleFlowSettingsState) -> Void = { f in
        let result = stateValue.modify { f($0) }
        statePromise.set(result)
    }

    let arguments = TeleFlowSettingsControllerArguments(
        toggleAntiDelete: { newValue in
            TeleFlowSettings.shared.isAntiDeleteEnabled = newValue
            TeleFlowAntiDeleteService.shared.updateSettings(isEnabled: newValue)
            updateState { s in var s = s; s.isAntiDeleteEnabled = newValue; return s }
        },
        toggleGrayOut: { newValue in
            TeleFlowSettings.shared.isGrayOutDeletedEnabled = newValue
            updateState { s in var s = s; s.isGrayOutDeletedEnabled = newValue; return s }
        },
        toggleTrashIcon: { newValue in
            TeleFlowSettings.shared.isShowTrashIconEnabled = newValue
            updateState { s in var s = s; s.isShowTrashIconEnabled = newValue; return s }
        },
        updateOpacity: { newValue in
            let opacity = Double(newValue) / 100.0
            TeleFlowSettings.shared.deletedOpacity = opacity
            updateState { s in var s = s; s.deletedOpacity = opacity; return s }
        },
        toggleHideAds: { newValue in
            TeleFlowSettings.shared.isHideAdsEnabled = newValue
            updateState { s in var s = s; s.isHideAdsEnabled = newValue; return s }
        },
        toggleHideStories: { newValue in
            TeleFlowSettings.shared.isHideStoriesEnabled = newValue
            updateState { s in var s = s; s.isHideStoriesEnabled = newValue; return s }
        }
    )

    let signal: Signal<(ItemListControllerState, (ItemListNodeState, TeleFlowSettingsControllerArguments)), NoError> = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get()
    )
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, TeleFlowSettingsControllerArguments)) in
        let itemListPresentationData = ItemListPresentationData(presentationData)
        let entries = teleFlowSettingsEntries(state: state, presentationData: itemListPresentationData)

        let controllerState = ItemListControllerState(
            presentationData: itemListPresentationData,
            title: .text("TeleFlow"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: true
        )
        let listState = ItemListNodeState(
            presentationData: itemListPresentationData,
            entries: entries,
            style: .blocks,
            ensureVisibleItemTag: nil
        )

        return (controllerState, (listState, arguments))
    }

    let controller: ItemListController = ItemListController(context: context, state: signal)
    return controller
}
