import SwiftUI

struct ContentView: View {
    @State private var service: TelemetryService

    init(service: TelemetryService? = nil) {
        _service = State(initialValue: service ?? TelemetryService())
    }

    var body: some View {
        MainNavigationView(service: service)
            .frame(minWidth: 840, minHeight: 560)
            .task {
                await service.refresh()
            }
    }
}

#Preview("Mock Data") {
    ContentView(service: TelemetryService(client: MockMoleClient()))
}
