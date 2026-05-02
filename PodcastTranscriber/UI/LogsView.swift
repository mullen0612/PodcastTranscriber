import SwiftUI

struct LogsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading) {
            Text("Logs")
                .font(.headline)
                .padding(.horizontal)

            if appState.logger.logs.isEmpty {
                Text("No log entries yet.")
                    .foregroundColor(.secondary)
                    .padding()
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    List(appState.logger.logs.reversed()) { entry in
                        HStack(alignment: .top) {
                            Text("[\(entry.timestamp.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits)))]")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundColor(.secondary)

                            Circle()
                                .frame(width: 6, height: 6)
                                .foregroundColor(entry.level == .error ? .red : .blue)

                            Text(entry.message)
                                .font(.caption)
                                .foregroundColor(entry.level == .error ? .red : .primary)
                                .lineLimit(nil)

                            Spacer()
                        }
                        .padding(.vertical, 1)
                        .id(entry.id)
                    }
                    .listStyle(.plain)
                    .onChange(of: appState.logger.logs.count) { _ in
                        if let last = appState.logger.logs.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        if let last = appState.logger.logs.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .padding(.vertical)
    }
}
