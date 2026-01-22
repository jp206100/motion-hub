//
//  KnobView.swift
//  Motion Hub
//
//  Rotary knob control component
//

import SwiftUI

struct KnobView: View {
    @Binding var value: Double  // 0.0 - 1.0
    let label: String
    let displayValue: String
    let stepped: Bool
    let steps: [String]?

    @State private var isDragging = false
    @State private var lastDragValue: CGFloat = 0

    private let knobSize: CGFloat = 60
    private let rotationRange: Double = 270  // degrees
    private let startAngle: Double = 135     // -135° from top

    init(value: Binding<Double>,
         label: String,
         displayValue: String,
         stepped: Bool = false,
         steps: [String]? = nil) {
        self._value = value
        self.label = label
        self.displayValue = displayValue
        self.stepped = stepped
        self.steps = steps
    }

    var body: some View {
        VStack(spacing: 8) {
            // Knob
            ZStack {
                // Background circle
                Circle()
                    .fill(AppColors.bgLight)
                    .frame(width: knobSize, height: knobSize)

                // Value arc
                Circle()
                    .trim(from: 0, to: value)
                    .stroke(
                        AppColors.accent,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: knobSize - 6, height: knobSize - 6)
                    .rotationEffect(.degrees(-90 + startAngle))

                // Center indicator line
                Rectangle()
                    .fill(AppColors.accent)
                    .frame(width: 2, height: knobSize / 2.5)
                    .offset(y: -knobSize / 4.5)
                    .rotationEffect(.degrees(-startAngle + (value * rotationRange)))
                    .shadow(color: AppColors.accent.opacity(0.5), radius: 4)

                // Center dot
                Circle()
                    .fill(AppColors.bgDarkest)
                    .frame(width: 8, height: 8)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            lastDragValue = gesture.location.y
                        }

                        let delta = lastDragValue - gesture.location.y
                        let sensitivity: CGFloat = 0.005
                        var newValue = value + Double(delta * sensitivity)
                        newValue = max(0, min(1, newValue))

                        if stepped, let steps = steps {
                            let stepCount = steps.count
                            let stepIndex = Int(round(newValue * Double(stepCount - 1)))
                            newValue = Double(stepIndex) / Double(stepCount - 1)
                        }

                        value = newValue
                        lastDragValue = gesture.location.y
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )

            // Label
            Text(label)
                .font(AppFonts.display(size: 11))
                .foregroundColor(AppColors.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)

            // Value display
            Text(displayValue)
                .font(AppFonts.mono(size: 13))
                .foregroundColor(AppColors.textPrimary)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Preview
struct KnobView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 20) {
            KnobView(
                value: .constant(0.72),
                label: "Intensity",
                displayValue: "72%"
            )

            KnobView(
                value: .constant(0.5),
                label: "Speed",
                displayValue: "2X",
                stepped: true,
                steps: ["1X", "2X", "3X", "4X"]
            )
        }
        .padding()
        .background(AppColors.bgDark)
        .preferredColorScheme(.dark)
    }
}
