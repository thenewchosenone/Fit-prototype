import SwiftUI

struct TrackerMessageCard: View {
    let title: String
    let message: String

    var body: some View {
        LiftCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.liftMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
