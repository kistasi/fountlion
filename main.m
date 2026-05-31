#import <Cocoa/Cocoa.h>
#import "FountainDocument.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation AppDelegate

- (void)buildMenu {
    NSMenu *menubar = [[NSMenu alloc] init];
    [NSApp setMainMenu:menubar];

    // ── App menu ────────────────────────────────────────────────────────────
    NSMenuItem *appItem = [[NSMenuItem alloc] init];
    [menubar addItem:appItem];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"FountLion"];
    appItem.submenu = appMenu;
    [appMenu addItemWithTitle:@"About FountLion"
                       action:@selector(orderFrontStandardAboutPanel:)
                keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Quit FountLion"
                       action:@selector(terminate:)
                keyEquivalent:@"q"];

    // ── File menu ────────────────────────────────────────────────────────────
    NSMenuItem *fileItem = [[NSMenuItem alloc] init];
    [menubar addItem:fileItem];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    fileItem.submenu = fileMenu;
    [fileMenu addItemWithTitle:@"New"
                        action:@selector(newDocument:)
                 keyEquivalent:@"n"];
    [fileMenu addItemWithTitle:@"Open…"
                        action:@selector(openDocument:)
                 keyEquivalent:@"o"];
    [fileMenu addItem:[NSMenuItem separatorItem]];
    [fileMenu addItemWithTitle:@"Save"
                        action:@selector(saveDocument:)
                 keyEquivalent:@"s"];
    NSMenuItem *saveAs = [fileMenu addItemWithTitle:@"Save As…"
                                             action:@selector(saveDocumentAs:)
                                      keyEquivalent:@"s"];
    [saveAs setKeyEquivalentModifierMask:NSShiftKeyMask | NSCommandKeyMask];
    [fileMenu addItemWithTitle:@"Revert to Saved"
                        action:@selector(revertDocumentToSaved:)
                 keyEquivalent:@""];

    // ── Edit menu ────────────────────────────────────────────────────────────
    NSMenuItem *editItem = [[NSMenuItem alloc] init];
    [menubar addItem:editItem];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    editItem.submenu = editMenu;

    [editMenu addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
    NSMenuItem *redo = [editMenu addItemWithTitle:@"Redo"
                                           action:@selector(redo:)
                                    keyEquivalent:@"z"];
    [redo setKeyEquivalentModifierMask:NSShiftKeyMask | NSCommandKeyMask];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItemWithTitle:@"Cut"   action:@selector(cut:)       keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"Copy"  action:@selector(copy:)      keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste" action:@selector(paste:)     keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    [editMenu addItem:[NSMenuItem separatorItem]];

    // Find submenu — NSTextView responds to performFindPanelAction: via responder chain.
    NSMenuItem *findItem = [[NSMenuItem alloc] initWithTitle:@"Find" action:nil keyEquivalent:@""];
    NSMenu *findMenu = [[NSMenu alloc] initWithTitle:@"Find"];
    findItem.submenu = findMenu;

    NSMenuItem *findPanel = [findMenu addItemWithTitle:@"Find…"
                                                action:@selector(performFindPanelAction:)
                                         keyEquivalent:@"f"];
    findPanel.tag = 1;  // NSFindPanelActionShowFindPanel

    NSMenuItem *findNext = [findMenu addItemWithTitle:@"Find Next"
                                               action:@selector(performFindPanelAction:)
                                        keyEquivalent:@"g"];
    findNext.tag = 2;   // NSFindPanelActionNext

    NSMenuItem *findPrev = [findMenu addItemWithTitle:@"Find Previous"
                                               action:@selector(performFindPanelAction:)
                                        keyEquivalent:@"g"];
    [findPrev setKeyEquivalentModifierMask:NSShiftKeyMask | NSCommandKeyMask];
    findPrev.tag = 3;   // NSFindPanelActionPrevious

    [editMenu addItem:findItem];

    // ── View menu ────────────────────────────────────────────────────────────
    NSMenuItem *viewItem = [[NSMenuItem alloc] init];
    [menubar addItem:viewItem];
    NSMenu *viewMenu = [[NSMenu alloc] initWithTitle:@"View"];
    viewItem.submenu = viewMenu;
    [viewMenu addItemWithTitle:@"Dark Mode"
                        action:@selector(toggleDarkMode:)
                 keyEquivalent:@""];
}

- (IBAction)toggleDarkMode:(id)sender {
    BOOL dark = ![[NSUserDefaults standardUserDefaults] boolForKey:@"darkMode"];
    [[NSUserDefaults standardUserDefaults] setBool:dark forKey:@"darkMode"];
    for (FountainDocument *doc in [[NSDocumentController sharedDocumentController] documents]) {
        [doc applyColorScheme];
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)item {
    if (item.action == @selector(toggleDarkMode:)) {
        BOOL dark = [[NSUserDefaults standardUserDefaults] boolForKey:@"darkMode"];
        item.state = dark ? NSOnState : NSOffState;
    }
    return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self buildMenu];
    (void)[NSDocumentController sharedDocumentController];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender {
    return YES;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {
    return NO;
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        [app setDelegate:delegate];
        [app run];
    }
    return 0;
}
