//
//  SWVFileReader.swift
//  voltapeak
//
//  Created by Stéphane Cadinot on 09/05/2026.
//

import Foundation

/// Lecteur de fichiers de voltampérométrie SWV
class SWVFileReader {
    
    enum FileError: LocalizedError {
        case fileNotFound
        case invalidFormat
        case insufficientData
        case permissionDenied
        case encodingError
        
        var errorDescription: String? {
            switch self {
            case .fileNotFound:
                return "Fichier introuvable"
            case .invalidFormat:
                return "Format de fichier invalide. Vérifiez que c'est un fichier texte avec deux colonnes (Potentiel, Courant)."
            case .insufficientData:
                return "Données insuffisantes (moins de 5 points). Le fichier doit contenir au moins 5 lignes de données."
            case .permissionDenied:
                return "Permissions insuffisantes pour accéder au fichier. Vérifiez les paramètres App Sandbox dans Xcode."
            case .encodingError:
                return "Erreur d'encodage. Le fichier doit être encodé en ISO Latin-1."
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .permissionDenied:
                return "Dans Xcode : Signing & Capabilities > App Sandbox > User Selected File (Read Only)"
            case .invalidFormat:
                return "Le fichier doit avoir le format :\nPotentiel    Courant\n-0.500    -1.234e-06\n..."
            case .encodingError:
                return "Essayez de réenregistrer le fichier avec l'encodage ISO Latin-1"
            default:
                return nil
            }
        }
    }
    
    /// Lit un fichier SWV et retourne les données brutes
    /// - Parameters:
    ///   - url: URL du fichier
    ///   - config: Configuration de lecture
    /// - Returns: Tableau de points (potentiel, courant)
    static func readFile(at url: URL, config: SWVFileConfiguration) throws -> [VoltammetryPoint] {
        // Vérifier que le fichier existe et est accessible
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw FileError.permissionDenied
        }
        
        // Lecture du fichier avec l'encodage spécifié
        let content: String
        do {
            content = try String(contentsOf: url, encoding: config.encoding)
        } catch let error as NSError {
            // Erreur de permissions spécifique
            if error.domain == NSCocoaErrorDomain && error.code == 257 {
                throw FileError.permissionDenied
            }
            // Erreur d'encodage
            if error.domain == NSCocoaErrorDomain && error.code == 261 {
                throw FileError.encodingError
            }
            throw error
        }
        
        // Séparer en lignes
        let lines = content.components(separatedBy: .newlines)
        
        guard lines.count > 1 else {
            throw FileError.invalidFormat
        }
        
        // Ignorer la première ligne (en-tête) et les lignes vides
        let dataLines = lines.dropFirst().filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        var points: [VoltammetryPoint] = []
        
        for line in dataLines {
            // Séparer les colonnes
            let columns = line.components(separatedBy: config.columnSeparator.rawValue)
            
            guard columns.count >= 2 else { continue }
            
            // Convertir en nombres (gérer le séparateur décimal)
            let potentialString = columns[0].trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: config.decimalSeparator.rawValue, with: ".")
            let currentString = columns[1].trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: config.decimalSeparator.rawValue, with: ".")
            
            if let potential = Double(potentialString),
               let current = Double(currentString),
               current != 0 {  // Ignorer les points à courant nul
                points.append(VoltammetryPoint(potential: potential, current: current))
            }
        }
        
        guard points.count >= 5 else {
            throw FileError.insufficientData
        }
        
        return points
    }
    
    /// Traite les données brutes : tri et inversion du signe du courant (COMME PYTHON)
    /// - Parameter points: Points bruts
    /// - Returns: Tuple (potentiels, courants) triés
    static func processData(_ points: [VoltammetryPoint]) -> (potentials: [Double], currents: [Double]) {
        // Tri par potentiel croissant
        let sorted = points.sorted { $0.potential < $1.potential }
        
        // Extraction et inversion du signe (EXACTEMENT comme le code Python)
        // Python fait : signalValues = -dataFrame["Current"].values
        let potentials = sorted.map { $0.potential }
        let currents = sorted.map { -$0.current }  // INVERSION comme Python
        
        return (potentials, currents)
    }
}
