import SwiftUI

struct TutorialView: View {

    let type: TutorialType

    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(spacing: 20) {
            Text(type == .measure ? "How to Measure" : "How to Measure Angles")
                .font(.system(.largeTitle, design: .rounded).bold())
                .foregroundColor(.primary)
                .padding(.top)

            Divider()
                .padding(.horizontal, 24)

            if type == .measure {
                Text("Move your pointer fingers inward or outward to measure")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 24)
            } else {
                Text("Create two lines to form an angle")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 24)
            }

            Divider()
                .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 16) {
                if type == .measure {
                    instructionRow(
                        icon: "plus.circle.fill",
                        text: "Add a line measurement",
                        gesture: "🤏 Left Pinch"
                    )
                    instructionRow(
                        icon: "minus.circle.fill",
                        text: "Remove a line measurement",
                        gesture: "🤌 Right Pinch"
                    )
                } else {
                    instructionRow(
                        icon: "plus.circle.fill",
                        text: "Place first angle line",
                        gesture: "🤏 Left Pinch"
                    )
                    instructionRow(
                        icon: "plus.circle.fill",
                        text: "Place second line to complete angle",
                        gesture: "🤏 Left Pinch"
                    )
                    .fixedSize(horizontal: false, vertical: true) // allow wrapping vertically for longer text
                    instructionRow(
                        icon: "minus.circle.fill",
                        text: "Delete last angle",
                        gesture: "🤌 Right Pinch"
                    )
                }

                Divider()
                    .padding(.horizontal, 24)

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)

                    Text("To improve tracking accuracy, point your index finger while measuring")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true) // allow wrapping vertically for longer text
                        .multilineTextAlignment(.leading) // optional: align nicely
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                dismissWindow(id: "TutorialView")
            } label: {
                Text("Got it 👍")
                    .font(.headline)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .frame(width: 500, height: 500)
        .glassBackgroundEffect()
    }
}

private func instructionRow(icon: String, text: String, gesture: String) -> some View {
    HStack {
        Image(systemName: icon)
            .foregroundColor(.white)

        Text(text)
            .font(.title3.bold())

        Spacer()

        Text(gesture)
            .foregroundColor(.secondary)
            .font(.callout)
    }
}

//#Preview {
//    TutorialView(type: <#TutorialType#>)
//}
