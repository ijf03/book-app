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
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: systemImage)
                    .frame(width: 24)
                    .foregroundStyle(Color.appAccent)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(title)
                        .font(AppTypography.headline)
                        .foregroundStyle(Color.textPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .font(AppTypography.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
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
