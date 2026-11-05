//
//  TruncationTokenProbeTests.m
//
//  Verification-only probes for the linked truncation-token fix.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <TTTAttributedLabel.h>
#import <objc/message.h>

@interface TTTProbeLabel : TTTAttributedLabel
@property (nonatomic, assign) BOOL counting;
@property (nonatomic, assign) NSUInteger needsDisplayCount;
@end

@implementation TTTProbeLabel
- (void)setNeedsDisplay {
    if (self.counting) {
        self.needsDisplayCount += 1;
    }
    [super setNeedsDisplay];
}
@end

@interface TruncationTokenProbeTests : XCTestCase
@end

@implementation TruncationTokenProbeTests

- (NSString *)body:(NSUInteger)length {
    NSMutableString *s = [NSMutableString string];
    for (NSUInteger i = 0; i < length; i++) [s appendString:@"W"];
    return s;
}

- (TTTProbeLabel *)labelWithBody:(NSString *)body lines:(NSInteger)lines mode:(NSLineBreakMode)mode {
    TTTProbeLabel *label = [[TTTProbeLabel alloc] initWithFrame:CGRectMake(0, 0, 280, 80)];
    label.adjustsFontSizeToFitWidth = NO;
    label.font = [UIFont systemFontOfSize:12];
    label.numberOfLines = lines;
    label.lineBreakMode = mode;
    label.text = [[NSAttributedString alloc] initWithString:body attributes:@{NSFontAttributeName : label.font}];
    return label;
}

- (NSAttributedString *)token:(id)url {
    return [[NSAttributedString alloc] initWithString:@"more" attributes:@{NSLinkAttributeName : url}];
}

- (void)draw:(TTTAttributedLabel *)label {
    UIGraphicsBeginImageContextWithOptions(label.bounds.size, NO, 1.0);
    [label drawTextInRect:label.bounds];
    UIGraphicsEndImageContext();
}

- (NSUInteger)drawUntilIdle:(TTTProbeLabel *)label {
    label.needsDisplayCount = 0;
    label.counting = YES;
    NSUInteger steps = 0;
    while (steps < 30) {
        NSUInteger before = label.needsDisplayCount;
        [self draw:label];
        steps++;
        if (label.needsDisplayCount == before) break;
    }
    label.counting = NO;
    return steps;
}

- (TTTAttributedLabelLink *)tokenLink:(TTTAttributedLabel *)label {
    return ((id (*)(id, SEL))objc_msgSend)(label, NSSelectorFromString(@"currentTruncationTokenLink"));
}

- (void)testProbeAdjustsFontSizeToFitWidthDoesNotRedrawFromDraw {
    TTTProbeLabel *label = [self labelWithBody:[self body:500] lines:1 mode:NSLineBreakByTruncatingTail];
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.5;
    label.attributedTruncationToken = [self token:[NSURL URLWithString:@"https://example.test/more"]];
    NSUInteger steps = [self drawUntilIdle:label];
    XCTAssertEqual(steps, (NSUInteger)1);
    XCTAssertEqual(label.needsDisplayCount, (NSUInteger)0);
    XCTAssertEqual(label.links.count, (NSUInteger)0);
}

- (void)testProbeAdjustsFontSizeStillRestoresOriginalText {
    TTTProbeLabel *label = [self labelWithBody:[self body:500] lines:2 mode:NSLineBreakByTruncatingTail];
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.5;
    NSAttributedString *before = [label.attributedText copy];
    [self draw:label];
    XCTAssertTrue([label.attributedText isEqualToAttributedString:before]);
}

- (void)testProbeLinkInheritedFromBodyIntoEllipsisDoesNotGrow {
    TTTProbeLabel *label = [[TTTProbeLabel alloc] initWithFrame:CGRectMake(0, 0, 280, 80)];
    label.adjustsFontSizeToFitWidth = NO;
    label.font = [UIFont systemFontOfSize:12];
    label.numberOfLines = 1;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.text = [[NSAttributedString alloc] initWithString:[self body:500]
                                                 attributes:@{NSFontAttributeName : label.font,
                                                              NSLinkAttributeName : [NSURL URLWithString:@"https://example.test/body"]}];
    NSUInteger baseline = label.links.count;
    NSUInteger steps = [self drawUntilIdle:label];
    XCTAssertEqual(steps, (NSUInteger)1);
    XCTAssertEqual(label.links.count, baseline);
    TTTAttributedLabelLink *token = [self tokenLink:label];
    XCTAssertNotNil(token);
    XCTAssertEqualObjects(token.result.URL, [NSURL URLWithString:@"https://example.test/body"]);
}

- (void)testProbeStringValuedTokenLink {
    TTTProbeLabel *label = [self labelWithBody:[self body:500] lines:1 mode:NSLineBreakByTruncatingTail];
    label.attributedTruncationToken = [self token:@"https://example.test/string"];
    XCTAssertEqual([self drawUntilIdle:label], (NSUInteger)1);
    XCTAssertEqual(label.links.count, (NSUInteger)0);
    TTTAttributedLabelLink *token = [self tokenLink:label];
    XCTAssertTrue([token.result.URL isKindOfClass:[NSURL class]]);
    XCTAssertEqualObjects(token.result.URL.absoluteString, @"https://example.test/string");
}

