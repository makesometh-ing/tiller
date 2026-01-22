//
//  WindowServiceProtocol.swift
//  Tiller
//

import Foundation

protocol WindowServiceProtocol {
    func getVisibleWindows() -> [WindowInfo]
    func getWindow(byID id: WindowID) -> WindowInfo?
    func getFocusedWindow() -> FocusedWindowInfo?
    func getWindows(forBundleID bundleID: String) -> [WindowInfo]
    func startObserving(callback: @escaping @MainActor (WindowChangeEvent) -> Void)
    func stopObserving()
}
