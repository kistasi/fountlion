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
static const CGFloat kStatusBarHeight = 22.0;
static const CGFloat kContainerWidthFraction = 0.7;

- (NSTextField *)makePlainLabel {
    NSTextField *label = [[NSTextField alloc] initWithFrame:NSZeroRect];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setBordered:NO];
    [label setDrawsBackground:NO];
    [label setFont:[NSFont systemFontOfSize:11]];
    return label;
}

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

    NSRect contentBounds = ((NSView *)window.contentView).bounds;
    NSRect scrollRect = NSMakeRect(0, kStatusBarHeight,
                                   contentBounds.size.width,
                                   contentBounds.size.height - kStatusBarHeight);
    self.scrollView = [[NSScrollView alloc] initWithFrame:scrollRect];
    [self.scrollView setHasVerticalScroller:YES];
    [self.scrollView setHasHorizontalScroller:NO];
    [self.scrollView setBorderType:NSNoBorder];
    [self.scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self.scrollView setDrawsBackground:YES];

    NSSize cs = self.scrollView.contentSize;
    CGFloat containerW = floor(cs.width * kContainerWidthFraction);
    CGFloat hInset = floor((cs.width - containerW) / 2.0);

    self.textView =
        [[FountainTextView alloc] initWithFrame:NSMakeRect(0, 0, cs.width, cs.height)];
    [self.textView setMinSize:NSMakeSize(0, cs.height)];
    [self.textView setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
    [self.textView setVerticallyResizable:YES];
    [self.textView setHorizontallyResizable:NO];
    [self.textView setAutoresizingMask:NSViewWidthSizable];
    [[self.textView textContainer] setWidthTracksTextView:NO];
    [[self.textView textContainer] setContainerSize:NSMakeSize(containerW, FLT_MAX)];
    [self.textView setTextContainerInset:NSMakeSize(hInset, 20)];

    [self.textView setFont:[NSFont fontWithName:@"Courier" size:12]];
    [self.textView setAllowsUndo:YES];
    [self.textView setUsesFindPanel:YES];
    [self.textView setDelegate:self];

    [self.scrollView setDocumentView:self.textView];
    [window.contentView addSubview:self.scrollView];

    // Status bar
    NSRect statusRect = NSMakeRect(0, 0, contentBounds.size.width, kStatusBarHeight);
    self.statusBar = [[NSView alloc] initWithFrame:statusRect];
    [self.statusBar setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];

    self.separatorView = [[NSView alloc] initWithFrame:NSZeroRect];
    [self.statusBar addSubview:self.separatorView];

    self.fileLabel = [self makePlainLabel];
    [[self.fileLabel cell] setLineBreakMode:NSLineBreakByTruncatingHead];
    [self.statusBar addSubview:self.fileLabel];

    self.countsLabel = [self makePlainLabel];
    [self.countsLabel setAlignment:NSRightTextAlignment];
    [self.statusBar addSubview:self.countsLabel];

    self.modeButton = [[NSButton alloc] initWithFrame:NSZeroRect];
    [self.modeButton setButtonType:NSSwitchButton];
    [self.modeButton setTitle:@"Dark Mode"];
    [self.modeButton setFont:[NSFont systemFontOfSize:11]];
    [self.modeButton setTarget:nil];
    [self.modeButton setAction:@selector(toggleDarkMode:)];
    [self.statusBar addSubview:self.modeButton];

    self.fontSizePopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [[self.fontSizePopup cell] setControlSize:NSSmallControlSize];
    [self.fontSizePopup setFont:[NSFont systemFontOfSize:11]];
    NSArray *fontSizes = [NSArray arrayWithObjects:
        [NSNumber numberWithInt:10], [NSNumber numberWithInt:11],
        [NSNumber numberWithInt:12], [NSNumber numberWithInt:13],
        [NSNumber numberWithInt:14], [NSNumber numberWithInt:16],
        [NSNumber numberWithInt:18], [NSNumber numberWithInt:20],
        [NSNumber numberWithInt:24], nil];
    for (NSNumber *pt in fontSizes) {
        [self.fontSizePopup addItemWithTitle:[NSString stringWithFormat:@"%ld pt", (long)pt.integerValue]];
        [[self.fontSizePopup lastItem] setRepresentedObject:pt];
    }
    NSInteger savedSize = [[NSUserDefaults standardUserDefaults] integerForKey:@"fontSize"];
    if (savedSize == 0) savedSize = 14;
    for (NSMenuItem *item in [self.fontSizePopup itemArray]) {
        if ([item.representedObject integerValue] == savedSize) {
            [self.fontSizePopup selectItem:item];
            break;
        }
    }
    [self.fontSizePopup setTarget:self];
    [self.fontSizePopup setAction:@selector(fontSizeChanged:)];
    [self.statusBar addSubview:self.fontSizePopup];

    [window.contentView addSubview:self.statusBar];

    self.leftBorderView = [[NSView alloc] initWithFrame:NSZeroRect];
    [self.leftBorderView setWantsLayer:YES];
    [self.leftBorderView setAutoresizingMask:NSViewNotSizable];
    [window.contentView addSubview:self.leftBorderView];

    self.rightBorderView = [[NSView alloc] initWithFrame:NSZeroRect];
    [self.rightBorderView setWantsLayer:YES];
    [self.rightBorderView setAutoresizingMask:NSViewNotSizable];
    [window.contentView addSubview:self.rightBorderView];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowDidResize:)
                                                 name:NSWindowDidResizeNotification
                                               object:window];

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
    [self applyFontSize];
    [self layoutStatusBar];
    [self centerTextView];

    NSWindowController *wc = [[NSWindowController alloc] initWithWindow:window];
    [self addWindowController:wc];
    [wc showWindow:nil];
    [self updateStatusBar];
}

