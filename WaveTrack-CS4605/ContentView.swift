//
//  ContentView.swift
//  WaveTrack-CS4605
//
//  Created by Minhnie on 2/19/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    

    var body: some View {
        ZStack {
            Color("Background").ignoresSafeArea()
            
            VStack {
                
                Text("Welcome To")
                    .font(.custom("SourceSerifPro-Bold", size: 36))
                Text("WaveTrack")
                    .font(.custom("SourceSerifPro-Bold", size: 36))
                    .padding(.bottom, 10)
                Text("Press below to record your gesture")
                    .font(.custom("SourceSerifPro-It", size: 24))
                    .padding(.bottom, 80)
                Button {
                    
                } label: {
                    Text("Record Gesture")
                        .font(.custom("AndadaPro-Bold", size: 20))
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 343, height: 52)
                        .background(Color.black)
                        .cornerRadius(16)

                }
                .padding(.horizontal)

                

            }
        }
    }
}

#Preview {
    ContentView()
        
}
