//
//  SectionHeader.swift
//  Book App
//
//  Created by Sabi on 1/10/2026.
//

import Foundation
import SwiftUI

struct SectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(AppTypography.title)
                .foregroundStyle(Color.textPrimary)

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(AppTypography.callout)
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
