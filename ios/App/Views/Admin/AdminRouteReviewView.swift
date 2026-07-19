import SwiftUI

struct AdminRouteReviewView: View {
    var route: Route
    var onHandled: () async -> Void

    @Environment(\.dismiss) var dismiss
    @State private var isProcessing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                MapContainerView(stops: route.stops)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal)

                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(route.name).font(.title3.bold())
                        Text(route.direction).foregroundStyle(.secondary)
                        if let summary = route.summary { Text(summary).font(.footnote) }
                        Text(String(format: NSLocalizedString("admin.review.stop_count", comment: ""), route.stops.count))
                            .font(.footnote).foregroundStyle(.secondary)
                        Text(String(format: NSLocalizedString("admin.review.creator", comment: ""), route.creatorDisplayName ?? route.creatorId ?? "-"))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                HStack(spacing: 12) {
                    Button {
                        Task { await handle(approve: true) }
                    } label: {
                        Label(NSLocalizedString("admin.review.approve", comment: ""), systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button(role: .destructive) {
                        Task { await handle(approve: false) }
                    } label: {
                        Label(NSLocalizedString("admin.review.reject", comment: ""), systemImage: "xmark.circle.fill")
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                .disabled(isProcessing)
            }
            .padding(.vertical)
        }
        .navigationTitle(NSLocalizedString("admin.review.title", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func handle(approve: Bool) async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            if approve {
                try await AdminAPIClient.shared.approveRoute(id: route.id)
            } else {
                try await AdminAPIClient.shared.rejectRoute(id: route.id)
            }
            await onHandled()
            dismiss()
        } catch {
            // 简化处理：失败时静默，用户可以下拉刷新重试；如需完整错误提示可以扩展一个 @State errorMessage
        }
    }
}
