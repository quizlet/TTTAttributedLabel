//
//  TruncationTokenProbeTests.m
//
//  Verification-only probes for the linked truncation-token fix.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <TTTAttributedLabel.h>
#import <objc/message.h>
#import <KIF.h>

@interface TTTProbeDelegate : NSObject <TTTAttributedLabelDelegate>
@property (nonatomic, strong) NSURL *selectedURL;
@end

@implementation TTTProbeDelegate
- (void)attributedLabel:(__unused TTTAttributedLabel *)label didSelectLinkWithURL:(NSURL *)url {
    self.selectedURL = url;
}
@end

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

- (BOOL)findTokenPoint:(CGPoint *)outPoint inLabel:(TTTAttributedLabel *)label {
    for (CGFloat y = 1.f; y < label.bounds.size.height; y += 1.f) {
        for (CGFloat x = label.bounds.size.width - 1.f; x > 0.f; x -= 1.f) {
            if ([label linkAtPoint:CGPointMake(x, y)]) {
                *outPoint = CGPointMake(x, y);
                return YES;
            }
        }
    }
    return NO;
}

- (void)testProbeTokenLinkResolvesAtTappedTokenAndIsStable {
    TTTProbeLabel *label = [self labelWithBody:[self body:500] lines:1 mode:NSLineBreakByTruncatingTail];
    NSURL *url = [NSURL URLWithString:@"https://example.test/more"];
    label.attributedTruncationToken = [self token:url];
    [self draw:label];

    CGPoint tokenPoint = CGPointZero;
    XCTAssertTrue([self findTokenPoint:&tokenPoint inLabel:label]);
    TTTAttributedLabelLink *first = [label linkAtPoint:tokenPoint];
    TTTAttributedLabelLink *second = [label linkAtPoint:tokenPoint];
    NSLog(@"PROBE token point %@ range %@", NSStringFromCGPoint(tokenPoint), NSStringFromRange(first.result.range));
    XCTAssertNotNil(first);
    XCTAssertTrue(first == second);
    XCTAssertEqualObjects(first.result.URL, url);
    XCTAssertEqual(first.result.range.length, (NSUInteger)4);
    XCTAssertTrue(NSMaxRange(first.result.range) <= label.attributedText.length);
    XCTAssertTrue([label containslinkAtPoint:tokenPoint]);
    XCTAssertFalse([label containslinkAtPoint:CGPointMake(3.f, tokenPoint.y)]);
    XCTAssertEqual(label.links.count, (NSUInteger)0);
}

