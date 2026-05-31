#import <XCTest/XCTest.h>
#import "../src/vendor/FastFountainParser.h"
#import "../src/vendor/FNElement.h"

// ---------------------------------------------------------------------------
// Helpers

@interface FastFountainParserTests : XCTestCase
@end

@implementation FastFountainParserTests

- (NSArray *)parse:(NSString *)s {
    return [[FastFountainParser alloc] initWithString:s].elements;
}

- (FNElement *)first:(NSString *)s {
    return (FNElement *)[[self parse:s] firstObject];
}

- (FNElement *)last:(NSString *)s {
    return (FNElement *)[[self parse:s] lastObject];
}

// Returns an array of elementType strings, for compact sequence assertions.
- (NSArray *)typesOf:(NSArray *)els {
    NSMutableArray *t = [NSMutableArray arrayWithCapacity:els.count];
    for (FNElement *el in els) [t addObject:el.elementType];
    return t;
}

// ===========================================================================
// MARK: - Scene Heading
// ===========================================================================

- (void)test_sceneHeading_INT {
    XCTAssertEqualObjects([self first:@"INT. OFFICE - DAY"].elementType, @"Scene Heading");
}

- (void)test_sceneHeading_EXT {
    XCTAssertEqualObjects([self first:@"EXT. BEACH - SUNSET"].elementType, @"Scene Heading");
}

- (void)test_sceneHeading_EST {
    XCTAssertEqualObjects([self first:@"EST. HARBOR - DAWN"].elementType, @"Scene Heading");
}

- (void)test_sceneHeading_INT_EXT_slash {
    XCTAssertEqualObjects([self first:@"INT./EXT. CAR - MOVING"].elementType, @"Scene Heading");
}

- (void)test_sceneHeading_caseInsensitive {
    XCTAssertEqualObjects([self first:@"int. office - day"].elementType, @"Scene Heading");
}

- (void)test_sceneHeading_requiresBlankLineBefore {
    // An INT. line immediately after another line (no blank) must NOT become a scene heading.
    NSArray *els = [self parse:@"Some action.\nINT. OFFICE - DAY"];
    // The two lines merge into a single Action element.
    XCTAssertEqual(els.count, (NSUInteger)1);
    XCTAssertEqualObjects(((FNElement *)els[0]).elementType, @"Action");
}

- (void)test_sceneHeading_withBlankBefore {
    NSArray *els = [self parse:@"Some action.\n\nINT. OFFICE - DAY"];
    XCTAssertEqualObjects(((FNElement *)els[1]).elementType, @"Scene Heading");
}

- (void)test_sceneHeading_elementText_preserved {
    FNElement *el = [self first:@"INT. WILL'S BEDROOM - NIGHT (1973)"];
    XCTAssertEqualObjects(el.elementText, @"INT. WILL'S BEDROOM - NIGHT (1973)");
}

- (void)test_sceneHeading_sceneNumber_extracted {
    FNElement *el = [self first:@"INT. OFFICE - DAY #42#"];
    XCTAssertEqualObjects(el.elementType, @"Scene Heading");
    XCTAssertEqualObjects(el.sceneNumber, @"42");
}

- (void)test_sceneHeading_noSceneNumber_isNil {
    XCTAssertNil([self first:@"INT. OFFICE - DAY"].sceneNumber);
}

// Forced scene heading

- (void)test_forcedSceneHeading_dotPrefix {
    FNElement *el = [self first:@".BASEMENT STAIRWELL"];
    XCTAssertEqualObjects(el.elementType, @"Scene Heading");
    XCTAssertEqualObjects(el.elementText, @"BASEMENT STAIRWELL");
}

- (void)test_forcedSceneHeading_doesNotRequireBlankBefore {
    NSArray *els = [self parse:@"Action line.\n.FORCED HEADING"];
    XCTAssertEqualObjects(((FNElement *)els.lastObject).elementType, @"Scene Heading");
}

- (void)test_forcedSceneHeading_withSceneNumber {
    FNElement *el = [self first:@".OFFICE #7#"];
    XCTAssertEqualObjects(el.elementType, @"Scene Heading");
    XCTAssertEqualObjects(el.sceneNumber, @"7");
    XCTAssertEqualObjects(el.elementText, @"OFFICE");
}

