import Foundation

internal extension EdgeInsets {
    func toUIEdgeInsetsValue() -> UIEdgeInsets {
        return UIEdgeInsets(top: CGFloat(self.top),
                            left: CGFloat(self.left),
                            bottom: CGFloat(self.bottom),
                            right: CGFloat(self.right))
    }
}

extension UIEdgeInsets: Hashable {
    func toMBXEdgeInsetsValue() -> EdgeInsets {
        return EdgeInsets(top: Double(self.top),
                          left: Double(self.left),
                          bottom: Double(self.bottom),
                          right: Double(self.right))
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(top)
        hasher.combine(bottom)
        hasher.combine(left)
        hasher.combine(right)
    }
}
