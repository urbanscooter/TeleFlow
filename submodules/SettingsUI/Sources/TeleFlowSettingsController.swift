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

// MARK: - Arguments

private final class TeleFlowSettingsControllerArguments {
    let toggleAntiDelete: (Bool) -> Void
    let toggleHideAds: (Bool) -> Void
    let toggleHideStories: (Bool) -> Void

    init(
        toggleAntiDelete: @escaping (Bool) -> Void,
        toggleHideAds: @escaping (Bool) -> Void,
        toggleHideStories: @escaping (Bool) -> Void
    ) {
        self.toggleAntiDelete = toggleAntiDelete
        self.toggleHideAds = toggleHideAds
        self.toggleHideStories = toggleHideStories
    }
}

// MARK: - Sections

private enum TeleFlowSettingsSection: Int32 {
    case features
}

// MARK: - Entries

private enum TeleFlowSettingsEntry: ItemListNodeEntry {
    case sectionHeader(String)
    case antiDelete(String, String, Bool)
    case antiDeleteInfo(String)
    case hideAds(String, String, Bool)
    case hideAdsInfo(String)
    case hideStories(String, String, Bool)
    case hideStoriesInfo(String)

    var section: ItemListSectionId {
        switch self {
        case .sectionHeader, .antiDelete, .antiDeleteInfo, .hideAds, .hideAdsInfo, .hideStories, .hideStoriesInfo:
            return TeleFlowSettingsSection.features.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .sectionHeader: return 0
        case .antiDelete: return 1
        case .antiDeleteInfo: return 2
        case .hideAds: return 3
        case .hideAdsInfo: return 4
        case .hideStories: return 5
        case .hideStoriesInfo: return 6
        }
    }

    static func ==(lhs: TeleFlowSettingsEntry, rhs: TeleFlowSettingsEntry) -> Bool {
        switch lhs {
        case let .sectionHeader(lhsText):
            if case let .sectionHeader(rhsText) = rhs { return lhsText == rhsText } else { return false }
        case let .antiDelete(lhsTitle, lhsSubtitle, lhsValue):
            if case let .antiDelete(rhsTitle, rhsSubtitle, rhsValue) = rhs {
                return lhsTitle == rhsTitle && lhsSubtitle == rhsSubtitle && lhsValue == rhsValue
            }
            return false
        case let .antiDeleteInfo(lhsText):
            if case let .antiDeleteInfo(rhsText) = rhs { return lhsText == rhsText } else { return false }
        case let .hideAds(lhsTitle, lhsSubtitle, lhsValue):
            if case let .hideAds(rhsTitle, rhsSubtitle, rhsValue) = rhs {
                return lhsTitle == rhsTitle && lhsSubtitle == rhsSubtitle && lhsValue == rhsValue
            }
            return false
        case let .hideAdsInfo(lhsText):
            if case let .hideAdsInfo(rhsText) = rhs { return lhsText == rhsText } else { return false }
        case let .hideStories(lhsTitle, lhsSubtitle, lhsValue):
            if case let .hideStories(rhsTitle, rhsSubtitle, rhsValue) = rhs {
                return lhsTitle == rhsTitle && lhsSubtitle == rhsSubtitle && lhsValue == rhsValue
            }
            return false
        case let .hideStoriesInfo(lhsText):
            if case let .hideStoriesInfo(rhsText) = rhs { return lhsText == rhsText } else { return false }
        }
    }

    static func <(lhs: TeleFlowSettingsEntry, rhs: TeleFlowSettingsEntry) -> Bool {
        lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! TeleFlowSettingsControllerArguments
        switch self {
        case let .sectionHeader(text):
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
                updated: { newValue in arguments.toggleAntiDelete(newValue) }
            )

        case let .antiDeleteInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)

        case let .hideAds(title, subtitle, value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: title,
                text: subtitle,
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { newValue in arguments.toggleHideAds(newValue) }
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
                updated: { newValue in arguments.toggleHideStories(newValue) }
            )

        case let .hideStoriesInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

// MARK: - State

private struct TeleFlowSettingsState: Equatable {
    var isAntiDeleteEnabled: Bool
    var isHideAdsEnabled: Bool
    var isHideStoriesEnabled: Bool
}

// MARK: - Factory

public func makeTeleFlowSettingsController(context: AccountContext) -> ViewController {
    var controller: ItemListController?

    let stateValue = Atomic<TeleFlowSettingsState>(value: TeleFlowSettingsState(
        isAntiDeleteEnabled: TeleFlowSettings.shared.isAntiDeleteEnabled,
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
            updateState { s in TeleFlowSettingsState(isAntiDeleteEnabled: newValue, isHideAdsEnabled: s.isHideAdsEnabled, isHideStoriesEnabled: s.isHideStoriesEnabled) }
        },
        toggleHideAds: { newValue in
            TeleFlowSettings.shared.isHideAdsEnabled = newValue
            updateState { s in TeleFlowSettingsState(isAntiDeleteEnabled: s.isAntiDeleteEnabled, isHideAdsEnabled: newValue, isHideStoriesEnabled: s.isHideStoriesEnabled) }
        },
        toggleHideStories: { newValue in
            TeleFlowSettings.shared.isHideStoriesEnabled = newValue
            updateState { s in TeleFlowSettingsState(isAntiDeleteEnabled: s.isAntiDeleteEnabled, isHideAdsEnabled: s.isHideAdsEnabled, isHideStoriesEnabled: newValue) }
        }
    )

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get()
    )
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let entries = teleFlowSettingsEntries(state: state, presentationData: presentationData)

        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("TeleFlow"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: true
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            ensureVisibleItemTag: nil
        )

        return (controllerState, (listState, arguments))
    }

    controller = ItemListController(context: context, state: signal)
    return controller!
}