- (void)test_dotDot_isNotForcedSceneHeading {
    // ".." must not be treated as a forced scene heading.
    // Need trailing content so the all-caps line isn't classified as Character
    // via the end-of-doc heuristic.
    NSArray *els = [self parse:@"..ELLIPSIS LINE\n\nAction follows."];
    XCTAssertNotEqualObjects(((FNElement *)els[0]).elementType, @"Scene Heading");
}

// ===========================================================================
// MARK: - Action
// ===========================================================================

- (void)test_action_defaultMixedCase {
    XCTAssertEqualObjects([self first:@"John walks to the door."].elementType, @"Action");
}

- (void)test_action_forced_bangPrefix {
    FNElement *el = [self first:@"!UPPER CASE BUT FORCED ACTION"];
    XCTAssertEqualObjects(el.elementType, @"Action");
    XCTAssertEqualObjects(el.elementText, @"!UPPER CASE BUT FORCED ACTION");
}

- (void)test_action_adjacentLinesMergedIntoOne {
    // Two consecutive action lines with no blank between become a single element.
    NSArray *els = [self parse:@"Line one.\nLine two."];
    XCTAssertEqual(els.count, (NSUInteger)1);
    XCTAssertEqualObjects(((FNElement *)els[0]).elementType, @"Action");
    XCTAssertEqualObjects(((FNElement *)els[0]).elementText, @"Line one.\nLine two.");
}

- (void)test_action_blankLineSeparatesElements {
    NSArray *els = [self parse:@"First paragraph.\n\nSecond paragraph."];
    XCTAssertEqual(els.count, (NSUInteger)2);
    XCTAssertEqualObjects(((FNElement *)els[0]).elementType, @"Action");
    XCTAssertEqualObjects(((FNElement *)els[1]).elementType, @"Action");
}

- (void)test_action_uppercaseSurroundedByBlanks {
    // All-caps line with a blank before AND after must be Action, not Character.
    // This was the "A RIVER." bug caused by the stale index lookahead.
    NSArray *els = [self parse:@"A RIVER.\n\nWe're underwater."];
    XCTAssertEqualObjects(((FNElement *)els[0]).elementType, @"Action");
}

- (void)test_action_uppercaseMidScript {
    // Uppercase scene-description line deep in a script must also be Action.
    NSArray *els = [self parse:@"INT. OFFICE - DAY\n\nON JOHN AND MARY\n\nJOHN\nHello."];
    XCTAssertEqualObjects(((FNElement *)els[1]).elementType, @"Action");  // ON JOHN AND MARY
}

- (void)test_action_isNotCenteredByDefault {
    XCTAssertFalse([self first:@"John walks in."].isCentered);
}

// ===========================================================================
// MARK: - Character
// ===========================================================================

- (void)test_character_simpleUppercase {
    NSArray *els = [self parse:@"INT. X - DAY\n\nJOHN\nHello."];
    FNElement *el = (FNElement *)els[1];
    XCTAssertEqualObjects(el.elementType, @"Character");
    XCTAssertEqualObjects(el.elementText, @"JOHN");
}

- (void)test_character_withVOExtension {
    NSArray *els = [self parse:@"INT. X - DAY\n\nEDWARD (V.O.)\nNarration."];
    XCTAssertEqualObjects(((FNElement *)els[1]).elementType, @"Character");
    XCTAssertEqualObjects(((FNElement *)els[1]).elementText, @"EDWARD (V.O.)");
}

- (void)test_character_withContdExtension {
    NSArray *els = [self parse:@"INT. X - DAY\n\nEDWARD (CONT'D)\nMore."];
    XCTAssertEqualObjects(((FNElement *)els[1]).elementType, @"Character");
}

- (void)test_character_withVOContd {
    NSArray *els = [self parse:@"INT. X - DAY\n\nEDWARD (V.O.)(CONT'D)\nMore."];
    XCTAssertEqualObjects(((FNElement *)els[1]).elementType, @"Character");
}

- (void)test_character_requiresBlankLineBefore {
    // No blank before → merges into the previous action, not a character.
    NSArray *els = [self parse:@"Some action.\nJOHN"];
    XCTAssertEqual(els.count, (NSUInteger)1);
    XCTAssertEqualObjects(((FNElement *)els[0]).elementType, @"Action");
}

