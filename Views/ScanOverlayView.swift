import SwiftUI

struct ScanOverlayView: View {
    var codeType: ScannerConstants.CodeType
    // inspired from:
    // https://stackoverflow.com/questions/65447683/swiftui-qr-code-scan-reactangle-with-border-corner
    var body: some View {
        GeometryReader { geometry in
            let cutoutWidth: CGFloat = min(geometry.size.width, geometry.size.height) / ScannerConstants.overlayWidthFactor
            let overlayWidthHeightRatio = codeType == ScannerConstants.CodeType.ean8 ? ScannerConstants.barcodeWidthHeightRatio : ScannerConstants.defaultWidthHeightRatio
            let cutoutHeight: CGFloat = cutoutWidth / overlayWidthHeightRatio
            
            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(StyleConstants.overlayOpacity))
                
                RoundedRectangle(cornerRadius: StyleConstants.roundedCornerRadius)
                    .fill(Color.black)
                    .frame(width: cutoutWidth, height: cutoutHeight, alignment: .center)
                    .blendMode(.destinationOut)
            }.compositingGroup()
            
            Path { path in
                
                let left = (geometry.size.width - cutoutWidth) / 2.0
                let right = left + cutoutWidth
                let top = (geometry.size.height - cutoutHeight) / 2.0
                let bottom = top + cutoutHeight
                
                path.addPath(
                    createCornersPath(
                        left: left, top: top,
                        right: right, bottom: bottom,
                        cornerRadius: StyleConstants.roundedCornerRadius, cornerLength: StyleConstants.roundedCornerStrokeLength
                    )
                )
            }
            .stroke(Color.blue, lineWidth: StyleConstants.overlayStrokeWidth)
            .frame(width: cutoutWidth, height: cutoutHeight, alignment: .center)
            .aspectRatio(1, contentMode: .fit)
        }
    }
    
    private func createCornersPath(
        left: CGFloat,
        top: CGFloat,
        right: CGFloat,
        bottom: CGFloat,
        cornerRadius: CGFloat,
        cornerLength: CGFloat
    ) -> Path {
        var path = Path()
        
        // top left
        path.move(to: CGPoint(x: left, y: (top + cornerRadius)))
        path.addArc(
            center: CGPoint(x: (left + cornerRadius), y: (top + cornerRadius)),
            radius: cornerRadius,
            startAngle: Angle(degrees: 180.0),
            endAngle: Angle(degrees: 270.0),
            clockwise: false
        )
        
        path.move(to: CGPoint(x: left + (cornerRadius), y: top))
        path.addLine(to: CGPoint(x: left + (cornerRadius) + cornerLength, y: top))
        
        path.move(to: CGPoint(x: left, y: top + (cornerRadius)))
        path.addLine(to: CGPoint(x: left, y: top + (cornerRadius) + cornerLength))
        
        // top right
        path.move(to: CGPoint(x: right - cornerRadius, y: top))
        path.addArc(
            center: CGPoint(x: (right - cornerRadius), y: (top + cornerRadius)),
            radius: cornerRadius,
            startAngle: Angle(degrees: 270.0),
            endAngle: Angle(degrees: 360.0),
            clockwise: false
        )
        
        path.move(to: CGPoint(x: right - (cornerRadius), y: top))
        path.addLine(to: CGPoint(x: right - (cornerRadius) - cornerLength, y: top))
        
        path.move(to: CGPoint(x: right, y: top + (cornerRadius)))
        path.addLine(to: CGPoint(x: right, y: top + (cornerRadius) + cornerLength))
        
        // bottom left
        path.move(to: CGPoint(x: left + cornerRadius, y: bottom))
        path.addArc(
            center: CGPoint(x: (left + cornerRadius), y: (bottom - cornerRadius)),
            radius: cornerRadius,
            startAngle: Angle(degrees: 90.0),
            endAngle: Angle(degrees: 180.0),
            clockwise: false
        )
        
        path.move(to: CGPoint(x: left + (cornerRadius), y: bottom))
        path.addLine(to: CGPoint(x: left + (cornerRadius) + cornerLength, y: bottom))
        
        path.move(to: CGPoint(x: left, y: bottom - (cornerRadius)))
        path.addLine(to: CGPoint(x: left, y: bottom - (cornerRadius) - cornerLength))
        
        // bottom right
        path.move(to: CGPoint(x: right, y: bottom - cornerRadius))
        path.addArc(
            center: CGPoint(x: (right - cornerRadius), y: (bottom - cornerRadius)),
            radius: cornerRadius,
            startAngle: Angle(degrees: 0.0),
            endAngle: Angle(degrees: 90.0),
            clockwise: false
        )
        
        path.move(to: CGPoint(x: right - (cornerRadius), y: bottom))
        path.addLine(to: CGPoint(x: right - (cornerRadius) - cornerLength, y: bottom))
        
        path.move(to: CGPoint(x: right, y: bottom - (cornerRadius)))
        path.addLine(to: CGPoint(x: right, y: bottom - (cornerRadius) - cornerLength))
        
        return path
    }
}

#Preview {
    ScanOverlayView(codeType: ScannerConstants.CodeType.ean8)
}
