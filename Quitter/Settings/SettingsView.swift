import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

/// The exported data as a dated .csv file for the share sheet. The CSV is only built when the user shares it.
struct CSVExport: Transferable {
    let build: @MainActor @Sendable () -> String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { export in
            let text = await export.build()
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(exportFileName(on: .now, calendar: .current))
            try Data(text.utf8).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @State private var confirmDelete = false
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    init(viewModel: SettingsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            Section("Notifications") {
                Toggle(isOn: Binding(
                    get: { viewModel.milestonesOn },
                    set: { on in Task { await viewModel.setMilestones(on) } }
                )) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Trophy notifications")
                            Text("One at each milestone, never at night")
                                .font(.footnote)
                                .foregroundStyle(Palette.onSurfaceVariant)
                        }
                    } icon: {
                        Image(systemName: "trophy")
                    }
                }
            }
            Section("Your data") {
                ShareLink(item: viewModel.export(), preview: SharePreview("Quitter export")) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export as CSV").foregroundStyle(Palette.onSurface)
                            Text("Habits, slips and reasons, for any spreadsheet")
                                .font(.footnote)
                                .foregroundStyle(Palette.onSurfaceVariant)
                        }
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Delete all data")
                            Text("Every habit and its history")
                                .font(.footnote)
                                .foregroundStyle(Palette.onSurfaceVariant)
                        }
                    } icon: {
                        Image(systemName: "trash")
                    }
                }
            }
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Stays on this phone")
                        Text("No account, no ads, no tracking. Nothing you enter is sent to us. Your phone's own backup may include it.")
                            .font(.footnote)
                            .foregroundStyle(Palette.onSurfaceVariant)
                    }
                } icon: {
                    Image(systemName: "lock")
                }
            } header: {
                Text("Privacy")
            } footer: {
                Text("Version \(viewModel.version)")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete everything?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive, action: viewModel.deleteAll)
        } message: {
            Text("All habits, slips and reasons are deleted from this phone. This can't be undone. Export first if you want a copy.")
        }
        .task(id: scenePhase) { await viewModel.refreshNotifications() }
        .alert("Notifications are off for Quitter.", isPresented: $viewModel.notificationsBlocked) {
            Button("Open Settings") { openNotificationSettings(openURL) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Turn them on in Settings to get a notification at each trophy.")
        }
        .alert("Couldn't delete", isPresented: $viewModel.deleteFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try again.")
        }
    }
}

#Preview {
    NavigationStack { SettingsView(viewModel: SettingsViewModel(store: SwiftDataHabitStore.inMemory(), onAllDeleted: {})) }
}
