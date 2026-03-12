import SwiftUI
import UniformTypeIdentifiers

struct AddStudentTopPopup: View {
    @Binding var name: String
    let onCancel: () -> Void
    let onAdd: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            let popupWidth = min(700, geometry.size.width * 0.66)

            VStack(alignment: .leading, spacing: 10) {
                Text("Schüler hinzufügen")
                    .font(.system(size: 15, weight: .semibold))

                TextField("z. B. Anna Müller", text: $name)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Abbrechen", action: onCancel)
                        .buttonStyle(.bordered)

                    Spacer()

                    Button("Hinzufügen", action: onAdd)
                        .buttonStyle(.borderedProminent)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(22)
            .background(Color.secondarySystemGroupedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 25, y: 10)
            .frame(width: popupWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

// MARK: - Add Students Popup (CSV Import)

struct AddStudentsPopup: View {
    let onAddSingle: () -> Void
    let onImportStudents: ([String]) -> Void
    let onClose: () -> Void

    @State private var showFilePicker = false
    @State private var csvPreviewNames: [String] = []
    @State private var showPreview = false
    @State private var errorMessage: String?

    var body: some View {
        GeometryReader { geometry in
            let popupWidth = min(500, geometry.size.width * 0.7)

            VStack(spacing: 0) {
                HStack {
                    Text("Schüler hinzufügen")
                        .font(.system(size: 18, weight: .bold, design: .rounded))

                    Spacer()

                    Button { onClose() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 16)

                if showPreview {
                    csvPreviewView
                } else {
                    optionsView
                }
            }
            .background(Color.secondarySystemGroupedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.15), radius: 30, y: 12)
            .frame(width: popupWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.commaSeparatedText, UTType.plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    private var optionsView: some View {
        VStack(spacing: 12) {
            Button {
                onClose()
                onAddSingle()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 40, height: 40)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Einzeln hinzufügen")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Einen Schüler manuell eingeben")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.gray.opacity(0.15), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            Button {
                showFilePicker = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "tablecells")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.green)
                        .frame(width: 40, height: 40)
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("CSV-Datei importieren")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Klassenliste aus einer .csv-Datei laden")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.gray.opacity(0.15), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            if let errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
    }

    private var csvPreviewView: some View {
        VStack(spacing: 14) {
            HStack {
                Text("\(csvPreviewNames.count) Schüler erkannt")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(csvPreviewNames.enumerated()), id: \.offset) { index, name in
                        HStack {
                            Text("\(index + 1).")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .trailing)
                            Text(name)
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        if index < csvPreviewNames.count - 1 {
                            Divider()
                        }
                    }
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.gray.opacity(0.15), lineWidth: 1)
                }
            }
            .frame(maxHeight: 250)

            HStack(spacing: 12) {
                Button("Abbrechen") {
                    showPreview = false
                    csvPreviewNames = []
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Alle importieren") {
                    onImportStudents(csvPreviewNames)
                    onClose()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Zugriff auf die Datei wurde verweigert."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let names = CSVImportService.parseStudentNames(from: content)
                if names.isEmpty {
                    errorMessage = "Keine Schülernamen in der Datei gefunden."
                } else {
                    errorMessage = nil
                    csvPreviewNames = names
                    showPreview = true
                }
            } catch {
                errorMessage = "Datei konnte nicht gelesen werden."
            }

        case .failure:
            errorMessage = "Datei konnte nicht geöffnet werden."
        }
    }
}
