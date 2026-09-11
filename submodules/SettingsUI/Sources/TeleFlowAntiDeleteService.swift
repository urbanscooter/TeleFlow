import Foundation
import UIKit
import Postbox
import SwiftSignalKit

// MARK: - Attribute (встроен, не требует declareEncodable в Coding.swift)

public final class TeleFlowDeletedAttribute: MessageAttribute {
    public let deletedAt: Int32
    public let originalAuthorName: String?

    public init(deletedAt: Int32, originalAuthorName: String?) {
        self.deletedAt = deletedAt
        self.originalAuthorName = originalAuthorName
    }

    public init(decoder: PostboxDecoder) {
        self.deletedAt = decoder.decodeInt32ForKey("d", orElse: 0)
        self.originalAuthorName = decoder.decodeOptionalStringForKey("a")
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.deletedAt, forKey: "d")
        if let n = self.originalAuthorName {
            encoder.encodeString(n, forKey: "a")
        } else {
            encoder.encodeNil(forKey: "a")
        }
    }

    public var associatedPeerIds: [PeerId] { return [] }
    public var associatedMessageIds: [MessageId] { return [] }
}

public extension Message {
    var teleFlowIsDeleted: Bool {
        return self.attributes.contains(where: { $0 is TeleFlowDeletedAttribute })
    }
}

public extension EngineMessage {
    var teleFlowIsDeleted: Bool {
        return (self._asMessage()).teleFlowIsDeleted
    }
}

// MARK: - Service

public final class TeleFlowAntiDeleteService {
    public static let shared = TeleFlowAntiDeleteService()
    public static let deletionMarkerText: String = "Удалено"
    public static let accountReadyNotification = Notification.Name("TeleFlowAntiDeleteService.accountReady")

    private static let suiteName = "group.ph.telegra.TeleFlow"
    private let trashNodeName = "tfTrashNode"

    private let queue = Queue()
    private var refreshTimer: SwiftSignalKit.Timer?

    private init() {
        // Шаг 2: регистрация атрибута в Postbox — один раз при инициализации.
        declareEncodable(TeleFlowDeletedAttribute.self, 0x7a3e0001)

        // Периодический обход видимых баблов (раз в секунду).
        self.refreshTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
            self?.refreshUI()
        }, queue: .mainQueue())
        self.refreshTimer?.start()

        // Реагируем на смену настроек мгновенно.
        NotificationCenter.default.addObserver(
            forName: Notification.Name("TeleFlowSettingsDidChange"),
            object: nil,
            queue: .main,
            using: { [weak self] _ in self?.refreshUI() }
        )
    }

    // MARK: - Settings reading (напрямую из UserDefaults, без зависимостей)

    private var isAntiDeleteEnabled: Bool {
        return UserDefaults(suiteName: Self.suiteName)?.bool(forKey: "isAntiDeleteEnabled") ?? false
    }

    private var isGrayOutEnabled: Bool {
        if UserDefaults(suiteName: Self.suiteName)?.object(forKey: "isGrayOutDeletedEnabled") == nil { return true }
        return UserDefaults(suiteName: Self.suiteName)?.bool(forKey: "isGrayOutDeletedEnabled") ?? true
    }

    private var isShowTrashEnabled: Bool {
        if UserDefaults(suiteName: Self.suiteName)?.object(forKey: "isShowTrashIconEnabled") == nil { return true }
        return UserDefaults(suiteName: Self.suiteName)?.bool(forKey: "isShowTrashIconEnabled") ?? true
    }

    private var deletedOpacity: Double {
        if UserDefaults(suiteName: Self.suiteName)?.object(forKey: "deletedOpacity") == nil { return 0.55 }
        let v = UserDefaults(suiteName: Self.suiteName)?.double(forKey: "deletedOpacity") ?? 0.55
        return min(1.0, max(0.1, v))
    }

    // MARK: - Delete hook (Шаг 1: вызывать ПЕРЕД transaction.removeMessage)

    public func handleIncomingMessageDeletions(account: Account, messageIds: [MessageId]) {
        guard !messageIds.isEmpty, self.isAntiDeleteEnabled else { return }
        let _ = (account.postbox.transaction { transaction -> Void in
            for messageId in messageIds {
                guard let message = transaction.getMessage(messageId) else { continue }
                if message.attributes.contains(where: { $0 is TeleFlowDeletedAttribute }) { continue }
                var attrs = message.attributes
                attrs.append(TeleFlowDeletedAttribute(
                    deletedAt: Int32(Date().timeIntervalSince1970),
                    originalAuthorName: nil
                ))
                transaction.updateMessage(messageId, update: { current in
                    var u = current
                    u.attributes = attrs
                    return u
                })
            }
        }).start(next: { [weak self] _ in
            Queue.mainQueue().async { self?.refreshUI() }
        })
    }

    public func notifyAccountReady(account: Account) {
        NotificationCenter.default.post(
            name: TeleFlowAntiDeleteService.accountReadyNotification,
            object: nil,
            userInfo: ["account": account]
        )
    }

    // MARK: - UI refresh

    private func refreshUI() {
        let enabled = self.isAntiDeleteEnabled
        self.walkBubbles { [weak self] bubble in
            guard let self else { return }
            let deleted = enabled && self.bubbleTeleFlowDeleted(bubble)
            self.apply(bubble: bubble, deleted: deleted)
        }
    }

    private func walkBubbles(_ action: @escaping (ASDisplayNode) -> Void) {
        for window in UIApplication.shared.windows {
            self.walkView(window, action)
        }
    }

    private func walkView(_ view: UIView, _ action: @escaping (ASDisplayNode) -> Void) {
        if let node = view.asyncdisplaykit_node {
            let className = String(describing: type(of: node))
            if className.contains("ChatMessageBubbleItemNode") {
                action(node)
            }
        }
        for sub in view.subviews {
            self.walkView(sub, action)
        }
    }

    private func bubbleTeleFlowDeleted(_ bubble: ASDisplayNode) -> Bool {
        guard let itemAny = bubble.value(forKey: "item") else { return false }
        guard let messageAny = (itemAny as AnyObject).value(forKey: "message") else { return false }
        guard let message = messageAny as? Message else { return false }
        return message.teleFlowIsDeleted
    }

    private func apply(bubble: ASDisplayNode, deleted: Bool) {
        // alpha
        let newAlpha: CGFloat = (deleted && self.isGrayOutEnabled)
            ? CGFloat(self.deletedOpacity)
            : 1.0
        if abs(bubble.alpha - newAlpha) > 0.001 {
            bubble.alpha = newAlpha
        }

        // корзина (SF Symbol, без ресурсов)
        var trash: ASImageNode? = bubble.subnodes?.first(where: { $0.name == self.trashNodeName }) as? ASImageNode
        if trash == nil {
            let node = ASImageNode()
            node.name = self.trashNodeName
            node.displaysAsynchronously = false
            node.isUserInteractionEnabled = false
            node.image = UIImage(systemName: "trash")?.withTintColor(.gray, renderingMode: .alwaysOriginal)
            bubble.addSubnode(node)
            trash = node
        }
        guard let trashNode = trash else { return }

        let shouldShow = deleted && self.isShowTrashEnabled
        trashNode.isHidden = !shouldShow
        if shouldShow {
            let size = CGSize(width: 12, height: 12)
            let b = bubble.bounds
            trashNode.frame = CGRect(
                x: b.width - size.width - 6,
                y: b.height - size.height - 4,
                width: size.width,
                height: size.height
            )
        }
    }
}
