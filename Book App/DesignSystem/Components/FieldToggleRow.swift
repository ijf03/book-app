//
//  FieldToggleRow.swift
//  Book App
//
//  Created by Sabi on 3/10/2026.
//

import SwiftUI

struct FieldToggleRow: View {
    let title: String
    let helperText: String
    let placeholder: String
    let keyboardType: UIKeyboardType

    @Binding var isEnabled: Bool
    @Binding var text: String

    var body: some View {
        AppCard {
            HStack(
                alignment: .center,
                spacing: AppSpacing.md
            ) {
                Button {
                    isEnabled.toggle()
                } label: {
                    Image(
                        systemName: isEnabled
                            ? "checkmark.square.fill"
                            : "square"
                    )
                    .font(.title3)
                    .foregroundStyle(
                        isEnabled
                            ? Color.appAccent
                            : Color.textSecondary
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    isEnabled
                        ? "Disable \(title)"
                        : "Enable \(title)"
                )

                VStack(
                    alignment: .leading,
                    spacing: AppSpacing.xs
                ) {
                    Text(title)
                        .font(AppTypography.headline)
                        .foregroundStyle(Color.textPrimary)

                    Text(helperText)
                        .font(AppTypography.caption)
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                TextField(
                    placeholder,
                    text: $text
                )
                .keyboardType(keyboardType)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
                .padding(AppSpacing.sm)
                .background {
                    RoundedRectangle(
                        cornerRadius: AppRadius.sm,
                        style: .continuous
                    )
                    .fill(Color.surfaceSecondary)
                }
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1 : 0.45)
            }
        }
    }
}

#Preview {
    @Previewable @State var enabled = true
    @Previewable @State var value = "67"

    FieldToggleRow(
        title: "Percentage",
        helperText: "Works with any format",
        placeholder: "0",
        keyboardType: .decimalPad,
        isEnabled: $enabled,
        text: $value
    )
    .padding()
}
