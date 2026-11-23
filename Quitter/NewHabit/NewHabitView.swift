import SwiftUI

struct NewHabitView: View {
    @State private var viewModel: NewHabitViewModel
    @FocusState private var focusedField: Field?

    private enum Field { case name, cost, minutes }

    init(viewModel: NewHabitViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

    var body: some View {
        Form {
            Section("What are you quitting?") {
                FlowLayout {
                    ForEach(HabitKind.allCases) { kind in
                        KindChip(kind: kind, isSelected: kind == viewModel.kind) {
                            viewModel.selectKind(kind)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                LabeledContent("Name") {
                    TextField("Name", text: Binding(get: { viewModel.name }, set: viewModel.updateName))
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.done)
                        .accessibilityIdentifier("name")
                }
                .accessibilityElement(children: .contain)

                // Changing this later would rewrite the streak history; a slip is the way to restart.
                if !viewModel.isEditing {
                    DatePicker(
                        "Last time you did it",
                        selection: Binding(get: { viewModel.lastDoneDisplay }, set: viewModel.setLastDone),
                        in: ...Date.now
                    )
                }
            } footer: {
                if viewModel.name.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("Give it a name").foregroundStyle(.red)
                }
            }

            Section {
                LabeledContent("Cost / day") {
                    HStack(spacing: 4) {
                        Spacer()
                        Text(Locale.current.currencySymbol ?? "$")
                            .foregroundStyle(Palette.onSurfaceVariant)
                        TextField("0.00", text: Binding(get: { viewModel.costText }, set: viewModel.updateCost))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 64)
                            .fixedSize(horizontal: true, vertical: false)
                            .focused($focusedField, equals: .cost)
                            .accessibilityIdentifier("costPerDay")
                    }
                }
                .accessibilityElement(children: .contain)
                LabeledContent("Time / day") {
                    HStack(spacing: 4) {
                        TextField("0", text: Binding(get: { viewModel.minutesText }, set: viewModel.updateMinutes))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .minutes)
                            .accessibilityIdentifier("minutesPerDay")
                        Text("min").foregroundStyle(Palette.onSurfaceVariant)
                    }
                }
                .accessibilityElement(children: .contain)
            } footer: {
                if viewModel.minutesTooHigh {
                    Text("A day only has 1,440 minutes.").foregroundStyle(.red)
                } else if let projection {
                    Label { projection } icon: {
                        Image(systemName: "lightbulb").foregroundStyle(Palette.primary)
                    }
                    .font(.footnote)
                    .padding(.top, 4)
                }
            }

            Section {
                Button(action: startTapped) {
                    Text(viewModel.isEditing ? "Save" : "Start the counter")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: Radius.button))
                .tint(Palette.primary)
                .foregroundStyle(Palette.onPrimary)
                .disabled(!viewModel.canStart)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(viewModel.isEditing ? "Edit habit" : "New habit")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Couldn't save the habit", isPresented: $viewModel.saveFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try again.")
        }
        .toolbar {
            // Number pads have no return key, so give them a way to close.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
    }

    private func startTapped() {
        focusedField = nil
        viewModel.startTapped()
    }

    private var projection: Text? {
        let money = viewModel.yearlyCost?.formatted(.currency(code: currencyCode).precision(.fractionLength(0)))
        switch (money, viewModel.yearlyHours) {
        case let (money?, hours?):
            return Text("At this rate you'll have kept **\(money)** and ^[\(hours) hours](inflect: true) in a year.")
        case let (money?, nil):
            return Text("At this rate you'll have kept **\(money)** in a year.")
        case let (nil, hours?):
            return Text("At this rate you'll have ^[\(hours) hours](inflect: true) back in a year.")
        case (nil, nil):
            return nil
        }
    }
}

private struct KindChip: View {
    let kind: HabitKind
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark").font(.footnote.weight(.semibold))
                }
                Text(kind.label)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Palette.onSurface)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Palette.secondaryContainer : .clear, in: .rect(cornerRadius: 8))
            .overlay {
                if !isSelected {
                    RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.outline)
                }
            }
            .contentShape(.rect)
        }
        // Plain style so each chip gets its own tap inside the Form row.
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("Light") {
    NavigationStack { NewHabitView(viewModel: NewHabitViewModel(store: SwiftDataHabitStore.inMemory())) }
}

#Preview("Dark") {
    NavigationStack { NewHabitView(viewModel: NewHabitViewModel(store: SwiftDataHabitStore.inMemory())) }
        .preferredColorScheme(.dark)
}
