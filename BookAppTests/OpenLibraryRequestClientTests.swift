import Foundation
import Testing
@testable import Book_App

struct OpenLibraryRequestClientTests {
    @Test func repeatedAndConcurrentRequestsShareOneDownload() async throws {
        let probe = CatalogueTransportProbe(status: 200)
        let client = OpenLibraryRequestClient(minimumInterval: 0, cacheDirectory: nil, transport: { request in
            try await probe.respond(request)
        })
        let url = try #require(URL(string: "https://example.invalid/search.json?q=books"))
        async let first = client.data(for: url)
        async let second = client.data(for: url)
        let values = try await (first, second)
        #expect(values.0 == values.1)
        _ = try await client.data(for: url)
        #expect(await probe.calls == 1)
    }

    @Test func rateLimitStopsRequestsToOtherURLsWithoutRetrying() async throws {
        let probe = CatalogueTransportProbe(status: 429)
        let client = OpenLibraryRequestClient(minimumInterval: 0, cacheDirectory: nil, transport: { request in
            try await probe.respond(request)
        })
        for path in ["first", "second"] {
            let url = try #require(URL(string: "https://example.invalid/\(path)"))
            do {
                _ = try await client.data(for: url)
                Issue.record("A rate-limited request must fail.")
            } catch {}
        }
        #expect(await probe.calls == 1)
    }

    @Test func cacheSurvivesClientRecreation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let probe = CatalogueTransportProbe(status: 200)
        let url = try #require(URL(string: "https://example.invalid/works/book.json"))
        let first = OpenLibraryRequestClient(minimumInterval: 0, cacheDirectory: directory, transport: { request in
            try await probe.respond(request)
        })
        let expected = try await first.data(for: url)
        let second = OpenLibraryRequestClient(minimumInterval: 0, cacheDirectory: directory, transport: { request in
            try await probe.respond(request)
        })
        #expect(try await second.data(for: url) == expected)
        #expect(await probe.calls == 1)
    }

    @Test func cooldownSurvivesClientRecreation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let probe = CatalogueTransportProbe(status: 429)
        let url = try #require(URL(string: "https://example.invalid/search.json"))
        for _ in 0..<2 {
            let client = OpenLibraryRequestClient(minimumInterval: 0, cacheDirectory: directory, transport: { request in
                try await probe.respond(request)
            })
            do { _ = try await client.data(for: url) } catch {}
        }
        #expect(await probe.calls == 1)
    }

    @Test func requestsToDifferentURLsAreSpacedApart() async throws {
        let probe = CatalogueTransportProbe(status: 200)
        let client = OpenLibraryRequestClient(minimumInterval: 0.05, cacheDirectory: nil, transport: { request in
            try await probe.respond(request)
        })
        for path in ["first", "second"] {
            let url = try #require(URL(string: "https://example.invalid/\(path)"))
            _ = try await client.data(for: url)
        }
        let dates = await probe.requestDates
        #expect(dates.count == 2)
        #expect(dates[1].timeIntervalSince(dates[0]) >= 0.045)
    }

    @Test func connectionFailureStopsFurtherRequests() async throws {
        let probe = CatalogueTransportProbe(status: 200)
        let client = OpenLibraryRequestClient(minimumInterval: 0, cacheDirectory: nil, transport: { request in
            _ = try await probe.respond(request)
            throw URLError(.cannotConnectToHost)
        })
        for path in ["first", "second"] {
            let url = try #require(URL(string: "https://example.invalid/\(path)"))
            do { _ = try await client.data(for: url) } catch {}
        }
        #expect(await probe.calls == 1)
    }
}

private actor CatalogueTransportProbe {
    private(set) var calls = 0
    private(set) var requestDates: [Date] = []
    let status: Int

    init(status: Int) { self.status = status }

    func respond(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
        calls += 1
        requestDates.append(Date())
        // Fixed test URLs and status codes always produce a valid HTTP response.
        guard let response = HTTPURLResponse(url: request.url ?? URL(fileURLWithPath: "/"),
                                       statusCode: status, httpVersion: "HTTP/1.1",
                                       headerFields: ["Retry-After": "300"]) else { throw URLError(.badServerResponse) }
        return (Data("cached catalogue response".utf8), response)
    }
}
