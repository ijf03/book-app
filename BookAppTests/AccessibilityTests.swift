import SwiftUI
import Testing
import UIKit
@testable import Book_App

@MainActor
struct AccessibilityTests {
    @Test func ratingAdjustmentsReachEveryValueAndRespectBounds() {
        var rating = 0
        let control = RatingStars(rating: Binding(get: { rating }, set: { rating = $0 }))
        for expected in 1...5 {
            control.adjustRating(.increment)
            #expect(rating == expected)
        }
        control.adjustRating(.increment)
        #expect(rating == 5)
        for expected in (0...4).reversed() {
            control.adjustRating(.decrement)
            #expect(rating == expected)
        }
        control.adjustRating(.decrement)
        #expect(rating == 0)
    }

    @Test func readOnlyRatingDoesNotChange() {
        var rating = 3
        let control = RatingStars(rating: Binding(get: { rating }, set: { rating = $0 }), isEditable: false)
        control.adjustRating(.increment)
        control.adjustRating(.decrement)
        #expect(rating == 3)
    }

    @Test func durationLayoutGrowsVerticallyAtLargestTextSize() {
        let normal = UIHostingController(rootView: ReadingDurationText(seconds: 3661)
            .environment(\.dynamicTypeSize, .large))
        let accessible = UIHostingController(rootView: ReadingDurationText(seconds: 3661)
            .environment(\.dynamicTypeSize, .accessibility5))
        let proposal = CGSize(width: 280, height: 10_000)
        let normalSize = normal.sizeThatFits(in: proposal)
        let accessibleSize = accessible.sizeThatFits(in: proposal)
        #expect(accessibleSize.height > normalSize.height)
        #expect(accessibleSize.width <= proposal.width + 1)
        #expect(accessibleSize.height.isFinite)
    }

    @Test func secondaryTextAndPrimaryButtonsMeetContrastInBothAppearances() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            func color(_ name: String) throws -> UIColor {
                try #require(UIColor(named: name, in: Bundle(for: AppDelegate.self), compatibleWith: traits))
                    .resolvedColor(with: traits)
            }
            let secondary = try color("TextSecondary")
            #expect(try contrast(secondary, color("Surface")) >= 4.5)
            #expect(try contrast(secondary, color("SurfaceSecondary")) >= 4.5)
            #expect(try contrast(color("OnAccent"), color("AppAccent")) >= 4.5)
        }
    }

    private func contrast(_ first: UIColor, _ second: UIColor) -> Double {
        func luminance(_ color: UIColor) -> Double {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            func linear(_ value: CGFloat) -> Double {
                let v = Double(value)
                return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        }
        let a = luminance(first), b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}
