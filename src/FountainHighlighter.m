#import "FountainHighlighter.h"
#import "vendor/FastFountainParser.h"
#import "vendor/FNElement.h"

// Screenplay margins in points (72 pt = 1 inch).
// Shared by buildParaStyles and elementTypeAtCharOffset: — change here, not both.
static const CGFloat kIndentBody          = 108.0;   // 1.5"
static const CGFloat kTailBody            = -72.0;   // 1.0" from right
static const CGFloat kIndentCharacter     = 252.0;   // 3.5"
static const CGFloat kIndentDialogue      = 180.0;   // 2.5"
static const CGFloat kTailDialogue        = -180.0;  // 2.5" from right
static const CGFloat kIndentParenthetical = 216.0;   // 3.0"

@implementation FountainHighlighter {
    NSTextView         *_textView;
    BOOL                _darkMode;
    NSArray            *_characterNames;
    // Cached fonts — same for both color schemes.
    NSFont             *_fontRegular;
    NSFont             *_fontBold;
    NSFont             *_fontOblique;
    // Colors — rebuilt when darkMode changes.
    NSColor            *_colorText;
    NSColor            *_colorGray;
    NSColor            *_colorAccent;
    // Paragraph styles — constant (independent of color scheme).
    NSParagraphStyle   *_paraBody;
    NSParagraphStyle   *_paraCharacter;
    NSParagraphStyle   *_paraDialogue;
    NSParagraphStyle   *_paraParenthetical;
    NSParagraphStyle   *_paraTransition;
    NSParagraphStyle   *_paraCenter;
}

@synthesize characterNames = _characterNames;
@synthesize darkMode = _darkMode;

- (instancetype)initWithTextView:(NSTextView *)textView {
    self = [super init];
    if (self) {
        _textView = textView;
        _characterNames = @[];
        [self buildCachedResources];
        [textView.textStorage setDelegate:self];
        [self highlightAll];
    }
    return self;
}

- (void)setDarkMode:(BOOL)darkMode {
    if (_darkMode == darkMode) return;
    _darkMode = darkMode;
    [self buildColors];
    [self highlightAll];
}

- (void)buildCachedResources {
    _fontRegular = [NSFont fontWithName:@"Courier" size:12];
    _fontBold    = [NSFont fontWithName:@"Courier-Bold" size:12];
    _fontOblique = [NSFont fontWithName:@"Courier-Oblique" size:12] ?: _fontRegular;
    [self buildColors];
    [self buildParaStyles];
}

- (void)buildColors {
    if (_darkMode) {
        _colorText   = [NSColor colorWithCalibratedWhite:0.92 alpha:1.0];
        _colorGray   = [NSColor colorWithCalibratedRed:0.55 green:0.78 blue:0.55 alpha:1.0];
        _colorAccent = [NSColor colorWithCalibratedRed:0.34 green:0.61 blue:0.84 alpha:1.0];
    } else {
        _colorText   = [NSColor blackColor];
        _colorGray   = [NSColor grayColor];
        _colorAccent = [NSColor colorWithCalibratedRed:0.1 green:0.1 blue:0.55 alpha:1.0];
    }
}

- (void)buildParaStyles {
    // Standard screenplay margins (72 pt = 1 inch).
    // All head/tail indents are absolute offsets from the left edge of the 612-pt page.

    NSMutableParagraphStyle *body = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    body.firstLineHeadIndent = kIndentBody;
    body.headIndent          = kIndentBody;
    body.tailIndent          = kTailBody;
    _paraBody = [body copy];

    NSMutableParagraphStyle *character = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    character.firstLineHeadIndent = kIndentCharacter;
    character.headIndent          = kIndentCharacter;
    _paraCharacter = [character copy];

    NSMutableParagraphStyle *dialogue = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    dialogue.firstLineHeadIndent = kIndentDialogue;
    dialogue.headIndent          = kIndentDialogue;
    dialogue.tailIndent          = kTailDialogue;
    _paraDialogue = [dialogue copy];

    NSMutableParagraphStyle *paren = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    paren.firstLineHeadIndent = kIndentParenthetical;
    paren.headIndent          = kIndentParenthetical;
    paren.tailIndent          = kTailDialogue;
    _paraParenthetical = [paren copy];

    NSMutableParagraphStyle *transition = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    transition.alignment  = NSRightTextAlignment;
    transition.headIndent = kIndentBody;
    transition.tailIndent = kTailBody;
    _paraTransition = [transition copy];

    NSMutableParagraphStyle *center = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    center.alignment = NSCenterTextAlignment;
    _paraCenter = [center copy];
}

// ---------------------------------------------------------------------------
// NSTextStorageDelegate

- (void)textStorageDidProcessEditing:(NSNotification *)notification {
    NSTextStorage *ts = notification.object;
    if (!(ts.editedMask & NSTextStorageEditedCharacters)) return;
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(highlightAll)
                                               object:nil];
    [self performSelector:@selector(highlightAll) withObject:nil afterDelay:0.0];
}

// ---------------------------------------------------------------------------
// Highlighting