// ---------------------------------------------------------------------------
// Color scheme (light / dark)

- (void)applyColorScheme {
    BOOL dark = [[NSUserDefaults standardUserDefaults] boolForKey:@"darkMode"];
    NSColor *textColor;
    if (dark) {
        [self.textView setBackgroundColor:[NSColor colorWithCalibratedWhite:0.12 alpha:1.0]];
        [self.textView setTextColor:[NSColor colorWithCalibratedWhite:0.92 alpha:1.0]];
        [self.textView setInsertionPointColor:[NSColor colorWithCalibratedWhite:0.9 alpha:1.0]];
        [self.scrollView setBackgroundColor:[NSColor colorWithCalibratedWhite:0.18 alpha:1.0]];
        [self.statusBar setWantsLayer:YES];
        [self.statusBar layer].backgroundColor = CGColorCreateGenericGray(0.15, 1.0);
        [self.separatorView setWantsLayer:YES];
        [self.separatorView layer].backgroundColor = CGColorCreateGenericGray(0.22, 1.0);
        textColor = [NSColor colorWithCalibratedWhite:0.65 alpha:1.0];
    } else {
        [self.textView setBackgroundColor:[NSColor whiteColor]];
        [self.textView setTextColor:[NSColor blackColor]];
        [self.textView setInsertionPointColor:[NSColor blackColor]];
        [self.scrollView setBackgroundColor:[NSColor colorWithCalibratedWhite:0.80 alpha:1.0]];
        [self.statusBar setWantsLayer:YES];
        [self.statusBar layer].backgroundColor = CGColorCreateGenericGray(0.93, 1.0);
        [self.separatorView setWantsLayer:YES];
        [self.separatorView layer].backgroundColor = CGColorCreateGenericGray(0.75, 1.0);
        textColor = [NSColor colorWithCalibratedWhite:0.3 alpha:1.0];
    }
    [self.fileLabel setTextColor:textColor];
    [self.countsLabel setTextColor:textColor];
    [self.modeButton setAttributedTitle:
        [[NSAttributedString alloc] initWithString:@"Dark Mode"
            attributes:@{NSForegroundColorAttributeName: textColor,
                         NSFontAttributeName: [NSFont systemFontOfSize:11]}]];
    [self.modeButton setState:dark ? NSOnState : NSOffState];
    self.highlighter.darkMode = dark;
    if (self.leftBorderView) {
        CGColorRef borderColor = dark ? CGColorCreateGenericGray(0.32, 1.0)
                                      : CGColorCreateGenericGray(0.72, 1.0);
        self.leftBorderView.layer.backgroundColor  = borderColor;
        self.rightBorderView.layer.backgroundColor = borderColor;
        CGColorRelease(borderColor);
    }
}

// ---------------------------------------------------------------------------
// Font size

- (void)applyFontSize {
    NSInteger size = [[NSUserDefaults standardUserDefaults] integerForKey:@"fontSize"];
    if (size == 0) size = 14;
    [self.textView setFont:[NSFont fontWithName:@"Courier" size:size]];
    self.highlighter.fontSize = size;
}

- (void)fontSizeChanged:(id)sender {
    NSInteger size = [[[self.fontSizePopup selectedItem] representedObject] integerValue];
    [[NSUserDefaults standardUserDefaults] setInteger:size forKey:@"fontSize"];
    [self.textView setFont:[NSFont fontWithName:@"Courier" size:size]];
    self.highlighter.fontSize = size;
}

// ---------------------------------------------------------------------------
// Status bar

