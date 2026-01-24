//
//  SavePackModal.swift
//  Motion Hub
//
//  Modal for saving current pack
//

import SwiftUI

struct SavePackModal: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var packManager: PackManager

    @State private var packName: String = ""
    @State private var isSaving = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var errorSuggestion: String?

    private let logger = DebugLogger.shared

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    appState.showSavePackModal = false
                }

            // Modal content
            VStack(spacing: 20) {
                // Header
                Text("Save Pack")
                    .font(AppFonts.displayBold(size: 18))
                    .foregroundColor(AppColors.textPrimary)
                    .textCase(.uppercase)
                    .tracking(1)

                // Pack name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pack Name")
                        .font(AppFonts.display(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                        .textCase(.uppercase)

                    TextField("Enter pack name", text: $packName)
                        .textFieldStyle(.plain)
                        .font(AppFonts.mono(size: 14))
                        .foregroundColor(AppColors.textPrimary)
                        .padding(12)
                        .background(AppColors.bgLight)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(AppColors.border, lineWidth: 1)
                        )
                }

                // Summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("What will be saved:")
                        .font(AppFonts.display(size: 11))
                        .foregroundColor(AppColors.textSecondary)

                    VStack(alignment: .leading, spacing: 4) {
                        summaryItem(
                            icon: "photo.on.rectangle",
                            text: "\(appState.currentPack?.mediaFiles.count ?? 0) media files"
                        )
                        summaryItem(
                            icon: "slider.horizontal.3",
                            text: "Current control settings"
                        )
                        summaryItem(
                            icon: "wand.and.stars",
                            text: "Extracted visual artifacts"
                        )
                    }
                }
                .padding()
                .background(AppColors.bgLight)
                .cornerRadius(6)

                // Buttons
                HStack(spacing: 12) {
                    Button("Cancel") {
                        appState.showSavePackModal = false
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button("Save") {
                        savePack()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(packName.isEmpty || isSaving)
                }
            }
            .padding(30)
            .frame(width: 400)
            .background(AppColors.bgDark)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.borderLight, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 20)
            .alert("Save Failed", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage + (errorSuggestion.map { "\n\n\($0)" } ?? ""))
            }
        }
    }

    private func summaryItem(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(AppColors.accent)
                .frame(width: 16)

            Text(text)
                .font(AppFonts.mono(size: 11))
                .foregroundColor(AppColors.textPrimary)
        }
    }

    private func savePack() {
        guard !packName.isEmpty else { return }
        isSaving = true
        logger.info("User initiated pack save: '\(packName)'", context: "SavePackModal")

        Task {
            do {
                // Get media files URLs
                let mediaFiles = appState.currentPack?.mediaFiles ?? []
                logger.debug("Collecting \(mediaFiles.count) media file URLs", context: "SavePackModal")

                let urls = mediaFiles.compactMap { file -> URL? in
                    guard let pack = appState.currentPack else { return nil }
                    return packManager.mediaURL(for: file, in: pack.id)
                }

                logger.debug("Resolved \(urls.count) valid URLs", context: "SavePackModal")

                // Check if we have any files to save
                if urls.isEmpty && mediaFiles.isEmpty {
                    logger.warning("No media files to save", context: "SavePackModal")
                    await MainActor.run {
                        errorMessage = "No media files to save"
                        errorSuggestion = "Add images, videos, or GIFs to your pack before saving"
                        showErrorAlert = true
                        isSaving = false
                    }
                    return
                }

                let pack = try await packManager.savePack(
                    name: packName,
                    mediaFiles: urls,
                    settings: appState.getCurrentSettings()
                )

                logger.info("Pack save completed successfully", context: "SavePackModal")

                await MainActor.run {
                    appState.currentPack = pack
                    appState.showSavePackModal = false
                    isSaving = false
                }
            } catch let error as PackSaveError {
                logger.error("Pack save failed with PackSaveError", error: error, context: "SavePackModal")
                await MainActor.run {
                    errorMessage = error.errorDescription ?? "Unknown error occurred"
                    errorSuggestion = error.recoverySuggestion
                    showErrorAlert = true
                    isSaving = false
                }
            } catch {
                logger.error("Pack save failed with unexpected error", error: error, context: "SavePackModal")
                await MainActor.run {
                    errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
                    errorSuggestion = "Please try again. If the problem persists, restart the application."
                    showErrorAlert = true
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFonts.displayBold(size: 13))
            .textCase(.uppercase)
            .foregroundColor(AppColors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                LinearGradient(
                    colors: configuration.isPressed
                        ? [AppColors.accentDim, AppColors.accentDim]
                        : [AppColors.accent, AppColors.accentDim],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(6)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFonts.displayBold(size: 13))
            .textCase(.uppercase)
            .foregroundColor(AppColors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(AppColors.bgLight)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(AppColors.border, lineWidth: 1)
            )
    }
}
