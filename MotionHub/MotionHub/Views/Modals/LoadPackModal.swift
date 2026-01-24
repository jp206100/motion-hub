//
//  LoadPackModal.swift
//  Motion Hub
//
//  Modal for loading saved packs
//

import SwiftUI

struct LoadPackModal: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var packManager: PackManager

    @State private var packs: [PackInfo] = []
    @State private var selectedPack: PackInfo?
    @State private var isLoading = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var errorSuggestion: String?

    private let logger = DebugLogger.shared
    private let gridColumns = [
        GridItem(.adaptive(minimum: 200), spacing: 16)
    ]

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    appState.showLoadPackModal = false
                }

            // Modal content
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("Load Pack")
                        .font(AppFonts.displayBold(size: 18))
                        .foregroundColor(AppColors.textPrimary)
                        .textCase(.uppercase)
                        .tracking(1)

                    Spacer()

                    Button(action: {
                        appState.showLoadPackModal = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                // Pack grid
                if packs.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: gridColumns, spacing: 16) {
                            ForEach(packs) { pack in
                                PackCard(
                                    pack: pack,
                                    isSelected: selectedPack?.id == pack.id,
                                    onSelect: {
                                        selectedPack = pack
                                    }
                                )
                            }
                        }
                        .padding(.vertical)
                    }
                    .frame(maxHeight: 400)
                }

                // Buttons
                HStack(spacing: 12) {
                    if selectedPack != nil {
                        Button(action: {
                            deletePack()
                        }) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(DangerButtonStyle())
                    }

                    Spacer()

                    Button("Cancel") {
                        appState.showLoadPackModal = false
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button("Load Selected") {
                        loadSelectedPack()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(selectedPack == nil || isLoading)
                }
            }
            .padding(30)
            .frame(width: 600)
            .background(AppColors.bgDark)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.borderLight, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 20)
            .alert("Load Failed", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage + (errorSuggestion.map { "\n\n\($0)" } ?? ""))
            }
        }
        .onAppear {
            loadPacksList()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundColor(AppColors.textDim)

            Text("No saved packs")
                .font(AppFonts.displayBold(size: 14))
                .foregroundColor(AppColors.textSecondary)

            Text("Save your first pack to see it here")
                .font(AppFonts.mono(size: 11))
                .foregroundColor(AppColors.textDim)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }

    // MARK: - Actions

    private func loadPacksList() {
        logger.debug("Loading packs list", context: "LoadPackModal")
        packs = packManager.listPacks()
        logger.info("Found \(packs.count) saved packs", context: "LoadPackModal")
    }

    private func loadSelectedPack() {
        guard let pack = selectedPack else { return }
        isLoading = true
        logger.info("User initiated pack load: '\(pack.name)'", context: "LoadPackModal")

        Task {
            do {
                let loadedPack = try await packManager.loadPack(id: pack.id)
                logger.info("Pack loaded successfully: '\(loadedPack.name)'", context: "LoadPackModal")

                await MainActor.run {
                    appState.currentPack = loadedPack
                    appState.loadPackSettings(loadedPack.settings)
                    appState.showLoadPackModal = false
                    isLoading = false
                }
            } catch let error as PackSaveError {
                logger.error("Pack load failed with PackSaveError", error: error, context: "LoadPackModal")
                await MainActor.run {
                    errorMessage = error.errorDescription ?? "Unknown error occurred"
                    errorSuggestion = error.recoverySuggestion
                    showErrorAlert = true
                    isLoading = false
                }
            } catch {
                logger.error("Pack load failed with unexpected error", error: error, context: "LoadPackModal")
                await MainActor.run {
                    errorMessage = "Failed to load pack: \(error.localizedDescription)"
                    errorSuggestion = "The pack may be corrupted. Try deleting and recreating it."
                    showErrorAlert = true
                    isLoading = false
                }
            }
        }
    }

    private func deletePack() {
        guard let pack = selectedPack else { return }
        logger.info("User initiated pack delete: '\(pack.name)'", context: "LoadPackModal")

        // Show confirmation alert
        let alert = NSAlert()
        alert.messageText = "Delete Pack"
        alert.informativeText = "Are you sure you want to delete \"\(pack.name)\"? This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try packManager.deletePack(id: pack.id)
                logger.info("Pack deleted successfully: '\(pack.name)'", context: "LoadPackModal")
                selectedPack = nil
                loadPacksList()
            } catch let error as PackSaveError {
                logger.error("Pack delete failed with PackSaveError", error: error, context: "LoadPackModal")
                errorMessage = error.errorDescription ?? "Unknown error occurred"
                errorSuggestion = error.recoverySuggestion
                showErrorAlert = true
            } catch {
                logger.error("Pack delete failed with unexpected error", error: error, context: "LoadPackModal")
                errorMessage = "Failed to delete pack: \(error.localizedDescription)"
                errorSuggestion = nil
                showErrorAlert = true
            }
        }
    }
}

// MARK: - Pack Card
struct PackCard: View {
    let pack: PackInfo
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Thumbnails
            HStack(spacing: 4) {
                ForEach(0..<min(3, pack.thumbnailURLs.count), id: \.self) { index in
                    if let image = NSImage(contentsOf: pack.thumbnailURLs[index]) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipped()
                            .grayscale(0.3)
                            .contrast(1.1)
                    }
                }

                if pack.thumbnailURLs.count < 3 {
                    ForEach(0..<(3 - pack.thumbnailURLs.count), id: \.self) { _ in
                        Rectangle()
                            .fill(AppColors.bgLight)
                            .frame(width: 60, height: 60)
                    }
                }
            }
            .cornerRadius(4)

            // Pack info
            VStack(alignment: .leading, spacing: 4) {
                Text(pack.name)
                    .font(AppFonts.displayBold(size: 13))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text("\(pack.mediaCount) files")
                        .font(AppFonts.mono(size: 10))
                        .foregroundColor(AppColors.textSecondary)

                    Text("•")
                        .foregroundColor(AppColors.textDim)

                    Text(pack.createdAt, style: .date)
                        .font(AppFonts.mono(size: 10))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding(12)
        .frame(width: 200)
        .background(isSelected ? AppColors.bgLighter : AppColors.bgLight)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? AppColors.accent : AppColors.border, lineWidth: isSelected ? 2 : 1)
        )
        .onTapGesture {
            onSelect()
        }
    }
}

struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14))
            .foregroundColor(AppColors.danger)
            .frame(width: 44, height: 44)
            .background(AppColors.bgLight)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(AppColors.border, lineWidth: 1)
            )
    }
}
