import SwiftUI

/// Poster thumbnail with a graceful placeholder. Used in library and search lists.
struct PosterImage: View {
    let url: URL?
    var width: CGFloat = 60
    var height: CGFloat = 90

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case let .success(image):
                image.resizable().aspectRatio(contentMode: .fill)
            case .failure:
                placeholder
            case .empty:
                ProgressView()
            @unknown default:
                placeholder
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(.secondarySystemBackground))
        )
    }

    private var placeholder: some View {
        Image(systemName: "photo")
            .foregroundStyle(.secondary)
            .frame(width: width, height: height)
    }
}
