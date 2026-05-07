import Foundation
import AVFoundation

struct AudioConversionService {

    /// Converts any audio file to 16kHz mono 16-bit PCM WAV using ffmpeg.
    static func convertToWav(audioURL: URL) async throws -> URL {
        let outputDirectory = Paths.temporaryDirectory()
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let outputURL = outputDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("wav")

        // Try ffmpeg first (supports MP3, FLAC, OGG, etc.)
        if let ffmpegURL = findFFmpeg() {
            do {
                try await convertWithFFmpeg(input: audioURL, output: outputURL, ffmpegURL: ffmpegURL)
                return outputURL
            } catch {
                // Fall through to AVFoundation fallback if ffmpeg is the primary path
                // but only for formats ffmpeg should handle (non-Apple codecs)
                throw error
            }
        }

        // Fallback: use AVFoundation for M4A/AAC and other Apple-native formats
        return try await convertWithAVFoundation(audioURL: audioURL, outputURL: outputURL)
    }

    // MARK: - ffmpeg path

    private static func findFFmpeg() -> URL? {
        // Check common installation paths
        let paths = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/opt/local/bin/ffmpeg"
        ]
        for path in paths {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.isExecutableFile(atPath: path) {
                return url
            }
        }
        // Try PATH resolution
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        which.arguments = ["which", "ffmpeg"]
        let pipe = Pipe()
        which.standardOutput = pipe
        which.standardError = FileHandle.nullDevice
        do {
            try which.run()
            which.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let path = path, !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        } catch {
            // ffmpeg not found via which
        }
        return nil
    }

    private static func convertWithFFmpeg(input: URL, output: URL, ffmpegURL: URL) async throws {
        let process = Process()
        process.executableURL = ffmpegURL
        process.arguments = [
            "-i", input.path,
            "-ar", "16000",
            "-ac", "1",
            "-c:a", "pcm_s16le",
            "-y",
            output.path
        ]

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = FileHandle.nullDevice

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorMessage = String(data: stderrData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown ffmpeg error"
                    continuation.resume(throwing: AudioConversionError.conversionFailed(
                        reason: "ffmpeg: \(errorMessage)"
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: AudioConversionError.conversionFailed(
                    reason: "Failed to launch ffmpeg: \(error.localizedDescription)"
                ))
            }
        }
    }

    // MARK: - AVFoundation fallback

    private static func convertWithAVFoundation(audioURL: URL, outputURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: audioURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard let firstTrack = audioTracks.first else {
            throw AudioConversionError.invalidAudioFormat
        }

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        guard let reader = try? AVAssetReader(asset: asset) else {
            throw AudioConversionError.conversionFailed(reason: "AVFoundation: Failed to create AVAssetReader")
        }

        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .wav) else {
            throw AudioConversionError.conversionFailed(reason: "AVFoundation: Failed to create AVAssetWriter")
        }

        let readerOutput = AVAssetReaderTrackOutput(track: firstTrack, outputSettings: outputSettings)
        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings)

        guard reader.canAdd(readerOutput) else {
            throw AudioConversionError.conversionFailed(reason: "AVFoundation: Cannot add reader output")
        }
        reader.add(readerOutput)

        guard writer.canAdd(writerInput) else {
            throw AudioConversionError.conversionFailed(reason: "AVFoundation: Cannot add writer input")
        }
        writer.add(writerInput)

        guard reader.startReading() else {
            throw AudioConversionError.conversionFailed(
                reason: reader.error?.localizedDescription ?? "AVFoundation: Failed to start reading"
            )
        }

        guard writer.startWriting() else {
            throw AudioConversionError.conversionFailed(
                reason: writer.error?.localizedDescription ?? "AVFoundation: Failed to start writing"
            )
        }

        writer.startSession(atSourceTime: .zero)

        return try await withCheckedThrowingContinuation { continuation in
            let queue = DispatchQueue(label: "audioConversion.avf.\(UUID().uuidString)")
            var hasResumed = false

            writerInput.requestMediaDataWhenReady(on: queue) {
                while writerInput.isReadyForMoreMediaData {
                    if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                        guard writerInput.append(sampleBuffer) else {
                            if !hasResumed {
                                hasResumed = true
                                let error = writer.error ?? NSError(
                                    domain: "AudioConversion",
                                    code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "AVFoundation: Failed to append sample buffer"]
                                )
                                writerInput.markAsFinished()
                                writer.cancelWriting()
                                continuation.resume(throwing: AudioConversionError.conversionFailed(
                                    reason: error.localizedDescription
                                ))
                            }
                            return
                        }
                    } else {
                        writerInput.markAsFinished()
                        writer.finishWriting {
                            guard !hasResumed else { return }
                            hasResumed = true
                            if writer.status == .failed {
                                continuation.resume(throwing: AudioConversionError.conversionFailed(
                                    reason: writer.error?.localizedDescription ?? "AVFoundation: Writer failed"
                                ))
                            } else if writer.status == .cancelled {
                                continuation.resume(throwing: AudioConversionError.conversionFailed(
                                    reason: "AVFoundation: Writer was cancelled"
                                ))
                            } else {
                                continuation.resume(returning: outputURL)
                            }
                        }
                        return
                    }
                }
            }
        }
    }

    // MARK: - Cleanup

    static func cleanTemporaryFiles() {
        let tempDirectory = Paths.temporaryDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

enum AudioConversionError: Error {
    case invalidAudioFormat
    case conversionFailed(reason: String)
}
