//
//  ReciterListBuilder.swift
//  Quran
//
//  Created by Afifi, Mohamed on 4/6/19.
//  Copyright © 2019 Quran.com. All rights reserved.
//

import UIKit

public struct ReciterListBuilder {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    @MainActor
    public func build(withListener listener: ReciterListListener, standalone: Bool) -> UIViewController {
        let viewModel = ReciterListViewModel(standalone: standalone)
        let viewController = ReciterListViewController(viewModel: viewModel)
        viewModel.listener = listener
        return viewController
    }
}
