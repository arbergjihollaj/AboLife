import Foundation
import Combine

final class DashboardStore: ObservableObject {
    @Published private(set) var snapshot: DashboardSnapshot

    init(snapshot: DashboardSnapshot = DashboardMockData.today) {
        self.snapshot = snapshot
    }
}
