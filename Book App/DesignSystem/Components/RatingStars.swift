//
//  RatingStar.swift
//  Book App
//
//  Created by Sabi on 12/10/2026.
//

import SwiftUI

struct RatingStars: View {

    @Binding
    var rating: Int

    var isEditable:
        Bool = true

    var body: some View {

        HStack(
            spacing: AppSpacing.sm
        ) {

            ForEach(
                1...5,
                id: \.self
            ) { value in

                Button {
                    guard isEditable
                    else {
                        return
                    }

                    rating = value

                } label: {

                    Image(
                        systemName:
                            value <= rating
                            ? "star.fill"
                            : "star"
                    )
                    .font(
                        .system(
                            size: 28
                        )
                    )
                    .foregroundStyle(
                        value <= rating
                        ? Color.appAccent
                        : Color.textSecondary
                    )
                    .frame(
                        width: 44,
                        height: 44
                    )
                    .contentShape(
                        Rectangle()
                    )
                }
                .buttonStyle(
                    .plain
                )
                .disabled(
                    !isEditable
                )
            }
        }
        .accessibilityElement(
            children: .ignore
        )
        .accessibilityLabel(
            "Rating"
        )
        .accessibilityValue(
            "\(rating) out of 5 stars"
        )
    }
}

