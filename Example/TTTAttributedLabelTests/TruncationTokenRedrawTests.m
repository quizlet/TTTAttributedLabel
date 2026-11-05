//
//  TruncationTokenRedrawTests.m
//
//  Spec for the linked truncation-token redraw loop.
//  These tests fail while drawing a truncation token that carries a link
//  appends another link and marks the label dirty. They pass once that link
//  is registered outside drawing and drawFramesetter no longer calls
//  addLink or setNeedsDisplay.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <TTTAttributedLabel.h>

static NSString * const TTTRedrawToken = @"more";
static CGFloat const TTTRedrawFontSize = 12.f;
static CGRect const TTTRedrawFrame = {{0.f, 0.f}, {280.f, 80.f}};

@interface TTTNeedsDisplayCountingLabel : TTTAttributedLabel
@property (nonatomic, assign) BOOL countNeedsDisplay;
@property (nonatomic, assign) NSUInteger needsDisplayCount;
@end

@implementation TTTNeedsDisplayCountingLabel

- (void)setNeedsDisplay {
    if (self.countNeedsDisplay) {
        self.needsDisplayCount += 1;
    }
    [super setNeedsDisplay];
}

@end

@interface TruncationTokenRedrawTests : XCTestCase
@end

@implementation TruncationTokenRedrawTests

- (NSString *)bodyWithLength:(NSUInteger)length {
    NSMutableString *body = [NSMutableString stringWithCapacity:length];
    for (NSUInteger index = 0; index < length; index++) {
        // 'W' is wider than the truncation token and is not a substring of it.
        [body appendString:@"W"];
    }
    return body;
}

- (NSAttributedString *)linkedToken {
    return [[NSAttributedString alloc] initWithString:TTTRedrawToken
                                            attributes:@{
                                                NSLinkAttributeName : [NSURL URLWithString:@"https://example.test/more"]
                                            }];
}

- (TTTNeedsDisplayCountingLabel *)labelWithLineBreakMode:(NSLineBreakMode)lineBreakMode
                                           numberOfLines:(NSInteger)numberOfLines
                                                    body:(NSString *)body {
    TTTNeedsDisplayCountingLabel *label = [[TTTNeedsDisplayCountingLabel alloc] initWithFrame:TTTRedrawFrame];
    label.adjustsFontSizeToFitWidth = NO;
    label.font = [UIFont systemFontOfSize:TTTRedrawFontSize];
    label.numberOfLines = numberOfLines;
    label.lineBreakMode = lineBreakMode;
    label.text = [[NSAttributedString alloc] initWithString:body
                                                  attributes:@{
                                                      NSFontAttributeName : label.font
                                                  }];
    return label;
}

- (void)drawLabel:(TTTNeedsDisplayCountingLabel *)label {
    UIGraphicsBeginImageContextWithOptions(label.bounds.size, NO, 1.0);
    [label drawTextInRect:label.bounds];
    UIGraphicsEndImageContext();
}

// Drives the same cycle UIKit performs after setNeedsDisplay: draw again while
// the label keeps requesting display. A linked truncation token must not keep
// that cycle alive, and must not append a link on any of the draws.
- (void)assertDrawsStayBounded:(TTTNeedsDisplayCountingLabel *)label {
    NSUInteger baseline = label.links.count;
    label.needsDisplayCount = 0;
    label.countNeedsDisplay = YES;

    NSUInteger steps = 0;
    while (steps < 30) {
        NSUInteger displaysBefore = label.needsDisplayCount;
        [self drawLabel:label];
        steps++;
        if (label.needsDisplayCount == displaysBefore) {
            break;
        }
    }

    XCTAssertEqual(steps, 1);
    XCTAssertEqual(label.needsDisplayCount, 0);
    XCTAssertEqual(label.links.count, baseline);
}

- (void)testLinkedAttributedTruncationTokenDoesNotRedrawOrGrowLinks {
    TTTNeedsDisplayCountingLabel *label = [self labelWithLineBreakMode:NSLineBreakByTruncatingTail
                                                          numberOfLines:1
                                                                   body:[self bodyWithLength:500]];
    label.attributedTruncationToken = [self linkedToken];
    [self assertDrawsStayBounded:label];
}

- (void)testLinkedTruncationTokenStringDoesNotRedrawOrGrowLinks {
    TTTNeedsDisplayCountingLabel *label = [self labelWithLineBreakMode:NSLineBreakByTruncatingTail
                                                          numberOfLines:2
                                                                   body:[self bodyWithLength:500]];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    label.truncationTokenString = TTTRedrawToken;
    label.truncationTokenStringAttributes = @{
        NSLinkAttributeName : [NSURL URLWithString:@"https://example.test/more"]
    };
#pragma clang diagnostic pop
    [self assertDrawsStayBounded:label];
}

- (void)testHighlightedLinkedTruncationTokenDoesNotRedrawOrGrowLinks {
    TTTNeedsDisplayCountingLabel *label = [self labelWithLineBreakMode:NSLineBreakByTruncatingTail
                                                          numberOfLines:1
                                                                   body:[self bodyWithLength:500]];
    label.attributedTruncationToken = [self linkedToken];
    label.highlightedTextColor = [UIColor redColor];
    label.highlighted = YES;
    [self assertDrawsStayBounded:label];
}

