import SwiftUI
import UniformTypeIdentifiers

/// Multi-step setup wizard presented as a modal sheet.
struct SetupWizardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep: WizardStep = .welcome
    @State private var draft = WizardDraft()
    @State private var showCancelConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            if currentStep != .welcome {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        ForEach(WizardStep.allCases, id: \.rawValue) { step in
                            Circle()
                                .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.primary.opacity(0.15))
                                .frame(width: 8, height: 8)
                        }
                    }
                    Text("Step \(currentStep.rawValue + 1) of \(WizardStep.totalSteps)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 16)
                .padding(.bottom, 8)
            }

            // Step content
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 40)

            Divider()

            // Navigation bar
            HStack {
                if currentStep != .welcome {
                    Button("Back") {
                        withAnimation { currentStep = currentStep.previous ?? .welcome }
                    }
                } else {
                    Button("Cancel") { showCancelConfirm = true }
                }

                Spacer()

                if currentStep.isSkippable {
                    Button("Skip") {
                        withAnimation { currentStep = currentStep.next ?? .done }
                    }
                    .foregroundStyle(.secondary)
                }

                if currentStep == .done {
                    Button("Finish") {
                        commitAndDismiss(startServer: false)
                    }
                    Button("Start Server") {
                        commitAndDismiss(startServer: true)
                    }
                    .buttonStyle(.borderedProminent)
                } else if currentStep == .welcome {
                    Button("Get Started") {
                        withAnimation { currentStep = .serverName }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Next") {
                        withAnimation { currentStep = currentStep.next ?? .done }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isCurrentStepValid)
                }
            }
            .padding()
        }
        .frame(width: 620, height: 520)
        .interactiveDismissDisabled(currentStep != .welcome)
        .alert("Cancel Setup?", isPresented: $showCancelConfirm) {
            Button("Continue Setup", role: .cancel) {}
            Button("Cancel", role: .destructive) { dismiss() }
        } message: {
            Text("Your settings won't be saved if you cancel now.")
        }
    }

    // MARK: - Step Content Router

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .welcome:
            WizardWelcomeStep()
        case .serverName:
            WizardServerNameStep(name: $draft.serverName)
        case .description:
            WizardDescriptionStep(description: $draft.serverDescription)
        case .fileRoot:
            WizardFileRootStep(fileRoot: $draft.fileRoot, configDir: appState.configDir)
        case .banner:
            WizardBannerStep(useDefault: $draft.useDefaultBanner, sourceURL: $draft.bannerSourceURL, filename: $draft.bannerFilename)
        case .agreement:
            WizardAgreementStep(text: $draft.agreementText)
        case .network:
            WizardNetworkStep(port: $draft.serverPort, enableBonjour: $draft.enableBonjour)
        case .trackers:
            WizardTrackerStep(enabled: $draft.enableTrackerRegistration, options: $draft.trackerOptions)
        case .news:
            WizardNewsStep(dateFormat: $draft.newsDateFormat, delimiter: $draft.newsDelimiter)
        case .limits:
            WizardLimitsStep(maxDownloads: $draft.maxDownloads, maxDownloadsPerClient: $draft.maxDownloadsPerClient, maxConnectionsPerIP: $draft.maxConnectionsPerIP)
        case .accounts:
            WizardAccountsStep()
        case .done:
            WizardDoneStep(draft: draft)
        }
    }

    // MARK: - Validation

    private var isCurrentStepValid: Bool {
        switch currentStep {
        case .serverName:
            return !draft.serverName.trimmingCharacters(in: .whitespaces).isEmpty
        case .description:
            return !draft.serverDescription.trimmingCharacters(in: .whitespaces).isEmpty
        default:
            return true
        }
    }

    // MARK: - Commit

    private func commitAndDismiss(startServer: Bool) {
        appState.commitWizardDraft(draft, startServer: startServer)
        dismiss()
    }
}
