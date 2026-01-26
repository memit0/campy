//
//  TransactionRow.swift
//  campy
//
//  Transaction history row component
//

import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: CampySpacing.md) {
            // Icon
            transactionIcon

            // Description
            VStack(alignment: .leading, spacing: CampySpacing.xs) {
                Text(transaction.displayDescription)
                    .font(CampyFonts.body())
                    .foregroundColor(CampyColors.textPrimary)
            }

            Spacer()

            // Amount
            Text(transaction.formattedAmount)
                .font(CampyFonts.body())
                .foregroundColor(transaction.isPositive ? CampyColors.success : CampyColors.textSecondary)
        }
        .padding(CampySpacing.md)
        .background(CampyColors.cardBackground)
        .cornerRadius(CampyRadius.large)
    }

    private var transactionIcon: some View {
        ZStack {
            Circle()
                .fill(iconBackgroundColor.opacity(0.2))
                .frame(width: 40, height: 40)

            Image(systemName: iconName)
                .font(.system(size: 16))
                .foregroundColor(iconBackgroundColor)
        }
    }

    private var iconName: String {
        switch transaction.type {
        case .purchase:
            return "plus"
        case .sessionWin:
            return "trophy.fill"
        case .sessionLoss:
            return "xmark"
        case .refund:
            return "arrow.uturn.backward"
        case .bonus:
            return "gift.fill"
        }
    }

    private var iconBackgroundColor: Color {
        switch transaction.type {
        case .purchase, .sessionWin, .bonus:
            return CampyColors.success
        case .sessionLoss:
            return CampyColors.error
        case .refund:
            return CampyColors.warning
        }
    }
}

#Preview {
    VStack(spacing: CampySpacing.sm) {
        ForEach(Transaction.previewTransactions) { transaction in
            TransactionRow(transaction: transaction)
        }
    }
    .padding()
    .background(CampyColors.background)
}