- (void)testNilLinkAttributesStillDoNotRedrawOrGrowLinks {
    // Default link attributes are non-nil, so the first draw also rewrites the
    // string. With no link attributes the string is unchanged and the draw
    // path still has to avoid appending and marking dirty.
    TTTNeedsDisplayCountingLabel *label = [self labelWithLineBreakMode:NSLineBreakByTruncatingTail
                                                          numberOfLines:1
                                                                   body:[self bodyWithLength:500]];
    label.linkAttributes = nil;
    label.attributedTruncationToken = [self linkedToken];
    [self assertDrawsStayBounded:label];
}

- (void)testEveryTruncatingModeAndLineCountStaysBounded {
    NSLineBreakMode modes[] = {
        NSLineBreakByTruncatingHead,
        NSLineBreakByTruncatingMiddle,
        NSLineBreakByTruncatingTail
    };
    NSInteger lineCounts[] = {1, 2};

    for (NSUInteger modeIndex = 0; modeIndex < sizeof(modes) / sizeof(modes[0]); modeIndex++) {
        for (NSUInteger lineIndex = 0; lineIndex < sizeof(lineCounts) / sizeof(lineCounts[0]); lineIndex++) {
            TTTNeedsDisplayCountingLabel *label = [self labelWithLineBreakMode:modes[modeIndex]
                                                                  numberOfLines:lineCounts[lineIndex]
                                                                           body:[self bodyWithLength:500]];
            label.attributedTruncationToken = [self linkedToken];
            [self assertDrawsStayBounded:label];
        }
    }
}

- (void)testUnlinkedTruncationTokenDoesNotAddLinks {
    TTTNeedsDisplayCountingLabel *label = [self labelWithLineBreakMode:NSLineBreakByTruncatingTail
                                                          numberOfLines:1
                                                                   body:[self bodyWithLength:500]];
    label.attributedTruncationToken = [[NSAttributedString alloc] initWithString:TTTRedrawToken];
    [self assertDrawsStayBounded:label];
}

- (void)testLinkedTokenOnTextThatFitsDoesNotAddLinks {
    TTTNeedsDisplayCountingLabel *label = [self labelWithLineBreakMode:NSLineBreakByTruncatingTail
                                                          numberOfLines:1
                                                                   body:@"Hi"];
    label.attributedTruncationToken = [self linkedToken];
    [self assertDrawsStayBounded:label];
}

- (void)testLinkedTokenWithNonTruncatingLineBreakDoesNotAddLinks {
    NSLineBreakMode modes[] = {
        NSLineBreakByWordWrapping,
        NSLineBreakByCharWrapping,
        NSLineBreakByClipping
    };
    for (NSUInteger modeIndex = 0; modeIndex < sizeof(modes) / sizeof(modes[0]); modeIndex++) {
        TTTNeedsDisplayCountingLabel *label = [self labelWithLineBreakMode:modes[modeIndex]
                                                              numberOfLines:1
                                                                       body:[self bodyWithLength:500]];
        label.attributedTruncationToken = [self linkedToken];
        [self assertDrawsStayBounded:label];
    }
}

@end

#if TTT_LINKED_TRUNCATION_HARNESS

#import <objc/message.h>

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    @autoreleasepool {
        TruncationTokenRedrawTests *tests = [TruncationTokenRedrawTests new];
        SEL selectors[] = {
            @selector(testLinkedAttributedTruncationTokenDoesNotRedrawOrGrowLinks),
            @selector(testLinkedTruncationTokenStringDoesNotRedrawOrGrowLinks),
            @selector(testHighlightedLinkedTruncationTokenDoesNotRedrawOrGrowLinks),
            @selector(testNilLinkAttributesStillDoNotRedrawOrGrowLinks),
            @selector(testEveryTruncatingModeAndLineCountStaysBounded),
            @selector(testUnlinkedTruncationTokenDoesNotAddLinks),
            @selector(testLinkedTokenOnTextThatFitsDoesNotAddLinks),
            @selector(testLinkedTokenWithNonTruncatingLineBreakDoesNotAddLinks)
        };
        int failures = 0;
        for (NSUInteger index = 0; index < sizeof(selectors) / sizeof(selectors[0]); index++) {
            NSUInteger before = tests.failureCount;
            BOOL threw = NO;
            @try {
                ((void (*)(id, SEL))objc_msgSend)(tests, selectors[index]);
            } @catch (NSException *exception) {
                threw = YES;
                failures++;
                NSLog(@"EXCEPTION %s: %@ %@", sel_getName(selectors[index]), exception.name, exception.reason);
            }
            NSUInteger added = tests.failureCount - before;
            failures += (int)added;
            NSLog(@"%s %s", (threw || added != 0) ? "FAIL" : "PASS", sel_getName(selectors[index]));
        }
        NSLog(@"done failures=%d", failures);
        return failures == 0 ? 0 : 1;
    }
}

#endif
