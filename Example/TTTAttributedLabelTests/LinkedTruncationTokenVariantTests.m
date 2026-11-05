//
//  LinkedTruncationTokenVariantTests.m
//
//  Verification-only variants of the short-last-line technique.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#if __has_include(<TTTAttributedLabel/TTTAttributedLabel.h>)
#import <TTTAttributedLabel/TTTAttributedLabel.h>
#elif __has_include(<TTTAttributedLabel.h>)
#import <TTTAttributedLabel.h>
#else
#import "TTTAttributedLabel.h"
#endif

static NSURL *TTTVariantURL(void) {
    return [NSURL URLWithString:@"https://example.com/more"];
}

@interface LinkedTruncationTokenVariantTests : XCTestCase
@end

@implementation LinkedTruncationTokenVariantTests

- (NSAttributedString *)tokenWithString:(NSString *)string link:(id)link {
    NSMutableDictionary *attributes = [@{ NSFontAttributeName : [UIFont systemFontOfSize:17.0] } mutableCopy];
    if (link) {
        attributes[NSLinkAttributeName] = link;
    }
    return [[NSAttributedString alloc] initWithString:string attributes:attributes];
}

- (void)drawLabel:(TTTAttributedLabel *)label times:(NSUInteger)times context:(NSString *)context {
    NSString *original = [label.attributedText.string copy];
    UIGraphicsBeginImageContextWithOptions(label.bounds.size, NO, 1);
    @try {
        for (NSUInteger i = 0; i < times; i++) {
            [label drawTextInRect:label.bounds];
            [label.layer renderInContext:UIGraphicsGetCurrentContext()];
        }
    } @catch (NSException *exception) {
        XCTFail(@"%@: drawing raised %@ (%@)", context, exception.name, exception.reason);
    }
    UIGraphicsEndImageContext();

    XCTAssertEqualObjects(label.attributedText.string, original, @"%@", context);
    NSUInteger length = label.attributedText.length;
    for (NSTextCheckingResult *result in label.links) {
        XCTAssertTrue(result.range.location <= length && result.range.length <= length - result.range.location,
                      @"%@: link {%lu, %lu} outside length %lu", context,
                      (unsigned long)result.range.location, (unsigned long)result.range.length, (unsigned long)length);
    }
    @try {
        (void)[label accessibilityElementCount];
    } @catch (NSException *exception) {
        XCTFail(@"%@: accessibility raised %@ (%@)", context, exception.name, exception.reason);
    }
}

- (void)testShortLastLineMatrix {
    NSArray *prefixes = @[ @"", @"\n", @"\n\n", @"\n\n\n", @"A\n", @"AB\n", @"\r\n", @"\u2028", @"\U0001F600\n", @"e\u0301\n", @"\u05D0\n" ];
    NSArray *tokens = @[ @"\u2026", @"\u2026 more", @"\u2026 read more", @"... and a much longer read more token" ];
    NSArray *modes = @[ @(NSLineBreakByTruncatingTail), @(NSLineBreakByTruncatingHead), @(NSLineBreakByTruncatingMiddle) ];
    NSArray *widths = @[ @1, @20, @240 ];

    for (NSString *prefix in prefixes) {
        for (NSString *token in tokens) {
            for (NSNumber *mode in modes) {
                for (NSInteger lines = 1; lines <= 3; lines++) {
                    for (NSNumber *width in widths) {
                        TTTAttributedLabel *label = [[TTTAttributedLabel alloc] initWithFrame:CGRectMake(0, 0, width.doubleValue, 120)];
                        label.font = [UIFont systemFontOfSize:17.0];
                        label.numberOfLines = lines;
                        label.lineBreakMode = (NSLineBreakMode)mode.integerValue;
                        label.attributedTruncationToken = [self tokenWithString:token link:TTTVariantURL()];
                        label.text = [prefix stringByAppendingString:@"rest\nof the\nsupplied label text that keeps going"];
                        NSString *context = [NSString stringWithFormat:@"prefix=%@ token=%@ mode=%@ lines=%ld width=%@",
                                             [prefix debugDescription], token, mode, (long)lines, width];
                        [self drawLabel:label times:2 context:context];
                    }
                }
            }
        }
    }
}

- (void)testTextAssignedThroughAttributedTextProperty {
    TTTAttributedLabel *label = [[TTTAttributedLabel alloc] initWithFrame:CGRectMake(0, 0, 240, 44)];
    label.attributedTruncationToken = [self tokenWithString:@"\u2026 more" link:TTTVariantURL()];
    label.attributedText = [[NSAttributedString alloc] initWithString:@"\nrest of the supplied label text"
                                                           attributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:17.0] }];
    [self drawLabel:label times:2 context:@"attributedText property"];
}

