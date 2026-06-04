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
    NSTextContainer *tc  = self.textContainer;

    // Ensure the layout manager has generated layout for the full container so
    // that line-fragment rects are valid even for off-screen scene headings
    // (needed for correct page-number sequencing).
    [lm ensureLayoutForTextContainer:tc];

    // [super drawRect:] may leave an arbitrary clip rect.  Reset it to the
    // full view bounds so our margin drawing is not silently discarded.
    NSGraphicsContext *ctx = [NSGraphicsContext currentContext];
    [ctx saveGraphicsState];
    [[NSBezierPath bezierPathWithRect:self.bounds] setClip];

    NSPoint    origin     = self.textContainerOrigin;
    CGFloat    containerW = tc.containerSize.width;
    NSUInteger totalLen   = self.textStorage.length;
    NSFont    *font       = self.font ?: [NSFont fontWithName:@"Courier" size:12];
    NSColor   *color      = self.textColor ?: [NSColor grayColor];
    NSDictionary *attrs   = [NSDictionary dictionaryWithObjectsAndKeys:
                                font,  NSFontAttributeName,
                                color, NSForegroundColorAttributeName, nil];

    NSUInteger lastPage = 0;

    for (NSUInteger i = 0; i < sceneRanges.count; i++) {
        NSRange cr = [[sceneRanges objectAtIndex:i] rangeValue];
        if (cr.location >= totalLen) continue;

        NSRange gr = [lm glyphRangeForCharacterRange:cr actualCharacterRange:nil];
        if (gr.length == 0) continue;

        NSRect  lr = [lm lineFragmentRectForGlyphAtIndex:gr.location effectiveRange:nil];
        CGFloat vy = origin.y + lr.origin.y;

        // Scene number — right-aligned flush against the container's left edge
        CGFloat marginW = origin.x - 10.0;
        if (marginW > 0) {
            NSString *numStr = [NSString stringWithFormat:@"%lu", (unsigned long)(i + 1)];
            NSSize    numSz  = [numStr sizeWithAttributes:attrs];
            [numStr drawAtPoint:NSMakePoint(origin.x - 10.0 - numSz.width, vy)
                 withAttributes:attrs];
        }

        // Page number — only on the first scene heading of each new page
        NSUInteger page = (NSUInteger)floor(lr.origin.y / kPageHeight) + 1;
        if (page > lastPage) {
            lastPage = page;
            NSString *pgStr = [NSString stringWithFormat:@"%lu.", (unsigned long)page];
            CGFloat    pgX  = origin.x + containerW + 10.0;
            if (pgX < NSWidth(self.frame))
                [pgStr drawAtPoint:NSMakePoint(pgX, vy) withAttributes:attrs];
        }
    }

    [ctx restoreGraphicsState];
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
    if (!self.characterNamesProvider) return [NSArray array];
    if (charRange.location == NSNotFound || charRange.length == 0) return [NSArray array];
    NSString *partial = [[self string] substringWithRange:charRange];
    if (partial.length == 0) return [NSArray array];
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
