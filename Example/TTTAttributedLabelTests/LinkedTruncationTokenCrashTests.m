//
//  LinkedTruncationTokenCrashTests.m
//
//  These tests fail while a linked truncation token can build an out-of-range
//  link during drawing. They pass once that range is rejected before attributes
//  are applied. Drawing is expected to leave the label text unchanged and every
//  stored link inside the string.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <CoreText/CoreText.h>

#if __has_include(<TTTAttributedLabel/TTTAttributedLabel.h>)
#import <TTTAttributedLabel/TTTAttributedLabel.h>
#elif __has_include(<TTTAttributedLabel.h>)
#import <TTTAttributedLabel.h>
#else
#import "TTTAttributedLabel.h"
#endif

static NSString * const TTTLinkedTokenText = @"\u2026 more";
static NSString * const TTTLongLinkedTokenText = @"\u2026 read more";

static NSURL *TTTLinkedTokenURL(void) {
    return [NSURL URLWithString:@"https://example.com/more"];
}

static BOOL TTTRangeIsInsideString(NSRange range, NSUInteger length) {
    return range.location <= length && range.length <= length - range.location;
}

@interface LinkedTruncationTokenCrashTests : XCTestCase
@end

@implementation LinkedTruncationTokenCrashTests

- (TTTAttributedLabel *)labelWithBounds:(CGRect)bounds {
    TTTAttributedLabel *label = [[TTTAttributedLabel alloc] initWithFrame:bounds];
    label.font = [UIFont systemFontOfSize:17.0];
    return label;
}

- (NSAttributedString *)linkedToken:(NSString *)token {
    return [[NSAttributedString alloc] initWithString:token attributes:@{
        NSFontAttributeName : [UIFont systemFontOfSize:17.0],
        NSForegroundColorAttributeName : [UIColor blueColor],
        NSLinkAttributeName : TTTLinkedTokenURL()
    }];
}

- (NSString *)layoutDescriptionForLabel:(TTTAttributedLabel *)label {
    NSAttributedString *text = label.attributedText;
    if (text.length == 0 || CGRectIsEmpty(label.bounds)) {
        return [NSString stringWithFormat:@"textLength=%lu bounds=%@", (unsigned long)text.length, NSStringFromCGRect(label.bounds)];
    }

    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)text);
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, label.bounds);
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, (CFIndex)text.length), path, NULL);
    CFArrayRef lines = CTFrameGetLines(frame);
    NSMutableString *description = [NSMutableString stringWithFormat:@"numberOfLines=%ld lineBreakMode=%ld textLength=%lu lineCount=%ld\n",
                                     (long)label.numberOfLines,
                                     (long)label.lineBreakMode,
                                     (unsigned long)text.length,
                                     (long)CFArrayGetCount(lines)];
    for (CFIndex index = 0; index < CFArrayGetCount(lines); index++) {
        CTLineRef line = CFArrayGetValueAtIndex(lines, index);
        CFRange range = CTLineGetStringRange(line);
        [description appendFormat:@"line %ld location=%ld length=%ld end=%ld\n",
                                   (long)index,
                                   (long)range.location,
                                   (long)range.length,
                                   (long)(range.location + range.length)];
    }
    CFRelease(frame);
    CGPathRelease(path);
    CFRelease(framesetter);
    return description;
}

- (void)drawLabel:(TTTAttributedLabel *)label inContext:(BOOL)useDrawTextInRect {
    if (useDrawTextInRect) {
        [label drawTextInRect:label.bounds];
    } else {
        [label.layer renderInContext:UIGraphicsGetCurrentContext()];
    }
}

- (void)assertDrawingPreservesTextAndInBoundsLinks:(TTTAttributedLabel *)label
                                 useDrawTextInRect:(BOOL)useDrawTextInRect {
    NSString *original = [label.attributedText.string copy];
    NSString *layout = [self layoutDescriptionForLabel:label];
    XCTAssertGreaterThan(label.bounds.size.width, 0);
    XCTAssertGreaterThan(label.bounds.size.height, 0);

    UIGraphicsBeginImageContextWithOptions(label.bounds.size, NO, 1);
    @try {
        [self drawLabel:label inContext:useDrawTextInRect];
        [self drawLabel:label inContext:useDrawTextInRect];
    } @catch (NSException *exception) {
        UIGraphicsEndImageContext();
        XCTFail(@"Drawing raised %@ (%@). Layout before drawing:\n%@", exception.name, exception.reason, layout);
        return;
    }
    UIGraphicsEndImageContext();

    XCTAssertEqualObjects(label.attributedText.string, original);
    for (NSTextCheckingResult *result in label.links) {
        XCTAssertTrue(TTTRangeIsInsideString(result.range, label.attributedText.length),
                      @"link range {%lu, %lu} is outside a string of length %lu. Layout before drawing:\n%@",
                      (unsigned long)result.range.location,
                      (unsigned long)result.range.length,
                      (unsigned long)label.attributedText.length,
                      layout);
    }
}