- (void)test_character_followedByBlankIsAction {
    // Uppercase line with a blank AFTER it AND more content following → Action.
    NSArray *els = [self parse:@"INT. X - DAY\n\nNOT A CHARACTER\n\nAction follows."];
    XCTAssertEqualObjects(((FNElement *)els[1]).elementType, @"Action");
}

- (void)test_character_atEndOfDoc_isCharacter {
    // A lone character name at the end of the document (user still typing)
    // must stay Character, not fall through to Action.
    NSArray *els = [self parse:@"INT. OFFICE - DAY\n\nJOHN"];
    XCTAssertEqualObjects(((FNElement *)els.lastObject).elementType, @"Character");
}

- (void)test_character_forced_atSign {
    // '@' forces a character even when the text contains lowercase letters.
    NSArray *els = [self parse:@"INT. X - DAY\n\n@mcTavish\nHello."];
    XCTAssertEqualObjects(((FNElement *)els[1]).elementType, @"Character");
    XCTAssertEqualObjects(((FNElement *)els[1]).elementText, @"@mcTavish");
}

// ===========================================================================
// MARK: - Dialogue
// ===========================================================================

- (void)test_dialogue_followsCharacter {
    NSArray *els = [self parse:@"INT. X - DAY\n\nJOHN\nHello there."];
    XCTAssertEqualObjects(((FNElement *)els[2]).elementType, @"Dialogue");
    XCTAssertEqualObjects(((FNElement *)els[2]).elementText, @"Hello there.");
}

- (void)test_dialogue_multipleLinesMerged {
    // Two dialogue lines with no blank between → single Dialogue element with \n.
    NSArray *els = [self parse:@"INT. X - DAY\n\nJOHN\nLine one.\nLine two."];
    FNElement *dlg = (FNElement *)els.lastObject;
    XCTAssertEqualObjects(dlg.elementType, @"Dialogue");
    XCTAssertEqualObjects(dlg.elementText, @"Line one.\nLine two.");
}

- (void)test_dialogue_blankLineEndsBlock {
    // A blank line ends the dialogue block; the next uppercase line is a new character.
    NSArray *els = [self parse:@"INT. X - DAY\n\nJOHN\nHello.\n\nMARY\nHi."];
    XCTAssertEqualObjects([self typesOf:els],
        (@[@"Scene Heading", @"Character", @"Dialogue", @"Character", @"Dialogue"]));
}

- (void)test_dialogue_mixedCaseLineInsideBlock {
    // A mixed-case line inside a dialogue block is Dialogue, not Action.
    NSArray *els = [self parse:@"INT. X - DAY\n\nJOHN\nThis is my line."];
    XCTAssertEqualObjects(((FNElement *)els[2]).elementType, @"Dialogue");
}

// ===========================================================================
// MARK: - Parenthetical
// ===========================================================================

- (void)test_parenthetical_betweenCharacterAndDialogue {
    NSArray *els = [self parse:@"INT. X - DAY\n\nJOHN\n(quietly)\nShhh."];
    XCTAssertEqualObjects(((FNElement *)els[2]).elementType, @"Parenthetical");
    XCTAssertEqualObjects(((FNElement *)els[2]).elementText, @"(quietly)");
    XCTAssertEqualObjects(((FNElement *)els[3]).elementType, @"Dialogue");
}

- (void)test_parenthetical_betweenTwoDialogueLines {
    NSArray *els = [self parse:@"INT. X - DAY\n\nJOHN\nFirst line.\n(beat)\nSecond line."];
    XCTAssertEqualObjects([self typesOf:els],
        (@[@"Scene Heading", @"Character", @"Dialogue", @"Parenthetical", @"Dialogue"]));
}

- (void)test_parenthetical_elementText {
    NSArray *els = [self parse:@"INT. X - DAY\n\nJOHN\n(low but insistent)\nStop."];
    XCTAssertEqualObjects(((FNElement *)els[2]).elementText, @"(low but insistent)");
}

// ===========================================================================
// MARK: - Transition
// ===========================================================================

- (void)test_transition_CUT_TO {
    NSArray *els = [self parse:@"INT. X - DAY\n\nAction.\n\nCUT TO:"];
    XCTAssertEqualObjects(((FNElement *)els.lastObject).elementType, @"Transition");
}

