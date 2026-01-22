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
        packs = packManager.listPacks()
    }

    private func loadSelectedPack() {
        guard let pack = selectedPack else { return }
        isLoading = true

        Task {
            do {
                let loadedPack = try await packManager.loadPack(id: pack.id)
                await MainActor.run {
                    appState.currentPack = loadedPack
                    appState.loadPackSettings(loadedPack.settings)
                    appState.showLoadPackModal = false
                    isLoading = false
                }
            } catch {
                print("Error loading pack: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }

    private func deletePack() {
        guard let pack = selectedPack else { return }

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
                selectedPack = nil
                loadPacksList()
            } catch {
                print("Error deleting pack: \(error)")
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
