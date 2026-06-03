#import <XCTest/XCTest.h>
#import <Cocoa/Cocoa.h>
#import "../src/FountainHighlighter.h"

// Simple script used across multiple tests:
//   offset 0..17   "INT. OFFICE - DAY"  — Scene Heading (bold)
//   offset 18      "\n"
//   offset 19      "\n"                 — blank line
//   offset 20..23  "JOHN"               — Character (centered)
//   offset 24      "\n"
//   offset 25..31  "Hello."             — Dialogue (indented)
static NSString * const kScript = @"INT. OFFICE - DAY\n\nJOHN\nHello.";

@interface FountainHighlighterTests : XCTestCase
@property (strong) NSTextView *textView;
@property (strong) FountainHighlighter *highlighter;
@end

@implementation FountainHighlighterTests

- (void)setUp {
    [super setUp];
    self.textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 800, 600)];
    [self.textView setString:kScript];
    // initWithTextView: calls highlightAll immediately
    self.highlighter = [[FountainHighlighter alloc] initWithTextView:self.textView];
}

- (NSDictionary *)attrsAt:(NSUInteger)offset {
    return [self.textView.textStorage attributesAtIndex:offset effectiveRange:nil];
}

// ---------------------------------------------------------------------------

- (void)test_sceneHeading_isBold {
    NSFont *font = [self attrsAt:0][NSFontAttributeName];
    XCTAssertEqualObjects(font.fontName, @"Courier-Bold");
}

- (void)test_character_hasScreenplayIndent {
    // Character cues sit at 3.5" (252 pt) from the left edge of the page.
    NSParagraphStyle *p = [self attrsAt:20][NSParagraphStyleAttributeName];
    XCTAssertEqualWithAccuracy(p.headIndent, 252.0, 0.5);
}

- (void)test_dialogue_hasLeftIndent {
    NSParagraphStyle *p = [self attrsAt:25][NSParagraphStyleAttributeName];
    XCTAssertGreaterThan(p.headIndent, 0.0);
}

- (void)test_action_isRegularWeight {
    // An action line should use the plain (non-bold) Courier font.
    NSString *script = @"John walks to the window.";
    [self.textView setString:script];
    [self.highlighter highlightAll];
    NSFont *font = [self attrsAt:0][NSFontAttributeName];
    XCTAssertEqualObjects(font.fontName, @"Courier");
}

- (void)test_transition_isRightAligned {
    NSString *script = @"INT. X - DAY\n\nAction.\n\nCUT TO:";
    [self.textView setString:script];
    [self.highlighter highlightAll];
    // "CUT TO:" starts at offset 24
    NSUInteger offset = [script rangeOfString:@"CUT TO:"].location;
    NSParagraphStyle *p = [self attrsAt:offset][NSParagraphStyleAttributeName];
    XCTAssertEqual(p.alignment, NSRightTextAlignment);
}

- (void)test_sectionHeading_isDarkBlue {
    NSString *script = @"# ACT ONE";
    [self.textView setString:script];
    [self.highlighter highlightAll];
    NSColor *color = [self attrsAt:0][NSForegroundColorAttributeName];
    // Section headings use a dark blue; blue component should dominate
    NSColor *rgb = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    XCTAssertGreaterThan(rgb.blueComponent, rgb.redComponent);
}

- (void)test_emptyDocument_doesNotCrash {
    [self.textView setString:@""];
    XCTAssertNoThrow([self.highlighter highlightAll]);
}

- (void)test_highlightAll_coveresFullLength {
    // After highlighting, every character should have a font attribute.
    NSTextStorage *ts = self.textView.textStorage;
    NSUInteger len = ts.length;
    NSUInteger idx = 0;
    while (idx < len) {
        NSRange effective;
        NSDictionary *attrs = [ts attributesAtIndex:idx effectiveRange:&effective];
        XCTAssertNotNil(attrs[NSFontAttributeName],
                        @"No font attribute at index %lu", (unsigned long)idx);
        idx = NSMaxRange(effective);
    }
}

