import SwiftUI
import WebKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var serverAddress: String = "" // User inputs server IP
    @State private var showPicker = false
    @State private var showWebView = false
    @State private var webURL: URL?
    @State private var status = "Idle"

    var body: some View {
        ZStack {
            if showWebView, let webURL {
                FullScreenWebView(url: webURL)
                    .edgesIgnoringSafeArea(.all)
            } else {
                VStack(spacing: 20) {
                    Text("APK Runner (iOS)")
                        .font(.title)
                    TextField("Server Adresse eingeben", text: $serverAddress)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    Button("Select APK") {
                        showPicker = true
                    }
                    Text(status)
                        .foregroundColor(.gray)
                }
                .fileImporter(
                    isPresented: $showPicker,
                    allowedContentTypes: [UTType(filenameExtension: "apk")!]
                ) { result in
                    switch result {
                    case .success(let url):
                        Task {
                            await upload(apkURL: url)
                        }
                    case .failure(let err):
                        status = "Error: \(err.localizedDescription)"
                    }
                }
                .padding()
            }
        }
    }

    func upload(apkURL: URL) async {
        guard !serverAddress.isEmpty else {
            status = "Bitte Server-Adresse eingeben"
            return
        }
        status = "Uploading..."
        let boundary = UUID().uuidString
        guard let uploadURL = URL(string: "\(serverAddress)/upload") else {
            status = "Ungültige Server-Adresse"
            return
        }

        var req = URLRequest(url: uploadURL)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        guard let fileData = try? Data(contentsOf: apkURL) else {
            status = "File read error"
            return
        }

        var body = Data()
        let filename = apkURL.lastPathComponent
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"apk\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/vnd.android.package-archive\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        do {
            let (resData, _) = try await URLSession.shared.upload(for: req, from: body)
            if let s = String(data: resData, encoding: .utf8) {
                print("Response:", s)
            }
            status = "Done! Opening emulator..."
            webURL = URL(string: "\(serverAddress)/6080/")
            showWebView = true
        } catch {
            status = "Upload failed: \(error.localizedDescription)"
        }
    }
}

struct FullScreenWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.configuration.preferences.javaScriptEnabled = true
        webView.scrollView.isScrollEnabled = true
        webView.load(URLRequest(url: url))
        webView.allowsBackForwardNavigationGestures = false
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
