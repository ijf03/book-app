//
//  DesignSystemPreview.swift
//  Book App
//
//  Created by Sabi on 1/10/2026.
//

import Foundation
import SwiftUI

struct DesignSystemPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("Design System")
                    .font(AppTypography.largeTitle)
                    .foregroundStyle(Color.textPrimary)

                SectionHeader(title: "Buttons")

                Button("Update Progress") {
                    // Preview only
                }
                .buttonStyle(AppButtonStyle(kind: .primary))

                Button("Add to Library") {
                    // Preview only
                }
                .buttonStyle(AppButtonStyle(kind: .secondary))

                SectionHeader(title: "Progress")

                ProgressBar(progress: 0.67)

                SectionHeader(title: "Cards")

                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Fourth Wing")
                            .font(AppTypography.headline)
                            .foregroundStyle(Color.textPrimary)

                        Text("Rebecca Yarros")
                            .font(AppTypography.body)
                            .foregroundStyle(Color.textSecondary)

                        ProgressBar(progress: 0.67)

                        Text("67% complete")
                            .font(AppTypography.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
            .padding(AppSpacing.md)
        }
        .background(Color.surfaceSecondary)
    }
}

#Preview {
    DesignSystemPreview()
}
