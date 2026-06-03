#import "FountainTextView.h"
#import "FountainHighlighter.h"

static const CGFloat kPageHeight = 792.0;  // US letter at 72 pt/in

@implementation FountainTextView {
    BOOL _triggeringComplete;
}

// ---------------------------------------------------------------------------
// Margin annotations — scene numbers (left) and page numbers (right)

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    if (!self.highlighter) return;

    NSArray *sceneRanges = self.highlighter.sceneHeadingRanges;
    if (!sceneRanges.count) return;

    NSLayoutManager *lm = self.layoutManager;
    NSTextContainer *tc = self.textContainer;
    NSPoint origin      = self.textContainerOrigin;
    CGFloat containerW  = tc.containerSize.width;
    NSUInteger totalLen = self.textStorage.length;
    NSFont  *font       = self.font ?: [NSFont fontWithName:@"Courier" size:12];
    NSColor *color      = self.textColor ?: [NSColor grayColor];

    NSMutableParagraphStyle *rightPS = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    rightPS.alignment = NSRightTextAlignment;
    NSDictionary *leftAttrs  = @{ NSFontAttributeName: font,
                                   NSForegroundColorAttributeName: color };
    NSDictionary *rightAttrs = @{ NSFontAttributeName: font,
                                   NSForegroundColorAttributeName: color,
                                   NSParagraphStyleAttributeName: [rightPS copy] };

    NSUInteger lastPage = 0;

    for (NSUInteger i = 0; i < sceneRanges.count; i++) {
        NSRange cr = [[sceneRanges objectAtIndex:i] rangeValue];
        if (cr.location >= totalLen) continue;

        NSRange gr = [lm glyphRangeForCharacterRange:cr actualCharacterRange:nil];
        if (gr.length == 0) continue;

        NSRect  lr = [lm lineFragmentRectForGlyphAtIndex:gr.location effectiveRange:nil];
        CGFloat vy = origin.y + lr.origin.y;
        CGFloat h  = lr.size.height;

        // Scene number — right-aligned flush against the container's left edge
        NSString *numStr  = [NSString stringWithFormat:@"%lu", (unsigned long)(i + 1)];
        CGFloat   marginW = origin.x - 10.0;
        if (marginW > 0)
            [numStr drawInRect:NSMakeRect(0, vy, marginW, h) withAttributes:rightAttrs];

        // Page number — only on the first scene heading of each new page
        NSUInteger page = (NSUInteger)floor(lr.origin.y / kPageHeight) + 1;
        if (page > lastPage) {
            lastPage = page;
            NSString *pgStr = [NSString stringWithFormat:@"%lu.", (unsigned long)page];
            CGFloat   pgX   = origin.x + containerW + 10.0;
            CGFloat   pgW   = NSWidth(self.frame) - pgX;
            if (pgW > 0)
                [pgStr drawInRect:NSMakeRect(pgX, vy, pgW, h) withAttributes:leftAttrs];
        }
    }
}

// ---------------------------------------------------------------------------
// Smart newline — set typing attributes so the cursor lands at the right
// indent immediately, before the highlighter's delayed re-pass fires.

- (void)insertNewline:(id)sender {
    NSUInteger loc = self.selectedRange.location;
    NSString *prevType = (self.highlighter && loc > 0)
        ? [self.highlighter elementTypeAtCharOffset:loc]
        : @"Action";
    [super insertNewline:sender];
    if ([prevType isEqualToString:@"Character"]) {
        [self setTypingAttributes:[self.highlighter attrsForType:@"Dialogue" centered:NO]];
    }
}

// ---------------------------------------------------------------------------
// Character name autocomplete — fires after each insertion on an ALL CAPS line.

- (void)insertText:(id)string replacementRange:(NSRange)replacementRange {
    [super insertText:string replacementRange:replacementRange];
    if (!_triggeringComplete) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                 selector:@selector(triggerAutocomplete)
                                                   object:nil];
        [self performSelector:@selector(triggerAutocomplete) withObject:nil afterDelay:0.0];
    }
}

- (void)triggerAutocomplete {
    if (!self.characterNamesProvider) return;
    if (![self currentLineIsCharacterCue]) return;
    NSRange partial = [self rangeForUserCompletion];
    if (partial.location == NSNotFound || partial.length == 0) return;
    if ([self completionsForPartialWordRange:partial indexOfSelectedItem:nil].count == 0) return;
    _triggeringComplete = YES;
    [self complete:nil];
    _triggeringComplete = NO;
}

// Returns YES when the current line looks like a character cue (all-caps,
// not a scene heading prefix, not a transition suffix).
- (BOOL)currentLineIsCharacterCue {
    NSString *text = self.string;
    NSRange sel = self.selectedRange;
    if (sel.location == NSNotFound) return NO;
    NSRange lineRange = [text lineRangeForRange:NSMakeRange(sel.location, 0)];
    NSString *line = [text substringWithRange:lineRange];
    line = [line stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    if (line.length < 2) return NO;
    for (NSUInteger i = 0; i < line.length; i++) {
        unichar c = [line characterAtIndex:i];
        if (c >= 'a' && c <= 'z') return NO;
    }
    // Scene heading prefixes
    if ([line hasPrefix:@"INT."] || [line hasPrefix:@"EXT."] || [line hasPrefix:@"I/E"]) return NO;
    // Transition suffixes
    if ([line hasSuffix:@"TO:"] || [line hasSuffix:@"OUT."] || [line hasSuffix:@"IN:"]) return NO;
    return YES;
}

// Complete from line start to cursor so the whole cue is replaced on accept.
- (NSRange)rangeForUserCompletion {
    NSString *text = self.string;
    NSRange sel = self.selectedRange;
    if (sel.location == NSNotFound) return NSMakeRange(NSNotFound, 0);
    NSRange lineRange = [text lineRangeForRange:NSMakeRange(sel.location, 0)];
    return NSMakeRange(lineRange.location, sel.location - lineRange.location);
}

- (NSArray *)completionsForPartialWordRange:(NSRange)charRange
                         indexOfSelectedItem:(NSInteger *)index {
    if (!self.characterNamesProvider) return @[];
    if (charRange.location == NSNotFound || charRange.length == 0) return @[];
    NSString *partial = [[self string] substringWithRange:charRange];
    if (partial.length == 0) return @[];
    NSArray *allNames = self.characterNamesProvider();
    NSMutableArray *matches = [NSMutableArray array];
    for (NSString *name in allNames) {
        if (name.length > partial.length &&
            [name compare:partial options:NSCaseInsensitiveSearch
                    range:NSMakeRange(0, partial.length)] == NSOrderedSame) {
            [matches addObject:name];
        }
    }
    if (index) *index = -1;
    return [matches copy];
}

@end
