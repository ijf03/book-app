import Foundation

/// Open Library subjects mix genres with people, places and cataloguing labels.
/// Only explicit recognised genre terms are mapped; titles/authors are never classifiers.
/// Priority is deterministic and favours specific genres over broad Fiction.
nonisolated enum OpenLibraryGenre {
    static func primary(from subjects: [String]) -> String? {
        let terms = Set(subjects.flatMap { subject in
            subject.lowercased().split(whereSeparator: { ",;/".contains($0) })
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        })
        let genres: [(String, Set<String>)] = [
            ("Science fiction", ["science fiction", "science fiction & fantasy", "dystopian fiction", "dystopias"]),
            ("Fantasy", ["fantasy", "fantasy fiction", "fantasy & magic", "magical realism"]),
            ("Mystery", ["mystery", "mystery fiction", "mystery and detective stories", "detective and mystery stories", "mystery & detective"]),
            ("Thriller", ["thriller", "thrillers", "suspense fiction", "thriller fiction"]),
            ("Horror", ["horror", "horror fiction", "horror tales"]),
            ("Romance", ["romance", "romance fiction", "love stories"]),
            ("Historical fiction", ["historical fiction"]),
            ("Biography", ["biography", "biographies", "autobiography", "autobiographies", "memoir", "memoirs"]),
            ("Poetry", ["poetry", "poems"]),
            ("Comics & graphic novels", ["comics", "graphic novels", "comics & graphic novels", "manga"]),
            ("History", ["history"]),
            ("Science", ["science", "popular science"]),
            ("Philosophy", ["philosophy"]),
            ("Self-help", ["self-help", "self help", "personal development"]),
            ("Literary fiction", ["literary fiction"]),
            ("Fiction", ["fiction"]),
            ("Non-fiction", ["nonfiction", "non-fiction"])
        ]
        return genres.first { !$0.1.isDisjoint(with: terms) }?.0
    }

    static func workID(_ raw: String) -> String? {
        let value = raw.hasPrefix("/works/") ? String(raw.dropFirst(7)) : raw
        guard value.range(of: "^OL[0-9]+W$", options: .regularExpression) != nil else { return nil }
        return "/works/" + value
    }
}
