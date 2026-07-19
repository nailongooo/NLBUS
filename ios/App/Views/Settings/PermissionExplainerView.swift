import SwiftUI

struct PermissionExplainerView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)

                Text(NSLocalizedString("permission.title", comment: "")).font(.title2.bold())
                Text(NSLocalizedString("permission.body_1", comment: ""))
                Text(NSLocalizedString("permission.body_2", comment: ""))
                Text(NSLocalizedString("permission.body_3", comment: ""))
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle(NSLocalizedString("settings.location_permission", comment: ""))
    }
}
