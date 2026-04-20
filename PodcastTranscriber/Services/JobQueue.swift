import Foundation

/// A simple job queue for managing background tasks.
class JobQueue {
    private let queue = OperationQueue()

    init() {
        queue.maxConcurrentOperationCount = 1 // Serial queue
    }

    func addJob(_ job: @escaping () -> Void) {
        queue.addOperation(job)
    }
}