#import <XCTest/XCTest.h>
#import <Cocoa/Cocoa.h>
#import "../FountainDocument.h"

@interface FountainDocumentTests : XCTestCase
@end

@implementation FountainDocumentTests

- (FountainDocument *)freshDoc {
    return [[FountainDocument alloc] init];
}

- (NSData *)utf8:(NSString *)s {
    return [s dataUsingEncoding:NSUTF8StringEncoding];
}

// ---------------------------------------------------------------------------

- (void)test_dataOfType_nilTextView_returnsEmptyUTF8 {
    FountainDocument *doc = [self freshDoc];
    NSData *data = [doc dataOfType:@"fountain" error:nil];
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    XCTAssertNotNil(str);
    XCTAssertEqualObjects(str, @"");
}

- (void)test_readFromData_storesToPendingContent {
    FountainDocument *doc = [self freshDoc];
    NSString *text = @"INT. OFFICE - DAY\n\nJOHN\nHello.";
    BOOL ok = [doc readFromData:[self utf8:text] ofType:@"fountain" error:nil];
    XCTAssertTrue(ok);
    XCTAssertNil(doc.textView, @"textView should not exist before makeWindowControllers");
    XCTAssertEqualObjects(doc.pendingContent, text);
}

- (void)test_readFromData_emptyData {
    FountainDocument *doc = [self freshDoc];
    BOOL ok = [doc readFromData:[NSData data] ofType:@"fountain" error:nil];
    XCTAssertTrue(ok);
    XCTAssertEqualObjects(doc.pendingContent, @"");
}

- (void)test_readFromData_unicodeRoundTrip {
    FountainDocument *doc = [self freshDoc];
    NSString *text = @"Ça va? — «Non.»\n\U0001F3AC";
    BOOL ok = [doc readFromData:[self utf8:text] ofType:@"fountain" error:nil];
    XCTAssertTrue(ok);
    XCTAssertEqualObjects(doc.pendingContent, text);
}

- (void)test_readFromData_latin1Fallback {
    // 0xe9 = 'é' in ISO Latin-1; invalid as standalone UTF-8.
    const uint8_t bytes[] = { 'C', 'a', 'f', 0xe9 };
    NSData *latin1Data = [NSData dataWithBytes:bytes length:4];
    FountainDocument *doc = [self freshDoc];
    BOOL ok = [doc readFromData:latin1Data ofType:@"fountain" error:nil];
    XCTAssertTrue(ok);
    XCTAssertNotNil(doc.pendingContent);
    XCTAssertTrue([doc.pendingContent hasPrefix:@"Caf"]);
}

- (void)test_roundTrip_readThenDataOfType {
    FountainDocument *doc = [self freshDoc];
    NSString *text = @"FADE IN:\n\nEXT. ROOFTOP - NIGHT";
    [doc readFromData:[self utf8:text] ofType:@"fountain" error:nil];

    // Simulate makeWindowControllers flushing pendingContent into a text view.
    NSTextView *tv = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 800, 600)];
    [tv setString:doc.pendingContent];
    doc.textView = tv;
    doc.pendingContent = nil;

    NSData *saved = [doc dataOfType:@"fountain" error:nil];
    NSString *recovered = [[NSString alloc] initWithData:saved encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(recovered, text);
}

- (void)test_readFromData_withExistingTextView_setsStringDirectly {
    // When textView already exists (window open), readFromData: must update it
    // immediately rather than stashing to pendingContent.
    FountainDocument *doc = [self freshDoc];
    NSTextView *tv = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 800, 600)];
    doc.textView = tv;

    NSString *text = @"EXT. BEACH - SUNSET\n\nThe sun sets.";
    BOOL ok = [doc readFromData:[self utf8:text] ofType:@"fountain" error:nil];
    XCTAssertTrue(ok);
    XCTAssertNil(doc.pendingContent, @"pendingContent should be nil when textView is set");
    XCTAssertEqualObjects([tv string], text);
}

@end
