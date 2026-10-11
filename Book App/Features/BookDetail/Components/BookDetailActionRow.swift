//
//  BookDetailActionRow.swift
//  Book App
//
//  Created by Sabi on 1/10/2026.
//

import SwiftUI

struct BookDetailActionRow: View {

    let title: String
    let systemImage: String
    var subtitle: String?
    var action: () -> Void

    var body: some View {

        Button(
            action: action
        ) {

            HStack(
                alignment: .center,
                spacing: AppSpacing.md
            ) {

                icon

                textContent

                Spacer(
                    minLength: AppSpacing.sm
                )

                Image(
                    systemName: "chevron.right"
                )
                .font(
                    .system(
                        size: 13,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    Color.textSecondary
                )
            }
            .frame(
                minHeight: 56
            )
            .contentShape(
                Rectangle()
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Icon

    private var icon: some View {

        ZStack {

            RoundedRectangle(
                cornerRadius: AppRadius.sm,
                style: .continuous
            )
            .fill(
                Color.accentTint
            )

            Image(
                systemName: systemImage
            )
            .font(
                .system(
                    size: 17,
                    weight: .medium
                )
            )
            .foregroundStyle(
                Color.appAccent
            )
        }
        .frame(
            width: 38,
            height: 38
        )
    }

    // MARK: - Text

    private var textContent: some View {

        VStack(
            alignment: .leading,
            spacing: AppSpacing.xs
        ) {

            Text(title)
                .font(
                    AppTypography.headline
                )
                .foregroundStyle(
                    Color.textPrimary
                )

            if let subtitle {

                Text(subtitle)
                    .font(
                        AppTypography.caption
                    )
                    .foregroundStyle(
                        Color.textSecondary
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }
}
#Preview {
    VStack {
        BookDetailActionRow(
            title: "Notes",
            systemImage: "note.text",
            subtitle: "View your reading notes",
            action: {}
        )

        BookDetailActionRow(
            title: "Write a Review",
            systemImage: "star",
            action: {}
        )
    }
    .padding()
}
