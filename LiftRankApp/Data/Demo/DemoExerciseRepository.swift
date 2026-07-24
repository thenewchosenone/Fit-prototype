import Foundation

extension DemoRepository {
    func addCustomTrainingExercise(_ exercise: TrainingExerciseCatalogItem) {
        customTrainingExercises.insert(exercise, at: 0)
        persistWorkoutSnapshot()
    }
}
