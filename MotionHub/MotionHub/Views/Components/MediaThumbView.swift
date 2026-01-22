//
//  MediaThumbView.swift
//  Motion Hub
//
//  Media thumbnail component for inspiration panel
//

import SwiftUI
import AppKit

struct MediaThumbView: View {
    let media: MediaFile?
    let mediaURL: URL?

    @State private var thumbnail: NSImage?
    @State private var isHovered = false

    init(media: MediaFile?, mediaURL: URL? = nil) {
        self.media = media
        self.mediaURL = mediaURL
    }

    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipped()
                    .grayscale(0.3)
                    .contrast(1.1)
                    .cornerRadius(6)
            } else {
                // Empty state
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        style: StrokeStyle(lineWidth: 2, dash: [5, 5])
                    )
                    .foregroundColor(AppColors.border)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 24))
                            .foregroundColor(AppColors.textDim)
                    )
            }

            // Type badge
            if let media = media {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        typeBadge(for: media.type)
                            .padding(4)
                    }
                }
            }
        }
        .frame(width: 80, height: 80)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            loadThumbnail()
        }
    }

    private func typeBadge(for type: MediaType) -> some View {
        Text(type.rawValue.uppercased())
            .font(AppFonts.mono(size: 8))
            .foregroundColor(AppColors.textPrimary)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(AppColors.bgDarkest.opacity(0.8))
            .cornerRadius(3)
    }

    private func loadThumbnail() {
        guard let mediaURL = mediaURL else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            if let image = NSImage(contentsOf: mediaURL) {
                DispatchQueue.main.async {
                    self.thumbnail = image
                }
            }
        }
    }
}

// MARK: - Preview
struct MediaThumbView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 12) {
            MediaThumbView(media: nil)

            MediaThumbView(
                media: MediaFile(filename: "test.jpg", type: .image)
            )
        }
        .padding()
        .background(AppColors.bgDark)
        .preferredColorScheme(.dark)
    }
}
