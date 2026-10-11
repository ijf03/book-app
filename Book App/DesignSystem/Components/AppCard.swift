//
//  AppCard.swift
//  Book App
//
//  Created by Sabi on 1/10/2026.
//

import Foundation
import SwiftUI

struct AppCard<Content: View>: View {

    private let content: Content

    init(
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppSpacing.md)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background {
                RoundedRectangle(
                    cornerRadius: AppRadius.lg,
                    style: .continuous
                )
                .fill(Color.surface)
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: AppRadius.lg,
                    style: .continuous
                )
                .stroke(
                    Color.border,
                    lineWidth: 1
                )
            }
    }
}
#Preview {
    AppCard {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Currently Reading")
                .font(AppTypography.headline)

            Text("Fourth Wing")
                .font(AppTypography.body)

            Text("Rebecca Yarros")
                .font(AppTypography.caption)
                .foregroundStyle(Color.textSecondary)
        }
    }
    .padding()
    .background(Color.surfaceSecondary)
}
