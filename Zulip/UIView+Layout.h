// Copyright (c) 2012 Pivotal Labs (www.pivotallabs.com) Contact email: adam@pivotallabs.com
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <UIKit/UIKit.h>

typedef enum {
    ViewCornerTopLeft,
    ViewCornerBottomLeft,
    ViewCornerTopRight,
    ViewCornerBottomRight
} ViewCorner;

@interface UIView (Layout)

- (CGFloat) top;
- (CGFloat) bottom;
- (CGFloat) left;
- (CGFloat) right;

- (CGFloat) width;
- (CGFloat) height;

- (CGSize) size;
- (CGPoint) origin;

- (CGFloat)bottomOfSuperview;
- (CGFloat)rightOfSuperview;

//-------------------------
// PivotalCoreKit code here
//-------------------------

// Intended for the idiom view.center = superview.centerBounds;
- (CGPoint)centerBounds;

// Move/resize as separate operations, working off of all four corners
- (void)moveCorner:(ViewCorner)corner toPoint:(CGPoint)point;
- (void)moveToPoint:(CGPoint)point;
- (void)moveBy:(CGPoint)pointDelta;
- (void)resizeTo:(CGSize)size keepingCorner:(ViewCorner)corner;
- (void)resizeTo:(CGSize)size;

@end