- (void)test_transition_SMASH_CUT_TO {
    NSArray *els = [self parse:@"Action.\n\nSMASH CUT TO:"];
    XCTAssertEqualObjects(((FNElement *)els.lastObject).elementType, @"Transition");
}

- (void)test_transition_FADE_OUT {
    NSArray *els = [self parse:@"INT. X - DAY\n\nAction.\n\nFADE OUT."];
    XCTAssertEqualObjects(((FNElement *)els.lastObject).elementType, @"Transition");
}

- (void)test_transition_CUT_TO_BLACK {
    NSArray *els = [self parse:@"Action.\n\nCUT TO BLACK."];
    XCTAssertEqualObjects(((FNElement *)els.lastObject).elementType, @"Transition");
}

- (void)test_transition_FADE_TO_BLACK {
    NSArray *els = [self parse:@"Action.\n\nFADE TO BLACK."];
    XCTAssertEqualObjects(((FNElement *)els.lastObject).elementType, @"Transition");
}

- (void)test_transition_forced_greaterThan {
    // ">" forces a transition. Use a form that doesn't end in "TO:" — otherwise
    // the [^a-z]*TO:$ branch runs first (it has no preconditions) and absorbs it,
    // leaving the ">" in elementText.
    NSArray *els = [self parse:@"Action.\n\n> SMASH CUT:"];
    XCTAssertEqualObjects(((FNElement *)els.lastObject).elementType, @"Transition");
    XCTAssertEqualObjects(((FNElement *)els.lastObject).elementText, @"SMASH CUT:");
}

// ===========================================================================
// MARK: - Centered Action
// ===========================================================================

- (void)test_centeredAction_greaterThanLessThan {
    NSArray *els = [self parse:@"> THE END <"];
    FNElement *el = (FNElement *)els.lastObject;
    XCTAssertEqualObjects(el.elementType, @"Action");
    XCTAssertTrue(el.isCentered);
    XCTAssertEqualObjects(el.elementText, @"THE END");
}

- (void)test_centeredAction_stripsAngleBrackets {
    FNElement *el = (FNElement *)[[self parse:@"> A RIVER. <"] lastObject];
    XCTAssertEqualObjects(el.elementText, @"A RIVER.");
}

// ===========================================================================
// MARK: - Section Heading
// ===========================================================================

- (void)test_sectionHeading_depth1 {
    FNElement *el = [self first:@"# ACT ONE"];
    XCTAssertEqualObjects(el.elementType, @"Section Heading");
    XCTAssertEqual(el.sectionDepth, (NSUInteger)1);
}

- (void)test_sectionHeading_depth2 {
    FNElement *el = [self first:@"## Scene 1"];
    XCTAssertEqualObjects(el.elementType, @"Section Heading");
    XCTAssertEqual(el.sectionDepth, (NSUInteger)2);
}

- (void)test_sectionHeading_depth3 {
    FNElement *el = [self first:@"### Beat"];
    XCTAssertEqualObjects(el.elementType, @"Section Heading");
    XCTAssertEqual(el.sectionDepth, (NSUInteger)3);
}

- (void)test_sectionHeading_textStripsLeadingHashes {
    // The returned elementText still has the space after ##.
    FNElement *el = [self first:@"## Scene 1"];
    XCTAssertEqualObjects(el.elementText, @" Scene 1");
}

- (void)test_sectionHeadings_doNotRequireBlankBefore {
    NSArray *els = [self parse:@"# ACT ONE\n## Scene 1\nAction."];
    XCTAssertEqualObjects(((FNElement *)els[0]).elementType, @"Section Heading");
    XCTAssertEqualObjects(((FNElement *)els[1]).elementType, @"Section Heading");
}

// ===========================================================================
// MARK: - Synopsis
// ===========================================================================

- (void)test_synopsis_equalPrefix {
    XCTAssertEqualObjects([self first:@"= The hero arrives."].elementType, @"Synopsis");
}

- (void)test_synopsis_textStripsLeadingEqual {
    // The leading "=" is replaced with ""; the space after it remains.
    FNElement *el = [self first:@"= The hero arrives."];
    XCTAssertEqualObjects(el.elementText, @" The hero arrives.");
}

