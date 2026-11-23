import SwiftUI

struct MemoryUsageBar: View {
    var usedFraction: Double
    var tint: Color
    var language: AppLanguage

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width * min(1, max(0, usedFraction))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.18))
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, width))
            }
        }
        .frame(height: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.text(.memoryUsedAccessibility, language))
        .accessibilityValue(
            L10n.percentAccessibility(
                Int((min(1, max(0, usedFraction)) * 100).rounded()),
                language
            )
        )
    }
}
