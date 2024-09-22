//
// Copyright 2022-2024 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE in the repository root for full details.
//

import UIKit

struct NoticeRoomTimelineItem: TextBasedRoomTimelineItem, Equatable {
    let id: TimelineItemIdentifier
    let timestamp: String
    let isOutgoing: Bool
    let isEditable: Bool
    let canBeRepliedTo: Bool
    let isThreaded: Bool
    
    let sender: TimelineItemSender
    
    let content: NoticeRoomTimelineItemContent

    var debugInfo: String?
    
    var replyDetails: TimelineItemReplyDetails?
    
    var properties: RoomTimelineItemProperties
    
    var body: String {
        content.body
    }
    
    var contentType: EventBasedMessageTimelineItemContentType {
        .notice(content)
    }

    // Compute the noticeContentType in the initializer
    var noticeContentType: NoticeCategoryType
    
    init(id: TimelineItemIdentifier, timestamp: String, isOutgoing: Bool, isEditable: Bool, canBeRepliedTo: Bool, isThreaded: Bool, sender: TimelineItemSender, content: NoticeRoomTimelineItemContent, debugInfo: String? = nil, replyDetails: TimelineItemReplyDetails? = nil, properties: RoomTimelineItemProperties = RoomTimelineItemProperties()) {
        self.id = id
        self.timestamp = timestamp
        self.isOutgoing = isOutgoing
        self.isEditable = isEditable
        self.canBeRepliedTo = canBeRepliedTo
        self.isThreaded = isThreaded
        self.sender = sender
        self.content = content
        self.debugInfo = debugInfo
        self.replyDetails = replyDetails
        self.properties = properties
        
        // Computing noticeContentType in the initializer
        noticeContentType = NoticeCategoryType.computeContentType(debugInfo)
    }
}
