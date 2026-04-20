import Foundation
import Combine

/// AppState serves as the global dependency injection container and state manager.
class AppState: ObservableObject {
    let objectWillChange = PassthroughSubject<Void, Never>()
    // TODO: Inject repositories, services, and logger here.
}