- (void)testAdjustsFontSizeToFitWidth {
    TTTAttributedLabel *label = [[TTTAttributedLabel alloc] initWithFrame:CGRectMake(0, 0, 120, 44)];
    label.font = [UIFont systemFontOfSize:17.0];
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.5;
    label.attributedTruncationToken = [self tokenWithString:@"\u2026 more" link:TTTVariantURL()];
    label.text = @"\nrest of the supplied label text that is much wider than the label";
    [self drawLabel:label times:2 context:@"adjustsFontSizeToFitWidth"];
}

- (void)testTextInsetsAndVerticalAlignment {
    TTTAttributedLabel *label = [[TTTAttributedLabel alloc] initWithFrame:CGRectMake(0, 0, 240, 60)];
    label.font = [UIFont systemFontOfSize:17.0];
    label.textInsets = UIEdgeInsetsMake(5, 100, 5, 100);
    label.verticalAlignment = TTTAttributedLabelVerticalAlignmentBottom;
    label.attributedTruncationToken = [self tokenWithString:@"\u2026 more" link:TTTVariantURL()];
    label.text = @"\nrest of the supplied label text";
    [self drawLabel:label times:2 context:@"textInsets"];
}

- (void)testStringLinkValueAndHighlight {
    TTTAttributedLabel *label = [[TTTAttributedLabel alloc] initWithFrame:CGRectMake(0, 0, 240, 44)];
    label.font = [UIFont systemFontOfSize:17.0];
    label.highlightedTextColor = [UIColor redColor];
    label.highlighted = YES;
    label.attributedTruncationToken = [self tokenWithString:@"\u2026 more" link:@"https://example.com/more"];
    label.text = @"\n\nrest of the supplied label text";
    [self drawLabel:label times:2 context:@"string link"];
}

- (void)testEmptyTruncationToken {
    TTTAttributedLabel *label = [[TTTAttributedLabel alloc] initWithFrame:CGRectMake(0, 0, 240, 44)];
    label.font = [UIFont systemFontOfSize:17.0];
    label.attributedTruncationToken = [[NSAttributedString alloc] initWithString:@""];
    label.text = @"\nrest of the supplied label text";
    [self drawLabel:label times:1 context:@"empty token"];
}

- (void)testTextChangedAfterLinkWasAdded {
    TTTAttributedLabel *label = [[TTTAttributedLabel alloc] initWithFrame:CGRectMake(0, 0, 120, 44)];
    label.font = [UIFont systemFontOfSize:17.0];
    label.attributedTruncationToken = [self tokenWithString:@"\u2026 more" link:TTTVariantURL()];
    label.text = @"a long first line of supplied text that truncates";
    [self drawLabel:label times:1 context:@"long text"];
    label.text = @"\nx";
    [self drawLabel:label times:2 context:@"short text after long text"];
    XCTAssertEqual(label.links.count, (NSUInteger)0);
}

- (void)testDiagnosticNormalTruncationLinks {
    NSArray *configs = @[ @[@200, @44, @1], @[@120, @60, @0], @[@120, @60, @2], @[@300, @50, @2] ];
    for (NSArray *config in configs) {
        TTTAttributedLabel *label = [[TTTAttributedLabel alloc] initWithFrame:CGRectMake(0, 0, [config[0] doubleValue], [config[1] doubleValue])];
        label.font = [UIFont systemFontOfSize:17.0];
        label.numberOfLines = [config[2] integerValue];
        label.attributedTruncationToken = [self tokenWithString:@"\u2026 more" link:TTTVariantURL()];
        label.text = @"The NSString class declares the programmatic interface for an object that manages immutable strings.";
        [self drawLabel:label times:3 context:@"diagnostic"];
        NSMutableString *ranges = [NSMutableString string];
        for (NSTextCheckingResult *result in label.links) {
            [ranges appendFormat:@"{%lu,%lu} ", (unsigned long)result.range.location, (unsigned long)result.range.length];
        }
        NSLog(@"DIAG config=%@ numberOfLines=%ld lineBreakMode=%ld links=%lu %@", [config componentsJoinedByString:@"x"], (long)label.numberOfLines, (long)label.lineBreakMode, (unsigned long)label.links.count, ranges);
    }
}

- (void)testLinkStillAddedWhenLineIsLongEnoughAndNotDuplicated {
    TTTAttributedLabel *label = [[TTTAttributedLabel alloc] initWithFrame:CGRectMake(0, 0, 120, 60)];
    label.font = [UIFont systemFontOfSize:17.0];
    label.numberOfLines = 2;
    NSString *token = @"\u2026 more";
    label.attributedTruncationToken = [self tokenWithString:token link:TTTVariantURL()];
    label.text = @"The NSString class declares the programmatic interface for an object that manages immutable strings.";
    [self drawLabel:label times:5 context:@"long line"];

    XCTAssertEqual(label.links.count, (NSUInteger)1);
    NSTextCheckingResult *result = label.links.firstObject;
    XCTAssertEqualObjects(result.URL, TTTVariantURL());
    XCTAssertEqual(result.range.length, token.length);
    XCTAssertGreaterThan(result.range.location, (NSUInteger)0);
}

@end
