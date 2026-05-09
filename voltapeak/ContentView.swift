//
//  ContentView.swift
//  voltapeak
//
//  Created by Stéphane Cadinot on 09/05/2026.
//

import SwiftUI
import Charts
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var viewModel = VoltapeakViewModel()
    @State private var selectedFileURL: URL?
    @State private var showingFileImporter = false
    @State private var showingErrorAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Barre d'outils supérieure
            toolbarSection
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Zone de configuration
            configurationSection
                .padding()
                .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // Zone de graphique principale
            if let analysis = viewModel.currentAnalysis {
                VoltammogramChartView(analysis: analysis)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "Aucune donnée",
                    systemImage: "waveform.path.ecg",
                    description: Text("Sélectionnez un fichier .txt pour commencer l'analyse")
                )
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.plainText, UTType(filenameExtension: "txt")!],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .alert("Erreur", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) {}
            
            // Bouton d'aide si erreur de permissions
            if viewModel.errorMessage?.contains("permissions") == true ||
               viewModel.errorMessage?.contains("Sandbox") == true {
                Button("Aide") {
                    if let url = URL(string: "https://developer.apple.com/documentation/security/app_sandbox") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            } else {
                Text("Une erreur est survenue")
            }
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showingErrorAlert = newValue != nil
        }
    }
    
    // MARK: - Toolbar Section
    
    private var toolbarSection: some View {
        HStack {
            Text("Voltapeak")
                .font(.title)
                .fontWeight(.bold)
            
            Spacer()
            
            if let fileName = selectedFileURL?.lastPathComponent {
                Text(fileName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 300)
            }
            
            Spacer()
            
            Button(action: { showingFileImporter = true }) {
                Label("Parcourir", systemImage: "doc.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isProcessing)
            
            Button(action: exportCSV) {
                Label("Exporter CSV", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.currentAnalysis == nil)
        }
    }
    
    // MARK: - Configuration Section
    
    private var configurationSection: some View {
        HStack(spacing: 30) {
            // Séparateur de colonnes
            VStack(alignment: .leading, spacing: 8) {
                Text("Séparateur de colonnes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $viewModel.config.columnSeparator) {
                    ForEach(SWVFileConfiguration.ColumnSeparator.allCases, id: \.self) { separator in
                        Text(separator.displayName).tag(separator)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            }
            
            Divider()
                .frame(height: 40)
            
            // Séparateur décimal
            VStack(alignment: .leading, spacing: 8) {
                Text("Séparateur décimal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $viewModel.config.decimalSeparator) {
                    ForEach(SWVFileConfiguration.DecimalSeparator.allCases, id: \.self) { separator in
                        Text(separator.displayName).tag(separator)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            selectedFileURL = url
            
            // Demander l'accès sécurisé au fichier (sandbox macOS)
            guard url.startAccessingSecurityScopedResource() else {
                viewModel.errorMessage = "Impossible d'accéder au fichier. Vérifiez les permissions."
                return
            }
            
            // Assurer que l'accès sera libéré à la fin
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            Task {
                await viewModel.analyzeFile(at: url)
            }
            
        case .failure(let error):
            viewModel.errorMessage = error.localizedDescription
        }
    }
    
    private func exportCSV() {
        guard let csvContent = viewModel.exportToCSV() else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "voltapeak_export.csv"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? csvContent.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}

// MARK: - Chart View

struct VoltammogramChartView: View {
    let analysis: VoltammetryAnalysis
    
    var body: some View {
        VStack(alignment: .leading) {
            // Titre et statistiques du pic
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Correction de baseline : \(analysis.fileName)")
                        .font(.headline)
                    
                    Text("Pic corrigé à \(String(format: "%.3f V", analysis.peakPotential)) (\(String(format: "%.3f mA", analysis.peakCurrent * 1e3)))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Graphique
            Chart {
                let (potentials, rawCurrents) = SWVFileReader.processData(analysis.rawData)
                
                // Signal brut (transparence)
                ForEach(Array(zip(potentials, rawCurrents).enumerated()), id: \.offset) { index, data in
                    LineMark(
                        x: .value("Potentiel", data.0),
                        y: .value("Courant", data.1)
                    )
                    .foregroundStyle(.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                }
                .accessibilityLabel("Signal brut")
                
                // Signal lissé
                ForEach(Array(zip(potentials, analysis.smoothedSignal).enumerated()), id: \.offset) { index, data in
                    LineMark(
                        x: .value("Potentiel", data.0),
                        y: .value("Courant", data.1)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                }
                .accessibilityLabel("Signal lissé")
                
                // Baseline
                ForEach(Array(zip(potentials, analysis.baseline).enumerated()), id: \.offset) { index, data in
                    LineMark(
                        x: .value("Potentiel", data.0),
                        y: .value("Courant", data.1)
                    )
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                }
                .accessibilityLabel("Baseline estimée")
                
                // Signal corrigé
                ForEach(Array(zip(potentials, analysis.correctedSignal).enumerated()), id: \.offset) { index, data in
                    LineMark(
                        x: .value("Potentiel", data.0),
                        y: .value("Courant", data.1)
                    )
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .accessibilityLabel("Signal corrigé")
                
                // Marqueur du pic
                PointMark(
                    x: .value("Potentiel", analysis.peakPotential),
                    y: .value("Courant", analysis.peakCurrent)
                )
                .foregroundStyle(.pink)
                .symbolSize(100)
                
                // Ligne verticale au pic
                RuleMark(x: .value("Pic", analysis.peakPotential))
                    .foregroundStyle(.pink.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            .chartXAxis {
                AxisMarks(position: .bottom) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .chartXAxisLabel("Potentiel (V)")
            .chartYAxisLabel("Courant (A)")
            .padding()
            
            // Légende
            legendView
                .padding(.horizontal)
                .padding(.bottom)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private var legendView: some View {
        HStack(spacing: 20) {
            LegendItem(color: .gray.opacity(0.5), label: "Signal brut")
            LegendItem(color: .blue, label: "Signal lissé")
            LegendItem(color: .orange, label: "Baseline estimée", dashed: true)
            LegendItem(color: .green, label: "Signal corrigé")
            LegendItem(color: .pink, label: "Pic corrigé", isPoint: true)
        }
        .font(.caption)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    var dashed: Bool = false
    var isPoint: Bool = false
    
    var body: some View {
        HStack(spacing: 4) {
            if isPoint {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            } else {
                Rectangle()
                    .fill(color)
                    .frame(width: 20, height: dashed ? 1 : 2)
                    .overlay {
                        if dashed {
                            Rectangle()
                                .stroke(color, style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
                        }
                    }
            }
            Text(label)
        }
    }
}

#Preview {
    ContentView()
}
