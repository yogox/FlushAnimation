//
//  ContentView.swift
//  FlushAnimation
//
//  Created by yogox on 2022/04/10.
//

import SwiftUI

public func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
}

public func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
}

enum TopBottom: Int {
    case top = -1
    case bottom = 1
    
    func outside(_ value: CGFloat) -> CGFloat {
        return value * CGFloat(self.rawValue)
    }
    
    func inside(_ value: CGFloat) -> CGFloat {
        return value * CGFloat(self.rawValue) * -1
    }
}

struct FlashDown: ViewModifier {
    let offset: CGFloat
    
    func body(content: Content) -> some View {
        content
            .transition(.asymmetric(
                insertion: .offset(x: 0, y: -offset),
                removal: .identity)
            )
    }
}

struct FlushShape: Shape {
    var singleArrayPoints: [CGPoint]
    var boxHeight: CGFloat
    var topScale: CGFloat
    var bottomScale: CGFloat
    
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get {
            AnimatablePair(topScale, bottomScale)
        }
        set {
            topScale = newValue.first
            bottomScale = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        let topWavePoints = WavePoints(singleArrayPoints)
        let bottomWavePoinrs = WavePoints(singleArrayPoints, reversal: true)
        topWavePoints.applyScale(topScale)
        bottomWavePoinrs.applyScale(bottomScale)
        bottomWavePoinrs.applyOffsetY(boxHeight)
        
        var path = Path()
        // 上側の曲線を引く
        path.move(to: topWavePoints.p0)
        for i in 0..<(topWavePoints.count) {
            path.addCurve(to: topWavePoints.p[i], control1: topWavePoints.c1[i], control2: topWavePoints.c2[i])
        }
        // パスを引くとeoFillをfalseにしても全塗りしてくれないので、下側は反転情報で後ろから曲線を引く
        path.addLine(to: bottomWavePoinrs.p0)
        for i in 0..<(bottomWavePoinrs.count) {
            path.addCurve(to: bottomWavePoinrs.p[i], control1: bottomWavePoinrs.c1[i], control2: bottomWavePoinrs.c2[i])
        }
        path.closeSubpath()
        
        return path
    }
}

class WavePoints {
    var p0: CGPoint = CGPoint.zero
    var p: [CGPoint] = []
    var c1: [CGPoint] = []
    var c2: [CGPoint] = []
    var count: Int = 0
    
    init(_ singleArray:[CGPoint], reversal:Bool = false) {
        if !singleArray.isEmpty {
            if !reversal {
                loadSingleArrayPoints(singleArray)
            } else {
                reverseLoadSingleArrayPoints(singleArray)
            }
        }
    }
    
    func loadSingleArrayPoints(_ singleArray:[CGPoint]) {
        var singleArray = singleArray
        let p0 = singleArray.removeFirst()
        self.p0 = p0
        let eachCount = singleArray.count / 3
        self.count = eachCount
        let subP = singleArray[0..<eachCount]
        singleArray.removeFirst(eachCount)
        self.p = [CGPoint](subP)
        let subC1 = singleArray[0..<eachCount]
        singleArray.removeFirst(eachCount)
        self.c1 = [CGPoint](subC1)
        let subC2 = singleArray[0..<eachCount]
        singleArray.removeFirst(eachCount)
        self.c2 = [CGPoint](subC2)
    }
    
    func reverseLoadSingleArrayPoints(_ singleArray:[CGPoint]) {
        var singleArray = singleArray
        let eachCount = (singleArray.count - 1) / 3
        self.count = eachCount
        let subP = singleArray[0..<eachCount].reversed()
        singleArray.removeFirst(eachCount)
        self.p = [CGPoint](subP)
        let p0 = singleArray.removeFirst()
        self.p0 = p0
        let subC2 = singleArray[0..<eachCount].reversed()
        singleArray.removeFirst(eachCount)
        self.c2 = [CGPoint](subC2)
        let subC1 = singleArray[0..<eachCount].reversed()
        singleArray.removeFirst(eachCount)
        self.c1 = [CGPoint](subC1)
    }
    
    func applyScale(_ scale: CGFloat) {
        p0 = CGPoint(x: p0.x, y: p0.y * scale)
        p = p.map{ CGPoint(x: $0.x, y: $0.y * scale) }
        c1 = c1.map{ CGPoint(x: $0.x, y: $0.y * scale) }
        c2 = c2.map{ CGPoint(x: $0.x, y: $0.y * scale) }
    }
    
    func applyOffsetY(_ offset: CGFloat) {
        p0 = CGPoint(x: p0.x, y: p0.y + offset)
        p = p.map{ CGPoint(x: $0.x, y: $0.y + offset) }
        c1 = c1.map{ CGPoint(x: $0.x, y: $0.y + offset) }
        c2 = c2.map{ CGPoint(x: $0.x, y: $0.y + offset) }
    }
}

struct ContentView: View {
    // ループ用タイマー
    @State var timer :Timer?
    
    // アニメーション用プロパティ
    // アニメーション速度
    private let flushSpeed:CGFloat = 1.5
    // トランザクション契機
    @State private var animateA:Bool = true
    // FlushShape点座標
    @State private var singleArrayPoints: [CGPoint] = []
    // Flush伸長アニメーション用
    static private let inisialTopScale: CGFloat = 0
    static private let inisialBottomScale: CGFloat = 0.5
    @State private var topScale = inisialTopScale
    @State private var bottomScale = inisialBottomScale
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let barHeight = geometry.safeAreaInsets.top
            let squareLength = CGFloat.minimum(width, height)
            let screenHeight = height + barHeight
            
