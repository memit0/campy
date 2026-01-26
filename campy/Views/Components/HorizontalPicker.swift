//
//  HorizontalPicker.swift
//  campy
//
//  Horizontal scrolling picker for time and bet selection
//

import SwiftUI

struct HorizontalPicker<T: Hashable>: View {
    let items: [T]
    @Binding var selectedIndex: Int?
    let itemLabel: (T) -> String

    var body: some View {
        GeometryReader { geometry in
            let itemWidth: CGFloat = 60
            let spacing: CGFloat = CampySpacing.md
            let sidePadding = (geometry.size.width - itemWidth) / 2

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: spacing) {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                            PickerItem(
                                label: itemLabel(item),
                                isSelected: index == selectedIndex
                            )
                            .id(index)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedIndex = index
                                }
                            }
                        }
                    }
                    .padding(.horizontal, sidePadding)
                }
                .onChange(of: selectedIndex) { _, newValue in
                    if let newValue = newValue {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(height: 50)
    }
}

struct PickerItem: View {
    let label: String
    let isSelected: Bool

    var body: some View {
        Text(label)
            .font(isSelected ? CampyFonts.pickerSelected() : CampyFonts.picker())
            .foregroundColor(isSelected ? CampyColors.textPrimary : CampyColors.textMuted)
            .frame(width: 60)
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Time Picker
struct TimePicker: View {
    @Binding var selectedIndex: Int?

    var body: some View {
        HorizontalPicker(
            items: CampyOptions.timeOptions,
            selectedIndex: $selectedIndex
        ) { minutes in
            "\(minutes)"
        }
    }
}

// MARK: - Bet Picker
struct BetPicker: View {
    @Binding var selectedIndex: Int?

    var body: some View {
        HorizontalPicker(
            items: CampyOptions.betOptions,
            selectedIndex: $selectedIndex
        ) { amount in
            "\(amount)b"
        }
    }
}

// MARK: - Picker Toggle
enum PickerMode {
    case time
    case bet

    var icon: String {
        switch self {
        case .time: return "clock"
        case .bet: return "square.grid.2x2"
        }
    }
}

struct PickerToggle: View {
    @Binding var mode: PickerMode

    var body: some View {
        HStack(spacing: CampySpacing.xxl) {
            ToggleButton(
                icon: PickerMode.time.icon,
                isSelected: mode == .time
            ) {
                mode = .time
            }

            ToggleButton(
                icon: PickerMode.bet.icon,
                isSelected: mode == .bet
            ) {
                mode = .bet
            }
        }
    }
}

struct ToggleButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isSelected ? CampyColors.accent : CampyColors.textMuted)
        }
    }
}

#Preview {
    struct PreviewContainer: View {
        @State var timeIndex: Int? = 2
        @State var betIndex: Int? = 2
        @State var mode: PickerMode = .time

        var body: some View {
            VStack(spacing: 40) {
                VStack(spacing: CampySpacing.md) {
                    Text("Time: \(timeIndex.map { CampyOptions.timeOptions[$0] } ?? 0) min")
                        .foregroundColor(.white)
                    TimePicker(selectedIndex: $timeIndex)
                }

                VStack(spacing: CampySpacing.md) {
                    Text("Bet: \(betIndex.map { CampyOptions.betOptions[$0] } ?? 0)b")
                        .foregroundColor(.white)
                    BetPicker(selectedIndex: $betIndex)
                }

                PickerToggle(mode: $mode)
            }
            .padding()
            .background(CampyColors.background)
        }
    }

    return PreviewContainer()
}
