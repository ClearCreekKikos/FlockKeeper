import AppIntents

@available(iOS 16.0, *)
struct FlockKeeperShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: VoiceCommandIntent(),
            phrases: [
                "Run command in \(.applicationName)",
                "Open voice control in \(.applicationName)",
                "Talk to \(.applicationName)",
                "Voice command in \(.applicationName)"
            ],
            shortTitle: "Run Voice Command",
            systemImageName: "mic"
        )
    }
}
