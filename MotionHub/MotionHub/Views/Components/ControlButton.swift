//
//  ControlButton.swift
//  Motion Hub
//
//  Button component for controls
//

import SwiftUI

struct ControlButton: View {
    let label: String
    let icon: String
    let isToggle: Bool
    @Binding var isActive: Bool
    let action: () -> Void

    @State private var isHovered = false

    init(label: String,
         icon: String,
         isToggle: Bool = false,
         isActive: Binding<Bool> = .constant(false),
         action: @escaping () -> Void) {
        self.label = label
        self.icon = icon
        self.isToggle = isToggle
        self._isActive = isActive
        self.action = action
    }

    var body: some View {
        Button(action: {
            if isToggle {
                isActive.toggle()
            }
            action()
        }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))

                Text(label)
                    .font(AppFonts.displayBold(size: 13))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(buttonBackground)
            .foregroundColor(buttonForeground)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(buttonBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var buttonBackground: some View {
        Group {
            if isToggle && isActive {
                AppColors.accent.opacity(0.15)
            } else if !isToggle {
                LinearGradient(
                    colors: isHovered
                        ? [AppColors.bgLighter, AppColors.bgLight]
                        : [AppColors.bgLight, AppColors.bgMid],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                AppColors.bgLight
            }
        }
    }

    private var buttonForeground: Color {
        if isToggle && isActive {
            return AppColors.accent
        } else if !isToggle && isHovered {
            return AppColors.accent
        }
        return AppColors.textPrimary
    }

    private var buttonBorder: Color {
        if isToggle && isActive {
            return AppColors.accent
        }
        return AppColors.border
    }
}

// MARK: - Preview
struct ControlButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            ControlButton(
                label: "Reset",
                icon: "arrow.counterclockwise",
                action: {}
            )

            ControlButton(
                label: "Monochrome",
                icon: "circle.lefthalf.filled",
                isToggle: true,
                isActive: .constant(true),
                action: {}
            )
        }
        .padding()
        .background(AppColors.bgDark)
        .preferredColorScheme(.dark)
    }
}
