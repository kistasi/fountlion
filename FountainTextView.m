#import "FountainTextView.h"
#import "FountainHighlighter.h"

@implementation FountainTextView {
    BOOL _triggeringComplete;
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
