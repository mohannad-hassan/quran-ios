//
//  File.swift
//  QuranEngine
//
//  Created by Mohannad Hassan on 07/03/2025.
//

import Foundation
import Combine

class SerializationScheduler {

    private let invokationSubject = PassthroughSubject<Void, Never>()
    var invokationSignal: AnyPublisher<Void, Never> { invokationSubject.eraseToAnyPublisher() }

    func localDataModified() {

    }
}
