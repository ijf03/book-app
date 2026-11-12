//
//  FieldToggleRow.swift
//  Book App
//
//  Created by Sabi on 3/10/2026.
//

import SwiftUI

struct FieldToggleRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let title: String
    let helperText: String
    let placeholder: String
    let keyboardType: UIKeyboardType

    @Binding var isEnabled: Bool
    @Binding var text: String

    var body: some View {
        AppCard {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.md))
                : AnyLayout(HStackLayout(alignment: .center, spacing: AppSpacing.md))
            layout {
                Button {
                    isEnabled.toggle()
                } label: {
                    Image(
                        systemName: isEnabled
                            ? "checkmark.square.fill"
                            : "square"
                    )
                    .font(.title3)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .foregroundStyle(
                        isEnabled
                            ? Color.appAccent
                            : Color.textSecondary
                    )
                }
                .buttonStyle(.plain)
                .accessibilityValue(isEnabled ? "On" : "Off")
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
                .accessibilityLabel(title)
                .multilineTextAlignment(.trailing)
                .frame(width: typeSize.isAccessibilitySize ? nil : 100)
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
