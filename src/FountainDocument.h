#import <Cocoa/Cocoa.h>

@class FountainHighlighter;
@class FountainTextView;

@interface FountainDocument : NSDocument <NSTextViewDelegate>
@property (strong) FountainTextView *textView;
@property (strong) NSScrollView *scrollView;
@property (strong) NSString *pendingContent;
@property (strong) FountainHighlighter *highlighter;
- (void)applyColorScheme;
@end
