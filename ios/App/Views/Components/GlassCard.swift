import SwiftUI

/// 统一的"卡片"容器：
/// - 在 iOS 26 及以上系统使用官方的 Liquid Glass（.glassEffect()）
/// - 在 iOS 18~25 上优雅降级为半透明毛玻璃材质（.ultraThinMaterial）
/// 这样整个 App 的卡片风格只需要维护这一处即可。
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 20
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(iOS 26.0, *) {
            content()
                .padding(16)
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content()
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
        }
    }
}
