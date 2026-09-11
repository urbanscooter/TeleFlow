import Foundation
import Postbox
import TelegramCore

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
