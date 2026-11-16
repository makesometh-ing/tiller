// Removes all visible pixels that aren't connected to the center of an app icon, for example a mark
// from the image generator in the transparent corners. Usage: swift scripts/clean-icon.swift <in.png> <out.png>
import AppKit

let args = CommandLine.arguments
let image = NSImage(contentsOfFile: args[1])!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let w = image.width, h = image.height
var pixels = [UInt8](repeating: 0, count: w * h * 4)
let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

var keep = [Bool](repeating: false, count: w * h)
var stack = [(w / 2) + (h / 2) * w]
keep[stack[0]] = true
while let i = stack.popLast() {
    let x = i % w, y = i / w
    for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
        let nx = x + dx, ny = y + dy
        guard nx >= 0, ny >= 0, nx < w, ny < h else { continue }
        let n = nx + ny * w
        if !keep[n] && pixels[n * 4 + 3] > 0 { keep[n] = true; stack.append(n) }
    }
}
var cleared = 0
for i in 0..<(w * h) where !keep[i] && pixels[i * 4 + 3] > 0 {
    pixels[i * 4] = 0; pixels[i * 4 + 1] = 0; pixels[i * 4 + 2] = 0; pixels[i * 4 + 3] = 0
    cleared += 1
}
let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(filePath: args[2]))
print("\(args[1]): cleared \(cleared) pixels outside the icon")
