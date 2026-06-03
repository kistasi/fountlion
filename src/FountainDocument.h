#import <Cocoa/Cocoa.h>

@class FountainHighlighter;
@class FountainTextView;

@interface FountainDocument : NSDocument <NSTextViewDelegate>
@property (strong) FountainTextView *textView;
@property (strong) NSScrollView *scrollView;
@property (strong) NSString *pendingContent;
@property (strong) FountainHighlighter *highlighter;
@property (strong) NSView *statusBar;
@property (strong) NSView *separatorView;
@property (strong) NSTextField *fileLabel;
@property (strong) NSTextField *countsLabel;
@property (strong) NSButton *modeButton;
@property (strong) NSView *leftBorderView;
@property (strong) NSView *rightBorderView;
- (void)applyColorScheme;
- (void)updateStatusBar;
- (void)layoutStatusBar;
@end
