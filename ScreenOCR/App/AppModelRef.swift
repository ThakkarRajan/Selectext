import SwiftUI

@MainActor
enum AppModelRef {
    static weak var current: AppModel?
}
