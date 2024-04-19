//
//  File.swift
//
//
//  Created by mike on 2024/04/13.
//

import ArgumentParser
import CoreGraphics
import Foundation

struct List: ParsableCommand {
  mutating func run() {
    let list = CGWindowListCopyWindowInfo(CGWindowListOption.optionAll, kCGNullWindowID)
    let maxDisplays: UInt32 = 20
    var displays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
    var displayCount: UInt32 = 0
    let err: CGError = CGGetOnlineDisplayList(maxDisplays, &displays, &displayCount)
    if err != CGError.success {
      NSLog("error \(err)")
      return
    }
    guard let windowList = [NSDictionary](from: list) else {
      NSLog("Failed to get window list")
      return
    }
    windowList
      .compactMap { (window: NSDictionary) -> Item? in Item(window) }
      .filter { (item: Item) -> Bool in item.isOnScreen }
      .filter { (item: Item) -> Bool in 0 < item.minAxis.y }
      .sorted { (left: Item, right: Item) -> Bool in left.id < right.id }
      .forEach { (item: Item) -> Void in
        let ax = item.minAxis
        let c = item.app.map({ ch in ch.isASCII ? 0: 1 }).reduce(0, +)
        let line = String(
          format:
            "%6d %@ [w=%4d,h=%4d,x=%4d,y=%4d] \(item.title)",
          item.id,
          item.app.padding(toLength: 30 - c, withPad: " ", startingAt: 0),
          item.width,
          item.height,
          ax.x,
          ax.y
        )
        print(line)
      }
  }
}

struct Axis {
  let x: Int
  let y: Int
}

extension CFNumber {
  var intValue: Int {
    let ns = self as NSNumber
    return ns.intValue
  }
}

struct Item {
  let id: Int
  let app: String
  let title: String
  let isOnScreen: Bool
  let visible: Bool
  let height: Int
  let width: Int
  let minAxis: Axis
  let maxAxis: Axis
  init?(_ win: NSDictionary) {
    let cfId = win[kCGWindowNumber]
    guard let id: Int = cfId != nil ? (cfId as! CFNumber).intValue : nil else {
      return nil
    }
    let cfApp = win[kCGWindowOwnerName]
    let app: String = cfApp != nil ? (cfApp as! CFString as NSString as String) : ""
    let cfName = win[kCGWindowName]
    let title: String = cfName != nil ? (cfName as! CFString as NSString as String) : ""
    let cfIsOnScreen = win[kCGWindowIsOnscreen] ?? false
    let cfAlpha = win[kCGWindowAlpha] ?? 0
    let visible: Bool = 0 < (cfAlpha as! CFNumber).intValue
    let cfWinBounds = win[kCGWindowBounds] as! CFDictionary
    var rect = CGRect()
    CGRectMakeWithDictionaryRepresentation(cfWinBounds, &rect)

    self.id = id
    self.app = app
    self.title = title
    self.isOnScreen = cfIsOnScreen as! Bool
    self.visible = visible
    self.height = Int(rect.height)
    self.width = Int(rect.width)
    self.minAxis = Axis(x: Int(rect.minX), y: Int(rect.minY))
    self.maxAxis = Axis(x: Int(rect.maxX), y: Int(rect.maxY))
  }
}

extension Array where Element == NSDictionary {
  init?(from mayArray: CFArray?) {
    guard let array = mayArray else {
      return nil
    }
    let size = CFArrayGetCount(array)
    self = (0..<size).map({ (index: Int) -> NSDictionary in
      let value = CFArrayGetValueAtIndex(array, index)
      return unsafeBitCast(value, to: NSDictionary.self)
    })
  }
}
