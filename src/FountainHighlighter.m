#import "FountainHighlighter.h"
#import "vendor/FastFountainParser.h"
#import "vendor/FNElement.h"

// Proportional screenplay margins relative to a standard 612-pt page.
static const CGFloat kFracIndentBody          =  72.0 / 612.0;
static const CGFloat kFracTailBody            =  72.0 / 612.0;  // magnitude; applied as negative
static const CGFloat kFracIndentCharacter     = 252.0 / 612.0;
static const CGFloat kFracIndentDialogue      = 180.0 / 612.0;
static const CGFloat kFracTailDialogue        = 180.0 / 612.0;  // magnitude; applied as negative
static const CGFloat kFracIndentParenthetical = 216.0 / 612.0;

@implementation FountainHighlighter {
    NSTextView         *_textView;
    BOOL                _darkMode;
    CGFloat             _containerWidth;
    CGFloat             _fontSize;
    NSArray            *_characterNames;
    // Cached fonts — rebuilt when fontSize changes.
    NSFont             *_fontRegular;
    NSFont             *_fontBold;
    NSFont             *_fontOblique;
    // Colors — rebuilt when darkMode changes.
    NSColor            *_colorText;
    NSColor            *_colorGray;
    NSColor            *_colorAccent;
    // Paragraph styles — rebuilt when containerWidth changes.
    NSParagraphStyle   *_paraBody;
    NSParagraphStyle   *_paraCharacter;
    NSParagraphStyle   *_paraDialogue;
    NSParagraphStyle   *_paraParenthetical;
    NSParagraphStyle   *_paraTransition;
    NSParagraphStyle   *_paraCenter;
    // Scaled indent values — set by buildParaStyles, read by elementTypeAtCharOffset:.
    CGFloat             _indentBody;
    CGFloat             _indentCharacter;
    CGFloat             _indentDialogue;
    CGFloat             _indentParenthetical;
}

@synthesize characterNames = _characterNames;
@synthesize darkMode = _darkMode;
@synthesize containerWidth = _containerWidth;
@synthesize fontSize = _fontSize;

- (instancetype)initWithTextView:(NSTextView *)textView {
    self = [super init];
    if (self) {
        _textView = textView;
        _characterNames = @[];
        _containerWidth = 612.0;
        _fontSize = 14.0;
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

- (void)setContainerWidth:(CGFloat)containerWidth {
    if (_containerWidth == containerWidth) return;
    _containerWidth = containerWidth;
    [self buildParaStyles];
    [self highlightAll];
}

- (void)setFontSize:(CGFloat)fontSize {
    if (_fontSize == fontSize) return;
    _fontSize = fontSize;
    [self buildFonts];
    [self highlightAll];
}

- (void)buildFonts {
    _fontRegular = [NSFont fontWithName:@"Courier" size:_fontSize];
    _fontBold    = [NSFont fontWithName:@"Courier-Bold" size:_fontSize];
    _fontOblique = [NSFont fontWithName:@"Courier-Oblique" size:_fontSize] ?: _fontRegular;
}

- (void)buildCachedResources {
    [self buildFonts];
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
    CGFloat W = _containerWidth;
    _indentBody          = floor(W * kFracIndentBody);
    CGFloat tailBody     = -floor(W * kFracTailBody);
    _indentCharacter     = floor(W * kFracIndentCharacter);
    _indentDialogue      = floor(W * kFracIndentDialogue);
    CGFloat tailDialogue = -floor(W * kFracTailDialogue);
    _indentParenthetical = floor(W * kFracIndentParenthetical);

    NSMutableParagraphStyle *body = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    body.firstLineHeadIndent = _indentBody;
    body.headIndent          = _indentBody;
    body.tailIndent          = tailBody;
    _paraBody = [body copy];

    NSMutableParagraphStyle *character = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    character.firstLineHeadIndent = _indentCharacter;
    character.headIndent          = _indentCharacter;
    _paraCharacter = [character copy];

    NSMutableParagraphStyle *dialogue = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    dialogue.firstLineHeadIndent = _indentDialogue;
    dialogue.headIndent          = _indentDialogue;
    dialogue.tailIndent          = tailDialogue;
    _paraDialogue = [dialogue copy];

    NSMutableParagraphStyle *paren = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    paren.firstLineHeadIndent = _indentParenthetical;
    paren.headIndent          = _indentParenthetical;
    paren.tailIndent          = tailDialogue;
    _paraParenthetical = [paren copy];

    NSMutableParagraphStyle *transition = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    transition.alignment  = NSRightTextAlignment;
    transition.headIndent = _indentBody;
    transition.tailIndent = tailBody;
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
    if (hi == _indentCharacter)     return @"Character";
    if (hi == _indentDialogue)      return @"Dialogue";
    if (hi == _indentParenthetical) return @"Parenthetical";
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
