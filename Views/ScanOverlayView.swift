import SwiftUI

struct ScanOverlayView: View {
    let barcodeAreaWidth: CGFloat
    let barcodeAreaHeight: CGFloat
    let barcodeAreaXPos: CGFloat
    let barcodeAreaYPos: CGFloat
    // inspired from:
    // https://stackoverflow.com/questions/65447683/swiftui-qr-code-scan-reactangle-with-border-corner
    var body: some View {
        GeometryReader { _ in
            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(StyleConstants.overlayOpacity))
                
                RoundedRectangle(cornerRadius: StyleConstants.roundedCornerRadius)
                    .fill(Color.black)
                    .frame(width: barcodeAreaWidth, height: barcodeAreaHeight, alignment: .center)
                    .blendMode(.destinationOut)
            }.compositingGroup()
            
            Path { path in
                
                let barcodeAreaXPosEnd = barcodeAreaXPos + barcodeAreaWidth
                let barcodeAreaYPosEnd = barcodeAreaYPos + barcodeAreaHeight
                
                path.addPath(
                    createCornersPath(
                        xStart: barcodeAreaXPos, yStart: barcodeAreaYPos,
                        xEnd: barcodeAreaXPosEnd, yEnd: barcodeAreaYPosEnd,
                        cornerRadius: StyleConstants.roundedCornerRadius, cornerLength: StyleConstants.roundedCornerStrokeLength
                    )
                )
            }
            .stroke(Color.blue, lineWidth: StyleConstants.overlayStrokeWidth)
            .frame(width: barcodeAreaWidth, height: barcodeAreaHeight, alignment: .center)
            .aspectRatio(1, contentMode: .fit)
        }
    }
    
    private func createCornersPath(
        xStart: CGFloat,
        yStart: CGFloat,
        xEnd: CGFloat,
        yEnd: CGFloat,
        cornerRadius: CGFloat,
        cornerLength: CGFloat
    ) -> Path {
        var path = Path()
        
        // top left
        path.move(to: CGPoint(x: xStart, y: (yStart + cornerRadius)))
        path.addArc(
            center: CGPoint(x: (xStart + cornerRadius), y: (yStart + cornerRadius)),
            radius: cornerRadius,
            startAngle: Angle(degrees: 180.0),
            endAngle: Angle(degrees: 270.0),
            clockwise: false
        )
        
        path.move(to: CGPoint(x: xStart + (cornerRadius), y: yStart))
        path.addLine(to: CGPoint(x: xStart + (cornerRadius) + cornerLength, y: yStart))
        
        path.move(to: CGPoint(x: xStart, y: yStart + (cornerRadius)))
        path.addLine(to: CGPoint(x: xStart, y: yStart + (cornerRadius) + cornerLength))
        
        // top right
        path.move(to: CGPoint(x: xEnd - cornerRadius, y: yStart))
        path.addArc(
            center: CGPoint(x: (xEnd - cornerRadius), y: (yStart + cornerRadius)),
            radius: cornerRadius,
            startAngle: Angle(degrees: 270.0),
            endAngle: Angle(degrees: 360.0),
            clockwise: false
        )
        
        path.move(to: CGPoint(x: xEnd - (cornerRadius), y: yStart))
        path.addLine(to: CGPoint(x: xEnd - (cornerRadius) - cornerLength, y: yStart))
        
        path.move(to: CGPoint(x: xEnd, y: yStart + (cornerRadius)))
        path.addLine(to: CGPoint(x: xEnd, y: yStart + (cornerRadius) + cornerLength))
        
        // bottom left
        path.move(to: CGPoint(x: xStart + cornerRadius, y: yEnd))
        path.addArc(
            center: CGPoint(x: (xStart + cornerRadius), y: (yEnd - cornerRadius)),
            radius: cornerRadius,
            startAngle: Angle(degrees: 90.0),
            endAngle: Angle(degrees: 180.0),
            clockwise: false
        )
        
        path.move(to: CGPoint(x: xStart + (cornerRadius), y: yEnd))
        path.addLine(to: CGPoint(x: xStart + (cornerRadius) + cornerLength, y: yEnd))
        
        path.move(to: CGPoint(x: xStart, y: yEnd - (cornerRadius)))
        path.addLine(to: CGPoint(x: xStart, y: yEnd - (cornerRadius) - cornerLength))
        
        // bottom right
        path.move(to: CGPoint(x: xEnd, y: yEnd - cornerRadius))
        path.addArc(
            center: CGPoint(x: (xEnd - cornerRadius), y: (yEnd - cornerRadius)),
            radius: cornerRadius,
            startAngle: Angle(degrees: 0.0),
            endAngle: Angle(degrees: 90.0),
            clockwise: false
        )
        
        path.move(to: CGPoint(x: xEnd - (cornerRadius), y: yEnd))
        path.addLine(to: CGPoint(x: xEnd - (cornerRadius) - cornerLength, y: yEnd))
        
        path.move(to: CGPoint(x: xEnd, y: yEnd - (cornerRadius)))
        path.addLine(to: CGPoint(x: xEnd, y: yEnd - (cornerRadius) - cornerLength))
        
        return path
    }
}
