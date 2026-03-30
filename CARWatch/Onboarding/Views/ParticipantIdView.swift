import SwiftUI

struct ParticipantIdView: View {
    
    @EnvironmentObject var studyDataVM: StudyDataViewModel
    
    @State var participantId = ""
    @State var showAlert: Bool = false
    
    var body: some View {
        VStack {
            Image(systemName: "person.text.rectangle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .font(.system(size: StyleConstants.mainScreenIconSize))
                .foregroundStyle(.blue)
                .opacity(StyleConstants.mainScreenIconOpacity)
                .padding()
                .frame(width: 100, alignment: .center)
            Text("Please enter the participant ID you received from us:")
                .font(.system(size: StyleConstants.explanationFontSize))
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField(
                "Participant ID",
                text: $participantId
            )
            .frame(maxWidth: .infinity, alignment:  .leading)
            .textFieldStyle(.roundedBorder)
            .padding(.bottom)
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
            
        }
        .padding(StyleConstants.edgePadding)
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
}

#Preview {
    ParticipantIdView().environmentObject(StudyDataViewModel())
}
