import SwiftUI
import Subsonic

struct HelpWindow: View {
    @Binding var showHelp: Bool
    @State private var waveOffset: CGFloat = 0.0
    @ObservedObject var fxMusic: SubsonicPlayer

    private let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            helpContent(in: geometry.size, safeAreaInsets: geometry.safeAreaInsets)
        }
        .onReceive(timer) { _ in
            waveOffset += 0.5
        }
    }

    private func helpContent(in size: CGSize, safeAreaInsets: EdgeInsets) -> some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            backgroundImage(in: size, safeAreaInsets: safeAreaInsets)

            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        fxMusic.play()
                        showHelp = false
                    }) {
                        Image("back")
                            .resizable()
                            .scaledToFit()
                            .frame(width: min(max(size.width * 0.25, 96), 126))
                            .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
                            .offset(y: sin(waveOffset * 0.05) * 3)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, max(18, size.width * 0.05))
                .padding(.top, safeAreaInsets.top)

                Spacer(minLength: size.height * 0.08)

                sineWaveImage("text1", amplitude: 2, speed: 0.05, phase: 0)
                    .frame(width: min(size.width * 0.99, 380))

                Spacer(minLength: size.height * 0.08)

                HStack(alignment: .center, spacing: max(6, size.width * 0.02)) {
                    sineWaveImage("wrong1", amplitude: 3, speed: 0.05, phase: 0)
                        .frame(width: min(size.width * 0.50, 220))

                    sineWaveImage("right1", amplitude: 3, speed: 0.05, phase: 0.7)
                        .frame(width: min(size.width * 0.50, 220))
                }
                .frame(maxWidth: size.width)
                .padding(.horizontal, max(6, size.width * 0.02))

                Spacer(minLength: size.height * 0.1)
            }
            .frame(width: size.width, height: size.height)
        }
    }

    private func sineWaveImage(_ imageName: String, amplitude: CGFloat, speed: CGFloat, phase: Double) -> some View {
        Image(imageName)
            .resizable()
            .scaledToFit()
            .offset(y: CGFloat(sin(waveOffset * speed + phase) * amplitude))
    }

    private func backgroundImage(in size: CGSize, safeAreaInsets: EdgeInsets) -> some View {
        let width = size.width + safeAreaInsets.leading + safeAreaInsets.trailing + 80
        let height = size.height + safeAreaInsets.top + safeAreaInsets.bottom + 80

        return Image("sea")
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .position(x: size.width / 2, y: size.height / 2)
            .clipped()
            .ignoresSafeArea()
    }
}
