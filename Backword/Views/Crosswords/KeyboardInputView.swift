import SwiftUI
import UIKit

/// A hidden UITextField wrapper that captures keyboard input and routes it to the GameViewModel.
struct KeyboardInputView: UIViewRepresentable {
    @ObservedObject var viewModel: GameViewModel

    func makeUIView(context: Context) -> InvisibleTextField {
        let field = InvisibleTextField()
        field.delegate = context.coordinator
        field.autocorrectionType = .no
        field.autocapitalizationType = .allCharacters
        field.spellCheckingType = .no
        field.keyboardType = .asciiCapable
        field.returnKeyType = .next
        field.textContentType = .none
        // Keep a dummy text so backspace always fires
        field.text = " "

        // Become first responder after a brief delay to avoid SwiftUI layout conflicts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            field.becomeFirstResponder()
        }
        return field
    }

    func updateUIView(_ uiView: InvisibleTextField, context: Context) {
        // Ensure keyboard stays up
        if !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        let viewModel: GameViewModel

        init(viewModel: GameViewModel) {
            self.viewModel = viewModel
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            if string.isEmpty {
                // Backspace
                Task { @MainActor in
                    viewModel.deleteLetter()
                }
            } else if let char = string.uppercased().first, char.isLetter {
                Task { @MainActor in
                    viewModel.enterLetter(char)
                }
            }

            // Reset the text field to a single space so backspace always works
            DispatchQueue.main.async {
                textField.text = " "
            }
            return false
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            Task { @MainActor in
                viewModel.nextClue()
            }
            return false
        }
    }
}

/// A UITextField that renders invisibly but still receives keyboard input.
class InvisibleTextField: UITextField {
    override var canBecomeFirstResponder: Bool { true }

    override func caretRect(for position: UITextPosition) -> CGRect { .zero }
    override func selectionRects(for range: UITextRange) -> [UITextSelectionRect] { [] }

    override func drawText(in rect: CGRect) {
        // Don't draw anything
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect { .zero }
    override func textRect(forBounds bounds: CGRect) -> CGRect { .zero }
}
