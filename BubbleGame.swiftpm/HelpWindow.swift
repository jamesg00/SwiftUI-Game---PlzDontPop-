import SwiftUI
import Subsonic 

struct HelpWindow: View {
    @Binding var showHelp: Bool
    @State private var waveOffset: CGFloat = 0.0
    @ObservedObject var fxMusic: SubsonicPlayer 

    let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()
    
    // Portrait screen size assumptions for iPad/iPhone (adjust as needed)
    let screenWidth: CGFloat = 375
    let screenHeight: CGFloat = 667

     
    var body: some View {
        ZStack {
            Image("sea")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            // Back button positioned absolutely near top-left
            Button(action: {
                fxMusic.play() 
                showHelp = false
            }) {
                Image("back")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90)
                    .offset(y: sin(waveOffset * 0.09) * 5)
            }
            .buttonStyle(.plain)
            .position(x: 200, y: 60) // Hardcoded near top-left
            
            // Title text centered horizontally, fixed y
            sineWaveImage("text1", amplitude: 5, speed: 0.08, phase: 0)
                .scaleEffect(1.4)
                .frame(width: 270)
                .position(x: screenWidth / 2 + 150, y: 200)
            
            // HStack with wrong1 on left, right1 on right, positioned absolutely near bottom
            sineWaveImage("wrong1", amplitude:9, speed: 0.1, phase:0)
                .scaledToFit()
                .frame(width: 205)
                .position(x: 230, y: screenHeight - 211)
            
            sineWaveImage("right1", amplitude:10, speed: 0.09, phase:0)
                .scaledToFit()
                .frame(width: 220)
                .position(x: screenWidth+60, y: screenHeight - 200)
        }
        .frame(width: screenWidth, height: screenHeight) // Fix the whole frame
        .onReceive(timer) { _ in
            waveOffset += 0.5 
        }
    }
    
    func sineWaveImage(_ imageName: String, amplitude: CGFloat, speed: CGFloat, phase: Double) -> some View {
        Image(imageName)
            .resizable()
            .scaledToFit()
            .offset(y: CGFloat(sin(waveOffset * speed + phase) * amplitude))
    }
}
