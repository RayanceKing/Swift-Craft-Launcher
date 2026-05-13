import SwiftUI

struct GeneralSettingsExperimentalUIRow: View {
    @ObservedObject var generalSettings: GeneralSettingsManager
    @State private var showingRestartAlert = false
    @State private var error: GlobalError?

    var body: some View {
        LabeledContent("settings.experimental_ui.label".localized()) {
            Toggle("settings.experimental_ui.description".localized(), isOn: $generalSettings.useExperimentalUI)
                .toggleStyle(.checkbox)
                .onChange(of: generalSettings.useExperimentalUI) { _, _ in
                    showingRestartAlert = true
                }
        }
        .labeledContentStyle(.custom)
        .confirmationDialog(
            "settings.experimental_ui.restart.title".localized(),
            isPresented: $showingRestartAlert,
            titleVisibility: .visible
        ) {
            Button("restart.now".localized(), role: .destructive) {
                restartAppSafely()
            }
            .keyboardShortcut(.defaultAction)
            Button("common.cancel".localized(), role: .cancel) {
                generalSettings.useExperimentalUI.toggle()
            }
        } message: {
            Text("settings.experimental_ui.restart.message".localized())
        }
        .alert(
            "error.notification.validation.title".localized(),
            isPresented: .constant(error != nil && error?.level == .popup)
        ) {
            Button("common.close".localized()) {
                error = nil
            }
        } message: {
            if let error = error {
                Text(error.localizedDescription)
            }
        }
    }

    private func restartAppSafely() {
        do {
            try restartApp()
        } catch {
            let globalError = GlobalError.from(error)
            GlobalErrorHandler.shared.handle(globalError)
            self.error = globalError
        }
    }

    private func restartApp() throws {
        guard let appURL = Bundle.main.bundleURL as URL? else {
            throw GlobalError.configuration(
                chineseMessage: "无法获取应用路径",
                i18nKey: "error.configuration.app_path_not_found",
                level: .popup
            )
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = [appURL.path]

        try task.run()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApplication.shared.terminate(nil)
        }
    }
}
