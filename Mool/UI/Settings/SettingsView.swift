import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @Environment(RecordingEngine.self) var engine
    @Environment(StorageManager.self) var storageManager

    var body: some View {
        TabView {
            RecordingSettingsTab(settings: engine.settings)
                .tabItem { Label("Recording", systemImage: "record.circle") }

            ShortcutsSettingsTab(settings: engine.settings)
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }

            StorageSettingsTab(storageManager: storageManager, settings: engine.settings)
                .tabItem { Label("Storage", systemImage: "internaldrive") }

            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 380)
    }
}

// MARK: - Recording Settings Tab

struct RecordingSettingsTab: View {
    @Bindable var settings: RecordingSettings

    var body: some View {
        Form {
            Section("Recording") {
                Picker("Default Mode", selection: $settings.mode) {
                    ForEach(RecordingMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

                Picker("Quality", selection: $settings.quality) {
                    ForEach(VideoQuality.allCases, id: \.self) { q in
                        Text(q.rawValue).tag(q)
                    }
                }

                Stepper(
                    "Countdown: \(settings.countdownDuration) sec",
                    value: $settings.countdownDuration,
                    in: 0...10
                )
            }

            Section("Camera") {
                Toggle("Mirror Camera", isOn: $settings.mirrorCamera)
            }

            Section("Audio") {
                Toggle("Capture Microphone", isOn: $settings.captureMicrophone)
                Toggle("Capture System Audio", isOn: $settings.captureSystemAudio)
            }

            Section("System") {
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { _, newValue in
                        (NSApp.delegate as? AppDelegate)?.setLaunchAtLogin(newValue)
                    }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: settings.mode) { _, _ in settings.save() }
        .onChange(of: settings.quality) { _, _ in settings.save() }
        .onChange(of: settings.countdownDuration) { _, _ in settings.save() }
        .onChange(of: settings.mirrorCamera) { _, _ in settings.save() }
        .onChange(of: settings.captureMicrophone) { _, _ in settings.save() }
        .onChange(of: settings.captureSystemAudio) { _, _ in settings.save() }
        .onChange(of: settings.launchAtLogin) { _, _ in settings.save() }
    }
}

// MARK: - Shortcuts Settings Tab

struct ShortcutsSettingsTab: View {
    @Bindable var settings: RecordingSettings

    var body: some View {
        Form {
            Section("Recording") {
                ShortcutField(label: "Start / Stop", shortcut: $settings.shortcuts.startStop)
                ShortcutField(label: "Pause / Resume", shortcut: $settings.shortcuts.pauseResume)
            }

            Section("Overlays") {
                ShortcutField(label: "Toggle Annotation", shortcut: $settings.shortcuts.toggleAnnotation)
                ShortcutField(label: "Toggle Camera Bubble", shortcut: $settings.shortcuts.toggleCamera)
                ShortcutField(label: "Toggle Speaker Notes", shortcut: $settings.shortcuts.toggleSpeakerNotes)
            }

            Section {
                EmptyView()
            } footer: {
                Text("Click a field, then press your desired key combination. Press Escape to cancel.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: settings.shortcuts.startStop.key) { _, _ in settings.save() }
        .onChange(of: settings.shortcuts.pauseResume.key) { _, _ in settings.save() }
        .onChange(of: settings.shortcuts.toggleAnnotation.key) { _, _ in settings.save() }
        .onChange(of: settings.shortcuts.toggleCamera.key) { _, _ in settings.save() }
        .onChange(of: settings.shortcuts.toggleSpeakerNotes.key) { _, _ in settings.save() }
    }
}

// MARK: - Storage Settings Tab

struct StorageSettingsTab: View {
    @Bindable var storageManager: StorageManager
    @Bindable var settings: RecordingSettings

    var body: some View {
        Form {
            Section("Storage Location") {
                LabeledContent("Recordings Folder") {
                    HStack {
                        Text(storageManager.storagePath.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                        Button("Change…") {
                            selectFolder()
                        }
                    }
                }
                LabeledContent("Total Size", value: storageManager.formattedTotalSize)
                Button("Open in Finder") {
                    NSWorkspace.shared.open(storageManager.storagePath)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Select Folder"
        if panel.runModal() == .OK, let url = panel.url {
            storageManager.setStoragePath(url)
            settings.storagePath = url
            settings.save()
        }
    }
}

// MARK: - About Tab

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "record.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)

            Text("Mool")
                .font(.largeTitle.bold())
            Text("Local Screen Recording")
                .foregroundStyle(.secondary)

            Text("Version 0.1.0")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text("All recordings stay on your Mac. No cloud, no account required.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