- (void)testDefaultOneLineTailTruncationWithLeadingNewline {
    TTTAttributedLabel *label = [self labelWithBounds:CGRectMake(0, 0, 240, 44)];
    XCTAssertEqual(label.numberOfLines, 1);
    XCTAssertEqual(label.lineBreakMode, NSLineBreakByTruncatingTail);
    label.attributedTruncationToken = [self linkedToken:TTTLinkedTokenText];
    label.text = @"\nrest of the supplied label text";

    [self assertDrawingPreservesTextAndInBoundsLinks:label useDrawTextInRect:YES];
}

- (void)testTailTruncationWhenFirstParagraphIsShorterThanToken {
    TTTAttributedLabel *label = [self labelWithBounds:CGRectMake(0, 0, 240, 44)];
    label.numberOfLines = 1;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.attributedTruncationToken = [self linkedToken:TTTLinkedTokenText];
    label.text = @"A\nrest of the supplied label text";

    [self assertDrawingPreservesTextAndInBoundsLinks:label useDrawTextInRect:YES];
}

- (void)testHeadTruncationWhenFirstParagraphIsShorterThanToken {
    TTTAttributedLabel *label = [self labelWithBounds:CGRectMake(0, 0, 240, 44)];
    label.numberOfLines = 1;
    label.lineBreakMode = NSLineBreakByTruncatingHead;
    label.attributedTruncationToken = [self linkedToken:TTTLinkedTokenText];
    label.text = @"A\nrest of the supplied label text";

    [self assertDrawingPreservesTextAndInBoundsLinks:label useDrawTextInRect:YES];
}

- (void)testMiddleTruncationWhenFirstParagraphIsShorterThanToken {
    TTTAttributedLabel *label = [self labelWithBounds:CGRectMake(0, 0, 240, 44)];
    label.numberOfLines = 1;
    label.lineBreakMode = NSLineBreakByTruncatingMiddle;
    label.attributedTruncationToken = [self linkedToken:TTTLinkedTokenText];
    label.text = @"A\nrest of the supplied label text";

    [self assertDrawingPreservesTextAndInBoundsLinks:label useDrawTextInRect:YES];
}

- (void)testMultilineTailTruncationWhenVisiblePrefixIsShorterThanToken {
    TTTAttributedLabel *label = [self labelWithBounds:CGRectMake(0, 0, 320, 120)];
    label.numberOfLines = 2;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.attributedTruncationToken = [self linkedToken:TTTLongLinkedTokenText];
    label.text = @"\nY\nremaining supplied label text";

    [self assertDrawingPreservesTextAndInBoundsLinks:label useDrawTextInRect:YES];
}

- (void)testDeprecatedTruncationTokenStringCarryingLink {
    TTTAttributedLabel *label = [self labelWithBounds:CGRectMake(0, 0, 240, 44)];
    label.numberOfLines = 1;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    label.truncationTokenString = TTTLinkedTokenText;
    label.truncationTokenStringAttributes = @{
        NSFontAttributeName : [UIFont systemFontOfSize:17.0],
        NSForegroundColorAttributeName : [UIColor blueColor],
        NSLinkAttributeName : TTTLinkedTokenURL()
    };
#pragma clang diagnostic pop
    label.text = @"\nrest of the supplied label text";

    [self assertDrawingPreservesTextAndInBoundsLinks:label useDrawTextInRect:YES];
}

- (void)testHighlightedDrawWithLinkedTruncationToken {
    TTTAttributedLabel *label = [self labelWithBounds:CGRectMake(0, 0, 240, 44)];
    label.numberOfLines = 1;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.highlightedTextColor = [UIColor greenColor];
    label.highlighted = YES;
    label.attributedTruncationToken = [self linkedToken:TTTLinkedTokenText];
    label.text = @"\nrest of the supplied label text";

    [self assertDrawingPreservesTextAndInBoundsLinks:label useDrawTextInRect:YES];
}

- (void)testLayerRenderWithLinkedTruncationToken {
    TTTAttributedLabel *label = [self labelWithBounds:CGRectMake(0, 0, 240, 44)];
    label.numberOfLines = 1;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.attributedTruncationToken = [self linkedToken:TTTLinkedTokenText];
    label.text = @"\nrest of the supplied label text";

    [self assertDrawingPreservesTextAndInBoundsLinks:label useDrawTextInRect:NO];
}

@end
