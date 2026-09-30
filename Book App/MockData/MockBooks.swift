import Foundation

extension Book {

    // MARK: - Normal mock data

    static let mockFourthWing = Book(
        id: "fourth-wing",
        title: "Fourth Wing",
        authors: ["Rebecca Yarros"],
        description: """
        A fantasy novel set within the brutal and competitive world of a war college for dragon riders.
        """,
        coverURL: nil,
        pageCount: 498,
        status: .reading,
        format: .physical
    )

    static let mockTomorrow = Book(
        id: "tomorrow",
        title: "Tomorrow, and Tomorrow, and Tomorrow",
        authors: ["Gabrielle Zevin"],
        description: """
        A novel about friendship, creativity, identity, and two people connected through video games.
        """,
        coverURL: nil,
        pageCount: 401,
        status: .toRead,
        format: .ebook
    )

    static let mockProjectHailMary = Book(
        id: "project-hail-mary",
        title: "Project Hail Mary",
        authors: ["Andy Weir"],
        description: """
        A lone astronaut must solve an impossible scientific problem far from Earth.
        """,
        coverURL: nil,
        pageCount: 476,
        status: .completed,
        format: .audiobook
    )

    static let mockIronFlame = Book(
        id: "iron-flame",
        title: "Iron Flame",
        authors: ["Rebecca Yarros"],
        description: """
        Violet Sorrengail continues her training while facing new dangers, secrets, and challenges.
        """,
        coverURL: nil,
        pageCount: 623,
        status: .toRead,
        format: .physical
    )

    static let mockDune = Book(
        id: "dune",
        title: "Dune",
        authors: ["Frank Herbert"],
        description: """
        Paul Atreides becomes caught in a struggle for survival and control of the desert planet Arrakis.
        """,
        coverURL: nil,
        pageCount: 688,
        status: .reading,
        format: .ebook
    )

    static let mockCirce = Book(
        id: "circe",
        title: "Circe",
        authors: ["Madeline Miller"],
        description: """
        A retelling of the life of Circe, the powerful witch from Greek mythology.
        """,
        coverURL: nil,
        pageCount: 393,
        status: .completed,
        format: .audiobook
    )

    static let mockSixOfCrows = Book(
        id: "six-of-crows",
        title: "Six of Crows",
        authors: ["Leigh Bardugo"],
        description: """
        Six dangerous outcasts attempt an impossible heist that could change their lives.
        """,
        coverURL: nil,
        pageCount: 465,
        status: .toRead,
        format: .physical
    )


    // MARK: - Edge cases

    // Very long title
    static let mockLongTitle = Book(
        id: "long-title",
        title: "The Extremely Inconvenient Adventures of a Reader Who Accidentally Found Themselves in a Very Complicated Fantasy World",
        authors: ["Amelia Hart"],
        description: """
        A mock book specifically created to test how the interface handles unusually long book titles.
        """,
        coverURL: nil,
        pageCount: 512,
        status: .reading,
        format: .ebook
    )

    // Two authors
    static let mockTwoAuthors = Book(
        id: "two-authors",
        title: "The Last Library",
        authors: [
            "Sophie Anderson",
            "Daniel Morgan"
        ],
        description: """
        Two writers explore a mysterious library containing books that were never written.
        """,
        coverURL: nil,
        pageCount: 352,
        status: .toRead,
        format: .physical
    )

    // No description
    static let mockNoDescription = Book(
        id: "no-description",
        title: "Midnight Archive",
        authors: ["Clara Bennett"],
        description: nil,
        coverURL: nil,
        pageCount: 286,
        status: .completed,
        format: .ebook
    )

    // No page count
    static let mockNoPageCount = Book(
        id: "no-page-count",
        title: "Voices From the Deep",
        authors: ["Eleanor West"],
        description: """
        An audiobook collection of interconnected stories set around a remote coastal town.
        """,
        coverURL: nil,
        pageCount: nil,
        status: .reading,
        format: .audiobook
    )

    // No cover
    static let mockNoCover = Book(
        id: "no-cover",
        title: "Forgotten Maps",
        authors: ["Lena Rivers"],
        description: """
        An explorer discovers a collection of maps leading to places that should not exist.
        """,
        coverURL: nil,
        pageCount: 338,
        status: .toRead,
        format: .physical
    )

    // Long author names
    static let mockLongAuthors = Book(
        id: "long-authors",
        title: "Fragments of Tomorrow",
        authors: [
            "Alexandra Elizabeth Montgomery",
            "Christopher Nathaniel Richardson"
        ],
        description: """
        A speculative fiction novel about memory, technology, and the consequences of predicting the future.
        """,
        coverURL: nil,
        pageCount: 421,
        status: .completed,
        format: .ebook
    )

    // Very short book
    static let mockShortBook = Book(
        id: "short-book",
        title: "Small Things",
        authors: ["Mia Lee"],
        description: """
        A short collection of reflective stories.
        """,
        coverURL: nil,
        pageCount: 84,
        status: .completed,
        format: .physical
    )

    // Very large page count
    static let mockHugeBook = Book(
        id: "huge-book",
        title: "The Endless Kingdom",
        authors: ["Nathan Cole"],
        description: """
        An enormous fantasy epic spanning generations, kingdoms, wars, and political alliances.
        """,
        coverURL: nil,
        pageCount: 1452,
        status: .reading,
        format: .physical
    )


    // MARK: - Collections

    static let mockBooks: [Book] = [
        mockFourthWing,
        mockTomorrow,
        mockProjectHailMary,
        mockIronFlame,
        mockDune,
        mockCirce,
        mockSixOfCrows,

        // Edge cases
        mockLongTitle,
        mockTwoAuthors,
        mockNoDescription,
        mockNoPageCount,
        mockNoCover,
        mockLongAuthors,
        mockShortBook,
        mockHugeBook
    ]

    static let edgeCaseBooks: [Book] = [
        mockLongTitle,
        mockTwoAuthors,
        mockNoDescription,
        mockNoPageCount,
        mockNoCover,
        mockLongAuthors,
        mockShortBook,
        mockHugeBook
    ]
}