- (void)test_synopsis_isGrayAndItalic {
    NSString *script = @"= The hero arrives.";
    [self.textView setString:script];
    [self.highlighter highlightAll];
    NSDictionary *attrs = [self attrsAt:0];
    NSFont *font = attrs[NSFontAttributeName];
    NSColor *color = [attrs[NSForegroundColorAttributeName]
                        colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    // Synopsis uses the oblique (italic) font — name contains "Oblique" or falls back to regular.
    BOOL isOblique = [font.fontName rangeOfString:@"Oblique"
                                          options:NSCaseInsensitiveSearch].location != NSNotFound;
    XCTAssertTrue(isOblique, @"Synopsis font should be oblique, got %@", font.fontName);
    // Color should be gray: R ≈ G ≈ B and not black (0,0,0).
    XCTAssertGreaterThan(color.redComponent, 0.3);
    XCTAssertEqualWithAccuracy(color.redComponent, color.blueComponent, 0.1);
}

- (void)test_comment_isGray {
    NSString *script = @"INT. X - DAY\n\n[[A note here]]";
    [self.textView setString:script];
    [self.highlighter highlightAll];
    NSUInteger offset = [script rangeOfString:@"[[A note here]]"].location;
    NSColor *color = [[self attrsAt:offset][NSForegroundColorAttributeName]
                        colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    // Gray: all components roughly equal and not black.
    XCTAssertGreaterThan(color.redComponent, 0.3);
    XCTAssertEqualWithAccuracy(color.redComponent, color.blueComponent, 0.1);
}

- (void)test_parenthetical_hasCorrectIndent {
    // Parenthetical left margin is 3.0" = 216 pt.
    NSString *script = @"INT. X - DAY\n\nJOHN\n(quietly)\nShhh.";
    [self.textView setString:script];
    [self.highlighter highlightAll];
    NSUInteger offset = [script rangeOfString:@"(quietly)"].location;
    NSParagraphStyle *p = [self attrsAt:offset][NSParagraphStyleAttributeName];
    XCTAssertEqualWithAccuracy(p.headIndent, 216.0, 0.5);
}

- (void)test_characterNames_populatedAfterHighlight {
    NSString *script = @"INT. X - DAY\n\nJOHN\nHello.\n\nMARY\nHi.";
    [self.textView setString:script];
    [self.highlighter highlightAll];
    NSArray *names = self.highlighter.characterNames;
    XCTAssertTrue([names containsObject:@"JOHN"]);
    XCTAssertTrue([names containsObject:@"MARY"]);
}

- (void)test_characterNames_stripsVOExtension {
    NSString *script = @"INT. X - DAY\n\nEDWARD (V.O.)\nNarration.";
    [self.textView setString:script];
    [self.highlighter highlightAll];
    XCTAssertTrue([self.highlighter.characterNames containsObject:@"EDWARD"]);
    XCTAssertFalse([self.highlighter.characterNames containsObject:@"EDWARD (V.O.)"]);
}

- (void)test_characterNames_isSorted {
    NSString *script = @"INT. X - DAY\n\nZOE\nHi.\n\nALICE\nHello.";
    [self.textView setString:script];
    [self.highlighter highlightAll];
    NSArray *names = self.highlighter.characterNames;
    XCTAssertEqualObjects(names, [names sortedArrayUsingSelector:@selector(compare:)]);
}

- (void)test_elementTypeAtCharOffset_character {
    [self.textView setString:kScript];
    [self.highlighter highlightAll];
    // "JOHN" starts at offset 20
    NSString *type = [self.highlighter elementTypeAtCharOffset:20];
    XCTAssertEqualObjects(type, @"Character");
}

- (void)test_elementTypeAtCharOffset_dialogue {
    [self.textView setString:kScript];
    [self.highlighter highlightAll];
    // "Hello." starts at offset 25
    NSString *type = [self.highlighter elementTypeAtCharOffset:25];
    XCTAssertEqualObjects(type, @"Dialogue");
}

- (void)test_elementTypeAtCharOffset_action {
    NSString *script = @"John walks in.";
    [self.textView setString:script];
    [self.highlighter highlightAll];
    NSString *type = [self.highlighter elementTypeAtCharOffset:0];
    XCTAssertEqualObjects(type, @"Action");
}

- (void)test_elementTypeAtCharOffset_parenthetical {
    NSString *script = @"INT. X - DAY\n\nJOHN\n(quietly)\nShhh.";
    [self.textView setString:script];
    [self.highlighter highlightAll];
    // Pass an offset inside the parenthetical word itself (not at its very start, since
    // NSTextStorage extends paragraph style attributes to the paragraph separator so the
    // '\n' preceding "(quietly)" inherits the Character style).
    NSUInteger offset = [script rangeOfString:@"quietly"].location;
    NSString *type = [self.highlighter elementTypeAtCharOffset:offset];
    XCTAssertEqualObjects(type, @"Parenthetical");
}

- (void)test_sceneHeadingRanges_populatedAfterHighlight {
    // kScript: "INT. OFFICE - DAY" at offset 0, length 17
    [self.textView setString:kScript];
    [self.highlighter highlightAll];
    NSArray *ranges = self.highlighter.sceneHeadingRanges;
    XCTAssertEqual(ranges.count, (NSUInteger)1);
    NSRange r = [[ranges firstObject] rangeValue];
    XCTAssertEqual(r.location, (NSUInteger)0);
    XCTAssertEqual(r.length, [@"INT. OFFICE - DAY" length]);
}

- (void)test_sceneHeadingRanges_emptyWhenNoSceneHeadings {
    [self.textView setString:@"Just an action line."];
    [self.highlighter highlightAll];
    XCTAssertEqual(self.highlighter.sceneHeadingRanges.count, (NSUInteger)0);
}

- (void)test_sceneHeadingRanges_multipleScenes {
    NSString *script = @"INT. A - DAY\n\nAction.\n\nEXT. B - NIGHT\n\nMore action.";
    [self.textView setString:script];
    [self.highlighter highlightAll];
    XCTAssertEqual(self.highlighter.sceneHeadingRanges.count, (NSUInteger)2);
}

- (void)test_setContainerWidth_rebuildsCharacterIndent {
    // Default containerWidth=612 → floor(612 * 252/612) = 252
    NSParagraphStyle *p1 = [self.highlighter attrsForType:@"Character" centered:NO][NSParagraphStyleAttributeName];
    XCTAssertEqualWithAccuracy(p1.headIndent, 252.0, 0.5);

    // New width 1000 → floor(1000 * 252/612) = 411
    self.highlighter.containerWidth = 1000.0;
    NSParagraphStyle *p2 = [self.highlighter attrsForType:@"Character" centered:NO][NSParagraphStyleAttributeName];
    XCTAssertEqualWithAccuracy(p2.headIndent, 411.0, 0.5);
}

- (void)test_setFontSize_rebuildsFontToNewSize {
    self.highlighter.fontSize = 18.0;
    NSFont *font = [self.highlighter attrsForType:@"Action" centered:NO][NSFontAttributeName];
    XCTAssertEqualWithAccuracy(font.pointSize, 18.0, 0.01);
}

- (void)test_setFontSize_noChangeSkipsRebuild {
    // Setting the same size should not crash and leave things unchanged.
    CGFloat original = self.highlighter.fontSize;
    XCTAssertNoThrow(self.highlighter.fontSize = original);
    NSFont *font = [self.highlighter attrsForType:@"Action" centered:NO][NSFontAttributeName];
    XCTAssertEqualWithAccuracy(font.pointSize, original, 0.01);
}

- (void)test_darkMode_sectionHeading_colorChanges {
    NSString *script = @"# ACT ONE";
    [self.textView setString:script];
    [self.highlighter highlightAll];
    NSColor *lightColor = [[self attrsAt:0][NSForegroundColorAttributeName]
                            colorUsingColorSpaceName:NSCalibratedRGBColorSpace];

    self.highlighter.darkMode = YES;
    NSColor *darkColor = [[self attrsAt:0][NSForegroundColorAttributeName]
                            colorUsingColorSpaceName:NSCalibratedRGBColorSpace];

    // Both modes use a blue accent, but dark mode has a much brighter blue component.
    XCTAssertGreaterThan(lightColor.blueComponent, lightColor.greenComponent,
                         @"Light accent should be blue-dominant");
    XCTAssertGreaterThan(darkColor.blueComponent, lightColor.blueComponent,
                         @"Dark mode accent should be a brighter blue than light mode");
}

@end
