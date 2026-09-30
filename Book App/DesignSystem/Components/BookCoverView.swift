//
//  BookCoverView.swift
//  Book App
//
//  Created by Sabi on 1/10/2026.
//

import SwiftUI

struct BookCoverView: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()

            case .empty:
                placeholder

            case .failure:
                placeholder

            @unknown default:
                placeholder
            }
        }
        .aspectRatio(2 / 3, contentMode: .fill)
        .clipShape(
            RoundedRectangle(
                cornerRadius: AppRadius.sm,
                style: .continuous
            )
        )
    }

    private var placeholder: some View {
        ZStack {
            Color.surfaceSecondary

            Image(systemName: "book.closed")
                .font(.title)
                .foregroundStyle(Color.textSecondary)
        }
    }
}

#Preview {
    BookCoverView(url: nil)
        .frame(width: 120)
        .padding()
}
