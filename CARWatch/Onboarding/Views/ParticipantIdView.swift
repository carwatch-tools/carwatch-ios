import SwiftUI

struct ParticipantIdView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    @EnvironmentObject var studyDataVM: StudyDataViewModel
    
    @State var participantId = ""
    @State var showAlert: Bool = false

    private var shouldUseVerticalActionLayout: Bool {
        StyleConstants.isAccessibilitySize(dynamicTypeSize)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let usesExpandedLayout = StyleConstants.isExpandedPadLayout(for: size)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if usesExpandedLayout {
                        Spacer(minLength: StyleConstants.onboardingVerticalSpacingInset(for: size))
                    }

                    VStack(alignment: .leading, spacing: 20) {
                        Image(systemName: "person.text.rectangle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .font(.system(size: StyleConstants.mainScreenIconSize(for: size)))
                            .foregroundStyle(.blue)
                            .opacity(StyleConstants.mainScreenIconOpacity)
                            .padding()
                            .frame(width: StyleConstants.isCompactScreen(for: size) ? 80 : 100, alignment: .center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .accessibilityHidden(true)
                        Text("Please enter the participant ID you received from us:")
                            .font(.system(size: StyleConstants.explanationFontSize(for: size)))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityAddTraits(.isHeader)
                        TextField(
                            "Participant ID",
                            text: $participantId
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textFieldStyle(.roundedBorder)
                        .padding(.bottom)
                        .accessibilityIdentifier("participantId.input")
                        .accessibilityLabel(localizedAppString("Participant ID"))
                        .accessibilityHint(localizedAppString("Enter the participant ID provided by the study team."))
                        Group {
                            if shouldUseVerticalActionLayout {
                                VStack(alignment: .trailing, spacing: 12) {
                                    continueButton
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            } else {
                                continueButton
                            }
                        }
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
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Input invalid! Please enter a valid participant ID!"),
                  dismissButton: Alert.Button.default(
                    Text("OK"), action: {
                        showAlert = false
                    }
                  )
            )
        }
    }

    private var continueButton: some View {
        Button("Continue") {
            studyDataVM.studyData.participantId = participantId
            if studyDataVM.isParticipantIdRequired() {
                showAlert = true
            } else {
                logDeviceProperties()
                logAppMetadata()
                logParticipantId(participantId: participantId)
                logStudyData(studyData: studyDataVM.studyData)
            }
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("participantId.continue")
        .accessibilityHint(localizedAppString("Validates the participant ID and continues."))
    }
}

#Preview {
    ParticipantIdView().environmentObject(StudyDataViewModel())
}