- (void)testProbeResizingAndResettingTextBetweenDraws {
    TTTProbeLabel *label = [self labelWithBody:[self body:500] lines:2 mode:NSLineBreakByTruncatingTail];
    label.attributedTruncationToken = [self token:[NSURL URLWithString:@"https://example.test/more"]];
    for (NSUInteger i = 0; i < 100; i++) {
        label.frame = CGRectMake(0, 0, 100 + (i % 7) * 30, 40 + (i % 3) * 20);
        if (i % 5 == 0) {
            label.text = [[NSAttributedString alloc] initWithString:[self body:300 + i] attributes:@{NSFontAttributeName : label.font}];
        }
        label.highlightedTextColor = [UIColor redColor];
        label.highlighted = (i % 2 == 0);
        [self draw:label];
        (void)[label accessibilityElementCount];
    }
    label.counting = YES;
    label.needsDisplayCount = 0;
    for (NSUInteger i = 0; i < 50; i++) {
        [self draw:label];
    }
    XCTAssertEqual(label.links.count, (NSUInteger)0);
    XCTAssertEqual(label.needsDisplayCount, (NSUInteger)0);
}

- (void)testProbeTokenLinkResolvesAtTappedTokenAndIsStable {
    TTTProbeLabel *label = [self labelWithBody:[self body:500] lines:1 mode:NSLineBreakByTruncatingTail];
    NSURL *url = [NSURL URLWithString:@"https://example.test/more"];
    label.attributedTruncationToken = [self token:url];
    [self draw:label];

    CGRect textRect = [label textRectForBounds:label.bounds limitedToNumberOfLines:label.numberOfLines];
    CGPoint tokenPoint = CGPointMake(CGRectGetMaxX(textRect) - 3.f, CGRectGetMidY(textRect));
    TTTAttributedLabelLink *first = [label linkAtPoint:tokenPoint];
    TTTAttributedLabelLink *second = [label linkAtPoint:tokenPoint];
    XCTAssertNotNil(first);
    XCTAssertTrue(first == second);
    XCTAssertEqualObjects(first.result.URL, url);
    XCTAssertEqual(first.result.range.length, (NSUInteger)4);
    XCTAssertTrue(NSMaxRange(first.result.range) <= label.attributedText.length);
    XCTAssertTrue([label containslinkAtPoint:tokenPoint]);
    XCTAssertFalse([label containslinkAtPoint:CGPointMake(CGRectGetMinX(textRect) + 3.f, CGRectGetMidY(textRect))]);
    XCTAssertEqual(label.links.count, (NSUInteger)0);
}

- (void)testProbeNoTokenLinkWhenTextFitsOrTokenUnlinked {
    TTTProbeLabel *fits = [self labelWithBody:@"Hi" lines:1 mode:NSLineBreakByTruncatingTail];
    fits.attributedTruncationToken = [self token:[NSURL URLWithString:@"https://example.test/more"]];
    XCTAssertNil([self tokenLink:fits]);

    TTTProbeLabel *unlinked = [self labelWithBody:[self body:500] lines:1 mode:NSLineBreakByTruncatingTail];
    unlinked.attributedTruncationToken = [[NSAttributedString alloc] initWithString:@"more"];
    XCTAssertNil([self tokenLink:unlinked]);

    TTTProbeLabel *wrapping = [self labelWithBody:[self body:500] lines:1 mode:NSLineBreakByWordWrapping];
    wrapping.attributedTruncationToken = [self token:[NSURL URLWithString:@"https://example.test/more"]];
    XCTAssertNil([self tokenLink:wrapping]);
}

- (void)testProbeLongTokenOnShortLineDoesNotThrow {
    NSMutableString *longToken = [NSMutableString string];
    for (NSUInteger i = 0; i < 200; i++) [longToken appendString:@"m"];
    TTTProbeLabel *label = [self labelWithBody:@"ab\ncd\nef" lines:1 mode:NSLineBreakByTruncatingTail];
    label.attributedTruncationToken = [[NSAttributedString alloc] initWithString:longToken attributes:@{NSLinkAttributeName : [NSURL URLWithString:@"https://example.test/more"]}];
    XCTAssertNoThrow([self draw:label]);
    TTTAttributedLabelLink *token = [self tokenLink:label];
    XCTAssertNotNil(token);
    XCTAssertTrue(NSMaxRange(token.result.range) <= label.attributedText.length);
}

- (void)testProbeAccessibilityIncludesTokenLinkOnce {
    TTTProbeLabel *label = [self labelWithBody:[self body:500] lines:1 mode:NSLineBreakByTruncatingTail];
    label.attributedTruncationToken = [self token:[NSURL URLWithString:@"https://example.test/more"]];
    for (NSUInteger i = 0; i < 10; i++) [self draw:label];
    XCTAssertEqual([label accessibilityElementCount], (NSInteger)2);
}

@end