// ===========================================================================
// MARK: - Comment / Note
// ===========================================================================

- (void)test_comment_doubleSquareBrackets {
    NSArray *els = [self parse:@"INT. X - DAY\n\n[[This is a note]]"];
    XCTAssertEqualObjects(((FNElement *)els.lastObject).elementType, @"Comment");
    XCTAssertEqualObjects(((FNElement *)els.lastObject).elementText, @"This is a note");
}

- (void)test_comment_requiresBlankBefore {
    // [[...]] without a preceding blank line merges into the previous action element.
    NSArray *els = [self parse:@"Action line.\n[[Not a comment yet]]"];
    XCTAssertEqual(els.count, (NSUInteger)1);
    XCTAssertEqualObjects(((FNElement *)els[0]).elementType, @"Action");
}

// ===========================================================================
// MARK: - Page Break
// ===========================================================================

- (void)test_pageBreak_threeEquals {
    XCTAssertEqualObjects([self first:@"==="].elementType, @"Page Break");
}

- (void)test_pageBreak_fourEquals {
    XCTAssertEqualObjects([self first:@"===="].elementType, @"Page Break");
}

- (void)test_singleEqual_isSynopsis_notPageBreak {
    XCTAssertEqualObjects([self first:@"= synopsis"].elementType, @"Synopsis");
}

// ===========================================================================
// MARK: - Lyrics
// ===========================================================================

- (void)test_lyrics_tildePrefix {
    XCTAssertEqualObjects([self first:@"~Happy birthday to you"].elementType, @"Lyrics");
}

- (void)test_lyrics_adjacentLinesAreMultipleElements {
    NSArray *els = [self parse:@"~Line one\n~Line two"];
    XCTAssertEqual(els.count, (NSUInteger)2);
    XCTAssertEqualObjects(((FNElement *)els[0]).elementType, @"Lyrics");
    XCTAssertEqualObjects(((FNElement *)els[1]).elementType, @"Lyrics");
}

- (void)test_lyrics_blankBetweenGroupsInsertsSpacerElement {
    // A blank line between two lyric groups inserts a spacer Lyrics(" ") element.
    NSArray *els = [self parse:@"~Verse one\n\n~Verse two"];
    BOOL hasSpacerLyrics = NO;
    for (FNElement *el in els) {
        if ([el.elementType isEqualToString:@"Lyrics"] && [el.elementText isEqualToString:@" "])
            hasSpacerLyrics = YES;
    }
    XCTAssertTrue(hasSpacerLyrics);
}

// ===========================================================================
// MARK: - Boneyard
// ===========================================================================

- (void)test_boneyard_singleLine {
    XCTAssertEqualObjects([self first:@"/* Cut for time */"].elementType, @"Boneyard");
}

- (void)test_boneyard_multiLine {
    NSArray *els = [self parse:@"/*\nThis scene was cut.\nAll of it.\n*/"];
    XCTAssertEqualObjects(((FNElement *)els.lastObject).elementType, @"Boneyard");
}

// ===========================================================================
// MARK: - Dual Dialogue
// ===========================================================================

- (void)test_dualDialogue_caretMarksSecondCharacter {
    NSArray *els = [self parse:@"INT. X - DAY\n\nJOHN\nHi.\n\nJANE ^\nHey."];
    FNElement *jane = nil;
    for (FNElement *el in els)
        if ([el.elementType isEqualToString:@"Character"] && [el.elementText isEqualToString:@"JANE"])
            jane = el;
    XCTAssertNotNil(jane);
    XCTAssertTrue(jane.isDualDialogue);
}

- (void)test_dualDialogue_firstCharacterAlsoFlagged {
    NSArray *els = [self parse:@"INT. X - DAY\n\nJOHN\nHi.\n\nJANE ^\nHey."];
    FNElement *john = nil;
    for (FNElement *el in els)
        if ([el.elementType isEqualToString:@"Character"] && [el.elementText isEqualToString:@"JOHN"])
            john = el;
    XCTAssertNotNil(john);
    XCTAssertTrue(john.isDualDialogue);
}

