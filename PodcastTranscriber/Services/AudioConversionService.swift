import Foundation
import AVFoundation

struct AudioConversionService {
    static func convertToWav(audioURL: URL) async throws -> URL {
        let outputDirectory = Paths.temporaryDirectory()
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let outputURL = outputDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("wav")

        let asset = AVURLAsset(url: audioURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard let firstTrack = audioTracks.first else {
            throw AudioConversionError.invalidAudioFormat
        }
        let formatDescriptions = try await firstTrack.load(.formatDescriptions)
        guard formatDescriptions.first != nil else {
            throw AudioConversionError.invalidAudioFormat
        }

        let reader = try AVAssetReader(asset: asset)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .wav)

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        let readerOutput = AVAssetReaderTrackOutput(track: firstTrack, outputSettings: nil)
        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings)

        reader.add(readerOutput)
        writer.add(writerInput)

        reader.startReading()
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let processingQueue = DispatchQueue(label: "audioConversionQueue")

        return try await withCheckedThrowingContinuation { continuation in
            writerInput.requestMediaDataWhenReady(on: processingQueue) {
                while writerInput.isReadyForMoreMediaData {
                    if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                        writerInput.append(sampleBuffer)
                    } else {
                        writerInput.markAsFinished()
                        writer.finishWriting { 
                            if writer.status == .failed {
                                continuation.resume(throwing: AudioConversionError.conversionFailed(reason: writer.error?.localizedDescription ?? "Unknown error"))
                            } else {
                                continuation.resume(returning: outputURL)
                            }
                        }
                        break
                    }
                }
            }
        }
    }

    static func cleanTemporaryFiles() {
        let tempDirectory = Paths.temporaryDirectory()
        try? FileManager.default.removeItem(at: tempDirectory)
    }
}

enum AudioConversionError: Error {
    case invalidAudioFormat
    case conversionFailed(reason: String)
}
