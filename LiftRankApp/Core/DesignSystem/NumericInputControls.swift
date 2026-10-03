import SwiftUI

enum NumericInputPresentation {
    case card
    case inset
    case formRow

    var background: Color {
        switch self {
        case .card:
            return Color.liftCard
        case .inset, .formRow:
            return Color.liftField
        }
    }

    var padding: CGFloat {
        switch self {
        case .card:
            return 16
        case .inset:
            return 12
        case .formRow:
            return 0
        }
    }
}

struct NumericInputField: View {
    let title: String
    @Binding var value: Double
    var unit: String?
    var precision: ClosedRange<Int> = 0...1
    var presentation: NumericInputPresentation = .card

    var body: some View {
        switch presentation {
        case .formRow:
            HStack {
                Text(title)
                Spacer()
                TextField(title, value: $value, format: .number.precision(.fractionLength(precision)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 110)
                if let unit {
                    Text(unit)
                        .foregroundStyle(Color.liftMuted)
                }
            }
        case .card, .inset:
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
                HStack {
                    TextField(title, value: $value, format: .number.precision(.fractionLength(precision)))
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                    if let unit {
                        Text(unit)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.liftMuted)
                    }
                }
                .padding(presentation.padding)
                .background(presentation.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct IntegerInputField: View {
    let title: String
    @Binding var value: Int
    var unit: String?
    var presentation: NumericInputPresentation = .card

    var body: some View {
        switch presentation {
        case .formRow:
            HStack {
                Text(title)
                Spacer()
                TextField(title, value: $value, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 110)
                if let unit {
                    Text(unit)
                        .foregroundStyle(Color.liftMuted)
                }
            }
        case .card, .inset:
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.liftMuted)
                HStack {
                    TextField(title, value: $value, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                    if let unit {
                        Text(unit)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.liftMuted)
                    }
                }
                .padding(presentation.padding)
                .background(presentation.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct OptionalNumericInputField: View {
    let title: String
    @Binding var value: Double?
    var unit: String?
    var presentation: NumericInputPresentation = .inset
    @State private var text: String
    @FocusState private var isFocused: Bool

    init(title: String, value: Binding<Double?>, unit: String? = nil, presentation: NumericInputPresentation = .inset) {
        self.title = title
        self._value = value
        self.unit = unit
        self.presentation = presentation
        self._text = State(initialValue: value.wrappedValue.map(Self.format) ?? "")
    }

    var body: some View {
        optionalField(keyboard: .decimalPad)
            .onChange(of: text) { _, newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                value = trimmed.isEmpty ? nil : Double(trimmed)
            }
            .onChange(of: value) { _, newValue in
                if !isFocused {
                    text = newValue.map(Self.format) ?? ""
                }
            }
    }

    private func optionalField(keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
            HStack {
                TextField("Optional", text: $text)
                    .focused($isFocused)
                    .keyboardType(keyboard)
                    .textFieldStyle(.plain)
                if let unit {
                    Text(unit)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                }
            }
            .padding(presentation.padding == 0 ? 10 : presentation.padding)
            .background(presentation == .formRow ? Color.clear : presentation.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private static func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

struct OptionalIntegerInputField: View {
    let title: String
    @Binding var value: Int?
    var unit: String?
    var presentation: NumericInputPresentation = .inset
    @State private var text: String
    @FocusState private var isFocused: Bool

    init(title: String, value: Binding<Int?>, unit: String? = nil, presentation: NumericInputPresentation = .inset) {
        self.title = title
        self._value = value
        self.unit = unit
        self.presentation = presentation
        self._text = State(initialValue: value.wrappedValue.map(String.init) ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.liftMuted)
            HStack {
                TextField("Optional", text: $text)
                    .focused($isFocused)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                if let unit {
                    Text(unit)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.liftMuted)
                }
            }
            .padding(presentation.padding == 0 ? 10 : presentation.padding)
            .background(presentation == .formRow ? Color.clear : presentation.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .onChange(of: text) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            value = trimmed.isEmpty ? nil : Int(trimmed)
        }
        .onChange(of: value) { _, newValue in
            if !isFocused {
                text = newValue.map(String.init) ?? ""
            }
        }
    }
}
