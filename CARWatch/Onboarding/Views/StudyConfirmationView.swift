import SwiftUI

struct StudyConfirmationView: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @EnvironmentObject var sessionVM: SessionViewModel
    @EnvironmentObject var studyDataVM: StudyDataViewModel

    private var studyData: StudyData {
        studyDataVM.studyData
    }

    private var participantIdDescription: String {
        studyData.participantId.isEmpty ? localizedAppString("Will be entered next") : studyData.participantId
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let usesExpandedLayout = StyleConstants.isExpandedPadLayout(for: size)

            ScrollView {
                VStack(spacing: 0) {
                    if usesExpandedLayout {
                        Spacer(minLength: StyleConstants.onboardingVerticalSpacingInset(for: size))
                    }

                    VStack(alignment: .leading, spacing: 20) {
                        Text("Study Details")
                            .font(.title.weight(.bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityAddTraits(.isHeader)

                        Text("Please confirm that this study configuration matches the information you received before continuing to the tutorial.")
                            .font(.system(size: StyleConstants.explanationFontSize(for: size)))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Group {
                            detailRow(title: "Study Name", value: Text(studyData.studyName))
                            detailRow(title: "Participant ID", value: Text(participantIdDescription))
                            detailRow(title: "Study Days", value: Text("\(studyData.studyDays)"))
                            detailRow(title: "Samples Per Day", value: Text("\(studyData.numSamples)"))
                            detailRow(title: "Evening Sample", value: Text(studyData.hasEveningSample ? "Yes" : "No"))
                        }

                        VStack(spacing: 12) {
                            Button("Confirm and Continue to Tutorial") {
                                sessionVM.startTutorial()
                            }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("studyConfirmation.continue")
                            .accessibilityHint(localizedAppString("Confirms these study details and opens the tutorial."))

                            Button("Reregister") {
                                studyDataVM.resetStudyData()
                                sessionVM.reregister()
                            }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("studyConfirmation.reregister")
                            .accessibilityHint(localizedAppString("Returns to registration so you can scan a different study QR code."))
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: StyleConstants.onboardingContentMaxWidth(for: size) ?? .infinity, alignment: .leading)
                    .padding(StyleConstants.edgePadding(for: size))
                    .frame(maxWidth: .infinity, alignment: .center)

                    if usesExpandedLayout {
                        Spacer(minLength: StyleConstants.onboardingVerticalSpacingInset(for: size))
                    }
                }
                .frame(minHeight: size.height)
            }
        }
    }

    private func detailRow(title: LocalizedStringKey, value: Text) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            value
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.blue.opacity(StyleConstants.cardBackgroundOpacity(for: colorSchemeContrast)), in: RoundedRectangle(cornerRadius: StyleConstants.roundedCornerRadius))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let sessionVM = SessionViewModel()
    let studyDataVM = StudyDataViewModel()
    studyDataVM.studyData = StudyData(
        isValid: true,
        studyName: "Preview Study",
        salivaDistances: [0, 30, 45],
        salivaTimes: [Time(hour: 12, minute: 0)],
        startSample: "S1",
        studyDays: 3,
        numParticipants: 24,
        hasEveningSample: true,
        shareEmailAdress: "preview@example.com",
        isCheckDuplicatesEnabled: true,
        participantId: ""
    )

    return StudyConfirmationView()
        .environmentObject(sessionVM)
        .environmentObject(studyDataVM)
        .environment(\.locale, Locale(identifier: "en"))
}
