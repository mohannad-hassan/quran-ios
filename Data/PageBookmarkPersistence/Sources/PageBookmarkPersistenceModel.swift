//
//  PageBookmarkPersistenceModel.swift
//  Quran
//
//  Created by Mohamed Afifi on 2023-03-05.
//  Copyright © 2023 Quran.com. All rights reserved.
//

import Foundation

public struct PageBookmarkPersistenceModel: Equatable {
    public let remoteID: String?
    public let page: Int
    public let creationDate: Date

    public init(remoteID: String?, page: Int, creationDate: Date) {
        self.remoteID = remoteID
        self.page = page
        self.creationDate = creationDate
    }
}

extension PageBookmarkPersistenceModel {
    init(page: Int, creationDate: Date) {
        self.init(remoteID: nil, page: page, creationDate: creationDate)
    }
}
