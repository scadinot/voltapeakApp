//
//  SettingsView.swift
//  voltapeak
//
//  Created by Stéphane Cadinot on 09/05/2026.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("refreshInterval") private var refreshInterval: Double = 1.0
    @AppStorage("maxReadings") private var maxReadings: Int = 100
    @AppStorage("alertThreshold") private var alertThreshold: Double = 5.0
    @AppStorage("enableAlerts") private var enableAlerts: Bool = false
    
    var body: some View {
        Form {
            Section("Surveillance") {
                LabeledContent("Intervalle de rafraîchissement") {
                    HStack {
                        Slider(value: $refreshInterval, in: 0.1...5.0, step: 0.1)
                            .frame(width: 200)
                        Text(String(format: "%.1f s", refreshInterval))
                            .frame(width: 50, alignment: .trailing)
                    }
                }
                
                LabeledContent("Nombre max de lectures") {
                    Stepper("\(maxReadings)", value: $maxReadings, in: 10...1000, step: 10)
                }
            }
            
            Section("Alertes") {
                Toggle("Activer les alertes", isOn: $enableAlerts)
                
                LabeledContent("Seuil d'alerte (V)") {
                    HStack {
                        TextField("Seuil", value: $alertThreshold, format: .number)
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                        Text("V")
                    }
                }
                .disabled(!enableAlerts)
            }
            
            Section("À propos") {
                LabeledContent("Version") {
                    Text("1.0")
                }
                
                LabeledContent("Auteur") {
                    Text("Stéphane Cadinot")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 350)
    }
}

#Preview {
    SettingsView()
}
