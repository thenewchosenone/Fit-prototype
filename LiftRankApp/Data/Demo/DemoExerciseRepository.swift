import Foundation

extension DemoRepository {
    var trainingExerciseCatalog: [TrainingExerciseCatalogItem] {
        MockData.trainingExerciseLibrary + customTrainingExercises
    }

    func clearCustomTrainingExercises() {
        customTrainingExercises.removeAll()
        scheduleWorkoutSnapshotPersistence()
    }

    func addCustomTrainingExercise(_ exercise: TrainingExerciseCatalogItem) {
        guard !trainingExerciseCatalog.contains(where: { $0.id == exercise.id }) else { return }
        customTrainingExercises.insert(exercise, at: 0)
        scheduleWorkoutSnapshotPersistence()
    }
}
