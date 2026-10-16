// Backeddy — janela "Apoie o projeto" (PIX + GitHub Sponsors)
import SwiftUI
import AppKit
import CoreImage

let repoURL = URL(string: "https://github.com/backeddy/mac")!
let sponsorsURL = URL(string: "https://github.com/sponsors/lordironballs")!
let pixKey = "pix@xwa.com.br"
/// Código PIX "copia e cola" (BR Code estático). Gerado e conferido (CRC16-CCITT) para a chave acima.
let pixPayload = "00020126360014br.gov.bcb.pix0114pix@xwa.com.br5204000053039865802BR5913EDDY ANTONINI6009SAO PAULO62070503***63040797"

func qrImage(_ text: String, scale: CGFloat = 8) -> NSImage? {
    guard let f = CIFilter(name: "CIQRCodeGenerator") else { return nil }
    f.setValue(Data(text.utf8), forKey: "inputMessage")
    f.setValue("M", forKey: "inputCorrectionLevel")
    guard let out = f.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) else { return nil }
    let rep = NSCIImageRep(ciImage: out)
    let img = NSImage(size: rep.size)
    img.addRepresentation(rep)
    return img
}

/// Foto do autor embutida no app (assets/avatar.jpg, copiada pelo build.sh), se existir
let authorPhoto: NSImage? = Bundle.main.url(forResource: "avatar", withExtension: "jpg").flatMap { NSImage(contentsOf: $0) }

func copyToClipboard(_ s: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(s, forType: .string)
}

struct SupportView: View {
    @EnvironmentObject var m: Model
    @State private var copied: String?
    private let qr = qrImage(pixPayload)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                if let authorPhoto {
                    Image(nsImage: authorPhoto).resizable().scaledToFill()
                        .frame(width: 88, height: 88).clipShape(Circle())
                        .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 1))
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                } else {
                    appIcon(64)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("supportTitle")).font(.title2.weight(.semibold))
                    Text(L("supportSubtitle")).font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Card {
                HStack(alignment: .top, spacing: 16) {
                    if let qr {
                        Image(nsImage: qr).interpolation(.none).resizable()
                            .frame(width: 150, height: 150)
                            .padding(8).background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Label(L("pixTitle"), systemImage: "qrcode").font(.headline)
                        Text(L("pixHint")).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Text(Lf("pixKeyLabel", pixKey)).font(.callout.monospaced()).textSelection(.enabled)
                        HStack {
                            Button(L("copyKey")) { copyToClipboard(pixKey); copied = "key" }
                            Button(L("copyPixCode")) { copyToClipboard(pixPayload); copied = "code" }
                        }
                        if copied != nil {
                            Label(L("copied"), systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(Color.green)
                        }
                    }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Label(L("intlTitle"), systemImage: "globe").font(.headline)
                    Text(L("intlHint")).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Link(destination: sponsorsURL) { Label("GitHub Sponsors", systemImage: "heart.fill") }
                            .buttonStyle(.borderedProminent).tint(.pink)
                        Link(destination: repoURL) { Label(L("starRepo"), systemImage: "star") }
                            .buttonStyle(.bordered)
                    }
                }
            }

            Text(L("supportThanks")).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(width: 520)
        .id(m.lang)
    }
}
