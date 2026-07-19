import SwiftUI
import UniformTypeIdentifiers

struct UploadRouteView: View {
    @Environment(\.dismiss) var dismiss

    @State private var isPickerPresented = false
    @State private var importedDraft: Route?
    @State private var importError: String?
    @State private var isPublic = false
    @State private var isSaving = false
    @State private var savedSuccessfully = false

    var body: some View {
        Form {
            Section {
                Text(NSLocalizedString("upload_route.instructions", comment: ""))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    isPickerPresented = true
                } label: {
                    Label(NSLocalizedString("upload_route.choose_file", comment: ""), systemImage: "doc.badge.plus")
                }
            }

            if let importError {
                Section {
                    Text(importError).foregroundStyle(.red)
                }
            }

            if let draft = importedDraft {
                Section(NSLocalizedString("upload_route.preview", comment: "")) {
                    Text(draft.name).font(.headline)
                    Text(String(format: NSLocalizedString("upload_route.stop_count", comment: ""), draft.stops.count))
                        .font(.footnote)
                    ForEach(draft.stops.prefix(5)) { stop in
                        Text("• \(stop.name)").font(.caption).foregroundStyle(.secondary)
                    }
                    if draft.stops.count > 5 {
                        Text("...").font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section {
                    Toggle(NSLocalizedString("create_route.make_public", comment: ""), isOn: $isPublic)
                }

                Section {
                    Button {
                        Task { await save(draft) }
                    } label: {
                        if isSaving { ProgressView() } else { Text(NSLocalizedString("common.save", comment: "")).frame(maxWidth: .infinity) }
                    }
                    .disabled(isSaving)
                }
            }
        }
        .navigationTitle(NSLocalizedString("upload_route.title", comment: ""))
        .fileImporter(
            isPresented: $isPickerPresented,
            allowedContentTypes: [.json, .commaSeparatedText, UTType(filenameExtension: "gpx") ?? .xml],
            allowsMultipleSelection: false
        ) { result in
            handlePickedFile(result)
        }
        .alert(NSLocalizedString("create_route.saved_title", comment: ""), isPresented: $savedSuccessfully) {
            Button(NSLocalizedString("common.ok", comment: "")) { dismiss() }
        }
    }

    private func handlePickedFile(_ result: Result<[URL], Error>) {
        importError = nil
        importedDraft = nil
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                importedDraft = try RouteFileImporter.importRoute(from: url)
            } catch {
                importError = error.localizedDescription
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func save(_ draft: Route) async {
        isSaving = true
        defer { isSaving = false }
        var toSave = draft
        toSave.isPublic = isPublic
        toSave.status = isPublic ? .pending : .privateOnly
        do {
            _ = try await APIClient.shared.createRoute(toSave)
            savedSuccessfully = true
        } catch {
            importError = error.localizedDescription
        }
    }
}
