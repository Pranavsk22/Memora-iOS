//
//  Category.swift
//  Home
//
//  Created by you on 11/11/25.
//

import Foundation
import UIKit

struct Category: Hashable {
    let id: UUID
    let title: String
    let slug: String          // used to match prompts (e.g. "childhood")
    let iconSystemName: String?     // optional SF Symbol name

    init(id: UUID = UUID(), title: String, slug: String, iconSystemName: String? = nil) {
        self.id = id
        self.title = title
        self.slug = slug
        self.iconSystemName = iconSystemName
    }
}

struct CategoryData {
    // EXACT categories you requested (use these slugs when filtering prompts)
    static let sample: [Category] = [
        Category(title: "Recipies",     slug: "recipies", iconSystemName: "fork.knife"),
        Category(title: "Childhood",    slug: "childhood", iconSystemName: "teddybear"),
        Category(title: "Travel",       slug: "travel", iconSystemName: "airplane"),
        Category(title: "Love",         slug: "love", iconSystemName: "heart.fill"),
        Category(title: "Life Lessons", slug: "life_lessons", iconSystemName: "book.closed" )
    ]
}