- (void)testProbeTappingTokenCallsDelegateWithTokenURL {
    TTTProbeLabel *label = [self labelWithBody:[self body:500] lines:1 mode:NSLineBreakByTruncatingTail];
    NSURL *url = [NSURL URLWithString:@"https://example.test/more"];
    label.attributedTruncationToken = [self token:url];
    TTTProbeDelegate *delegate = [TTTProbeDelegate new];
    label.delegate = delegate;

    CGPoint tokenPoint = CGPointZero;
    XCTAssertTrue([self findTokenPoint:&tokenPoint inLabel:label]);

    UIWindow *window = [[UIApplication sharedApplication].windows lastObject];
    [window addSubview:label];
    [label tapAtPoint:tokenPoint];
    [label removeFromSuperview];

    XCTAssertEqualObjects(delegate.selectedURL, url);
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

- (unsigned long long)renderHash:(UIView *)view {
    CGSize size = view.bounds.size;
    size_t width = (size_t)ceil(size.width), height = (size_t)ceil(size.height);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL, width, height, 8, width * 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    CGContextTranslateCTM(ctx, 0, (CGFloat)height);
    CGContextScaleCTM(ctx, 1, -1);
    [view.layer renderInContext:ctx];
    const unsigned char *bytes = CGBitmapContextGetData(ctx);
    unsigned long long hash = 1469598103934665603ULL;
    for (size_t i = 0; i < width * height * 4; i++) {
        hash = (hash ^ bytes[i]) * 1099511628211ULL;
    }
    CGContextRelease(ctx);
    return hash;
}

- (TTTAttributedLabel *)snapshotLabel {
    TTTAttributedLabel *label = [[TTTAttributedLabel alloc] initWithFrame:CGRectMake(0, 0, 300, 100)];
    label.numberOfLines = 0;
    return label;
}

- (NSAttributedString *)snapshotText {
    return [[NSAttributedString alloc] initWithString:@"Pallando, Merlyn, and Melisandre were walking one day..."
                                           attributes:@{NSForegroundColorAttributeName : [UIColor redColor],
                                                        NSFontAttributeName : [UIFont boldSystemFontOfSize:16.f]}];
}

- (void)testProbeRenderHashesOfExistingSnapshotConfigurations {
    NSArray *tokens = @[
        [[NSAttributedString alloc] initWithString:@"[DOTDOTDOT]" attributes:@{NSFontAttributeName : [UIFont boldSystemFontOfSize:12], NSForegroundColorAttributeName : [UIColor blueColor]}],
        [[NSAttributedString alloc] initWithString:@"[more]" attributes:@{NSFontAttributeName : [UIFont boldSystemFontOfSize:12], NSForegroundColorAttributeName : [UIColor blueColor], NSLinkAttributeName : [NSURL URLWithString:@"http://ytmnd.com"]}],
        [[NSAttributedString alloc] initWithString:@"[more]" attributes:@{NSFontAttributeName : [UIFont boldSystemFontOfSize:12], NSForegroundColorAttributeName : [UIColor blueColor], NSLinkAttributeName : [NSURL URLWithString:@"http://ytmnd.com"], NSUnderlineStyleAttributeName : @YES}],
        [[NSAttributedString alloc] initWithString:@"[more]" attributes:@{NSFontAttributeName : [UIFont boldSystemFontOfSize:12], NSForegroundColorAttributeName : [UIColor blueColor], NSLinkAttributeName : [NSURL URLWithString:@"http://ytmnd.com"], NSUnderlineStyleAttributeName : @YES, NSUnderlineColorAttributeName : [UIColor redColor]}],
    ];
    NSArray *names = @[@"testAttributedTruncationToken", @"testAttributedTruncationTokenLinks", @"testAttributedTruncationTokenLinksUnderline", @"testAttributedTruncationTokenLinksUnderlineColor"];
    for (NSUInteger i = 0; i < tokens.count; i++) {
        TTTAttributedLabel *label = [self snapshotLabel];
        label.attributedTruncationToken = tokens[i];
        label.text = [self snapshotText];
        [label setFrame:CGRectMake(0, 0, 120, 60)];
        NSLog(@"PROBE render %@ %016llx", names[i], [self renderHash:label]);
    }

    TTTAttributedLabel *adjusts = [self snapshotLabel];
    adjusts.adjustsFontSizeToFitWidth = YES;
    adjusts.minimumScaleFactor = 0.25f;
    adjusts.numberOfLines = 1;
    adjusts.text = [self snapshotText];
    [adjusts setFrame:CGRectMake(0, 0, 150, 50)];
    NSLog(@"PROBE render testAdjustsFontSizeToFitWidth %016llx", [self renderHash:adjusts]);

    TTTAttributedLabel *lines = [self snapshotLabel];
    lines.numberOfLines = 1;
    lines.text = [self snapshotText];
    NSLog(@"PROBE render testNumberOfLines %016llx", [self renderHash:lines]);

    TTTAttributedLabel *sized = [self snapshotLabel];
    sized.numberOfLines = 3;
    sized.attributedTruncationToken = [[NSAttributedString alloc] initWithString:@"[more]" attributes:@{NSFontAttributeName : [UIFont boldSystemFontOfSize:14], NSForegroundColorAttributeName : [UIColor greenColor]}];
    sized.text = [[NSAttributedString alloc] initWithString:@"Test\nString\nWith\nLines" attributes:@{NSFontAttributeName : [UIFont boldSystemFontOfSize:15], NSForegroundColorAttributeName : [UIColor redColor]}];
    [sized sizeToFit];
    NSLog(@"PROBE render testSizeToFitWithTruncationToken %016llx", [self renderHash:sized]);

    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 375, 667)];
    NSString *text = @"The NSString class declares the programmatic interface for an object that manages immutable strings. An immutable string is a text string that is defined when it is created and subsequently cannot be changed. NSString is implemented to represent an array of Unicode characters, in other words, a text string.";
    for (NSUInteger i = 0; i < 10; i++) {
        TTTAttributedLabel *l = [[TTTAttributedLabel alloc] initWithFrame:CGRectMake(10, 10 * (i + 1) + (i * 50) + 10, container.bounds.size.width - (i + 1) * 20, 50)];
        l.numberOfLines = 2;
        l.attributedTruncationToken = [[NSAttributedString alloc] initWithString:@"...more" attributes:@{NSForegroundColorAttributeName : [UIColor blueColor], NSLinkAttributeName : [NSURL URLWithString:@"http://more.com"]}];
        l.text = text;
        [container addSubview:l];
    }
    NSLog(@"PROBE render testLabelTruncationVaryingWidthSizing %016llx", [self renderHash:container]);
}

- (void)testProbeAccessibilityIncludesTokenLinkOnce {
    TTTProbeLabel *label = [self labelWithBody:[self body:500] lines:1 mode:NSLineBreakByTruncatingTail];
    label.attributedTruncationToken = [self token:[NSURL URLWithString:@"https://example.test/more"]];
    for (NSUInteger i = 0; i < 10; i++) [self draw:label];
    XCTAssertEqual([label accessibilityElementCount], (NSInteger)2);
}

@end
