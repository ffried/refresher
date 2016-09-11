//
// PullToRefreshView.swift
//
// Copyright (c) 2014 Josip Cavar
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import UIKit
import QuartzCore

private var KVOContext = "RefresherKVOContext"
private let ContentOffsetKeyPath = "contentOffset"

open class PullToRefreshView: UIView {
    public typealias PullToRefreshAction = () -> ()
    public enum State {
//        case Inactive = 0 // Maybe in the future we will want to distinguish here
        case pulling
        case readyToRelease
        case refreshing
    }
    
    private var scrollViewBouncesDefaultValue: Bool = false
    private var scrollViewInsetsDefaultValue: UIEdgeInsets = UIEdgeInsets.zero
    
    private let animationOptions: UIViewAnimationOptions = [.allowAnimatedContent, .beginFromCurrentState]
    open let animationDuration: TimeInterval = 0.3
    
    internal var action: PullToRefreshAction = {}
    
    private var previousOffset: CGFloat = 0
    
    internal var loading: Bool = false {
        didSet {
            if loading {
                state = .refreshing
                startAnimating()
            } else {
                stopAnimating()
            }
        }
    }
    
    open private(set) var state: State = .pulling {
        didSet { stateChanged(oldValue) }
    }
    
    // MARK: Object lifecycle methods
    public override init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }
    
//    public override init() {
//        super.init()
//    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    open override func awakeFromNib() {
        super.awakeFromNib()
        initialize()
    }
    
    open func initialize() { } // Overridden by subclasses
    
    deinit {
        (superview as? UIScrollView)?.removeObserver(self, forKeyPath: ContentOffsetKeyPath, context: &KVOContext)
    }
    
    // MARK: - UIView methods
    open override func willMove(toSuperview newSuperview: UIView!) {
        superview?.removeObserver(self, forKeyPath: ContentOffsetKeyPath, context: &KVOContext)
    }
    
    open override func didMoveToSuperview() {
        if let scrollView = superview as? UIScrollView {
            scrollView.addObserver(self, forKeyPath: ContentOffsetKeyPath, options: .initial, context: &KVOContext)
            scrollViewBouncesDefaultValue = scrollView.bounces
            scrollViewInsetsDefaultValue = scrollView.contentInset
        }
    }
    
    // MARK: - KVO method
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &KVOContext && keyPath == ContentOffsetKeyPath && object as? UIView == superview {
            if let scrollView = object as? UIScrollView {
//                println("Refresher: y content offset: \(scrollView.contentOffset.y)")
                let offsetWithoutInsets = previousOffset + scrollViewInsetsDefaultValue.top
                if offsetWithoutInsets < -frame.size.height {
                    if !scrollView.isDragging && !loading {
                        loading = true
                    } else if !loading {
                        state = .readyToRelease
                        changeProgress(-offsetWithoutInsets / frame.size.height)
                    }
                } else if !loading && offsetWithoutInsets < 0.0 {
                    state = .pulling
                    changeProgress(-offsetWithoutInsets / frame.size.height)
                }
                previousOffset = scrollView.contentOffset.y
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    // MARK: - PullToRefreshView methods
    open func startAnimating() {
        if let scrollView = superview as? UIScrollView {
            var insets = scrollView.contentInset
            insets.top += frame.size.height
            // we need to restore previous offset because we will animate scroll view insets and regular scroll view animating is not applied then
            scrollView.contentOffset.y = previousOffset
            scrollView.bounces = false
            UIView.animate(withDuration: animationDuration, delay: 0.0, options: animationOptions, animations: {
                scrollView.contentInset = insets
                scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x, y: -insets.top)
                }) { finished in
                    self.action()
            }
        }
    }
    
    open func stopAnimating() {
        if let scrollView = superview as? UIScrollView {
            scrollView.bounces = scrollViewBouncesDefaultValue
            UIView.animate(withDuration: animationDuration, delay: 0.0, options: animationOptions, animations: {
                scrollView.contentInset = self.scrollViewInsetsDefaultValue
                }) { finished in
                    self.changeProgress(0.0)
            }
        }
    }
    
    open func changeProgress(_ progress: CGFloat) { } // Overridden by subclasses
    
    open func stateChanged(_ previousState: State) { } // Overridden by subclasses
}