- (void)layoutStatusBar {
    if (!self.statusBar) return;
    CGFloat W = NSWidth(self.statusBar.frame);
    CGFloat H = NSHeight(self.statusBar.frame);
    CGFloat pad = 8.0;
    CGFloat btnW  = 90.0;
    CGFloat popW  = 62.0;
    CGFloat cntW  = 185.0;
    CGFloat labelH = 15.0;
    CGFloat popH   = 18.0;
    CGFloat y    = floor((H - labelH) / 2.0);
    CGFloat popY = floor((H - popH)   / 2.0);

    CGFloat btnX = W - pad - btnW;
    CGFloat popX = btnX - pad - popW;
    CGFloat cntX = popX - pad - cntW;
    CGFloat fileW = cntX - pad - pad;
    if (fileW < 0) fileW = 0;

    [self.fileLabel    setFrame:NSMakeRect(pad,  y,    fileW, labelH)];
    [self.countsLabel  setFrame:NSMakeRect(cntX, y,    cntW,  labelH)];
    [self.fontSizePopup setFrame:NSMakeRect(popX, popY, popW,  popH)];
    [self.modeButton   setFrame:NSMakeRect(btnX, y - 1, btnW, labelH + 2)];
    [self.separatorView setFrame:NSMakeRect(0, H - 1, W, 1)];
}

- (void)updateStatusBar {
    if (!self.fileLabel) return;

    NSString *text = self.textView ? [self.textView string] : @"";

    __block NSInteger wordCount = 0;
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                             options:NSStringEnumerationByWords
                          usingBlock:^(NSString *s, NSRange sr, NSRange er, BOOL *stop) {
        (void)s; (void)sr; (void)er; (void)stop;
        wordCount++;
    }];
    NSInteger charCount = (NSInteger)text.length;

    NSString *(^fmt)(NSInteger) = ^(NSInteger n) {
        if (n >= 1000)
            return [NSString stringWithFormat:@"%ld,%03ld",
                    (long)(n / 1000), (long)(n % 1000)];
        return [NSString stringWithFormat:@"%ld", (long)n];
    };
    [self.countsLabel setStringValue:
        [NSString stringWithFormat:@"%@ words  %@ chars", fmt(wordCount), fmt(charCount)]];

    NSURL *url = self.fileURL;
    NSString *pathStr = url ? [url.path stringByAbbreviatingWithTildeInPath] : @"Untitled";
    [self.fileLabel setStringValue:pathStr];
}

- (void)centerTextView {
    if (!self.textView) return;
    CGFloat W = self.scrollView.contentSize.width;

    // Explicitly match the text view frame to the clip view so the inset
    // is always symmetric regardless of whether autoresizing fired.
    NSRect tvFrame = self.textView.frame;
    if (tvFrame.size.width != W) {
        tvFrame.size.width = W;
        [self.textView setFrame:tvFrame];
    }

    CGFloat containerW = floor(W * kContainerWidthFraction);
    CGFloat hInset = floor((W - containerW) / 2.0);
    [[self.textView textContainer] setContainerSize:NSMakeSize(containerW, FLT_MAX)];
    [self.textView setTextContainerInset:NSMakeSize(hInset, 20)];
    self.highlighter.containerWidth = containerW;

    if (self.leftBorderView) {
        NSRect sv = self.scrollView.frame;
        [self.leftBorderView  setFrame:NSMakeRect(hInset,              NSMinY(sv), 1, NSHeight(sv))];
        [self.rightBorderView setFrame:NSMakeRect(hInset + containerW, NSMinY(sv), 1, NSHeight(sv))];
    }
}

- (void)windowDidResize:(NSNotification *)notification {
    [self layoutStatusBar];
    [self centerTextView];
}

- (void)setFileURL:(NSURL *)fileURL {
    [super setFileURL:fileURL];
    [self updateStatusBar];
}

// ---------------------------------------------------------------------------
// NSDocument file I/O

// Strips a trailing Fountain compatibility comment ([[...]] or /* ... */) from
// `text`, stores it in self.trailingComment, and returns the stripped text.
// The full suffix from the last newline before the opener is stored so that the
// file round-trips byte-for-byte on save.
- (BOOL)tryStripTrailing:(NSString *)text open:(NSString *)open close:(NSString *)close result:(NSString **)outStripped {
    NSRange startRange = [text rangeOfString:open options:NSBackwardsSearch];
    if (startRange.location == NSNotFound) return NO;
    NSUInteger afterOpen = NSMaxRange(startRange);
    NSRange closeRange = [text rangeOfString:close
                                     options:0
                                       range:NSMakeRange(afterOpen, text.length - afterOpen)];
    if (closeRange.location == NSNotFound) return NO;
    NSUInteger afterClose = NSMaxRange(closeRange);
    NSString *tail = [text substringFromIndex:afterClose];
    if ([[tail stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] > 0) return NO;
    self.trailingComment = [text substringFromIndex:startRange.location];
    *outStripped = [text substringToIndex:startRange.location];
    return YES;
}

- (NSString *)stripTrailingCompatComment:(NSString *)text {
    NSString *stripped = nil;
    if ([self tryStripTrailing:text open:@"/*" close:@"*/" result:&stripped]) return stripped;
    if ([self tryStripTrailing:text open:@"[[" close:@"]]" result:&stripped]) return stripped;
    self.trailingComment = nil;
    return text;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    NSString *text = self.textView ? [self.textView string] : @"";
    if (self.trailingComment)
        text = [text stringByAppendingString:self.trailingComment];
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
    text = [self stripTrailingCompatComment:text];
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
    [self updateStatusBar];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
