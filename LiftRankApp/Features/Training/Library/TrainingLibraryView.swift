import SwiftUI

extension TrainingTrackerView {
    private var librarySections: [(letter: String, results: [ExerciseSearchResult])] {
        let grouped = Dictionary(grouping: filteredLibraryResults.sorted {
            $0.exercise.name.localizedStandardCompare($1.exercise.name) == .orderedAscending
        }) { result in
            result.exercise.name.first.map { String($0).uppercased() } ?? "#"
        }
        return grouped.keys.sorted().map { ($0, grouped[$0] ?? []) }
    }

    func libraryAlphabetIndex(scrollProxy: ScrollViewProxy) -> some View {
        VStack(spacing: 1) {
            ForEach(librarySections.map(\.letter), id: \.self) { letter in
                Button(letter) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        scrollProxy.scrollTo("library-letter-\(letter)", anchor: .top)
                    }
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.liftBlue)
                .frame(width: 22)
                .frame(minHeight: 12)
                .buttonStyle(.plain)
                .accessibilityLabel("Jump to exercises beginning with \(letter)")
            }
        }
        .padding(.vertical, 6)
        .background(Color.liftBackground.opacity(0.9))
        .clipShape(Capsule())
    }

    private func libraryRow(_ result: ExerciseSearchResult) -> some View {
        let exercise = result.exercise
        return Button {
            selectedLibraryExercise = exercise
        } label: {
            HStack(spacing: 12) {
                ExerciseCatalogIcon(exercise: exercise)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.liftText)
                    if let reason = result.reasonLabel, !librarySearch.isEmpty {
                        Text(reason)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.liftBlue)
                    }
                    Text("\(exercise.equipment) • \(exercise.resolvedMuscleProfile.primaryDescription)")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftMuted)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens exercise details, history, records, and charts")
    }

    func library(scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.liftMuted)
                TextField("Search exercises", text: $librarySearch)
                    .textFieldStyle(.plain)
                if !librarySearch.isEmpty {
                    Button {
                        librarySearch = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.liftMuted)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear exercise search")
                }
                Button {
                    showingLibraryFilters = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(libraryFilters.isEmpty ? Color.liftMuted : Color.liftBlue)
                            .frame(width: 44, height: 44)
                        if libraryFilters.activeCategoryCount > 0 {
                            Text("\(libraryFilters.activeCategoryCount)")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.white)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(Color.liftBlue)
                                .clipShape(Circle())
                                .offset(x: 2, y: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Filter exercise library")
                .accessibilityValue(libraryFilters.isEmpty ? "No filters applied" : "\(libraryFilters.activeCategoryCount) filter categories applied")

                Button {
                    showingCreateLibraryExercise = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Color.liftBlue)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Create custom exercise")
            }
            .padding(.leading, 12)
            .padding(.trailing, 4)
            .frame(minHeight: 46)
            .background(Color.liftCard)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            }

            if !libraryFilters.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(libraryFilters.activeChips) { chip in
                            Button {
                                libraryFilters.clear(category: chip.category)
                            } label: {
                                HStack(spacing: 6) {
                                    Text(chip.title)
                                    Image(systemName: "xmark")
                                }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.liftBlue)
                                .padding(.horizontal, 11)
                                .frame(minHeight: 36)
                                .background(Color.liftBlue.opacity(0.14))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(chip.title) filter")
                        }

                        Button("Clear all") {
                            libraryFilters = ExerciseLibraryFilterSelection()
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.liftMuted)
                        .frame(minHeight: 36)
                    }
                }
            }

            Text("\(filteredLibraryResults.count) exercises")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.liftMuted)

            if filteredLibraryResults.isEmpty {
                LiftEmptyState(
                    title: "No exercises found",
                    message: "Try another search or clear the active filters.",
                    symbolName: "magnifyingglass"
                )
                Button("Clear filters") {
                    libraryFilters = ExerciseLibraryFilterSelection()
                    librarySearch = ""
                }
                .buttonStyle(LiftSecondaryButtonStyle())
            } else {

                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(librarySections, id: \.letter) { section in
                        VStack(alignment: .leading, spacing: 0) {
                            Text(section.letter)
                                .font(.caption.weight(.black))
                                .foregroundStyle(Color.liftBlue)
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                                .background(Color.liftCardRaised.opacity(0.7))
                                .id("library-letter-\(section.letter)")

                            ForEach(Array(section.results.enumerated()), id: \.element.id) { index, result in
                                libraryRow(result)
                                if index < section.results.count - 1 {
                                    Divider()
                                        .overlay(Color.white.opacity(0.07))
                                        .padding(.leading, 68)
                                }
                            }
                        }
                        .background(Color.liftCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        }
                    }
                }
                .padding(.trailing, librarySearch.isEmpty ? 16 : 0)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}
