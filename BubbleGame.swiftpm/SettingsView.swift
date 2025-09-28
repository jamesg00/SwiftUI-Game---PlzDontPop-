import SwiftUI
import Subsonic

struct SettingsView: View {
    @Binding var showSettings: Bool
    @State private var waveOffset: CGFloat = 0.0
    @State private var dragAmount = CGSize.zero        
    @State private var dragX : CGFloat = 0.0  
    @State private var lastDragX: CGFloat = 0.0
    @State private var dragXf : CGFloat = 0.0
    @State private var lastDragXf : CGFloat = 0.0
    @ObservedObject var bgMusic: SubsonicPlayer 
    @ObservedObject var fxMusic: SubsonicPlayer

    
    let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Image("sea")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            // ✅ Back button with sine wave animation
            Button(action: {
                fxMusic.play()
                showSettings = false
            }) {
                Image("back")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80)
                
               
            }
            .offset(y: CGFloat(sin(waveOffset * 0.1) * 8)) // 👈 Sine wave applied here
            .buttonStyle(.plain)
            .position(x: 200, y: 50) // 👈 Adjust this as needed for placement
            
            
        //Code for images of music volume text and volumes slider. Adds play button to be moved this will contorl background music
            Image("musicvol")
                .resizable()
                .scaledToFit()
                .position(x: 120, y: 160 + CGFloat(sin(waveOffset * 0.08) * 6))                 
                .frame(width:230) 
            
            Image("volume1")
                .resizable()   
                .scaledToFit()   
                .position(x: 150, y:220)
                .frame(width:300)
            
            Image("play2")
                .resizable()
                .scaledToFit()
                .position(x: -98 + dragX, y: 220) // Always based off -98 starting point
                .frame(width: 35)
                .zIndex(dragX == 0 ? 0 : 1)
                .gesture(
                    DragGesture(coordinateSpace: .global)
                        .onChanged { value in
                            let newX = lastDragX + value.translation.width
                            dragX = min(max(newX, 0), 235) // clamp between 0 and 250
                            
                            bgMusic.volume = dragX/250
                        }
                        .onEnded { _ in
                            lastDragX = dragX // lock in position
                        }
                )
            
             
        //Same thing but for fx volume. This will control hit1.mp3    
            Image("fxvol")
                .resizable()
                .scaledToFit()
                .position(x: 80, y: 370 + CGFloat(sin(waveOffset * 0.05) * 6))
                .frame(width:160)
            
            Image("volume1")
                .resizable()   
                .scaledToFit()   
                .position(x: 150, y:430)
                .frame(width:300)

            Image("play2")
                .resizable()
                .scaledToFit()
                .position(x:-98 + dragXf, y:430)
                .frame(width:35)
                .zIndex(dragXf == 0 ? 0 : 1)

                .gesture(
                    DragGesture(coordinateSpace: .global)
                        .onChanged { value in
                            let newXf = lastDragXf + value.translation.width
                            dragXf = min(max(newXf, 0), 235) // clamp between 0 and 250
                            
                            fxMusic.volume = dragXf/250
                        }
                        .onEnded { _ in
                            lastDragXf = dragXf // lock in position
                        }
                )            
        }
        .onReceive(timer) { _ in
            waveOffset += 1
        }
        
        .onAppear{
            let initialX = bgMusic.volume * 250
            dragX = initialX
            lastDragX = initialX
            
            let initialXf = fxMusic.volume * 250
            dragXf = initialXf
            lastDragXf = initialXf
        }
    }
    

}
