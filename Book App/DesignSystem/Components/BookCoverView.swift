//
//  BookCoverView.swift
//  Book App
//
//  Created by Sabi on 1/10/2026.
//

import SwiftUI
import UIKit

struct BookCoverView: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    @State private var cover: UIImage?

    var body: some View {
        coverContent
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Book cover")
        .task(id: url) {
            cover = nil
            guard let url else { return }
            do {
                let data = try await OpenLibraryRequestClient.shared.data(for: url)
                try Task.checkCancellation()
                cover = UIImage(data: data)
            } catch {
                // Keep the placeholder; scrolling must not trigger automatic retries.
            }
        }

        .clipShape(
            RoundedRectangle(
                cornerRadius: AppRadius.sm,
                style: .continuous
            )
        )
        .shadow(
            color: Color.black.opacity(0.14),
            radius: 6,
            x: 0,
            y: 3
        )
    }

    @ViewBuilder
    private var coverContent: some View {
        if contentMode == .fit {
            // The slot determines layout, so the downloaded image's proportions
            // cannot widen a card or push its title into the following shelf.
            Color.clear
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .overlay {
                    if let cover {
                        Image(uiImage: cover)
                            .resizable()
                            .scaledToFit()
                    } else {
                        placeholder
                    }
                }
        } else {
            ZStack {
                if let cover {
                    Image(uiImage: cover)
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholder
                }
            }
            .aspectRatio(2.0 / 3.0, contentMode: .fill)
        }
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
