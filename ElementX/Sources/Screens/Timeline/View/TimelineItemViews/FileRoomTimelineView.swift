//
// Copyright 2022-2024 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE in the repository root for full details.
//

import Foundation
import SwiftUI

struct FileRoomTimelineView: View {
    let timelineItem: FileRoomTimelineItem
    
    var body: some View {
        TimelineStyler(timelineItem: timelineItem) {
            Label(title: { Text(timelineItem.body) },
                  icon: { Image(systemName: "doc.text.fill")
                      .foregroundColor(.compound.iconPrimary)
                  })
                  .labelStyle(RoomTimelineViewLabelStyle())
                  .font(.compound.bodyLG)
                  .padding(.vertical, 12)
                  .padding(.horizontal, 6)
                  .accessibilityLabel(L10n.commonFile)
        }
    }
}

struct FileRoomTimelineView_Previews: PreviewProvider, TestablePreview {
    static let viewModel = TimelineViewModel.mock
    
    static var previews: some View {
        body.environmentObject(viewModel.context)
    }
    
    static var body: some View {
        VStack(spacing: 20.0) {
            FileRoomTimelineView(timelineItem: FileRoomTimelineItem(id: .random,
                                                                    timestamp: "Now",
                                                                    isOutgoing: false,
                                                                    isEditable: false,
                                                                    canBeRepliedTo: true,
                                                                    isThreaded: false,
                                                                    sender: .init(id: "Bob"),
                                                                    content: .init(body: "document.pdf", source: nil, thumbnailSource: nil, contentType: nil)))

            FileRoomTimelineView(timelineItem: FileRoomTimelineItem(id: .random,
                                                                    timestamp: "Now",
                                                                    isOutgoing: false,
                                                                    isEditable: false,
                                                                    canBeRepliedTo: true,
                                                                    isThreaded: false,
                                                                    sender: .init(id: "Bob"),
                                                                    content: .init(body: "document.docx", source: nil, thumbnailSource: nil, contentType: nil)))
            
            FileRoomTimelineView(timelineItem: FileRoomTimelineItem(id: .random,
                                                                    timestamp: "Now",
                                                                    isOutgoing: false,
                                                                    isEditable: false,
                                                                    canBeRepliedTo: true,
                                                                    isThreaded: false,
                                                                    sender: .init(id: "Bob"),
                                                                    content: .init(body: "document.txt", source: nil, thumbnailSource: nil, contentType: nil)))
        }
    }
}
