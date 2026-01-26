//
//  UserAvatar.swift
//  campy
//
//  User avatar component for displaying participant initials
//

import SwiftUI

struct UserAvatar: View {
    let initial: String
    let color: Color
    var size: CGFloat = CampyLayout.avatarSize
    var showBorder: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)

            if showBorder {
                Circle()
                    .stroke(CampyColors.textPrimary, lineWidth: 2)
                    .frame(width: size, height: size)
            }

            Text(initial)
                .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Avatar Stack
struct AvatarStack: View {
    let participants: [SessionParticipant]
    var maxVisible: Int = 4
    var avatarSize: CGFloat = CampyLayout.avatarSize

    var body: some View {
        VStack(alignment: .trailing, spacing: CampySpacing.xs) {
            ForEach(Array(participants.prefix(maxVisible).enumerated()), id: \.element.id) { index, participant in
                UserAvatar(
                    initial: participant.initial,
                    color: participant.avatarColor,
                    size: avatarSize
                )
            }

            if participants.count > maxVisible {
                Text("+\(participants.count - maxVisible)")
                    .font(CampyFonts.caption())
                    .foregroundColor(CampyColors.textSecondary)
            }
        }
    }
}

// MARK: - Horizontal Avatar Row
struct AvatarRow: View {
    let participants: [SessionParticipant]
    var spacing: CGFloat = -10

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(participants) { participant in
                UserAvatar(
                    initial: participant.initial,
                    color: participant.avatarColor,
                    showBorder: true
                )
            }
        }
    }
}

#Preview {
    let participants = [
        SessionParticipant(peerId: "1", displayName: "Emma", avatarColorIndex: 0),
        SessionParticipant(peerId: "2", displayName: "Sam", avatarColorIndex: 1),
        SessionParticipant(peerId: "3", displayName: "Kim", avatarColorIndex: 2),
    ]

    return VStack(spacing: 40) {
        UserAvatar(initial: "E", color: CampyColors.avatarColors[0])

        AvatarStack(participants: participants)

        AvatarRow(participants: participants)
    }
    .padding()
    .background(CampyColors.background)
}
