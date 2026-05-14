import SwiftUI

struct GeneralSettingsExperimentalUIRow: View {
    @ObservedObject var generalSettings: GeneralSettingsManager

    var body: some View {
        LabeledContent("settings.experimental_ui.label".localized()) {
            Toggle("settings.experimental_ui.description".localized(), isOn: $generalSettings.useExperimentalUI)
                .toggleStyle(.checkbox)
        }
        .labeledContentStyle(.custom)
    }
}
