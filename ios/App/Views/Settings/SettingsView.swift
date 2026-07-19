import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section(NSLocalizedString("settings.appearance", comment: "")) {
                Picker(NSLocalizedString("settings.color_scheme", comment: ""), selection: $appState.preferredColorSchemeRaw) {
                    Text(NSLocalizedString("settings.color_scheme.system", comment: "")).tag("system")
                    Text(NSLocalizedString("settings.color_scheme.light", comment: "")).tag("light")
                    Text(NSLocalizedString("settings.color_scheme.dark", comment: "")).tag("dark")
                }
                ColorPicker(NSLocalizedString("settings.accent_color", comment: ""), selection: Binding(
                    get: { Color(hex: appState.accentColorHex) },
                    set: { appState.accentColorHex = $0.toHex() }
                ))
            }

            Section(NSLocalizedString("settings.reminder_section", comment: "")) {
                Toggle(NSLocalizedString("settings.reminder_override", comment: ""), isOn: $appState.reminderDistanceOverrideEnabled)
                if appState.reminderDistanceOverrideEnabled {
                    distanceStepper(NSLocalizedString("settings.pre_alert", comment: ""), value: $appState.overridePreAlertMeters, range: 500...3000)
                    distanceStepper(NSLocalizedString("settings.approaching", comment: ""), value: $appState.overrideApproachingMeters, range: 100...1000)
                    distanceStepper(NSLocalizedString("settings.arrival", comment: ""), value: $appState.overrideArrivalMeters, range: 30...400)
                }
                Text(NSLocalizedString("settings.reminder_hint", comment: ""))
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section(NSLocalizedString("settings.permissions_section", comment: "")) {
                NavigationLink(NSLocalizedString("settings.location_permission", comment: "")) {
                    PermissionExplainerView()
                }
                Button(NSLocalizedString("settings.open_system_settings", comment: "")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }

            Section {
                NavigationLink(NSLocalizedString("nav.feedback", comment: "")) { FeedbackView() }
                NavigationLink(NSLocalizedString("nav.about", comment: "")) { AboutView() }
            }
        }
        .navigationTitle(NSLocalizedString("nav.settings", comment: ""))
    }

    private func distanceStepper(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        Stepper(value: value, in: range, step: 50) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue)) 米").foregroundStyle(.secondary)
            }
        }
    }
}
