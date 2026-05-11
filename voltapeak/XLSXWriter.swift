//
//  XLSXWriter.swift
//  voltapeak
//
//  Génère un fichier .xlsx (Excel 2007+, OOXML) à partir d'une analyse SWV.
//  Implémentation autonome : mini-ZIP store-only (compression method=0)
//  + 5 fichiers XML minimaux. Aucune dépendance externe.
//
//  Format produit lisible par Excel, Numbers, Google Sheets, LibreOffice.
//

import Foundation

enum XLSXWriter {

    /// Construit un .xlsx complet et renvoie ses octets prêts à écrire sur disque.
    /// - Parameters:
    ///   - analysis: résultat d'analyse à sérialiser
    ///   - potentials: potentiels triés/inversés (`SWVFileReader.processData`)
    ///   - rawCurrents: courants bruts alignés
    static func write(
        analysis: VoltammetryAnalysis,
        potentials: [Double],
        rawCurrents: [Double]
    ) -> Data {
        let files: [(name: String, data: Data)] = [
            ("[Content_Types].xml", Data(contentTypes.utf8)),
            ("_rels/.rels", Data(rootRels.utf8)),
            ("xl/workbook.xml", Data(workbook.utf8)),
            ("xl/_rels/workbook.xml.rels", Data(workbookRels.utf8)),
            ("xl/worksheets/sheet1.xml",
             Data(buildSheetXML(analysis: analysis,
                                potentials: potentials,
                                rawCurrents: rawCurrents).utf8))
        ]
        return ZIPStore.archive(files)
    }

    // MARK: - XML statiques

    private static let contentTypes = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\
    <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\
    <Default Extension="xml" ContentType="application/xml"/>\
    <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>\
    <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>\
    </Types>
    """

    private static let rootRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>\
    </Relationships>
    """

    private static let workbook = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\
    <sheets><sheet name="Analyse SWV" sheetId="1" r:id="rId1"/></sheets>\
    </workbook>
    """

    private static let workbookRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>\
    </Relationships>
    """

    // MARK: - Construction de la feuille

    private static let headers = [
        "Potentiel (V)",
        "Courant brut (A)",
        "Signal lissé (A)",
        "Baseline (A)",
        "Signal corrigé (A)"
    ]

