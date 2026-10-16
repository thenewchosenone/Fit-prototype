import SwiftUI

extension TrainingTrackerView {
    func libraryAlphabetIndex(
        scrollProxy: ScrollViewProxy,
        sections: [ExerciseLibrarySection]
    ) -> some View {
        VStack(spacing: 1) {
            ForEach(sections.map(\.letter), id: \.self) { letter in
                Button(letter) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        scrollProxy.scrollTo("library-letter-\(letter)", anchor: .top)
                    }
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.liftAccentText)
                .frame(width: 28, height: 24)
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
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.liftText)
                    if let reason = result.reasonLabel, !librarySearch.isEmpty {
                        Text(reason)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.liftAccentText)
                    }
                    Text("\(exercise.equipment) • \(exercise.resolvedMuscleProfile.primaryDescription)")
                        .font(.caption)
                        .foregroundStyle(Color.liftMuted)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.liftMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens exercise details, history, records, and charts")
    }

    func library(
        scrollProxy: ScrollViewProxy,
        results: [ExerciseSearchResult],
        sections: [ExerciseLibrarySection]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    librarySearchField
                    libraryFilterButton(expanded: true)
                    libraryCreateButton(expanded: true)
                }
            } else {
                HStack(spacing: 0) {
                    librarySearchField
                    libraryFilterButton(expanded: false)
                    libraryCreateButton(expanded: false)
                }
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
                                .foregroundStyle(Color.liftAccentText)
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

            Text("\(results.count) \(results.count == 1 ? "exercise" : "exercises")")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.liftMuted)

            if results.isEmpty {
                LiftEmptyState(
                    title: "No exercises found",
                    message: "Try another search or clear the active filters.",
                    symbolName: "magnifyingglass"
                )
                Button("Clear filters") {
                    libraryFilters = ExerciseLibraryFilterSelection()
                }
                .buttonStyle(LiftSecondaryButtonStyle())
            } else {

                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(sections) { section in
                        LazyVStack(alignment: .leading, spacing: 0) {
                            Text(section.letter)
                                .font(.caption.weight(.black))
                                .foregroundStyle(Color.liftAccentText)
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                                .background(Color.liftCardRaised.opacity(0.7))
                                .id("library-letter-\(section.letter)")
                                .accessibilityAddTraits(.isHeader)

                            ForEach(Array(section.results.enumerated()), id: \.element.id) { index, result in
                                libraryRow(result)
                                if index < section.results.count - 1 {
                                    Divider()
                                        .overlay(Color.liftOverlay)
                                        .padding(.leading, 12)
                                }
                            }
                        }
                        .background(Color.liftCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.liftOverlay, lineWidth: 1)
                        }
                    }
                }
                .padding(.trailing, librarySearch.isEmpty && !dynamicTypeSize.isAccessibilitySize ? 16 : 0)
            }
        }
    }

    private var librarySearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.liftMuted)
            TextField("Search exercises", text: $librarySearch)
                .textFieldStyle(.plain)
                .focused($isLibrarySearchFocused)
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
        }
        .padding(.leading, 12)
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
        .background(Color.liftCard)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.liftOverlay, lineWidth: 1)
        }
    }

    private func libraryFilterButton(expanded: Bool) -> some View {
        Button {
            showingLibraryFilters = true
        } label: {
            Group {
                if expanded {
                    Label("Filter exercises", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(libraryFilters.isEmpty ? Color.liftMuted : Color.liftAccentText)
                            .frame(width: 44, height: 44)
                        if libraryFilters.activeCategoryCount > 0 {
                            Text("\(libraryFilters.activeCategoryCount)")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(Color.liftOnAccent)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(Color.liftBlue)
                                .clipShape(Circle())
                                .offset(x: 2, y: 2)
                        }
                    }
                }
            }
            .foregroundStyle(libraryFilters.isEmpty ? Color.liftMuted : Color.liftAccentText)
            .padding(.horizontal, expanded ? 12 : 0)
            .frame(minHeight: 46)
            .background(expanded ? Color.liftCard : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filter exercise library")
        .accessibilityValue(libraryFilters.isEmpty ? "No filters applied" : "\(libraryFilters.activeCategoryCount) filter categories applied")
    }

    private func libraryCreateButton(expanded: Bool) -> some View {
        Button {
            showingCreateLibraryExercise = true
        } label: {
            Group {
                if expanded {
                    Label("Create custom exercise", systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
                }
            }
            .foregroundStyle(Color.liftAccentText)
            .padding(.horizontal, expanded ? 12 : 0)
            .frame(minHeight: 46)
            .background(expanded ? Color.liftCard : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Create custom exercise")
    }
}
