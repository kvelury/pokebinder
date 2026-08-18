import AppKit
import SwiftUI

enum TypeIconAssets {
    private static let resourceBundle: Bundle = {
        if let resourceURL = Bundle.main.resourceURL,
           let appBundle = Bundle(
               url: resourceURL.appendingPathComponent("PokeBinder_PokeBinder.bundle")
           ) {
            return appBundle
        }
        return .module
    }()

    private static let images: [PokemonType: NSImage] = Dictionary(
        uniqueKeysWithValues: PokemonType.allCases.compactMap { type in
            guard let url = resourceBundle.url(
                forResource: type.rawValue,
                withExtension: "svg",
                subdirectory: "TypeIcons"
            ), let image = NSImage(contentsOf: url) else {
                return nil
            }
            return (type, image)
        }
    )

    static func image(for type: PokemonType) -> NSImage? {
        images[type]
    }
}

struct TypeIconView: View {
    let type: PokemonType
    let size: CGFloat
    var isMuted = false
    var tooltip: String? = nil
    var showsTooltip = true

    var body: some View {
        let icon = ZStack {
            Circle().fill(type.color)

            if let image = TypeIconAssets.image(for: type) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.21)
            } else {
                Text(type.title.prefix(1))
                    .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .overlay(
            Circle().strokeBorder(.white.opacity(0.34), lineWidth: max(0.5, size * 0.035))
        )
        .saturation(isMuted ? 0.2 : 1)
        .opacity(isMuted ? 0.72 : 1)
        .accessibilityLabel(type.title)

        if showsTooltip {
            icon.hoverTooltip(tooltip ?? type.title)
        } else {
            icon
        }
    }
}

struct TypeIconGroup: View {
    let types: [PokemonType]
    let size: CGFloat
    var spacing: CGFloat = 4
    var isMuted = false
    var showsTooltip = true

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(types) { type in
                TypeIconView(type: type, size: size, isMuted: isMuted, showsTooltip: showsTooltip)
            }
        }
    }
}