- (void)highlightAll {
    NSTextStorage *ts = _textView.textStorage;
    NSString *text = [ts string];
    NSUInteger len = text.length;

    [ts beginEditing];
    [ts setAttributes:[self attrsForType:@"Action" centered:NO]
                range:NSMakeRange(0, len)];

    if (len == 0) { [ts endEditing]; return; }

    FastFountainParser *parser = [[FastFountainParser alloc] initWithString:text];
    NSArray *elements = parser.elements;
    if (!elements.count) { [ts endEditing]; return; }

    // Collect character names while iterating elements.
    NSMutableSet *names = [NSMutableSet set];

    NSArray *lines = [text componentsSeparatedByString:@"\n"];
    NSMutableArray *offsets = [NSMutableArray arrayWithCapacity:lines.count];
    NSUInteger pos = 0;
    for (NSString *line in lines) {
        [offsets addObject:[NSNumber numberWithUnsignedInteger:pos]];
        pos += line.length + 1;
    }

    NSUInteger elemIdx = 0;
    NSUInteger lineIdx = parser.titlePageLineCount;
    NSUInteger lineCount = lines.count;

    while (elemIdx < elements.count && lineIdx < lineCount) {
        if (((NSString *)[lines objectAtIndex:lineIdx]).length == 0) { lineIdx++; continue; }

        FNElement *el = [elements objectAtIndex:elemIdx];
        NSUInteger elemLineCount = [[el.elementText componentsSeparatedByString:@"\n"] count];

        NSUInteger startOff = [[offsets objectAtIndex:lineIdx] unsignedIntegerValue];
        NSUInteger endLineIdx = MIN(lineIdx + elemLineCount - 1, lineCount - 1);
        NSUInteger endOff = [[offsets objectAtIndex:endLineIdx] unsignedIntegerValue]
                          + ((NSString *)[lines objectAtIndex:endLineIdx]).length;

        if (startOff <= endOff && endOff <= len) {
            [ts setAttributes:[self attrsForType:el.elementType centered:el.isCentered]
                        range:NSMakeRange(startOff, endOff - startOff)];
        }

        if ([el.elementType isEqualToString:@"Character"]) {
            NSString *name = [el.elementText stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceAndNewlineCharacterSet]];
            // Strip extensions like "(V.O.)" or "(CONT'D)"
            NSRange paren = [name rangeOfString:@"("];
            if (paren.location != NSNotFound) {
                name = [[name substringToIndex:paren.location]
                    stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            }
            if (name.length > 0) [names addObject:name];
        }

        lineIdx += elemLineCount;
        elemIdx++;
    }

    [ts endEditing];

    _characterNames = [[names allObjects] sortedArrayUsingSelector:@selector(compare:)];
}

// ---------------------------------------------------------------------------
// Element type inference — reads back the paragraph style applied by highlightAll.

- (NSString *)elementTypeAtCharOffset:(NSUInteger)offset {
    NSTextStorage *ts = _textView.textStorage;
    if (ts.length == 0) return @"Action";
    NSUInteger idx = offset > 0 ? MIN(offset - 1, ts.length - 1) : 0;
    NSParagraphStyle *para = [ts attribute:NSParagraphStyleAttributeName
                                   atIndex:idx
                            effectiveRange:nil];
    if (!para) return @"Action";
    CGFloat hi = para.headIndent;
    if (hi == kIndentCharacter)     return @"Character";
    if (hi == kIndentDialogue)      return @"Dialogue";
    if (hi == kIndentParenthetical) return @"Parenthetical";
    return @"Action";
}

// ---------------------------------------------------------------------------
// Attribute dictionaries

- (NSDictionary *)attrsForType:(NSString *)type centered:(BOOL)centered {
    if ([type isEqualToString:@"Scene Heading"]) {
        return @{ NSFontAttributeName: _fontBold,    NSForegroundColorAttributeName: _colorText,   NSParagraphStyleAttributeName: _paraBody         };
    }
    if ([type isEqualToString:@"Character"]) {
        return @{ NSFontAttributeName: _fontRegular, NSForegroundColorAttributeName: _colorText,   NSParagraphStyleAttributeName: _paraCharacter     };
    }
    if ([type isEqualToString:@"Dialogue"]) {
        return @{ NSFontAttributeName: _fontRegular, NSForegroundColorAttributeName: _colorText,   NSParagraphStyleAttributeName: _paraDialogue      };
    }
    if ([type isEqualToString:@"Parenthetical"]) {
        return @{ NSFontAttributeName: _fontRegular, NSForegroundColorAttributeName: _colorText,   NSParagraphStyleAttributeName: _paraParenthetical };
    }
    if ([type isEqualToString:@"Transition"]) {
        return @{ NSFontAttributeName: _fontRegular, NSForegroundColorAttributeName: _colorText,   NSParagraphStyleAttributeName: _paraTransition    };
    }
    if ([type isEqualToString:@"Section Heading"]) {
        return @{ NSFontAttributeName: _fontBold,    NSForegroundColorAttributeName: _colorAccent, NSParagraphStyleAttributeName: _paraBody         };
    }
    if ([type isEqualToString:@"Synopsis"] ||
        [type isEqualToString:@"Comment"]  ||
        [type isEqualToString:@"Boneyard"]) {
        return @{ NSFontAttributeName: _fontOblique, NSForegroundColorAttributeName: _colorGray,   NSParagraphStyleAttributeName: _paraBody         };
    }
    NSParagraphStyle *para = centered ? _paraCenter : _paraBody;
    return @{ NSFontAttributeName: _fontRegular, NSForegroundColorAttributeName: _colorText, NSParagraphStyleAttributeName: para };
}

@end
