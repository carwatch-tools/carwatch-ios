import SwiftUI

struct StudyConfirmationView: View {
    @EnvironmentObject var sessionVM: SessionViewModel
    @EnvironmentObject var studyDataVM: StudyDataViewModel

    private var studyData: StudyData {
        studyDataVM.studyData
    }

    private var morningSampleDescription: String {
        if studyData.salivaDistances.isEmpty {
            return String(localized: "No interval-based morning samples")
        }

        return studyData.salivaDistances
            .map { "\($0) min" }
            .joined(separator: ", ")
    }

    private var fixedSampleDescription: String {
        if studyData.salivaTimes.isEmpty {
            return String(localized: "No fixed sample times")
        }

        return studyData.salivaTimes
            .map { $0.stringValue() }
            .joined(separator: ", ")
    }

    private var participantIdDescription: String {
        studyData.participantId.isEmpty ? String(localized: "Will be entered next") : studyData.participantId
    }

    private var contactEmailDescription: String {
        studyData.shareEmailAdress.isEmpty ? String(localized: "Not available") : studyData.shareEmailAdress
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
                    detailRow(title: "Study Name", value: studyData.studyName)
                    detailRow(title: "Participant ID", value: participantIdDescription)
                    detailRow(title: "Study Days", value: "\(studyData.studyDays)")
                    detailRow(title: "Participants", value: "\(studyData.numParticipants)")
                    detailRow(title: "Samples Per Day", value: "\(studyData.numSamples)")
                    detailRow(title: "Start Sample", value: studyData.startSample)
                    detailRow(title: "Morning Intervals", value: morningSampleDescription)
                    detailRow(title: "Fixed Sample Times", value: fixedSampleDescription)
                    detailRow(title: "Evening Sample", value: String(localized: studyData.hasEveningSample ? "Yes" : "No"))
                    detailRow(title: "Duplicate Check", value: String(localized: studyData.isCheckDuplicatesEnabled ? "Enabled" : "Disabled"))
                    detailRow(title: "Contact Email", value: contactEmailDescription)
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

    private func detailRow(title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(value)
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
}
