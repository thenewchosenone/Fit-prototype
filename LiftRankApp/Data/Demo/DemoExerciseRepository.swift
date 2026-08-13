import Foundation

extension DemoRepository {
    var trainingExerciseCatalog: [TrainingExerciseCatalogItem] {
        MockData.trainingExerciseLibrary + customTrainingExercises
    }

    func clearCustomTrainingExercises() {
        customTrainingExercises.removeAll()
        persistWorkoutSnapshot()
    }

    func addCustomTrainingExercise(_ exercise: TrainingExerciseCatalogItem) {
        customTrainingExercises.insert(exercise, at: 0)
        persistWorkoutSnapshot()
    }
}
