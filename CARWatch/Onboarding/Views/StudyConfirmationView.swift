import SwiftUI

struct StudyConfirmationView: View {
    @EnvironmentObject var sessionVM: SessionViewModel
    @EnvironmentObject var studyDataVM: StudyDataViewModel

    private var studyData: StudyData {
        studyDataVM.studyData
    }

    private var participantIdDescription: String {
        studyData.participantId.isEmpty ? String(localized: "Will be entered next") : studyData.participantId
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Study Details")
                    .font(.title.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Please confirm that this study configuration matches the information you received before continuing to the tutorial.")
                    .font(.system(size: StyleConstants.explanationFontSize))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Group {
                    detailRow(title: "Study Name", value: Text(studyData.studyName))
                    detailRow(title: "Participant ID", value: Text(participantIdDescription))
                    detailRow(title: "Study Days", value: Text("\(studyData.studyDays)"))
                    detailRow(title: "Samples Per Day", value: Text("\(studyData.numSamples)"))
                    detailRow(title: "Evening Sample", value: Text(studyData.hasEveningSample ? "Yes" : "No"))
                }

                Button("Continue to Tutorial") {
                    sessionVM.startTutorial()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            .padding(StyleConstants.edgePadding)
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
        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: StyleConstants.roundedCornerRadius))
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