            ZStack() {
                if animateA {
                    FlushEffect(boxHeight: squareLength, offsetY: screenHeight, color: .green)
                } else {
                    FlushEffect(boxHeight: squareLength, offsetY: screenHeight, color: .purple)
                }
            }
            .frame(width: width, height: screenHeight, alignment: .top)
            .ignoresSafeArea()
            .onAppear() {
                animateShape(width: width, height: height - squareLength)
                timer = Timer.scheduledTimer(withTimeInterval: flushSpeed, repeats: true) { _ in
                    animateShape(width: width, height: height - squareLength)
                }
            }
        }
    }
    
    func FlushEffect(boxHeight: CGFloat, offsetY: CGFloat, color: Color) -> some View {
        return FlushShape(singleArrayPoints: singleArrayPoints,
                          boxHeight: boxHeight,
                          topScale: topScale,
                          bottomScale: bottomScale
        )
        .fill(color)
        .ignoresSafeArea()
        .offset(x: 0, y: offsetY)
        .modifier(FlashDown(offset: offsetY))
    }
    
}

extension ContentView {
    private static let dPxMinRate: CGFloat = 0.125
    private static let dPxMaxRate: CGFloat = 0.5
    private static let dPyMinRate: CGFloat = 0.4
    private static let dPyMaxRate: CGFloat = 0.6
    private static let dCxMinRate: CGFloat = 0.2
    private static let dCxMaxRate: CGFloat = 0.8
    private static let dC1xMaxRate: CGFloat = 0.6
    
    func animateShape(width: CGFloat, height: CGFloat) {
        let size = CGSize(width: width, height: height)
        makePointsArray(CGRect(origin: CGPoint.zero, size: size), .bottom)
        topScale = Self.inisialTopScale
        bottomScale = Self.inisialBottomScale
        
        withAnimation(.easeIn(duration: flushSpeed)) {
            animateA.toggle()
        }
        withAnimation(.easeOut(duration: flushSpeed)) {
            topScale = 1.0
            bottomScale = 1.0
        }
    }
    
    func makePointsArray(_ rect: CGRect, _ direction: TopBottom) {
        var points: [CGPoint] = []
        var c1s: [CGPoint] = []
        var c2s: [CGPoint] = []
        
        let width = rect.width
        let height = rect.height
        let origin = rect.origin
        
        let x0: CGFloat = origin.x
        var x:CGFloat = x0
        var sumX: CGFloat = x
        
        let dPxMin: CGFloat = width * Self.dPxMinRate
        let dPxMax: CGFloat = width * Self.dPxMaxRate
        let dCyMaxRate: CGFloat = 1 - Self.dPyMaxRate
        let dCyMax: CGFloat = height * dCyMaxRate
        
        while sumX < width {
            let y = CGFloat.random(in: (height * Self.dPyMinRate)...(height * Self.dPyMaxRate))
            points.append(CGPoint(x: sumX, y: origin.y + y))
            x = CGFloat.random(in: dPxMin...dPxMax)
            sumX = sumX + x
        }
        
        let lastP = points.removeLast()
        points.append(CGPoint(x: width, y: lastP.y))
        
        let cMaxNum = points.count - 2
        
        for i in 0...cMaxNum {
            let p = points[i]
            let px = p.x
            let py = p.y
            let pNext = points[i+1]
            
            let dx = pNext.x - px
            let dxMin = dx * Self.dCxMinRate
            let dxMax = dx * Self.dCxMaxRate
            let dx1Max = dx * Self.dC1xMaxRate
            
            let d1: CGPoint
            let dx1: CGFloat
            let dy1: CGFloat
            
            if i == 0 {
                dx1 = CGFloat.random(in: dxMin...dx1Max)
                dy1 = direction.outside(CGFloat.random(in: 0...(dCyMax)))
                d1 = CGPoint(x: dx1, y: dy1)
            } else {
                let d2pre = p - c2s[i-1]
                let k = d2pre.y / d2pre.x
                let dy1max: CGFloat
                if k > 0 {
                    dy1max = height - (py - origin.y)
                } else {
                    dy1max = origin.y - py
                }
                let dx1maxAfter = CGFloat.minimum(dx1Max, dy1max / k)
                
                if dx1maxAfter < dPxMin {
                    dx1 = dx1maxAfter
                } else {
                    dx1 = CGFloat.random(in: dPxMin/2...dx1maxAfter)
                }
                dy1 = dx1 * k
                d1 = CGPoint(x: dx1, y: dy1)
            }
            
            let dx2min = dx1
            let x2 = p.x + CGFloat.random(in: dx2min...dxMax)
            let y2: CGFloat
            if i == cMaxNum{
                let dy2 = direction.outside(CGFloat.random(in: 0...(dCyMax)))
                y2 = pNext.y + dy2
            } else {
                let dy2Min: CGFloat
                if dy1 < 0 {
                    dy2Min = 0
                } else {
                    dy2Min = dy1
                }
                y2 = origin.y + CGFloat.random(in: dy2Min...height)
            }
            
            c1s.append(p + d1)
            c2s.append(CGPoint(x: x2, y: y2))
            
        }
        
        singleArrayPoints = points + c1s + c2s
    }
}

struct ContentView_Previews: PreviewProvider {
    
    static var previews: some View {
        ContentView()
    }
    
}
