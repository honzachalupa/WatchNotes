import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct QrCodeView: View {
    var value: String
    
    func generateQR(text: String) -> NSImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.setValue("H", forKey: "inputCorrectionLevel")

        if let outputImage = filter.outputImage {
            let scale = 10.0
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            let scaledImage = outputImage.transformed(by: transform)
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                let size = CGSize(width: scaledImage.extent.width, height: scaledImage.extent.height)
                
                return NSImage(cgImage: cgImage, size: size)
            }
        }

        return NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil) ?? NSImage()
    }
    
    var body: some View {
        Image(nsImage: generateQR(text: value))
            .resizable()
            .interpolation(.none)
            .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    QrCodeView(value: "https://janchalupa.dev/")
}