    private static func buildSheetXML(
        analysis: VoltammetryAnalysis,
        potentials: [Double],
        rawCurrents: [Double]
    ) -> String {
        var rows = ""

        // En-tête (ligne 1) — chaînes inline (pas de table sharedStrings)
        rows += "<row r=\"1\">"
        for (i, header) in headers.enumerated() {
            let col = column(i)
            rows += "<c r=\"\(col)1\" t=\"inlineStr\"><is><t>\(xmlEscape(header))</t></is></c>"
        }
        rows += "</row>"

        // Données (lignes 2..n+1)
        let n = potentials.count
        for i in 0..<n {
            let r = i + 2
            let values: [Double] = [
                potentials[i],
                rawCurrents[i],
                analysis.smoothedSignal[i],
                analysis.baseline[i],
                analysis.correctedSignal[i]
            ]
            rows += "<row r=\"\(r)\">"
            for (j, v) in values.enumerated() {
                rows += "<c r=\"\(column(j))\(r)\"><v>\(v)</v></c>"
            }
            rows += "</row>"
        }

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\
        <sheetData>\(rows)</sheetData>\
        </worksheet>
        """
    }

    /// Convertit un index 0-based en lettre de colonne Excel (A, B, …, Z, AA, AB, …).
    private static func column(_ index: Int) -> String {
        var n = index
        var result = ""
        repeat {
            let r = n % 26
            result = String(UnicodeScalar(65 + r)!) + result
            n = n / 26 - 1
        } while n >= 0
        return result
    }

    /// Échappe les caractères réservés XML dans les chaînes.
    private static func xmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
         .replacingOccurrences(of: "'", with: "&apos;")
    }
}

// MARK: - Mini ZIP store-only (compression method = 0)

private enum ZIPStore {

    /// Empaquette une liste de fichiers (nom, données) en archive ZIP non compressée.
    /// Format suffisant pour OOXML — Excel/Numbers acceptent le ZIP store-only.
    static func archive(_ files: [(name: String, data: Data)]) -> Data {
        var output = Data()
        var centralDirectory = Data()

        for file in files {
            let nameBytes = Array(file.name.utf8)
            let crc = crc32(file.data)
            let size = UInt32(file.data.count)
            let localOffset = UInt32(output.count)

            // Local File Header
            var lfh = Data()
            lfh.appendUInt32LE(0x04034b50) // signature
            lfh.appendUInt16LE(20)         // version needed
            lfh.appendUInt16LE(0)          // general purpose flags
            lfh.appendUInt16LE(0)          // compression method = 0 (store)
            lfh.appendUInt16LE(0)          // last mod time
            lfh.appendUInt16LE(0)          // last mod date
            lfh.appendUInt32LE(crc)
            lfh.appendUInt32LE(size)       // compressed size (= uncompressed pour store)
            lfh.appendUInt32LE(size)       // uncompressed size
            lfh.appendUInt16LE(UInt16(nameBytes.count))
            lfh.appendUInt16LE(0)          // extra field length
            lfh.append(contentsOf: nameBytes)
            output.append(lfh)
            output.append(file.data)

            // Central Directory Entry
            var cde = Data()
            cde.appendUInt32LE(0x02014b50) // signature
            cde.appendUInt16LE(20)         // version made by
            cde.appendUInt16LE(20)         // version needed
            cde.appendUInt16LE(0)          // flags
            cde.appendUInt16LE(0)          // compression
            cde.appendUInt16LE(0)          // mod time
            cde.appendUInt16LE(0)          // mod date
            cde.appendUInt32LE(crc)
            cde.appendUInt32LE(size)
            cde.appendUInt32LE(size)
            cde.appendUInt16LE(UInt16(nameBytes.count))
            cde.appendUInt16LE(0)          // extra
            cde.appendUInt16LE(0)          // comment
            cde.appendUInt16LE(0)          // disk number
            cde.appendUInt16LE(0)          // internal attrs
            cde.appendUInt32LE(0)          // external attrs
            cde.appendUInt32LE(localOffset)
            cde.append(contentsOf: nameBytes)
            centralDirectory.append(cde)
        }

        let centralStart = UInt32(output.count)
        let centralSize = UInt32(centralDirectory.count)
        output.append(centralDirectory)

        // End of Central Directory Record
        var eocd = Data()
        eocd.appendUInt32LE(0x06054b50)
        eocd.appendUInt16LE(0)             // disk number
        eocd.appendUInt16LE(0)             // disk with central
        eocd.appendUInt16LE(UInt16(files.count))
        eocd.appendUInt16LE(UInt16(files.count))
        eocd.appendUInt32LE(centralSize)
        eocd.appendUInt32LE(centralStart)
        eocd.appendUInt16LE(0)             // comment length
        output.append(eocd)

        return output
    }

    /// CRC32 standard PKZIP (polynôme inversé 0xEDB88320).
    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                let mask: UInt32 = (crc & 1) != 0 ? 0xEDB88320 : 0
                crc = (crc >> 1) ^ mask
            }
        }
        return crc ^ 0xFFFFFFFF
    }
}

private extension Data {
    mutating func appendUInt16LE(_ v: UInt16) {
        append(UInt8(v & 0xff))
        append(UInt8((v >> 8) & 0xff))
    }
    mutating func appendUInt32LE(_ v: UInt32) {
        append(UInt8(v & 0xff))
        append(UInt8((v >> 8) & 0xff))
        append(UInt8((v >> 16) & 0xff))
        append(UInt8((v >> 24) & 0xff))
    }
}
