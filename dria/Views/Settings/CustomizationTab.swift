//
//  CustomizationTab.swift
//  dria
//

import SwiftUI

struct CustomizationTab: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        Form {
            Section("Features") {
                Toggle("Answer card", isOn: $state.answerCardEnabled)
                Text("Floating card by the cursor when you copy. Shortcut: ⌥⇧O")
                    .font(.caption).foregroundStyle(.secondary)

                Toggle("Menu-bar marquee", isOn: $state.marqueeEnabled)
                Text("Scrolls the answer in the menu bar. Shortcut: ⌥⇧N")
                    .font(.caption).foregroundStyle(.secondary)

                Toggle("Watch clipboard", isOn: Binding(
                    get: { state.autoMonitorClipboard },
                    set: { if $0 != state.autoMonitorClipboard { state.toggleClipboardMonitoring() } }
                ))
                Text("Detect (and answer) text you copy. Required for the answer card.")
                    .font(.caption).foregroundStyle(.secondary)

                Toggle("Auto-answer on copy", isOn: $state.autoAnswerOnCopy)
                Text("Send detected questions to AI automatically.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Answer Card") {
                if state.answerCardEnabled && (!state.autoMonitorClipboard || !state.smartDetectionEnabled) {
                    Button("Enable clipboard watching and question detection") {
                        state.smartDetectionEnabled = true
                        if !state.autoMonitorClipboard { state.toggleClipboardMonitoring() }
                    }
                    Text("Copied questions are sent to your selected AI provider. Use with your practice material outside restricted assessments.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Group {
                    Toggle("Answer anything I copy", isOn: $state.answerAnyClipboard)
                    Text("On: every copy is answered. Off: only text detected as a question.")
                        .font(.caption).foregroundStyle(.secondary)

                    Toggle("Follow cursor (click anywhere to pin)", isOn: $state.answerCardFollowCursor)
                    Toggle("Answer first, then reveal", isOn: $state.answerCardRevealFirst)
                    Toggle("Show explanation", isOn: $state.answerCardShowExplanation)

                    HStack {
                        Text("Opacity")
                        Slider(value: $state.answerCardOpacity, in: 0.05...1.0, step: 0.01)
                        Text("\(Int((state.answerCardOpacity * 100).rounded()))%")
                            .font(.caption).monospacedDigit()
                            .frame(width: 35)
                    }

                    HStack {
                        Text("Width")
                        Slider(value: $state.answerCardWidth, in: 260...520, step: 20)
                        Text("\(Int(state.answerCardWidth))")
                            .font(.caption).monospacedDigit()
                            .frame(width: 30)
                    }

                    Picker("Close after", selection: $state.answerCardDismissSeconds) {
                        Text("5 s").tag(5.0)
                        Text("15 s").tag(15.0)
                        Text("30 s").tag(30.0)
                        Text("60 s").tag(60.0)
                        Text("Never").tag(0.0)
                    }
                    Text("Pinning a card keeps it open.")
                        .font(.caption).foregroundStyle(.secondary)

                    Picker("Theme", selection: $state.answerCardTheme) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }
                .disabled(!state.answerCardEnabled)
            }

            Section("Menu-bar marquee") {
                HStack(spacing: 12) {
                    StealthPresetButton(label: "Full", icon: "eye", opacity: 1.0, current: state.marqueeOpacity) {
                        state.marqueeOpacity = 1.0
                    }
                    StealthPresetButton(label: "Subtle", icon: "eye.slash", opacity: 0.5, current: state.marqueeOpacity) {
                        state.marqueeOpacity = 0.5
                    }
                    StealthPresetButton(label: "Faint", icon: "cloud", opacity: 0.25, current: state.marqueeOpacity) {
                        state.marqueeOpacity = 0.25
                    }
                    StealthPresetButton(label: "Ghost", icon: "eye.slash.fill", opacity: 0.1, current: state.marqueeOpacity) {
                        state.marqueeOpacity = 0.1
                    }
                }
                .padding(.vertical, 4)

                HStack {
                    Image(systemName: "eye.slash").foregroundStyle(.secondary)
                    Slider(value: $state.marqueeOpacity, in: 0.05...1.0, step: 0.05)
                    Image(systemName: "eye").foregroundStyle(.secondary)
                }
                Text("Opacity: \(Int(state.marqueeOpacity * 100))% — \(opacityLabel(state.marqueeOpacity))")
                    .font(.caption).foregroundStyle(.secondary)

                HStack {
                    Text("Text width")
                    Slider(value: .init(
                        get: { Double(state.marqueeWidth) },
                        set: { state.marqueeWidth = Int($0) }
                    ), in: 10...50, step: 5)
                    Text("\(state.marqueeWidth)")
                        .font(.caption).monospacedDigit()
                        .frame(width: 25)
                }
                Text("Characters visible in the menu bar. Smaller = more discreet.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .disabled(!state.marqueeEnabled)

            Section("Click to Copy") {
                Picker("When clicking the icon, copy:", selection: $state.copyMode) {
                    Text("Short answer only").tag("short")
                    Text("Full explanation").tag("full")
                    Text("Marquee text (what's scrolling)").tag("marquee")
                }
                .pickerStyle(.radioGroup)
            }

            Section("Safety") {
                Toggle("Lock chat window", isOn: $state.lockPopover)
                Text("Prevents accidental popover. Use ⌘⌥3 for inline chat.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func opacityLabel(_ v: Double) -> String {
        if v < 0.15 { return "Ghost mode — nearly invisible" }
        if v < 0.3 { return "Faint — very hard to read" }
        if v < 0.5 { return "Subtle — blends with dark menus" }
        if v < 0.8 { return "Visible — readable but understated" }
        return "Full — normal text brightness"
    }
}

private struct StealthPresetButton: View {
    let label: String
    let icon: String
    let opacity: Double
    let current: Double
    let action: () -> Void

    private var isSelected: Bool {
        abs(current - opacity) < 0.06
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
