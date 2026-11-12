//
//  SectionHeader.swift
//  Book App
//
//  Created by Sabi on 1/10/2026.
//

import Foundation
import SwiftUI

struct SectionHeader: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.sm))
            : AnyLayout(HStackLayout())
        return layout {
            Text(title)
                .font(AppTypography.title)
                .accessibilityAddTraits(.isHeader)
                .foregroundStyle(Color.textPrimary)

            if !typeSize.isAccessibilitySize { Spacer() }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(AppTypography.callout)
                    .frame(minHeight: AppLayout.minimumTapTarget)
                    .foregroundStyle(Color.appAccent)
            }
        }
    }
}

#Preview {
    VStack(spacing: AppSpacing.lg) {
        SectionHeader(
            title: "Currently Reading",
            actionTitle: "See All",
            action: {}
        )

        SectionHeader(
            title: "Up Next"
        )
    }
    .padding()
}
