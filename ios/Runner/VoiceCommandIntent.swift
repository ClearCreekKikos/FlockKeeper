import AppIntents
import UIKit

@available(iOS 16.0, *)
struct VoiceCommandIntent: AppIntent {
    static var title: LocalizedStringResource = "Run Command"
    static var description = IntentDescription("Runs a herd management command in FlockKeeper.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Command", description: "What would you like FlockKeeper to do?")
    var command: String

    static var parameterSummary: some ParameterSummary {
        Summary("Ask FlockKeeper to \(\.$command)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let encodedQuery = command.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "flockkeeper://voice?query=\(encodedQuery)&autoStart=true"
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        
        return .result(dialog: "Opening FlockKeeper to run command: \(command)")
    }
}
