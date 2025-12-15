import SwiftUI
import PDFKit

struct PDFPreviewView: View {
    @EnvironmentObject var previewModel: PreviewModel

    var body: some View {
        Group {
            if let url = previewModel.fileURL {
                VStack {
                    Text(url.lastPathComponent)
                        .font(.headline)
                        .padding()
                    PDFViewRepresentable(url: url)
                        .edgesIgnoringSafeArea(.all)
                }
            } else {
                ContentUnavailableView {
                    Text("No PDF available")
                }
            }
        }
        .onAppear {
            previewModel.isVisible = true
        }
        .onDisappear {
            previewModel.isVisible = false
        }
    }
}

struct PDFViewRepresentable: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if let document = PDFDocument(url: url) {
            uiView.document = document
        }
    }
}

class PreviewModel: ObservableObject {
    @Published var fileURL: URL?
    @Published var isVisible: Bool = false
}
