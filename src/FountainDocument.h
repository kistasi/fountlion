#import <Cocoa/Cocoa.h>

@class FountainHighlighter;
@class FountainTextView;

@interface FountainDocument : NSDocument <NSTextViewDelegate>
@property (strong) FountainTextView *textView;
@property (strong) NSScrollView *scrollView;
@property (strong) NSString *pendingContent;
@property (strong) NSString *trailingComment;
@property (strong) FountainHighlighter *highlighter;
@property (strong) NSView *statusBar;
@property (strong) NSView *separatorView;
@property (strong) NSTextField *fileLabel;
@property (strong) NSTextField *countsLabel;
@property (strong) NSButton *modeButton;
@property (strong) NSView *leftBorderView;
@property (strong) NSView *rightBorderView;
@property (strong) NSPopUpButton *fontSizePopup;
- (void)applyColorScheme;
- (void)updateStatusBar;
- (void)layoutStatusBar;
@end
