import SwiftUI
import SwiftData
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
    @Environment(\.modelContext) private var modelContext

    let schoolClass: SchoolClass
    let onAddSingle: () -> Void
    let onImportCommitted: () -> Void
    let onClose: () -> Void

    @State private var stage: Stage = .options
    @State private var showFilePicker = false
    @State private var parsingErrors: [CSVImportIssue] = []
    @State private var invalidCandidates: [CSVImportCandidate] = []
    @State private var reviewResolutions: [CSVImportResolution] = []
    @State private var commitResult: CSVImportCommitResult?
    @State private var hasCommittedChanges = false
    @State private var selectionTarget: ResolutionSelectionTarget?
    @State private var errorMessage: String?

    private enum Stage {
        case options
        case review
        case summary
    }

    private struct ResolutionSelectionTarget: Identifiable {
        let id: UUID
        let index: Int
    }

    var body: some View {
        GeometryReader { geometry in
            let popupWidth = min(500, geometry.size.width * 0.7)

            VStack(spacing: 0) {
                HStack {
                    Text("Schüler hinzufügen")
                        .font(.system(size: 18, weight: .bold, design: .rounded))

                    Spacer()

                    Button { dismissPopup() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 16)

                switch stage {
                case .options:
                    optionsView
                case .review:
                    reviewView
                case .summary:
                    summaryView
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
        .sheet(item: $selectionTarget) { target in
            resolutionSelectionSheet(for: target)
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

    private var reviewView: some View {
        VStack(spacing: 14) {
            HStack {
                Text("\(reviewResolutions.count) gültige Zeilen geprüft")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !parsingErrors.isEmpty {
                        issueSection(title: "Dateifehler", issues: parsingErrors)
                    }

                    if !invalidCandidates.isEmpty {
                        invalidCandidatesSection
                    }

                    if !reviewResolutions.isEmpty {
                        VStack(spacing: 10) {
                            ForEach(Array(reviewResolutions.enumerated()), id: \.element.importCandidate.id) { index, resolution in
                                reviewRow(for: index, resolution: resolution)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 320)

            HStack(spacing: 12) {
                Button("Zurück") {
                    resetImportState(keepError: false)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Importieren") {
                    commitReview()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCommitReview)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
    }

    private var summaryView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Import abgeschlossen")
                .font(.system(size: 16, weight: .semibold))

            if let commitResult {
                VStack(alignment: .leading, spacing: 8) {
                    summaryLine(label: "Neu angelegt", value: "\(commitResult.createdStudents.count)")
                    summaryLine(label: "Bestehende verwendet", value: "\(commitResult.reusedStudents.count)")
                    summaryLine(label: "Übersprungen", value: "\(commitResult.skippedResolutions.count)")
                }
                .padding(14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.gray.opacity(0.15), lineWidth: 1)
                }
            }

            HStack {
                Spacer()
                Button("Schließen") {
                    dismissPopup()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
    }

    private var invalidCandidatesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ungültige Zeilen")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            ForEach(invalidCandidates, id: \.id) { candidate in
                VStack(alignment: .leading, spacing: 4) {
                    Text("#\(candidate.rowIndex) \(candidate.displayName.isEmpty ? "Ohne Namen" : candidate.displayName)")
                        .font(.system(size: 14, weight: .medium))
                    Text(candidate.issues.map(\.message).joined(separator: " · "))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
                }
            }
        }
    }

    private func reviewRow(for index: Int, resolution: CSVImportResolution) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("#\(resolution.importCandidate.rowIndex) \(resolution.importCandidate.displayName)")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Validierung: gültig · Match: \(matchStatusLabel(for: resolution.matchResult.matchStatus))")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(resolutionLabel(for: resolution.resolutionAction))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(resolution.isComplete ? .green : .orange)
            }

            if !resolution.matchResult.candidateMatches.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(resolution.matchResult.candidateMatches.enumerated()), id: \.offset) { _, match in
                        Text("\(match.displayLabel) · \(match.reason)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button {
                selectionTarget = ResolutionSelectionTarget(
                    id: resolution.importCandidate.id,
                    index: index
                )
            } label: {
                HStack {
                    Label("Entscheidung ändern", systemImage: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(resolution.isComplete ? Color.gray.opacity(0.12) : Color.orange.opacity(0.25), lineWidth: 1)
        }
    }

    private func issueSection(title: String, issues: [CSVImportIssue]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            ForEach(issues, id: \.id) { issue in
                Text(issue.message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var canCommitReview: Bool {
        !reviewResolutions.isEmpty && reviewResolutions.allSatisfy(\.isComplete)
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
                let importResult = CSVImportService.parseCandidates(from: content)
                let matchResults = try CSVImportService.matchCandidates(importResult.validCandidates, in: modelContext)
                let initialResolutions = CSVImportService.makeInitialResolutions(for: matchResults)

                guard !initialResolutions.isEmpty || !importResult.candidates.isEmpty || !importResult.parsingErrors.isEmpty else {
                    errorMessage = "Keine Schülernamen in der Datei gefunden."
                    return
                }

                errorMessage = nil
                parsingErrors = importResult.parsingErrors
                invalidCandidates = importResult.candidates.filter { $0.validationStatus == .invalid }
                reviewResolutions = initialResolutions
                commitResult = nil
                stage = .review
            } catch {
                errorMessage = "Datei konnte nicht gelesen werden."
            }

        case .failure:
            errorMessage = "Datei konnte nicht geöffnet werden."
        }
    }

    private func commitReview() {
        do {
            let result = try CSVImportService.commitResolutions(
                reviewResolutions,
                into: schoolClass,
                context: modelContext
            )
            commitResult = result
            hasCommittedChanges = result.outcomes.contains { $0.status == .committed }
            stage = .summary
            errorMessage = nil
        } catch {
            errorMessage = "Import konnte nicht abgeschlossen werden."
        }
    }

    private func resetImportState(keepError: Bool) {
        stage = .options
        parsingErrors = []
        invalidCandidates = []
        reviewResolutions = []
        commitResult = nil
        if !keepError {
            errorMessage = nil
        }
    }

    private func matchStatusLabel(for status: CSVImportMatchStatus) -> String {
        switch status {
        case .none:
            return "kein Treffer"
        case .single:
            return "1 Treffer"
        case .multiple:
            return "mehrere Treffer"
        }
    }

    private func resolutionLabel(for action: CSVImportResolutionAction) -> String {
        switch action {
        case .unresolved:
            return "Offen"
        case .createNewStudent:
            return "Neu anlegen"
        case .useExistingStudent:
            return "Bestehend"
        case .skip:
            return "Überspringen"
        }
    }

    private func summaryLine(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
        }
    }

    @ViewBuilder
    private func resolutionSelectionSheet(for target: ResolutionSelectionTarget) -> some View {
        let resolution = reviewResolutions[target.index]

        NavigationStack {
            List {
                Section("Importzeile") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(resolution.importCandidate.displayName)
                            .font(.system(size: 15, weight: .semibold))
                        Text("Match: \(matchStatusLabel(for: resolution.matchResult.matchStatus))")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }

                Section("Aktionen") {
                    selectionActionRow(
                        title: "Neu anlegen",
                        subtitle: "Neuen Student aus dieser CSV-Zeile erzeugen.",
                        isSelected: reviewResolutions[target.index].resolutionAction == .createNewStudent
                    ) {
                        reviewResolutions[target.index].resolutionAction = .createNewStudent
                        selectionTarget = nil
                    }

                    selectionActionRow(
                        title: "Überspringen",
                        subtitle: "Diese Zeile nicht importieren.",
                        isSelected: reviewResolutions[target.index].resolutionAction == .skip
                    ) {
                        reviewResolutions[target.index].resolutionAction = .skip
                        selectionTarget = nil
                    }

                    if resolution.matchResult.matchStatus != .none {
                        selectionActionRow(
                            title: "Offen lassen",
                            subtitle: "Noch keine Entscheidung treffen.",
                            isSelected: reviewResolutions[target.index].resolutionAction == .unresolved
                        ) {
                            reviewResolutions[target.index].resolutionAction = .unresolved
                            selectionTarget = nil
                        }
                    }
                }

                if !resolution.matchResult.candidateMatches.isEmpty {
                    Section("Vorhandene Schüler") {
                        ForEach(Array(resolution.matchResult.candidateMatches.enumerated()), id: \.offset) { _, match in
                            selectionActionRow(
                                title: match.student.fullName,
                                subtitle: match.contextSummary,
                                trailingText: match.reason,
                                isSelected: reviewResolutions[target.index].resolutionAction == .useExistingStudent(studentID: match.student.id)
                            ) {
                                reviewResolutions[target.index].resolutionAction = .useExistingStudent(studentID: match.student.id)
                                selectionTarget = nil
                            }
                        }
                    }
                }
            }
            .navigationTitle("Auswahl")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        selectionTarget = nil
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func selectionActionRow(
        title: String,
        subtitle: String,
        trailingText: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    if let trailingText {
                        Text(trailingText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dismissPopup() {
        if hasCommittedChanges {
            hasCommittedChanges = false
            onImportCommitted()
        }
        onClose()
    }
}
