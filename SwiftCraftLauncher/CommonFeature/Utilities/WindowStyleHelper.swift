//
//  WindowStyleHelper.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/27.
//

import AppKit
import SwiftUI

/// 窗口样式配置工具
enum WindowStyleHelper {
    /// 配置标准窗口样式（禁用缩小和放大）
    static func configureStandardWindow(_ window: NSWindow) {
        window.styleMask.remove([.miniaturizable, .resizable])
        window.collectionBehavior.insert(.fullScreenNone)
        window.standardWindowButton(.zoomButton)?.isEnabled = false
    }

    /// 将窗口定位到屏幕右上角，并锁定顶部边缘使其向下伸展
    static func positionAtTopRight(_ window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame
        let newFrame = NSRect(
            x: screenFrame.maxX - windowFrame.width - 20,
            y: screenFrame.maxY - windowFrame.height - 20,
            width: windowFrame.width,
            height: windowFrame.height
        )
        window.setFrame(newFrame, display: true)
    }

    /// 保持窗口顶部边缘固定，使窗口向下伸展
    static func keepTopEdgeFixed(_ window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let targetMaxY = screenFrame.maxY - 20
        var frame = window.frame
        if frame.maxY != targetMaxY {
            frame.origin.y = targetMaxY - frame.height
            window.setFrame(frame, display: true)
        }
    }
}

/// 窗口样式配置修饰符
struct WindowStyleConfig: ViewModifier {
    let windowID: WindowID

    func body(content: Content) -> some View {
        content
            .background(
                WindowAccessor(synchronous: false) { window in
                    // 确保窗口 identifier 被正确设置（用于单例查找）
                    if window.identifier?.rawValue != windowID.rawValue {
                        window.identifier = NSUserInterfaceItemIdentifier(windowID.rawValue)
                    }

                    // 下载窗口特殊配置
                    if windowID == .javaDownload {
                        window.styleMask.remove([.miniaturizable, .resizable])
                        window.collectionBehavior.insert(.fullScreenNone)
                        window.standardWindowButton(.zoomButton)?.isEnabled = false
                        WindowStyleHelper.positionAtTopRight(window)
                        window.minSize = NSSize(width: 400, height: 100)
                    } else {
                        WindowStyleHelper.configureStandardWindow(window)
                    }
                }
            )
    }
}

extension View {
    /// 应用窗口样式配置
    func windowStyleConfig(for windowID: WindowID) -> some View {
        modifier(WindowStyleConfig(windowID: windowID))
    }
}

/// 窗口清理修饰符
struct WindowCleanup: ViewModifier {
    let windowID: WindowID
    private let windowDataStore: WindowDataStore

    init(windowID: WindowID, windowDataStore: WindowDataStore = AppServices.windowDataStore) {
        self.windowID = windowID
        self.windowDataStore = windowDataStore
    }

    func body(content: Content) -> some View {
        content
            .onDisappear {
                windowDataStore.cleanup(for: windowID)
            }
    }
}

extension View {
    /// 应用窗口清理配置
    func windowCleanup(for windowID: WindowID) -> some View {
        modifier(WindowCleanup(windowID: windowID))
    }
}
