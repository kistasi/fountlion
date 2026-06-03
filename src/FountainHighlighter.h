#import <Cocoa/Cocoa.h>

@interface FountainHighlighter : NSObject <NSTextStorageDelegate>
- (instancetype)initWithTextView:(NSTextView *)textView;
- (void)highlightAll;

// Infer element type at a character offset by inspecting applied paragraph style.
- (NSString *)elementTypeAtCharOffset:(NSUInteger)offset;

// Public so FountainTextView can set typing attributes for smart continuation.
- (NSDictionary *)attrsForType:(NSString *)type centered:(BOOL)centered;

// Updated after each highlight pass; used for character-name autocomplete.
@property (readonly) NSArray *characterNames;

// Toggle dark-mode color scheme; triggers a full re-highlight.
@property (nonatomic) BOOL darkMode;

// Current text-container width in points; triggers a para-style rebuild and re-highlight.
@property (nonatomic) CGFloat containerWidth;

// Font size in points (default 12); triggers a font rebuild and re-highlight.
@property (nonatomic) CGFloat fontSize;
@end
