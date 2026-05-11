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
    @State private var viewModel = VoltapeakViewModel()  // Retour au ViewModel optimisé
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

            Button(action: exportXLSX) {
                Label("Exporter Excel", systemImage: "tablecells")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.currentAnalysis == nil)

            Button(action: exportPNG) {
                Label("Exporter PNG", systemImage: "photo")
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

    private func exportXLSX() {
        guard let xlsxData = viewModel.exportToXLSX() else { return }

        let panel = NSSavePanel()
        if let xlsxType = UTType(filenameExtension: "xlsx") {
            panel.allowedContentTypes = [xlsxType]
        }
        panel.nameFieldStringValue = "voltapeak_export.xlsx"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? xlsxData.write(to: url)
            }
        }
    }

    @MainActor
    private func exportPNG() {
        guard let analysis = viewModel.currentAnalysis else { return }

        let renderer = ImageRenderer(content:
            VoltammogramChartView(analysis: analysis)
                .frame(width: 1600, height: 1000)
        )
        renderer.scale = 2.0

        guard let nsImage = renderer.nsImage,
              let tiff = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            viewModel.errorMessage = "Échec du rendu PNG du graphique."
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "voltapeak_export.png"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? pngData.write(to: url)
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
            chartView
                .padding()

            // Légende
            legendView
                .padding(.horizontal)
                .padding(.bottom)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // Couleurs alignées sur les défauts matplotlib (tab10) pour parité visuelle Python
    private static let mplBlue   = Color(red: 0.122, green: 0.467, blue: 0.706)  // C0
    private static let mplOrange = Color(red: 1.000, green: 0.498, blue: 0.055)  // C1
    private static let mplGreen  = Color(red: 0.173, green: 0.627, blue: 0.173)  // C2
    private static let mplRed    = Color(red: 0.839, green: 0.153, blue: 0.157)  // C3
    private static let mplMagenta = Color(red: 1.0, green: 0.0, blue: 1.0)        // 'm'

    private var chartView: some View {
        // Pré-calcul des potentiels et du domaine
        let (potentials, rawCurrents) = SWVFileReader.processData(analysis.rawData)
        let xMin = potentials.min() ?? 0
        let xMax = potentials.max() ?? 1
        // Bornes Y : englobe toutes les séries + une petite marge
        let allY = rawCurrents + analysis.smoothedSignal + analysis.baseline + analysis.correctedSignal
        let yMin = (allY.min() ?? 0)
        let yMax = (allY.max() ?? 1)
        let yPad = (yMax - yMin) * 0.05
        let pts = Array(zip(potentials, rawCurrents))

        return Chart {
            // Signal brut (bleu α=0.5) — series: identifie la ligne pour SwiftUI Charts
            ForEach(pts.indices, id: \.self) { i in
                LineMark(
                    x: .value("Potentiel", pts[i].0),
                    y: .value("Courant", pts[i].1),
                    series: .value("Série", "brut")
                )
                .foregroundStyle(Self.mplBlue.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 0.8))
            }

            // Signal lissé (orange)
            ForEach(potentials.indices, id: \.self) { i in
                LineMark(
                    x: .value("Potentiel", potentials[i]),
                    y: .value("Courant", analysis.smoothedSignal[i]),
                    series: .value("Série", "lissé")
                )
                .foregroundStyle(Self.mplOrange)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            }

            // Baseline (vert dashed)
            ForEach(potentials.indices, id: \.self) { i in
                LineMark(
                    x: .value("Potentiel", potentials[i]),
                    y: .value("Courant", analysis.baseline[i]),
                    series: .value("Série", "baseline")
                )
                .foregroundStyle(Self.mplGreen)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            }

            // Signal corrigé (rouge)
            ForEach(potentials.indices, id: \.self) { i in
                LineMark(
                    x: .value("Potentiel", potentials[i]),
                    y: .value("Courant", analysis.correctedSignal[i]),
                    series: .value("Série", "corrigé")
                )
                .foregroundStyle(Self.mplRed)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            // Ligne verticale au pic (magenta pointillée)
            RuleMark(x: .value("Pic", analysis.peakPotential))
                .foregroundStyle(Self.mplMagenta.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

            // Marqueur du pic (magenta)
            PointMark(
                x: .value("Potentiel", analysis.peakPotential),
                y: .value("Courant", analysis.peakCurrent)
            )
            .foregroundStyle(Self.mplMagenta)
            .symbolSize(80)
        }
        .chartXScale(domain: xMin...xMax)
        .chartYScale(domain: (yMin - yPad)...(yMax + yPad))
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
    }

    private var legendView: some View {
        HStack(spacing: 20) {
            LegendItem(color: Self.mplBlue.opacity(0.5), label: "Signal brut")
            LegendItem(color: Self.mplOrange, label: "Signal lissé")
            LegendItem(color: Self.mplGreen, label: "Baseline estimée (asPLS)", dashed: true)
            LegendItem(color: Self.mplRed, label: "Signal corrigé")
            LegendItem(color: Self.mplMagenta, label: "Pic corrigé", isPoint: true)
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
