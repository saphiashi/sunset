import SwiftUI
import SwiftData

struct CollectionDetailView: View {
    let collectionID: UUID
    @Query private var collections: [SkyCollection]
    @Environment(\.modelContext) private var context
    @State private var newName = ""
    @State private var showRename = false

    private var collection: SkyCollection? { collections.first { $0.id == collectionID } }

    var body: some View {
        Group {
            if let collection {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 10) {
                            Image(systemName: collection.symbol)
                                .foregroundStyle(collection.accent)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(collection.name)
                                    .font(Typeface.display(32))
                                Text(collection.detail)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if collection.entries.isEmpty {
                            QuietEmpty(
                                symbol: collection.symbol,
                                title: "An empty shelf",
                                detail: "Open an evening you logged and add it here."
                            )
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                                ForEach(collection.entries.sorted { $0.capturedAt > $1.capturedAt }, id: \.id) { entry in
                                    NavigationLink(value: Route.entry(entry.id)) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            SkyPhoto(entry: entry, corner: 14)
                                                .frame(height: 170)
                                            Text(entry.spot?.name ?? "Sky")
                                                .font(Typeface.caption(12))
                                                .lineLimit(1)
                                                .foregroundStyle(.primary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            } else {
                QuietEmpty(symbol: "square.grid.2x2", title: "Missing collection", detail: "This shelf was put away.")
            }
        }
        .duskBackdrop()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if collection != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Rename") { showRename = true }
                }
            }
        }
        .alert("Rename collection", isPresented: $showRename) {
            TextField("Name", text: $newName)
            Button("Save") {
                if let collection, !newName.trimmingCharacters(in: .whitespaces).isEmpty {
                    collection.name = newName
                    try? context.save()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            newName = collection?.name ?? ""
        }
    }
}

struct NewCollectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var detail = ""
    @State private var token = "ember"

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("A line about it", text: $detail)
                Picker("Accent", selection: $token) {
                    Text("Ember").tag("ember")
                    Text("Rose").tag("rose")
                    Text("Storm").tag("storm")
                    Text("Gold").tag("gold")
                }
            }
            .navigationTitle("New collection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let collection = SkyCollection(
                            name: name,
                            detail: detail.isEmpty ? "A shelf you made." : detail,
                            symbol: "folder.fill",
                            accentToken: token
                        )
                        context.insert(collection)
                        try? context.save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
