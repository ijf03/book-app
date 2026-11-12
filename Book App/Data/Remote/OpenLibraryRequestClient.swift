import Foundation
import CryptoKit

/// One queue for catalogue and cover requests, shared across screens and repositories.
actor OpenLibraryRequestClient {
    static let shared = OpenLibraryRequestClient()

    typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)
    private struct CacheEntry: Codable {
        let data: Data
        let expires: Date
    }

    private struct Flight {
        let task: Task<Data, Error>
        var waiters: Set<UUID>
    }

    private let transport: Transport
    private let minimumInterval: TimeInterval
    private let cacheDirectory: URL?
    private var cache: [URL: CacheEntry] = [:]
    private var inFlight: [URL: Flight] = [:]
    private var tail: Task<Void, Never>?
    private var nextRequest = Date.distantPast
    private var blockedUntil = Date.distantPast

    init(minimumInterval: TimeInterval = 2, cacheDirectory: URL? = FileManager.default.urls(
        for: .cachesDirectory, in: .userDomainMask
    ).first?.appendingPathComponent("OpenLibrary", isDirectory: true),
         transport: @escaping Transport = { request in
             let (data, response) = try await URLSession.shared.data(for: request)
             guard let response = response as? HTTPURLResponse else { throw OpenLibraryError.invalidResponse }
             return (data, response)
         }) {
        self.minimumInterval = minimumInterval
        self.cacheDirectory = cacheDirectory
        self.transport = transport
        if let file = cacheDirectory?.appendingPathComponent("cooldown.json"),
           let data = try? Data(contentsOf: file),
           let date = try? JSONDecoder().decode(Date.self, from: data) {
            blockedUntil = date
        }
    }

    func data(for url: URL) async throws -> Data {
        try Task.checkCancellation()
        if let entry = cached(url), entry.expires > Date() { return entry.data }
        let waiter = UUID()
        let task: Task<Data, Error>
        if var flight = inFlight[url] {
            flight.waiters.insert(waiter)
            inFlight[url] = flight
            task = flight.task
        } else {
            guard Date() >= blockedUntil else { throw OpenLibraryError.cooldown }
            let previous = tail
            task = Task {
                await previous?.value
                try Task.checkCancellation()
                return try await self.download(url)
            }
            inFlight[url] = Flight(task: task, waiters: [waiter])
            tail = Task { _ = try? await task.value }
        }
        return try await withTaskCancellationHandler {
            defer { release(url, waiter: waiter) }
            let data = try await task.value
            try Task.checkCancellation()
            return data
        } onCancel: {
            Task { await self.release(url, waiter: waiter) }
        }
    }

    private func release(_ url: URL, waiter: UUID) {
        guard var flight = inFlight[url], flight.waiters.remove(waiter) != nil else { return }
        if flight.waiters.isEmpty {
            flight.task.cancel()
            inFlight[url] = nil
        } else {
            inFlight[url] = flight
        }
    }

    private func pause(for seconds: TimeInterval) {
        blockedUntil = Date().addingTimeInterval(seconds)
        if let file = cacheDirectory?.appendingPathComponent("cooldown.json"),
           let data = try? JSONEncoder().encode(blockedUntil) {
            try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: file, options: .atomic)
        }
    }

    private func download(_ url: URL) async throws -> Data {
        // Recheck after waiting: another queued request may have received a rate limit.
        guard Date() >= blockedUntil else { throw OpenLibraryError.cooldown }
        let delay = nextRequest.timeIntervalSinceNow
        if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
        guard Date() >= blockedUntil else { throw OpenLibraryError.cooldown }
        nextRequest = Date().addingTimeInterval(minimumInterval)
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("BookApp/1.0", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await transport(request)
            try Task.checkCancellation()
            guard (200..<300).contains(response.statusCode) else {
                if response.statusCode == 429 || response.statusCode == 403 {
                    let seconds = response.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
                    pause(for: max(300, seconds ?? 300))
                } else if response.statusCode >= 500 {
                    pause(for: 60)
                }
                throw OpenLibraryError.httpError(statusCode: response.statusCode)
            }
            // Search results change more often than book details and cover artwork.
            let lifetime: TimeInterval = url.path == "/search.json" ? 3_600 : 86_400
            let entry = CacheEntry(data: data, expires: Date().addingTimeInterval(lifetime))
            if cache.count >= 128 { cache.removeAll(keepingCapacity: true) }
            cache[url] = entry
            if let file = cacheFile(url), let encoded = try? JSONEncoder().encode(entry) {
                try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? encoded.write(to: file, options: .atomic)
            }
            return data
        } catch {
            if !(error is OpenLibraryError), !(error is CancellationError), (error as? URLError)?.code != .cancelled {
                pause(for: 60)
            }
            throw error
        }
    }

    private func cached(_ url: URL) -> CacheEntry? {
        if let entry = cache[url] { return entry }
        guard let file = cacheFile(url),
              let data = try? Data(contentsOf: file),
              let entry = try? JSONDecoder().decode(CacheEntry.self, from: data) else { return nil }
        return entry
    }

    private func cacheFile(_ url: URL) -> URL? {
        let name = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        return cacheDirectory?.appendingPathComponent(name)
    }
}
