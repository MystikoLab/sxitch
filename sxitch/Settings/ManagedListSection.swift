import SwiftUI

struct ManagedListSection: View {
    let addHeader: String
    let listHeader: String
    let emptyMessage: String
    let placeholder: String
    /// Explanatory text surfaced as a hover info tip next to the headers.
    var infoText: String? = nil

    @Binding var items: [String]
    @State private var newEntry: String = ""

    var body: some View {
        Section {
            HStack {
                TextField(placeholder, text: $newEntry)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addItem() }
                Button("Add", systemImage: "plus") { addItem() }
                    .disabled(newEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        } header: {
            headerView(for: addHeader)
        }

        Section {
            if items.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .italic()
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            } else {
                ForEach(items, id: \.self) { item in
                    HStack {
                        Text(item)
                        Spacer()
                        Button(role: .destructive) {
                            remove(item)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            headerView(for: listHeader)
        }
    }

    @ViewBuilder
    private func headerView(for title: String) -> some View {
        if let infoText {
            InfoTipHeader(title: title, tip: infoText)
        } else {
            Text(title)
        }
    }

    private func addItem() {
        let clean = newEntry.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty, !items.contains(where: { $0.lowercased() == clean }) else { return }
        items.append(clean)
        newEntry = ""
    }

    private func remove(_ item: String) {
        items.removeAll { $0 == item }
    }
}
