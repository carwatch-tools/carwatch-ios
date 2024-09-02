import SwiftUI

struct TutorialSlide: View {
    let imageName : String
    let titleText : String
    let explanationText : String
    
    var body: some View {
        VStack {
            Image(imageName)
                .resizable()
                .scaledToFit()
            Text(titleText)
                .font(.title.weight(.bold))
            Text(explanationText)
            Spacer()
        }
        .padding([.leading, .trailing])
    }
}

#Preview {
    TutorialSlide(imageName: "CarwatchLogo", titleText: "Some Title", explanationText: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.")
}
