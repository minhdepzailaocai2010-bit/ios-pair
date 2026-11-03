import SwiftUI

struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                content
                    .padding(18)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            } else {
                content
                    .padding(18)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(.white.opacity(0.13), lineWidth: 1)
                    }
            }
        }
    }
}
