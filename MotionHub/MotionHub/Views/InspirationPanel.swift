//
//  InspirationPanel.swift
//  Motion Hub
//
//  Left panel showing inspiration media and pack controls
//

import SwiftUI
import UniformTypeIdentifiers

struct InspirationPanel: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var packManager: PackManager

    @State private var isDraggingOver = false
    @State private var showingFilePicker = false

    private let gridColumns = [
        GridItem(.adaptive(minimum: 80), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()
                .background(AppColors.border)

            // Media grid
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(mediaFiles) { media in
                        MediaThumbView(
                            media: media,
                            mediaURL: mediaURL(for: media)
                        )
                    }

                    // Empty slots for adding more
                    if mediaFiles.count < 12 {
                        ForEach(0..<(12 - mediaFiles.count), id: \.self) { _ in
                            MediaThumbView(media: nil)
                                .onTapGesture {
                                    showingFilePicker = true
                                }
                        }
                    }
                }
                .padding()
            }
            .frame(maxHeight: .infinity)

            Divider()
                .background(AppColors.border)

            // Pack actions
            packActions
                .padding()
        }
        .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
            handleDrop(providers: providers)
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.image, .movie, .gif],
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Inspiration Pack")
                .font(AppFonts.displayBold(size: 16))
                .foregroundColor(AppColors.textPrimary)
                .textCase(.uppercase)
                .tracking(1)

            if let pack = appState.currentPack {
                Text(pack.name)
                    .font(AppFonts.mono(size: 11))
                    .foregroundColor(AppColors.textSecondary)
            } else {
                Text("No pack loaded")
                    .font(AppFonts.mono(size: 11))
                    .foregroundColor(AppColors.textDim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private var packActions: some View {
        VStack(spacing: 8) {
            Button(action: { showingFilePicker = true }) {
                HStack {
                    Image(systemName: "folder.badge.plus")
                    Text("Browse Files")
                        .font(AppFonts.displayBold(size: 12))
                        .textCase(.uppercase)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(AppColors.bgLight)
                .foregroundColor(AppColors.textPrimary)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AppColors.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Button(action: { appState.showSavePackModal = true }) {
                    Image(systemName: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(AppColors.bgLight)
                        .foregroundColor(AppColors.textPrimary)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(mediaFiles.isEmpty)

                Button(action: { appState.showLoadPackModal = true }) {
                    Image(systemName: "folder")
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(AppColors.bgLight)
                        .foregroundColor(AppColors.textPrimary)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Computed Properties

    private var mediaFiles: [MediaFile] {
        appState.currentPack?.mediaFiles ?? []
    }

    private func mediaURL(for media: MediaFile) -> URL? {
        guard let pack = appState.currentPack else { return nil }
        return packManager.mediaURL(for: media, in: pack.id)
    }

    // MARK: - File Handling

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []

        for provider in providers {
            _ = provider.loadDataRepresentation(for: .fileURL) { data, error in
                if let data = data,
                   let path = String(data: data, encoding: .utf8),
                   let url = URL(string: path) {
                    urls.append(url)
                }
            }
        }

        // Process URLs after a short delay to ensure all are loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            processMediaFiles(urls)
        }

        return true
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            processMediaFiles(urls)
        case .failure(let error):
            print("Error selecting files: \(error)")
        }
    }

    private func processMediaFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }

        print("📁 Processing \(urls.count) media files...")

        // Start accessing security-scoped resources
        let accessingURLs = urls.map { url -> (URL, Bool) in
            let accessing = url.startAccessingSecurityScopedResource()
            print("  - \(url.lastPathComponent): access=\(accessing)")
            return (url, accessing)
        }

        // Create or update the current pack
        let packName = appState.currentPack?.name ?? "Untitled Pack"
        let existingPackID = appState.currentPack?.id

        // Save pack to disk (for file references)
        Task {
            do {
                print("💾 Saving pack...")
                let savedPack = try await packManager.savePack(
                    name: packName,
                    mediaFiles: urls,
                    settings: appState.getCurrentSettings(),
                    existingPackID: existingPackID
                )

                // Stop accessing security-scoped resources
                for (url, wasAccessing) in accessingURLs {
                    if wasAccessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                // Update app state on main thread
                await MainActor.run {
                    appState.currentPack = savedPack
                    print("✅ Pack saved with \(savedPack.mediaFiles.count) media files")
                    print("   Pack ID: \(savedPack.id)")
                    print("   Media files: \(savedPack.mediaFiles.map { $0.filename }.joined(separator: ", "))")
                }

                // TODO: Trigger preprocessing
                // This will be implemented when we add PreprocessingManager

            } catch {
                print("❌ Error saving pack: \(error)")
                print("   Error details: \(error.localizedDescription)")

                // Stop accessing security-scoped resources on error
                for (url, wasAccessing) in accessingURLs {
                    if wasAccessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            }
        }
    }
}
