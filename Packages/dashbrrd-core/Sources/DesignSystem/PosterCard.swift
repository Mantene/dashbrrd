import SwiftUI
import CoreModel

/// Shared poster tile for library grids. Posters come from Sonarr/Radarr `remoteUrl`s
/// (public TMDB/TVDB URLs), so no auth header is needed for image loading in Phase 2.
public struct PosterCard: View {
    let item: MediaItem

    public init(item: MediaItem) {
        self.item = item
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .fill(.quaternary)
                AsyncImage(url: item.posterURL) { phase in
                    switch phase {
                    case let .success(image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .empty:
                        ProgressView()
                    case .failure:
                        Image(systemName: item.serviceKind.symbolName)
                            .font(.largeTitle)
                            .foregroundStyle(item.serviceKind.accentColor)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
            .overlay(alignment: .topTrailing) {
                if !item.monitored {
                    Image(systemName: "bell.slash.fill")
                        .font(.caption2)
                        .padding(DS.Spacing.xs)
                        .background(.ultraThinMaterial, in: Circle())
                        .padding(DS.Spacing.xs)
                }
            }

            Text(item.title)
                .font(.caption).fontWeight(.medium)
                .lineLimit(1)
            if let subtitle = item.subtitle {
                Text(subtitle)
                    .font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