- (void)test_dualDialogue_caretStrippedFromText {
    NSArray *els = [self parse:@"INT. X - DAY\n\nJOHN\nHi.\n\nJANE ^\nHey."];
    for (FNElement *el in els)
        if ([el.elementType isEqualToString:@"Character"])
            XCTAssertFalse([el.elementText containsString:@"^"],
                           @"^ should be stripped from elementText");
}

- (void)test_nonDualDialogue_isDualDialogueFalse {
    NSArray *els = [self parse:@"INT. X - DAY\n\nJOHN\nHi."];
    for (FNElement *el in els)
        XCTAssertFalse(el.isDualDialogue);
}

// ===========================================================================
// MARK: - Title Page
// ===========================================================================

- (void)test_titlePage_inlineKeyValue {
    FastFountainParser *p = [[FastFountainParser alloc] initWithString:@"Title: Big Fish\n\nAction."];
    XCTAssertEqual(p.titlePage.count, (NSUInteger)1);
    XCTAssertEqualObjects(p.titlePage[0][@"title"], @[@"Big Fish"]);
}

- (void)test_titlePage_authorNormalizedToAuthors {
    FastFountainParser *p = [[FastFountainParser alloc] initWithString:@"Author: Jane Doe\n\nAction."];
    NSDictionary *entry = p.titlePage[0];
    XCTAssertNotNil(entry[@"authors"], @"'author' key should be normalized to 'authors'");
    XCTAssertNil(entry[@"author"]);
}

- (void)test_titlePage_multipleKeys {
    FastFountainParser *p = [[FastFountainParser alloc]
        initWithString:@"Title: My Film\nAuthor: Jane Doe\n\nAction."];
    NSMutableDictionary *merged = [NSMutableDictionary dictionary];
    for (NSDictionary *d in p.titlePage) [merged addEntriesFromDictionary:d];
    XCTAssertNotNil(merged[@"title"]);
    XCTAssertNotNil(merged[@"authors"]);
}

- (void)test_titlePage_strippedFromElements {
    // Title page lines must NOT appear in the elements array.
    FastFountainParser *p = [[FastFountainParser alloc]
        initWithString:@"Title: Big Fish\n\nThis is a Southern story."];
    XCTAssertEqual(p.elements.count, (NSUInteger)1);
    XCTAssertEqualObjects(((FNElement *)p.elements[0]).elementType, @"Action");
}

- (void)test_titlePage_lineCount_singleLine {
    FastFountainParser *p = [[FastFountainParser alloc]
        initWithString:@"Title: Big Fish\n\nBody line."];
    // 1 title page line + 1 blank separator
    XCTAssertEqual(p.titlePageLineCount, (NSUInteger)2);
}

- (void)test_titlePage_lineCount_multipleLines {
    FastFountainParser *p = [[FastFountainParser alloc]
        initWithString:@"Title: My Film\nAuthor: Jane\nCredit: written by\n\nBody."];
    // 3 title page lines + 1 blank separator
    XCTAssertEqual(p.titlePageLineCount, (NSUInteger)4);
}

- (void)test_titlePage_lineCount_zeroWithoutTitlePage {
    FastFountainParser *p = [[FastFountainParser alloc]
        initWithString:@"INT. OFFICE - DAY\n\nJOHN\nHello."];
    XCTAssertEqual(p.titlePageLineCount, (NSUInteger)0);
}

- (void)test_titlePage_emptyArrayWithoutTitlePage {
    FastFountainParser *p = [[FastFountainParser alloc] initWithString:@"Action line."];
    XCTAssertEqual(p.titlePage.count, (NSUInteger)0);
}

// ===========================================================================
// MARK: - Multi-element / integration
// ===========================================================================

- (void)test_fullScript_elementSequence {
    NSString *script =
        @"INT. OFFICE - DAY\n"
         "\n"
         "ALICE\n"
         "(whispering)\n"
         "Can you hear me?\n"
         "\n"
         "BOB\n"
         "Loud and clear.\n"
         "\n"
         "CUT TO:";

    NSArray *els = [self parse:script];
    XCTAssertEqualObjects([self typesOf:els],
        (@[@"Scene Heading",
           @"Character", @"Parenthetical", @"Dialogue",
           @"Character", @"Dialogue",
           @"Transition"]));
}

