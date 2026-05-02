import SwiftUI
import UniformTypeIdentifiers

struct LocalTranscribeView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedFileURL: URL? = nil
    @State private var transcriptionState: TranscriptionState = .idle
    @State private var transcribedText: String = ""
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""

    private let localTranscriptionService = LocalTranscriptionService()

    enum TranscriptionState {
        case idle, preparing, transcribing, done, error
    }

    var body: some View {
        VStack {
            Text("Local Transcription")
                .font(.largeTitle)
                .padding()

            Button(action: {
                selectFile()
            }) {
                Text("Select Audio File")
            }
            .padding()

            if let fileURL = selectedFileURL {
                Text("Selected File: \(fileURL.lastPathComponent)")
                    .padding()
            }

            HStack {
                Button("Start Transcription") {
                    startTranscription()
                }
                .disabled(transcriptionState != .idle || selectedFileURL == nil)

                Button("Clear") {
                    clearSelection()
                }
                .disabled(transcriptionState == .transcribing)
            }
            .padding()

            if transcriptionState == .transcribing {
                ProgressView("Transcribing...")
                    .padding()
            }

            TextEditor(text: $transcribedText)
                .frame(height: 200)
                .border(Color.gray, width: 1)
                .padding()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.audio]
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            selectedFileURL = panel.url
        }
    }

    private func startTranscription() {
        guard let fileURL = selectedFileURL else { return }
        transcriptionState = .transcribing
        appState.logger.log("Starting local transcription for \(fileURL.lastPathComponent)")

        Task {
            do {
                let result = try await localTranscriptionService.transcribeLocalAudio(inputAudioURL: fileURL)
                await MainActor.run {
                    self.transcribedText = result
                    self.transcriptionState = .done
                    appState.logger.log("Local transcription complete")
                }
            } catch {
                await MainActor.run {
                    self.transcriptionState = .error
                    self.alertMessage = error.localizedDescription
                    self.showAlert = true
                    appState.logger.log("Local transcription failed: \(error.localizedDescription)", level: .error)
                }
            }
        }
    }

    private func clearSelection() {
        selectedFileURL = nil
        transcriptionState = .idle
        transcribedText = ""
    }
}
