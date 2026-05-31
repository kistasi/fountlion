#import <XCTest/XCTest.h>
#import <Cocoa/Cocoa.h>
#import "../FountainTextView.h"
#import "../FountainHighlighter.h"

// Expose private methods for testing without declaring them in the public header.
@interface FountainTextView (TestAccess)
- (BOOL)currentLineIsCharacterCue;
- (NSRange)rangeForUserCompletion;
@end

@interface FountainTextViewTests : XCTestCase
@property (strong) FountainTextView *textView;
@property (strong) FountainHighlighter *highlighter;
@end

@implementation FountainTextViewTests

- (void)setUp {
    [super setUp];
    self.textView = [[FountainTextView alloc] initWithFrame:NSMakeRect(0, 0, 800, 600)];
    self.highlighter = [[FountainHighlighter alloc] initWithTextView:self.textView];
    self.textView.highlighter = self.highlighter;
    self.textView.characterNamesProvider = ^NSArray *{ return @[@"ALICE", @"BOB", @"MARY"]; };
}

// ===========================================================================
// MARK: - currentLineIsCharacterCue
// ===========================================================================

- (void)test_currentLineIsCharacterCue_allCaps_returnsYES {
    [self.textView setString:@"JOHN"];
    [self.textView setSelectedRange:NSMakeRange(4, 0)];
    XCTAssertTrue([self.textView currentLineIsCharacterCue]);
}

- (void)test_currentLineIsCharacterCue_mixedCase_returnsNO {
    [self.textView setString:@"John"];
    [self.textView setSelectedRange:NSMakeRange(4, 0)];
    XCTAssertFalse([self.textView currentLineIsCharacterCue]);
}

- (void)test_currentLineIsCharacterCue_sceneHeadingINT_returnsNO {
    [self.textView setString:@"INT. OFFICE"];
    [self.textView setSelectedRange:NSMakeRange(11, 0)];
    XCTAssertFalse([self.textView currentLineIsCharacterCue]);
}

- (void)test_currentLineIsCharacterCue_sceneHeadingEXT_returnsNO {
    [self.textView setString:@"EXT. BEACH"];
    [self.textView setSelectedRange:NSMakeRange(10, 0)];
    XCTAssertFalse([self.textView currentLineIsCharacterCue]);
}

- (void)test_currentLineIsCharacterCue_transitionSuffix_returnsNO {
    [self.textView setString:@"CUT TO:"];
    [self.textView setSelectedRange:NSMakeRange(7, 0)];
    XCTAssertFalse([self.textView currentLineIsCharacterCue]);
}

- (void)test_currentLineIsCharacterCue_singleChar_returnsNO {
    // Line must be at least 2 characters.
    [self.textView setString:@"A"];
    [self.textView setSelectedRange:NSMakeRange(1, 0)];
    XCTAssertFalse([self.textView currentLineIsCharacterCue]);
}

- (void)test_currentLineIsCharacterCue_cursorOnSecondLine {
    // Only the current line (where the cursor sits) is evaluated.
    [self.textView setString:@"Action line.\nBOB"];
    [self.textView setSelectedRange:NSMakeRange(16, 0)];  // end of "BOB"
    XCTAssertTrue([self.textView currentLineIsCharacterCue]);
}

// ===========================================================================
// MARK: - completionsForPartialWordRange:
// ===========================================================================

- (void)test_completions_matchingPrefix {
    [self.textView setString:@"AL"];
    NSArray *completions = [self.textView completionsForPartialWordRange:NSMakeRange(0, 2)
                                                     indexOfSelectedItem:nil];
    XCTAssertTrue([completions containsObject:@"ALICE"]);
}

- (void)test_completions_multipleMatches {
    // "B" matches BOB; "M" matches MARY — set up a provider with both.
    self.textView.characterNamesProvider = ^NSArray *{ return @[@"BOB", @"BARBARA", @"MARY"]; };
    [self.textView setString:@"B"];
    NSArray *completions = [self.textView completionsForPartialWordRange:NSMakeRange(0, 1)
                                                     indexOfSelectedItem:nil];
    XCTAssertTrue([completions containsObject:@"BOB"]);
    XCTAssertTrue([completions containsObject:@"BARBARA"]);
    XCTAssertFalse([completions containsObject:@"MARY"]);
}

- (void)test_completions_noMatch_returnsEmpty {
    [self.textView setString:@"ZZ"];
    NSArray *completions = [self.textView completionsForPartialWordRange:NSMakeRange(0, 2)
                                                     indexOfSelectedItem:nil];
    XCTAssertEqual(completions.count, (NSUInteger)0);
}

- (void)test_completions_notFoundRange_returnsEmpty {
    NSArray *completions = [self.textView completionsForPartialWordRange:NSMakeRange(NSNotFound, 0)
                                                     indexOfSelectedItem:nil];
    XCTAssertEqual(completions.count, (NSUInteger)0);
}

- (void)test_completions_zeroLengthRange_returnsEmpty {
    [self.textView setString:@"AL"];
    NSArray *completions = [self.textView completionsForPartialWordRange:NSMakeRange(0, 0)
                                                     indexOfSelectedItem:nil];
    XCTAssertEqual(completions.count, (NSUInteger)0);
}

- (void)test_completions_doesNotMatchEqualLength {
    // A name exactly as long as the partial must not be returned (nothing to complete).
    [self.textView setString:@"BOB"];
    NSArray *completions = [self.textView completionsForPartialWordRange:NSMakeRange(0, 3)
                                                     indexOfSelectedItem:nil];
    XCTAssertFalse([completions containsObject:@"BOB"]);
}

// ===========================================================================
// MARK: - rangeForUserCompletion
// ===========================================================================

- (void)test_rangeForUserCompletion_singleLine {
    [self.textView setString:@"BOB"];
    [self.textView setSelectedRange:NSMakeRange(3, 0)];
    NSRange r = [self.textView rangeForUserCompletion];
    XCTAssertEqual(r.location, (NSUInteger)0);
    XCTAssertEqual(r.length, (NSUInteger)3);
}

- (void)test_rangeForUserCompletion_cursorMidLine {
    [self.textView setString:@"BO"];
    [self.textView setSelectedRange:NSMakeRange(2, 0)];
    NSRange r = [self.textView rangeForUserCompletion];
    XCTAssertEqual(r.location, (NSUInteger)0);
    XCTAssertEqual(r.length, (NSUInteger)2);
}

- (void)test_rangeForUserCompletion_secondLine {
    // Line 1 is 8 chars ("Action.\n"). Cursor is at offset 10 ("MA" → line 2 offset 2).
    [self.textView setString:@"Action.\nMA"];
    [self.textView setSelectedRange:NSMakeRange(10, 0)];
    NSRange r = [self.textView rangeForUserCompletion];
    XCTAssertEqual(r.location, (NSUInteger)8);
    XCTAssertEqual(r.length, (NSUInteger)2);
}

@end
