import SwiftUI

struct SFSymbolPickerView: View {
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var customSymbol = ""

    static let curated: [String] = [
        "terminal.fill", "terminal", "xmark", "checkmark", "chevron.left", "chevron.right",
        "globe", "applelogo", "command", "option", "shift", "control", "capslock",
        "doc.fill", "doc.text.fill", "folder.fill", "tray.fill", "externaldrive.fill",
        "network", "wifi", "antenna.radiowaves.left.and.right", "bolt.fill",
        "camera.fill", "photo.fill", "photo.on.rectangle.angled", "video.fill", "film.fill",
        "music.note", "music.note.list", "guitars.fill", "pianokeys", "mic.fill",
        "message.fill", "bubble.left.fill", "phone.fill", "envelope.fill", "person.fill",
        "person.2.fill", "person.3.fill", "house.fill", "briefcase.fill", "building.2.fill",
        "cart.fill", "creditcard.fill", "banknote.fill", "dollarsign.circle.fill",
        "calendar", "clock.fill", "timer", "stopwatch.fill", "alarm.fill",
        "location.fill", "map.fill", "mappin", "safari.fill", "airplane",
        "car.fill", "bicycle", "figure.walk", "leaf.fill", "flame.fill", "drop.fill",
        "sun.max.fill", "moon.fill", "star.fill", "heart.fill", "cloud.fill",
        "brain.head.profile", "puzzlepiece.fill", "gamecontroller.fill", "paintbrush.fill",
        "scissors", "scissors.circle.fill", "wrench.fill", "hammer.fill", "gearshape.fill",
        "link", "lock.fill", "key.fill", "qrcode", "barcode", "magnifyingglass",
        "rectangle.grid.2x2.fill", "square.grid.3x3.fill", "circle.grid.2x2.fill",
        "square.stack.3d.up.fill", "cube.fill", "pencil", "highlighter", "trash.fill",
        "books.vertical.fill", "graduationcap.fill", "backpack.fill", "fork.knife",
        "cup.and.saucer.fill", "mug.fill", "pawprint.fill", "bird.fill", "hare.fill",
    ]

    private var filtered: [String] {
        if search.isEmpty { return Self.curated }
        return Self.curated.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 64, maximum: 72), spacing: 8)
    ]

    var body: some View {
        VStack(spacing: 12) {
            TextField("Search symbols", text: $search)
                .textFieldStyle(.roundedBorder)

            if filtered.isEmpty {
                Text("No symbols match")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(filtered, id: \.self) { name in
                            symbolCell(name)
                        }
                    }
                    .padding(2)
                }
            }

            Divider()

            HStack(spacing: 8) {
                TextField("Any symbol name (e.g. square.and.arrow.up)", text: $customSymbol)
                    .textFieldStyle(.roundedBorder)
                if !customSymbol.isEmpty {
                    Image(systemName: customSymbol)
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.secondary)
                }
                Button("Add") {
                    let trimmed = customSymbol.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    onSelect(trimmed)
                    dismiss()
                }
                .disabled(customSymbol.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 480, height: 440)
    }

    private func symbolCell(_ name: String) -> some View {
        Button {
            onSelect(name)
            dismiss()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: name)
                    .font(.system(size: 22))
                    .frame(width: 44, height: 44)
                Text(name)
                    .font(.system(size: 8))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .help(name)
    }
}