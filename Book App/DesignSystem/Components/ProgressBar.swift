//
//  ProgressBar.swift
//  Book App
//
//  Created by Sabi on 1/10/2026.
//

import Foundation
import SwiftUI

struct ProgressBar: View {
    let progress: Double

    private var safeProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.surfaceSecondary)

                Capsule()
                    .fill(Color.appAccent)
                    .frame(
                        width: geometry.size.width * safeProgress
                    )
            }
        }
        .frame(height: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Reading progress"))
        .accessibilityValue(Text("\(Int(safeProgress * 100)) percent"))
    }
}

#Preview {
    VStack(spacing: AppSpacing.lg) {
        ProgressBar(progress: 0.25)
        ProgressBar(progress: 0.67)
        ProgressBar(progress: 1.0)
    }
    .padding()
}
