import SwiftUI
import Subsonic

struct SettingsView: View {
    @Binding var showSettings: Bool
    @State private var waveOffset: CGFloat = 0.0
    @State private var bgVolumeLevel: CGFloat = 0.7
    @State private var fxVolumeLevel: CGFloat = 0.7
    @State private var coinVolumeLevel: CGFloat = 0.8
    @State private var waterVolumeLevel: CGFloat = 0.9
    

    @ObservedObject var bgMusic: SubsonicPlayer
    @ObservedObject var fxMusic: SubsonicPlayer
    @ObservedObject var coinMusic: SubsonicPlayer
    @ObservedObject var waterMusic: SubsonicPlayer

    private let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            settingsContent(in: geometry.size, safeAreaInsets: geometry.safeAreaInsets)
        }
        .onAppear {
            syncVolumeLevelsFromPlayers()
        }
        .onReceive(timer) { _ in
            waveOffset += 1
        }
    }

    private func settingsContent(in size: CGSize, safeAreaInsets: EdgeInsets) -> some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            backgroundImage(in: size, safeAreaInsets: safeAreaInsets)

            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        fxMusic.play()
                        showSettings = false
                    }) {
                        Image("back")
                            .resizable()
                            .scaledToFit()
                            .frame(width: min(max(size.width * 0.25, 96), 126))
                            .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
                            .offset(y: CGFloat(sin(waveOffset * 0.06) * 3))
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, max(18, size.width * 0.05))
                .padding(.top, safeAreaInsets.top + 12)

                Spacer(minLength: size.height * 0.06)

                VStack(spacing: max(46, size.height * 0.075)) {
                    volumeControl(
                        titleImage: "musicvol",
                        titleWidth: min(size.width * 0.9, 380),
                        level: $bgVolumeLevel,
                        size: size
                    ) { level in
                        bgMusic.volume = level
                    }

                    volumeControl(
                        titleImage: "fxvol",
                        titleWidth: min(size.width * 0.72, 300),
                        level: $fxVolumeLevel,
                        size: size
                    ) { level in
                        fxMusic.volume = level;
                        coinMusic.volume = level;
                        waterMusic.volume = level
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: size.height * 0.18)
            }
            .frame(width: size.width, height: size.height)
        }
    }

    private func volumeControl(
        titleImage: String,
        titleWidth: CGFloat,
        level: Binding<CGFloat>,
        size: CGSize,
        onChange: @escaping (CGFloat) -> Void
    ) -> some View {
        let trackWidth = min(size.width * 0.98, 430)
        let knobSize = min(max(size.width * 0.14, 52), 66)
        let trackHeight = min(max(size.height * 0.08, 66), 86)
        let trackTravel = max(trackWidth - knobSize, 1)

        return VStack(spacing: 16) {
            Image(titleImage)
                .resizable()
                .scaledToFit()
                .frame(width: titleWidth)
                .offset(y: CGFloat(sin(waveOffset * 0.05) * 2))

            ZStack(alignment: .leading) {
                Image("volume1")
                    .resizable()
                    .scaledToFit()
                    .frame(width: trackWidth, height: trackHeight)

                Image("play2")
                    .resizable()
                    .scaledToFit()
                    .frame(width: knobSize)
                    .offset(x: trackTravel * level.wrappedValue)
            }
            .frame(width: trackWidth, height: max(trackHeight, knobSize))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let clampedX = min(max(value.location.x - knobSize / 2, 0), trackTravel)
                        let newLevel = clampedX / trackTravel
                        level.wrappedValue = newLevel
                        onChange(newLevel)
                    }
            )
        }
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

    private func syncVolumeLevelsFromPlayers() {
        bgVolumeLevel = min(max(bgMusic.volume, 0), 1)
        fxVolumeLevel = min(max(fxMusic.volume, 0), 1)
        coinVolumeLevel = min(max(coinMusic.volume, 0), 1)
        waterVolumeLevel = min(max(waterMusic.volume, 0), 1)
    }
}
