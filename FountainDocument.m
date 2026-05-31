#import "FountainDocument.h"
#import "FountainHighlighter.h"
#import "FountainTextView.h"

// Standard Fountain title-page template for brand-new documents.
static NSString * const kNewDocumentTemplate =
    @"Title: \n"
    @"Credit: Written by\n"
    @"Author: \n"
    @"Draft date: \n"
    @"Contact: \n"
    @"\n"
    @"\n"
    @"FADE IN:\n"
    @"\n"
    @"INT. LOCATION - DAY\n"
    @"\n"
    @"Action.\n"
    @"\n";

@implementation FountainDocument

static const CGFloat kPageWidth = 612.0;  // 8.5" at 72 pt/in

- (void)makeWindowControllers {
    NSUInteger style = NSTitledWindowMask | NSClosableWindowMask |
                       NSMiniaturizableWindowMask | NSResizableWindowMask;
    NSWindow *window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 820, 700)
                  styleMask:style
                    backing:NSBackingStoreBuffered
                      defer:NO];
    [window center];
    [window setCollectionBehavior:NSWindowCollectionBehaviorFullScreenPrimary];
    [window setMinSize:NSMakeSize(kPageWidth + 60, 400)];

    self.scrollView =
        [[NSScrollView alloc] initWithFrame:((NSView *)window.contentView).bounds];
    [self.scrollView setHasVerticalScroller:YES];
    [self.scrollView setHasHorizontalScroller:NO];
    [self.scrollView setBorderType:NSNoBorder];
    [self.scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self.scrollView setDrawsBackground:YES];

    NSSize cs = self.scrollView.contentSize;
    CGFloat pageX = floor((cs.width - kPageWidth) / 2.0);
    if (pageX < 0) pageX = 0;

    self.textView =
        [[FountainTextView alloc] initWithFrame:NSMakeRect(pageX, 0, kPageWidth, cs.height)];
    [self.textView setMinSize:NSMakeSize(kPageWidth, cs.height)];
    [self.textView setMaxSize:NSMakeSize(kPageWidth, FLT_MAX)];
    [self.textView setVerticallyResizable:YES];
    [self.textView setHorizontallyResizable:NO];
    [self.textView setAutoresizingMask:NSViewMinXMargin | NSViewMaxXMargin];
    [[self.textView textContainer] setWidthTracksTextView:YES];
    [[self.textView textContainer] setContainerSize:NSMakeSize(kPageWidth, FLT_MAX)];
    [self.textView setTextContainerInset:NSMakeSize(0, 20)];

    [self.textView setFont:[NSFont fontWithName:@"Courier" size:12]];
    [self.textView setAllowsUndo:YES];
    [self.textView setUsesFindPanel:YES];
    [self.textView setDelegate:self];

    [self.scrollView setDocumentView:self.textView];
    [window.contentView addSubview:self.scrollView];

    self.highlighter = [[FountainHighlighter alloc] initWithTextView:self.textView];

    // Wire autocomplete source into the text view.
    FountainHighlighter *h = self.highlighter;
    self.textView.characterNamesProvider = ^NSArray *{ return h.characterNames; };
    self.textView.highlighter = self.highlighter;

    if (self.pendingContent) {
        [self.textView setString:self.pendingContent];
        self.pendingContent = nil;
    } else if (!self.fileURL) {
        // New untitled document — load template and position cursor after "Title: "
        [self.textView setString:kNewDocumentTemplate];
        [self.textView setSelectedRange:NSMakeRange(7, 0)];
    }

    [self applyColorScheme];

    NSWindowController *wc = [[NSWindowController alloc] initWithWindow:window];
    [self addWindowController:wc];
    [wc showWindow:nil];
    [self updateWordCount];
}

// ---------------------------------------------------------------------------
// Color scheme (light / dark)

- (void)applyColorScheme {
    BOOL dark = [[NSUserDefaults standardUserDefaults] boolForKey:@"darkMode"];
    if (dark) {
        [self.textView setBackgroundColor:[NSColor colorWithCalibratedWhite:0.12 alpha:1.0]];
        [self.textView setTextColor:[NSColor colorWithCalibratedWhite:0.92 alpha:1.0]];
        [self.textView setInsertionPointColor:[NSColor colorWithCalibratedWhite:0.9 alpha:1.0]];
        [self.scrollView setBackgroundColor:[NSColor colorWithCalibratedWhite:0.18 alpha:1.0]];
    } else {
        [self.textView setBackgroundColor:[NSColor whiteColor]];
        [self.textView setTextColor:[NSColor blackColor]];
        [self.textView setInsertionPointColor:[NSColor blackColor]];
        [self.scrollView setBackgroundColor:[NSColor colorWithCalibratedWhite:0.80 alpha:1.0]];
    }
    self.highlighter.darkMode = dark;
}

// ---------------------------------------------------------------------------
// Word count in window title

- (void)updateWordCount {
    NSString *text = [self.textView string];
    __block NSInteger count = 0;
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                             options:NSStringEnumerationByWords
                          usingBlock:^(NSString *s, NSRange sr, NSRange er, BOOL *stop) {
        (void)s; (void)sr; (void)er; (void)stop;
        count++;
    }];
    NSString *baseName = [self displayName] ?: @"Untitled";
    NSString *countStr;
    if (count >= 1000) {
        countStr = [NSString stringWithFormat:@"%ld,%03ld",
                    (long)(count / 1000), (long)(count % 1000)];
    } else {
        countStr = [NSString stringWithFormat:@"%ld", (long)count];
    }
    NSString *title = [NSString stringWithFormat:@"%@ — %@ words", baseName, countStr];
    for (NSWindowController *wc in self.windowControllers) {
        [wc.window setTitle:title];
    }
}

// ---------------------------------------------------------------------------
// NSDocument file I/O

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    NSString *text = self.textView ? [self.textView string] : @"";
    return [text dataUsingEncoding:NSUTF8StringEncoding];
}

- (BOOL)readFromData:(NSData *)data
              ofType:(NSString *)typeName
               error:(NSError **)outError {
    NSString *text =
        [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!text)
        text = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    if (!text) text = @"";
    if (self.textView) {
        [self.textView setString:text];
    } else {
        self.pendingContent = text;
    }
    return YES;
}

// ---------------------------------------------------------------------------
// NSTextViewDelegate

- (void)textDidChange:(NSNotification *)notification {
    [self updateChangeCount:NSChangeDone];
    [self updateWordCount];
}

@end
