#import <XCTest/XCTest.h>
#import <Cocoa/Cocoa.h>
#import "../src/FountainDocument.h"

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

// ---------------------------------------------------------------------------
// Trailing compatibility comment strip/restore

- (void)test_trailingNote_isStrippedFromPendingContent {
    FountainDocument *doc = [self freshDoc];
    NSString *text = @"INT. X - DAY\n\nAction.\n\n[[compat]]";
    [doc readFromData:[self utf8:text] ofType:@"fountain" error:nil];
    XCTAssertFalse([doc.pendingContent containsString:@"[[compat]]"]);
    XCTAssertEqualObjects(doc.trailingComment, @"[[compat]]");
}

- (void)test_trailingBoneyard_isStrippedFromPendingContent {
    FountainDocument *doc = [self freshDoc];
    NSString *text = @"INT. X - DAY\n\nAction.\n\n/* compat */";
    [doc readFromData:[self utf8:text] ofType:@"fountain" error:nil];
    XCTAssertFalse([doc.pendingContent containsString:@"/* compat */"]);
    XCTAssertEqualObjects(doc.trailingComment, @"/* compat */");
}

- (void)test_trailingComment_roundTrip {
    FountainDocument *doc = [self freshDoc];
    NSString *original = @"INT. X - DAY\n\nAction.\n\n[[compat]]";
    [doc readFromData:[self utf8:original] ofType:@"fountain" error:nil];

    NSTextView *tv = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 800, 600)];
    [tv setString:doc.pendingContent];
    doc.textView = tv;
    doc.pendingContent = nil;

    NSData *saved = [doc dataOfType:@"fountain" error:nil];
    NSString *recovered = [[NSString alloc] initWithData:saved encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(recovered, original);
}

- (void)test_midDocumentBoneyard_isNotStripped {
    // /* ... */ with non-whitespace text after the closing tag must NOT be stripped.
    FountainDocument *doc = [self freshDoc];
    NSString *text = @"INT. X - DAY\n\n/* note */\n\nAction after.";
    [doc readFromData:[self utf8:text] ofType:@"fountain" error:nil];
    XCTAssertNil(doc.trailingComment);
    XCTAssertEqualObjects(doc.pendingContent, text);
}

- (void)test_midDocumentComment_isNotStripped {
    FountainDocument *doc = [self freshDoc];
    NSString *text = @"INT. X - DAY\n\n[[note]]\n\nAction.";
    [doc readFromData:[self utf8:text] ofType:@"fountain" error:nil];
    XCTAssertNil(doc.trailingComment);
    XCTAssertEqualObjects(doc.pendingContent, text);
}

// ---------------------------------------------------------------------------
// Status bar helpers

- (FountainDocument *)docWithTextView:(NSString *)content {
    FountainDocument *doc = [self freshDoc];
    NSTextView *tv = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 800, 600)];
    [tv setString:content];
    doc.textView = tv;

    doc.fileLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
    doc.countsLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
    return doc;
}

// ---------------------------------------------------------------------------
// updateStatusBar

- (void)test_updateStatusBar_nilFileLabel_doesNotCrash {
    FountainDocument *doc = [self freshDoc];
    XCTAssertNoThrow([doc updateStatusBar]);
}

- (void)test_updateStatusBar_nilTextView_showsZeroCounts {
    FountainDocument *doc = [self freshDoc];
    doc.fileLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
    doc.countsLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
    [doc updateStatusBar];
    XCTAssertEqualObjects(doc.countsLabel.stringValue, @"0 words  0 chars");
}

- (void)test_updateStatusBar_countsMatchText {
    FountainDocument *doc = [self docWithTextView:@"Hello world"];
    [doc updateStatusBar];
    XCTAssertEqualObjects(doc.countsLabel.stringValue, @"2 words  11 chars");
}

- (void)test_updateStatusBar_largeCountsFormatWithComma {
    // 1000 repetitions of "a " = 1000 words, 2000 chars
    NSMutableString *s = [NSMutableString string];
    for (int i = 0; i < 1000; i++) [s appendString:@"a "];
    FountainDocument *doc = [self docWithTextView:s];
    [doc updateStatusBar];
    XCTAssertEqualObjects(doc.countsLabel.stringValue, @"1,000 words  2,000 chars");
}

- (void)test_updateStatusBar_untitledDocument_showsUntitled {
    FountainDocument *doc = [self docWithTextView:@""];
    [doc updateStatusBar];
    XCTAssertEqualObjects(doc.fileLabel.stringValue, @"Untitled");
}

- (void)test_updateStatusBar_withFileURL_showsAbbreviatedPath {
    FountainDocument *doc = [self docWithTextView:@""];
    NSString *home = NSHomeDirectory();
    doc.fileURL = [NSURL fileURLWithPath:[home stringByAppendingPathComponent:@"script.fountain"]];
    [doc updateStatusBar];
    XCTAssertEqualObjects(doc.fileLabel.stringValue, @"~/script.fountain");
}

// ---------------------------------------------------------------------------
// layoutStatusBar

- (void)test_layoutStatusBar_nilStatusBar_doesNotCrash {
    FountainDocument *doc = [self freshDoc];
    XCTAssertNoThrow([doc layoutStatusBar]);
}

- (void)test_layoutStatusBar_framesWithKnownWidth {
    FountainDocument *doc = [self freshDoc];

    NSView *statusBar = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 500, 22)];
    doc.statusBar = statusBar;

    NSTextField *fileLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
    NSTextField *countsLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
    NSButton *modeButton = [[NSButton alloc] initWithFrame:NSZeroRect];
    NSPopUpButton *fontSizePopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    NSView *separatorView = [[NSView alloc] initWithFrame:NSZeroRect];
    doc.fileLabel = fileLabel;
    doc.countsLabel = countsLabel;
    doc.modeButton = modeButton;
    doc.fontSizePopup = fontSizePopup;
    doc.separatorView = separatorView;
    [statusBar addSubview:fileLabel];
    [statusBar addSubview:countsLabel];
    [statusBar addSubview:modeButton];
    [statusBar addSubview:fontSizePopup];
    [statusBar addSubview:separatorView];

    [doc layoutStatusBar];

    // Constants from layoutStatusBar: pad=8, btnW=90, popW=62, cntW=185, labelH=15, H=22
    // btnX = 500 - 8 - 90 = 402
    // popX = 402 - 8 - 62 = 332
    // cntX = 332 - 8 - 185 = 139
    // fileW = 139 - 8 - 8 = 123
    // y = floor((22 - 15) / 2) = 3,  popY = floor((22 - 18) / 2) = 2
    XCTAssertEqual(NSMinX(modeButton.frame),    402.0);
    XCTAssertEqual(NSMinX(fontSizePopup.frame), 332.0);
    XCTAssertEqual(NSWidth(fontSizePopup.frame), 62.0);
    XCTAssertEqual(NSMinY(fontSizePopup.frame),   2.0);
    XCTAssertEqual(NSMinX(countsLabel.frame),   139.0);
    XCTAssertEqual(NSWidth(countsLabel.frame),  185.0);
    XCTAssertEqual(NSMinX(fileLabel.frame),       8.0);
    XCTAssertEqual(NSWidth(fileLabel.frame),    123.0);
    XCTAssertEqual(NSMinY(fileLabel.frame),       3.0);
    // separator: full width, 1pt tall, at top of bar
    XCTAssertEqual(NSWidth(separatorView.frame),  500.0);
    XCTAssertEqual(NSHeight(separatorView.frame), 1.0);
    XCTAssertEqual(NSMinY(separatorView.frame),   21.0);
}

@end
