import SwiftUI

struct TutorialView: View {
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(spacing: 20) {

            // Title
            Text("How to Measure")
                .font(.system(.largeTitle, design: .rounded).bold())
                .foregroundColor(.primary)
                .padding(.top)

            Divider()
                .padding(.horizontal, 24)
            
            HStack(alignment: .top, spacing: 10) {
               
                Text("Move your pointer fingers inward or outward to measure")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 4)
            
            Divider()
                .padding(.horizontal, 24)

            // Instructions
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.white)
                        .imageScale(.large)

                    Text("Add a line measurement")
                        .font(.title3.bold())

                    Spacer()
                    Text("🤏 Left Pinch")
                        .foregroundColor(.secondary)
                        .font(.callout)
                }

                HStack {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.white)
                        .imageScale(.large)

                    Text("Remove a line measurement")
                        .font(.title3.bold())

                    Spacer()
                    Text("🤌 Right Pinch")
                        .foregroundColor(.secondary)
                        .font(.callout)
                }

                // Recommendation Note
                Divider()
                    .padding(.horizontal, 24)

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .imageScale(.medium)

                    Text("To improve tracking accuracy, point your index finger while measuring")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            
            Spacer()

          

            // Dismiss Button
            Button(action: {
                dismissWindow(id: "TutorialView")
            }) {
                Text("Got it 👍")
                    .font(.headline)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
            }
            .padding(.bottom)
        }
        .padding()
        .frame(width: 500, height: 500)
        .background(.ultraThinMaterial)
        .cornerRadius(32)
        .shadow(radius: 30)
        .glassBackgroundEffect()
    }
}

#Preview {
    TutorialView()
}
