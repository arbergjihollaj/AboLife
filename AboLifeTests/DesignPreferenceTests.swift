import AppKit
import SwiftUI
import XCTest

@testable import AboLife

@MainActor
final class DesignPreferenceTests: XCTestCase {
    private func fixture() -> UserDefaults {
        let name = "AboLife.DesignTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    func testDesignAccentAndOrderSurviveReopeningWithoutChangingDomainPreferences() {
        let defaults = fixture()
        defaults.set("keep", forKey: "unrelated")
        let store = AboLifeDesignStore(defaults: defaults)
        XCTAssertEqual(store.design, .spatial)
        store.design = .bento
        store.accent = .amber
        store.move(.week, to: .finance)
        let reopened = AboLifeDesignStore(defaults: defaults)
        XCTAssertEqual(reopened.design, .bento)
        XCTAssertEqual(reopened.accent, .amber)
        XCTAssertEqual(reopened.widgets.first, .week)
        XCTAssertEqual(defaults.string(forKey: "unrelated"), "keep")
    }

    func testUnknownAndDuplicateWidgetsAreRepairedWithoutLosingKnownOrder() {
        XCTAssertEqual(
            AboLifeDesignStore.normalizedWidgets(["week", "missing", "week", "finance"]),
            [.week, .finance, .training, .habits, .activity])
    }

    func testMovementInBothDirectionsAndBoundaries() {
        let store = AboLifeDesignStore(defaults: fixture())
        let original = store.widgets
        store.move(.finance, offset: -1)
        XCTAssertEqual(store.widgets, original)
        store.move(.finance, offset: 1)
        XCTAssertEqual(Array(store.widgets.prefix(2)), [.training, .finance])
        store.move(.finance, offset: -1)
        XCTAssertEqual(store.widgets, original)
        store.move(.week, offset: 1)
        XCTAssertEqual(store.widgets, original)
    }

    func testPreferenceDomainsAndInvalidValuesAreIsolated() {
        let first = fixture(), second = fixture()
        first.set("not-a-design", forKey: AboLifeDesignStore.designKey)
        let store = AboLifeDesignStore(defaults: first)
        XCTAssertEqual(store.design, .spatial)
        store.design = .fieldnotes
        XCTAssertEqual(AboLifeDesignStore(defaults: second).design, .spatial)
    }
}

@MainActor
final class NavigationMotionTests: XCTestCase {
    func testRestingSurfaceMatchesItsHitAreaAndBulgeExpandsOutsideIt() {
        let rect = CGRect(x: 10, y: 20, width: 90, height: 50)
        let rest = AboLifeLiquidBulgeShape(amount: 0).path(in: rect).boundingRect
        XCTAssertEqual(rest.minX, rect.minX, accuracy: 0.001)
        XCTAssertEqual(rest.maxY, rect.maxY, accuracy: 0.001)
        let peak = AboLifeLiquidBulgeShape(amount: 1).path(in: rect).boundingRect
        XCTAssertLessThan(peak.minX, rect.minX)
        XCTAssertLessThan(peak.minY, rect.minY)
        XCTAssertGreaterThan(peak.maxX, rect.maxX)
        XCTAssertGreaterThan(peak.maxY, rect.maxY)
    }

    func testDeformationIsBoundedEvenWhenAnimationOvershoots() {
        let rect = CGRect(x: 0, y: 0, width: 82, height: 56)
        let peak = AboLifeLiquidBulgeShape(amount: 1).path(in: rect).boundingRect
        XCTAssertEqual(AboLifeLiquidBulgeShape(amount: 20).path(in: rect).boundingRect, peak)
        XCTAssertEqual(AboLifeLiquidBulgeShape(amount: -20).path(in: rect).boundingRect, rect)
    }

    func testReduceMotionDisablesTheLiquidTransition() {
        XCTAssertNil(AboLifeMotion.animation(for: .liquid, reduceMotion: true))
        XCTAssertNotNil(AboLifeMotion.animation(for: .liquid, reduceMotion: false))
    }
}

@MainActor
final class DesignRenderingTests: XCTestCase {
    func testRenderThreeNativeDesigns() throws {
        guard let path = ProcessInfo.processInfo.environment["ABOLIFE_DESIGN_RENDER_DIR"] else {
            throw XCTSkip("Set ABOLIFE_DESIGN_RENDER_DIR for isolated native design reference images")
        }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for design in AboLifeDesign.allCases {
            for (name, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
                for width in [660.0, 1100.0] {
                    let view = DashboardView(store: DashboardStore(state: .default), rendersOverviewOnly: true)
                        .environmentObject(AIAssistantStore.previewStore())
                        .environmentObject(AppNavigationCoordinator())
                        .environment(\.aboLifeStyle, AboLifeStyle(design: design))
                        .fontDesign(design == .fieldnotes ? .serif : .default)
                        .padding(24)
                        .frame(width: width, alignment: .top)
                        .fixedSize(horizontal: false, vertical: true)
                        .background(AboLifeStyle(design: design).colors.pageBackground)
                        .environment(\.colorScheme, scheme)
                    let renderer = ImageRenderer(content: view)
                    renderer.scale = 2
                    let image = try XCTUnwrap(renderer.cgImage)
                    XCTAssertEqual(image.width, Int(width * 2))
                    let bitmap = NSBitmapImageRep(cgImage: image)
                    let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    try png.write(to: directory.appendingPathComponent("\(design.rawValue)-\(name)-\(Int(width)).png"))
                }
            }
        }
    }
}
