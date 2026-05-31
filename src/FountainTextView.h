#import <Cocoa/Cocoa.h>

@class FountainHighlighter;

@interface FountainTextView : NSTextView
@property (weak) FountainHighlighter *highlighter;
// Returns all known character names from the current document for autocomplete.
@property (copy) NSArray *(^characterNamesProvider)(void);
@end
