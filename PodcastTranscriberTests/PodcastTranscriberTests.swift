//
//  PodcastTranscriberTests.swift
//  PodcastTranscriberTests
//
//  Created by Mullen  Char  on 2026/4/20.
//

import Testing
import Foundation
@testable import PodcastTranscriber

struct PodcastTranscriberTests {

    @MainActor
    @Test func testFFmpegAvailable() async throws {
        let wavURL = try await AudioConversionService.convertToWav(
            audioURL: URL(fileURLWithPath: "/Users/mullenchar/StudySwift/PodcastTranscriber/Mytest.m4a")
        )
        defer { AudioConversionService.cleanTemporaryFiles() }
        #expect(FileManager.default.fileExists(atPath: wavURL.path))
        let attrs = try FileManager.default.attributesOfItem(atPath: wavURL.path)
        #expect((attrs[.size] as? Int64 ?? 0) > 44)
        print("ffmpeg WAV size: \(attrs[.size] ?? 0) bytes")
    }

    @MainActor
    @Test func testBundleModelURL() throws {
        let modelURL = try Paths.bundleModelURL()
        #expect(FileManager.default.fileExists(atPath: modelURL.path))
        print("Model found at: \(modelURL.path)")
    }

    @MainActor
    @Test func testAudioConversion() async throws {
        let testAudioURL = URL(fileURLWithPath: "/Users/mullenchar/StudySwift/PodcastTranscriber/Mytest.m4a")
        #expect(FileManager.default.fileExists(atPath: testAudioURL.path))

        let wavURL = try await AudioConversionService.convertToWav(audioURL: testAudioURL)
        defer { AudioConversionService.cleanTemporaryFiles() }

        print("WAV created at: \(wavURL.path)")
        #expect(FileManager.default.fileExists(atPath: wavURL.path))

        let attributes = try FileManager.default.attributesOfItem(atPath: wavURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        print("WAV file size: \(fileSize) bytes")
        #expect(fileSize > 44, "WAV file should be larger than 44-byte header")
    }

    @MainActor
    @Test func testFullTranscriptionPipeline() async throws {
        let testAudioURL = URL(fileURLWithPath: "/Users/mullenchar/StudySwift/PodcastTranscriber/Mytest.m4a")
        #expect(FileManager.default.fileExists(atPath: testAudioURL.path))

        // Step 1: Convert audio
        let wavURL = try await AudioConversionService.convertToWav(audioURL: testAudioURL)
        print("Step 1 - WAV path: \(wavURL.path)")
        print("Step 1 - WAV exists: \(FileManager.default.fileExists(atPath: wavURL.path))")

        // Step 2: Get model
        let modelURL = try Paths.bundleModelURL()
        print("Step 2 - Model path: \(modelURL.path)")
        print("Step 2 - Model exists: \(FileManager.default.fileExists(atPath: modelURL.path))")

        // Step 3: Transcribe
        let bridge = WhisperBridge()
        defer { AudioConversionService.cleanTemporaryFiles() }
        print("Step 3 - Calling pt_whisper_transcribe...")

        do {
            let result = try bridge.transcribe(audioURL: wavURL, modelURL: modelURL)
            print("Step 4 - Transcription result: \(result)")
            #expect(!result.isEmpty, "Transcription should not be empty")
        } catch let error as PodcastTranscriberError {
            print("Step 4 - PodcastTranscriberError: \(error)")
            throw error
        } catch {
            print("Step 4 - Unexpected error: \(error)")
            throw error
        }
    }
}
