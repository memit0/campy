//
//  BottomSheet.swift
//  campy
//
//  Custom bottom sheet component
//

import SwiftUI

struct BottomSheet<Content: View>: View {
    @Binding var isPresented: Bool
    let content: Content

    @State private var offset: CGFloat = 0
    @State private var lastOffset: CGFloat = 0

    init(isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Dimmed background
                if isPresented {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isPresented = false
                            }
                        }
                        .transition(.opacity)
                }

                // Sheet content
                if isPresented {
                    VStack(spacing: 0) {
                        // Handle
                        SheetHandle()
                            .padding(.top, CampySpacing.md)
                            .padding(.bottom, CampySpacing.sm)

                        content
                    }
                    .frame(maxWidth: .infinity)
                    .background(CampyColors.sheetBackground)
                    .cornerRadius(CampyRadius.sheet, corners: [.topLeft, .topRight])
                    .offset(y: offset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newOffset = lastOffset + value.translation.height
                                offset = max(0, newOffset)
                            }
                            .onEnded { value in
                                let threshold: CGFloat = 100
                                let velocity = value.predictedEndTranslation.height

                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    if offset > threshold || velocity > 500 {
                                        isPresented = false
                                        offset = 0
                                    } else {
                                        offset = 0
                                    }
                                }
                                lastOffset = 0
                            }
                    )
                    .transition(.move(edge: .bottom))
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented)
    }
}

// MARK: - Sheet Handle
struct SheetHandle: View {
    var body: some View {
        RoundedRectangle(cornerRadius: CampyRadius.small)
            .fill(CampyColors.textSecondary.opacity(0.5))
            .frame(width: CampyLayout.sheetHandleWidth, height: CampyLayout.sheetHandleHeight)
    }
}

// MARK: - Sheet Header
struct SheetHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: CampySpacing.xs) {
            Text(title)
                .font(CampyFonts.header())
                .foregroundColor(CampyColors.textPrimary)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(CampyFonts.body())
                    .foregroundColor(CampyColors.textSecondary)
            }
        }
        .padding(.bottom, CampySpacing.md)
    }
}

// MARK: - Divider
struct SheetDivider: View {
    var body: some View {
        Rectangle()
            .fill(CampyColors.textSecondary.opacity(0.2))
            .frame(height: 1)
            .padding(.vertical, CampySpacing.md)
    }
}

#Preview {
    struct PreviewContainer: View {
        @State var showSheet = true

        var body: some View {
            ZStack {
                CampyColors.background.ignoresSafeArea()

                Button("Show Sheet") {
                    showSheet = true
                }
                .foregroundColor(.white)

                BottomSheet(isPresented: $showSheet) {
                    VStack {
                        SheetHeader(title: "Active Sessions", subtitle: "Join a nearby session")
                        SheetDivider()
                        Text("Content goes here")
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal, CampySpacing.lg)
                    .frame(height: 400)
                }
            }
        }
    }

    return PreviewContainer()
}
