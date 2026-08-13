import SwiftUI

struct PlateauAlertCard: View {
    let insight: PlateauInsight
    let openDetails: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "equal.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.liftGold)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Possible plateau")
                        .font(.headline)
                    Text("\(insight.exerciseName) has not improved in 3 workouts.")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                }
                Spacer()
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.liftMuted)
                .accessibilityLabel("Dismiss plateau alert")
            }

            Button("Review recent sets", action: openDetails)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.liftBlue)
        }
        .padding(14)
        .background(Color.liftGold.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.liftGold.opacity(0.28), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}