- (void)test_bigFishOpeningSequence {
    // Mirrors the opening of Big-Fish.fountain through the first dialogue block.
    NSString *script =
        @"Title: Big Fish\n"
         "Author: John August\n"
         "\n"
         "This is a Southern story.\n"
         "\n"
         "====\n"
         "\n"
         "A RIVER.\n"
         "\n"
         "We're underwater.\n"
         "\n"
         "EDWARD (V.O.)\n"
         "There are some fish.";

    FastFountainParser *p = [[FastFountainParser alloc] initWithString:script];
    XCTAssertEqualObjects([self typesOf:p.elements],
        (@[@"Action",       // This is a Southern story.
           @"Page Break",   // ====
           @"Action",       // A RIVER.
           @"Action",       // We're underwater.
           @"Character",    // EDWARD (V.O.)
           @"Dialogue"]));  // There are some fish.
    XCTAssertGreaterThan(p.titlePageLineCount, (NSUInteger)0);
}

- (void)test_sceneWithTwoDialogueBlocks {
    NSString *script =
        @"INT. CAMPFIRE - NIGHT\n"
         "\n"
         "EDWARD\n"
         "Now, I'd tried everything.\n"
         "\n"
         "LITTLE BRAVE\n"
         "(confused)\n"
         "Your finger?\n"
         "\n"
         "EDWARD\n"
         "Gold.";

    XCTAssertEqualObjects([self typesOf:[self parse:script]],
        (@[@"Scene Heading",
           @"Character", @"Dialogue",
           @"Character", @"Parenthetical", @"Dialogue",
           @"Character", @"Dialogue"]));
}

- (void)test_multipleScenes {
    NSString *script =
        @"INT. BEDROOM - NIGHT\n"
         "\n"
         "Action.\n"
         "\n"
         "EXT. CAMPFIRE - NIGHT\n"
         "\n"
         "More action.";

    NSArray *els = [self parse:script];
    XCTAssertEqualObjects(((FNElement *)els[0]).elementType, @"Scene Heading");
    XCTAssertEqualObjects(((FNElement *)els[2]).elementType, @"Scene Heading");
}

// ===========================================================================
// MARK: - Input normalization
// ===========================================================================

- (void)test_lineEndings_CRLF_normalized {
    NSArray *els = [self parse:@"INT. OFFICE - DAY\r\n\r\nJOHN\r\nHello."];
    XCTAssertEqualObjects([self typesOf:els], (@[@"Scene Heading", @"Character", @"Dialogue"]));
}

- (void)test_lineEndings_CR_normalized {
    NSArray *els = [self parse:@"INT. OFFICE - DAY\r\rJOHN\rHello."];
    XCTAssertEqualObjects([self typesOf:els], (@[@"Scene Heading", @"Character", @"Dialogue"]));
}

- (void)test_emptyString_producesNoElements {
    XCTAssertEqual([self parse:@""].count, (NSUInteger)0);
}

- (void)test_onlyBlankLines_producesNoElements {
    XCTAssertEqual([self parse:@"\n\n\n"].count, (NSUInteger)0);
}

// ===========================================================================
// MARK: - Formerly-buggy index-lookahead cases
// ===========================================================================

- (void)test_uppercaseActionLine_surroundedByBlanks_isAction {
    // Previously the stale `index` caused "A RIVER." to be misclassified as Character.
    NSArray *els = [self parse:@"A RIVER.\n\nWe're underwater."];
    XCTAssertEqualObjects(((FNElement *)els[0]).elementType, @"Action");
}

- (void)test_twoUppercaseLinesEachSurroundedByBlanks_bothAction {
    // Both lines must be Action. Trailing content ensures neither triggers the
    // end-of-doc "user still typing" heuristic that would make the last one a Character.
    NSArray *els = [self parse:@"A RIVER.\n\nTHE BEAST.\n\nWe're underwater."];
    XCTAssertEqualObjects(((FNElement *)els[0]).elementType, @"Action");
    XCTAssertEqualObjects(((FNElement *)els[1]).elementType, @"Action");
}

- (void)test_characterAtEndOfDoc_isCharacter {
    // A lone character name at the end of the document (user still typing dialogue)
    // must remain Character, not fall through to Action.
    NSArray *els = [self parse:@"INT. OFFICE - DAY\n\nJOHN"];
    XCTAssertEqualObjects(((FNElement *)els.lastObject).elementType, @"Character");
}

@end
