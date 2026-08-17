import SwiftUI
import AppKit

/// Fetches and permanently caches the official artwork PNGs.
///
/// These files never change, so once one is on disk it is never re-fetched. The
/// actor hands back `Data` rather than `NSImage` so nothing non-Sendable crosses
/// the isolation boundary; decoding happens on the main actor, where the decoded
/// images are cached separately.
actor ArtworkStore {
    static let shared = ArtworkStore()

    private let directory: URL
    private var inFlight: [Int: Task<Data?, Never>] = [:]

    init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("PokeBinder/artwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func data(for dex: Int) async -> Data? {
        if let existing = inFlight[dex] { return await existing.value }

        let task = Task<Data?, Never> { [directory] in
            let file = directory.appendingPathComponent("\(dex).png")
            if let cached = try? Data(contentsOf: file), !cached.isEmpty {
                return cached
            }
            guard let (downloaded, response) = try? await URLSession.shared
                    .data(from: Pokedex.artworkURL(for: dex)),
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  !downloaded.isEmpty
            else { return nil }
            try? downloaded.write(to: file, options: .atomic)
            return downloaded
        }

        inFlight[dex] = task
        let result = await task.value
        inFlight[dex] = nil
        return result
    }

    /// Warm the cache for a page so flipping to it is never blank.
    func prefetch(page: Int) {
        guard (1...Pokedex.pageCount).contains(page) else { return }
        for side in BinderSide.allCases {
            for slot in 1...Pokedex.slotsPerSide {
                guard let dex = Pokedex.dexNumber(page: page, side: side, slot: slot),
                      inFlight[dex] == nil else { continue }
                Task { _ = await data(for: dex) }
            }
        }
    }
}

/// Decoded images, kept on the main actor so views can hit them synchronously and
/// avoid a flash of placeholder when flipping back to a page you've already seen.
@MainActor
enum ArtworkImageCache {
    private static let cache: NSCache<NSNumber, NSImage> = {
        let cache = NSCache<NSNumber, NSImage>()
        cache.countLimit = 200   // the whole Gen 1 set fits comfortably
        return cache
    }()

    static func image(for dex: Int) -> NSImage? {
        cache.object(forKey: NSNumber(value: dex))
    }

    static func store(_ image: NSImage, for dex: Int) {
        cache.setObject(image, forKey: NSNumber(value: dex))
    }
}

/// The artwork inside one pocket.
///
/// The cache is read while the body is being built, not from `.task`. `.task` only
/// runs *after* the first render, so a pocket handed a dex it already has art for
/// still drew one empty frame and then popped the image in — eight of those at once
/// is the flash of a page refreshing itself right after a turn lands.
@MainActor
struct CardArtworkView: View {
    let dexNumber: Int

    /// Art this view fetched itself, tagged with the dex it belongs to so that a
    /// pocket handed a new number never shows the previous one's image.
    @State private var fetched: FetchedArtwork?

    private var artwork: NSImage? {
        if let fetched, fetched.dex == dexNumber { return fetched.image }
        return ArtworkImageCache.image(for: dexNumber)
    }

    var body: some View {
        Group {
            if let artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                // Deliberately quiet: a spinner in all 8 pockets would be noisier
                // than the artwork simply arriving.
                Color.clear
            }
        }
        .task(id: dexNumber) { await load() }
    }

    private func load() async {
        // Already on screen from the cache — nothing to fetch, and nothing to fade.
        guard artwork == nil else { return }
        guard let data = await ArtworkStore.shared.data(for: dexNumber),
              let decoded = NSImage(data: data)
        else { return }
        ArtworkImageCache.store(decoded, for: dexNumber)
        withAnimation(.easeOut(duration: 0.18)) {
            fetched = FetchedArtwork(dex: dexNumber, image: decoded)
        }
    }
}

private struct FetchedArtwork {
    let dex: Int
    let image: NSImage
}
