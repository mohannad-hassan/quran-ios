//
//  GaplessAudioRequestBuilderTests.swift
//
//
//  Created by Mohammad Abdurraafay on 2023-02-12.
//

import AudioTimingPersistence
import Foundation
import QuranAudio
import QuranKit
import ReciterServiceFake
import XCTest
@testable import QuranAudioKit

class GaplessAudioRequestBuilderTests: XCTestCase {
    private var audioRequestBuilder: QuranAudioRequestBuilder!
    private var reciter = Reciter.gaplessReciter
    private let quran = Quran.hafsMadani1405

    override func setUpWithError() throws {
        try reciter.prepareGaplessReciterForTests(unZip: true)

        audioRequestBuilder = GaplessAudioRequestBuilder()
    }

    override func tearDown() async throws {
        Reciter.cleanUpAudio()
    }

    func testAudioFrameStartingFromZeroSecondsWhenThePlaybackIsNotRepeated() async throws {
        let from = try XCTUnwrap(AyahNumber(sura: quran.suras[1], ayah: 1))
        let to = try XCTUnwrap(AyahNumber(sura: quran.suras[1], ayah: 2))

        let audioRequest = try await audioRequestBuilder.buildRequest(
            with: reciter,
            from: from,
            to: to,
            frameRuns: .one,
            requestRuns: .one
        )
        let firstFrame = try XCTUnwrap(audioRequest.getRequest().files.first?.frames.first)
        XCTAssertEqual(firstFrame.startTime, .zero)
    }

    func testAudioFrameIsNotStartingFromZeroSecondsWhenThePlaybackIsRepeated() async throws {
        let from = try XCTUnwrap(AyahNumber(sura: quran.suras[1], ayah: 1))
        let to = try XCTUnwrap(AyahNumber(sura: quran.suras[1], ayah: 2))

        let audioRequest = try await audioRequestBuilder.buildRequest(
            with: reciter,
            from: from,
            to: to,
            frameRuns: .one,
            requestRuns: .indefinite
        )
        let firstFrame = try XCTUnwrap(audioRequest.getRequest().files.first?.frames.first)
        XCTAssertNotEqual(firstFrame.startTime, .zero)
    }
}
