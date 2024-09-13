//
// Copyright 2022 New Vector Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
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
