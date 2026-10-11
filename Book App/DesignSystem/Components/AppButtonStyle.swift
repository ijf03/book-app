//
//  AppButtonStyle.swift
//  Book App
//
//  Created by Sabi on 1/10/2026.
//

import Foundation
import SwiftUI

struct AppButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case destructive
    }

    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.headline)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.horizontal, AppSpacing.md)
            .foregroundStyle(foregroundColor)
            .background(
                backgroundColor,
                in: RoundedRectangle(
                    cornerRadius: AppRadius.md,
                    style: .continuous
                )
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }

    private var foregroundColor: Color {
        switch kind {
        case .primary:
            return .white
        case .secondary:
            return .appAccent
        case .destructive:
            return .white
        }
    }

    private var backgroundColor: Color {
        switch kind {
        case .primary:
            return .appAccent
        case .secondary:
            return .surfaceSecondary
        case .destructive:
            return .danger
        }
    }
}

extension ButtonStyle where Self == AppButtonStyle {
    static var appPrimary: AppButtonStyle {
        AppButtonStyle(kind: .primary)
    }

    static var appSecondary: AppButtonStyle {
        AppButtonStyle(kind: .secondary)
    }
}
