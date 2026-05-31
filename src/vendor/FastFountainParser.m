//  FastFountainParser.m — nyousefi/Fountain (MIT)
//  RegexKitLite replaced with NSString+Regex (NSRegularExpression-backed)
#import "FastFountainParser.h"
#import "FNElement.h"
#import "NSString+Regex.h"

static NSString * const kInlinePattern    = @"^([^\\t\\s][^:]+):\\s*([^\\t\\s].*$)";
static NSString * const kDirectivePattern = @"^([^\\t\\s][^:]+):([\\t\\s]*$)";

@implementation FastFountainParser

- (id)initWithString:(NSString *)string {
    self = [super init];
    if (self) {
        _elements  = [[NSMutableArray alloc] init];
        _titlePage = [[NSMutableArray alloc] init];
        [self parseContents:string];
    }
    return self;
}

- (id)initWithFile:(NSString *)filePath {
    self = [super init];
    if (self) {
        _elements  = [[NSMutableArray alloc] init];
        _titlePage = [[NSMutableArray alloc] init];
        NSError *error = nil;
        NSString *contents = [NSString stringWithContentsOfFile:filePath
                                                       encoding:NSUTF8StringEncoding
                                                          error:&error];
        if (!error) [self parseContents:contents];
    }
    return self;
}

- (void)parseContents:(NSString *)contents {
    contents = [contents stringByReplacingOccurrencesOfRegex:@"^\\s*" withString:@""];
    contents = [contents stringByReplacingOccurrencesOfRegex:@"\\r\\n|\\r|\\n" withString:@"\n"];
    contents = [NSString stringWithFormat:@"%@\n\n", contents];

    NSRange firstBlankLineRange = [contents rangeOfString:@"\n\n"];
    NSString *topOfDocument = [contents substringToIndex:firstBlankLineRange.location];

    // Title page
    BOOL foundTitlePage = NO;
    NSString *openKey = @"";
    NSMutableArray *openValues = [NSMutableArray array];
    NSArray *topLines = [topOfDocument componentsSeparatedByString:@"\n"];

    for (NSString *line in topLines) {
        if ([line isEqualToString:@""] || [line isMatchedByRegex:kDirectivePattern]) {
            foundTitlePage = YES;
            if (![openKey isEqualToString:@""]) {
                [self.titlePage addObject:@{openKey: openValues}];
            }
            openKey = [[line stringByMatching:kDirectivePattern capture:1] lowercaseString] ?: @"";
            if ([openKey isEqualToString:@"author"]) openKey = @"authors";
            openValues = [NSMutableArray array];
        } else if ([line isMatchedByRegex:kInlinePattern]) {
            foundTitlePage = YES;
            if (![openKey isEqualToString:@""]) {
                [self.titlePage addObject:@{openKey: openValues}];
                openKey = @"";
                openValues = [NSMutableArray array];
            }
            NSString *key   = [[line stringByMatching:kInlinePattern capture:1] lowercaseString];
            NSString *value = [line stringByMatching:kInlinePattern capture:2];
            if ([key isEqualToString:@"author"]) key = @"authors";
            [self.titlePage addObject:@{key: @[value ?: @""]}];
            openKey = @"";
            openValues = [NSMutableArray array];
        } else if (foundTitlePage) {
            [openValues addObject:[line stringByTrimmingCharactersInSet:
                                   [NSCharacterSet whitespaceCharacterSet]]];
        }
    }

    if (foundTitlePage) {
        if (![openKey isEqualToString:@""] || [self.titlePage count] > 0) {
            if (![openKey isEqualToString:@""]) {
                [self.titlePage addObject:@{openKey: openValues}];
            }
            // Record how many lines the title page occupies in the original text
            // (+1 for the blank separator line after the title page block).
            _titlePageLineCount = topLines.count + 1;
            contents = [contents stringByReplacingOccurrencesOfString:topOfDocument
                                                           withString:@""];
        }
    }

    // Body
    contents = [NSString stringWithFormat:@"\n%@", contents];
    NSArray *lines = [contents componentsSeparatedByCharactersInSet:
                      [NSCharacterSet newlineCharacterSet]];

    NSUInteger newlinesBefore = 0;
    BOOL isCommentBlock = NO;
    BOOL isInsideDialogueBlock = NO;
    NSMutableString *commentText = [NSMutableString string];

    for (NSUInteger index = 0; index < lines.count; index++) {
        NSString *line = [lines objectAtIndex:index];

        // Lyrics
        if (line.length > 0 && [line characterAtIndex:0] == '~') {
            FNElement *last = [self.elements lastObject];
            if (!last) {
                [self.elements addObject:[FNElement elementOfType:@"Lyrics" text:line]];
                newlinesBefore = 0; continue;
            }
            if ([last.elementType isEqualToString:@"Lyrics"] && newlinesBefore > 0)
                [self.elements addObject:[FNElement elementOfType:@"Lyrics" text:@" "]];
            [self.elements addObject:[FNElement elementOfType:@"Lyrics" text:line]];
            newlinesBefore = 0; continue;
        }

        // Forced action
        if (line.length > 0 && [line characterAtIndex:0] == '!') {
            [self.elements addObject:[FNElement elementOfType:@"Action" text:line]];
            newlinesBefore = 0; continue;
        }

        // Forced character
        if (line.length > 0 && [line characterAtIndex:0] == '@') {
            [self.elements addObject:[FNElement elementOfType:@"Character" text:line]];
            newlinesBefore = 0;
            isInsideDialogueBlock = YES; continue;
        }

        // Empty line in dialogue block (two spaces)
        if ([line isMatchedByRegex:@"^\\s{2}$"] && isInsideDialogueBlock) {
            newlinesBefore = 0;
            NSUInteger lastIdx = self.elements.count - 1;
            FNElement *prev = [self.elements objectAtIndex:lastIdx];
            if ([prev.elementType isEqualToString:@"Dialogue"]) {
                prev.elementText = [NSString stringWithFormat:@"%@\n%@", prev.elementText, line];
                [self.elements removeObjectAtIndex:lastIdx];
                [self.elements addObject:prev];
            } else {
                [self.elements addObject:[FNElement elementOfType:@"Dialogue" text:line]];
            }
            continue;
        }

        if ([line isMatchedByRegex:@"^\\s{2,}$"]) {
            [self.elements addObject:[FNElement elementOfType:@"Action" text:line]];
            newlinesBefore = 0; continue;
        }

        // Blank line
        if ([line isEqualToString:@""] && !isCommentBlock) {
            isInsideDialogueBlock = NO;
            newlinesBefore++; continue;
        }

        // Open boneyard
        if ([line isMatchedByRegex:@"^\\/\\*"]) {
            if ([line isMatchedByRegex:@"\\*\\/\\s*$"]) {
                NSString *t = [[line stringByReplacingOccurrencesOfString:@"/*" withString:@""]
                                     stringByReplacingOccurrencesOfString:@"*/" withString:@""];
                [self.elements addObject:[FNElement elementOfType:@"Boneyard" text:t]];
                newlinesBefore = 0;
            } else {
                isCommentBlock = YES;
                [commentText appendString:@"\n"];
            }
            continue;
        }

        // Close boneyard
        if ([line isMatchedByRegex:@"\\*\\/\\s*$"]) {
            NSString *t = [line stringByReplacingOccurrencesOfString:@"*/" withString:@""];
            if (!t || [t isMatchedByRegex:@"^\\s*$"])
                [commentText appendString:[t stringByTrimmingCharactersInSet:
                                           [NSCharacterSet whitespaceCharacterSet]]];
            isCommentBlock = NO;
            [self.elements addObject:[FNElement elementOfType:@"Boneyard" text:commentText]];
            commentText = [NSMutableString string];
            newlinesBefore = 0; continue;
        }

        if (isCommentBlock) {
            [commentText appendString:line];
            [commentText appendString:@"\n"];
            continue;
        }

        // Page break
        if ([line isMatchedByRegex:@"^={3,}\\s*$"]) {
            [self.elements addObject:[FNElement elementOfType:@"Page Break" text:line]];
            newlinesBefore = 0; continue;
        }

        // Synopsis
        NSString *trimmed = [line stringByTrimmingCharactersInSet:
                             [NSCharacterSet whitespaceCharacterSet]];
        if (trimmed.length > 0 && [trimmed characterAtIndex:0] == '=') {
            NSRange mr = [line rangeOfRegex:@"^\\s*={1}"];
            NSString *t = (mr.location != NSNotFound)
                ? [line stringByReplacingCharactersInRange:mr withString:@""] : line;
            [self.elements addObject:[FNElement elementOfType:@"Synopsis" text:t]];
            continue;
        }

        // Comment [[...]]
        if (newlinesBefore > 0 &&
            [line isMatchedByRegex:@"^\\s*\\[{2}\\s*([^\\]\\n])+\\s*\\]{2}\\s*$"]) {
            NSString *t = [[[line stringByReplacingOccurrencesOfString:@"[[" withString:@""]
                                  stringByReplacingOccurrencesOfString:@"]]" withString:@""]
                                  stringByTrimmingCharactersInSet:
                                      [NSCharacterSet whitespaceCharacterSet]];
            [self.elements addObject:[FNElement elementOfType:@"Comment" text:t]];
            continue;
        }

        // Section heading
        if (trimmed.length > 0 && [trimmed characterAtIndex:0] == '#') {
            NSRange mr = [line rangeOfRegex:@"^\\s*#+"];
            NSUInteger depth = (mr.location != NSNotFound) ? mr.length : 1;
            NSString *t = (mr.location != NSNotFound)
                ? [line substringFromIndex:(mr.location + mr.length)] : line;
            if (!t || t.length == 0) { index++; continue; }
            FNElement *el = [FNElement elementOfType:@"Section Heading" text:t];
            el.sectionDepth = depth;
            [self.elements addObject:el];
            newlinesBefore = 0; continue;
        }

        // Forced scene heading
        if (line.length > 1 && [line characterAtIndex:0] == '.' && [line characterAtIndex:1] != '.') {
            newlinesBefore = 0;
            NSString *sceneNum = nil, *t = nil;
            if ([line isMatchedByRegex:@"#([^\\n#]*?)#\\s*$"]) {
                sceneNum = [line stringByMatching:@"#([^\\n#]*?)#\\s*$" capture:1];
                t = [line stringByReplacingOccurrencesOfRegex:@"#([^\\n#]*?)#\\s*$" withString:@""];
                t = [[t substringFromIndex:1] stringByTrimmingCharactersInSet:
                     [NSCharacterSet whitespaceCharacterSet]];
            } else {
                t = [[line substringFromIndex:1] stringByTrimmingCharactersInSet:
                     [NSCharacterSet whitespaceCharacterSet]];
            }
            FNElement *el = [FNElement elementOfType:@"Scene Heading" text:t];
            if (sceneNum) el.sceneNumber = sceneNum;
            [self.elements addObject:el];
            continue;
        }

        // Scene heading (INT./EXT.)
        if (newlinesBefore > 0 &&
            [line isMatchedByRegex:@"^(INT|EXT|EST|(I|INT)\\.?\\/(E|EXT)\\.?)[\\.\\-\\s][^\\n]+$"
                           options:RKLCaseless
                           inRange:NSMakeRange(0, line.length)
                             error:nil]) {
            newlinesBefore = 0;
            NSString *sceneNum = nil, *t = nil;
            if ([line isMatchedByRegex:@"#([^\\n#]*?)#\\s*$"]) {
                sceneNum = [line stringByMatching:@"#([^\\n#]*?)#\\s*$" capture:1];
                t = [line stringByReplacingOccurrencesOfRegex:@"#([^\\n#]*?)#\\s*$" withString:@""];
            } else {
                t = line;
            }
            FNElement *el = [FNElement elementOfType:@"Scene Heading" text:t];
            if (sceneNum) el.sceneNumber = sceneNum;
            [self.elements addObject:el];
            continue;
        }

        // Transitions
        if ([line isMatchedByRegex:@"[^a-z]*TO:$"]) {
            [self.elements addObject:[FNElement elementOfType:@"Transition" text:line]];
            newlinesBefore = 0; continue;
        }
        NSString *lineNoLeading = [line stringByReplacingOccurrencesOfRegex:@"^\\s*" withString:@""];
        NSSet *transitions = [NSSet setWithArray:@[@"FADE OUT.", @"CUT TO BLACK.", @"FADE TO BLACK."]];
        if ([transitions containsObject:lineNoLeading]) {
            [self.elements addObject:[FNElement elementOfType:@"Transition" text:line]];
            newlinesBefore = 0; continue;
        }

        // Forced transition / centered action
        if (line.length > 0 && [line characterAtIndex:0] == '>') {
            if (line.length > 1 && [line characterAtIndex:(line.length - 1)] == '<') {
                NSString *t = [[line substringFromIndex:1] stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceCharacterSet]];
                t = [[t substringToIndex:(t.length - 1)] stringByTrimmingCharactersInSet:
                     [NSCharacterSet whitespaceCharacterSet]];
                FNElement *el = [FNElement elementOfType:@"Action" text:t];
                el.isCentered = YES;
                [self.elements addObject:el];
            } else {
                NSString *t = [[line substringFromIndex:1] stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceCharacterSet]];
                [self.elements addObject:[FNElement elementOfType:@"Transition" text:t]];
            }
            newlinesBefore = 0; continue;
        }

        // Character
        if (newlinesBefore > 0 && [line isMatchedByRegex:@"^[^a-z]+(\\(cont'd\\))?$"]) {
            NSUInteger nextIdx = index + 1;
            NSString *nextLine = (nextIdx < lines.count) ? [lines objectAtIndex:nextIdx] : nil;
            // Classify as character when the immediately-following line is non-blank,
            // OR when we are at the end of the document (only blank lines remain —
            // the user may still be typing the dialogue line).
            BOOL isChar = (nextLine != nil && nextLine.length > 0);
            if (!isChar && nextLine != nil) {
                BOOL moreContent = NO;
                for (NSUInteger k = nextIdx + 1; k < lines.count; k++) {
                    if (((NSString *)[lines objectAtIndex:k]).length > 0) { moreContent = YES; break; }
                }
                if (!moreContent) isChar = YES;
            }
            if (isChar) {
                newlinesBefore = 0;
                FNElement *el = [FNElement elementOfType:@"Character" text:line];
                if ([line isMatchedByRegex:@"\\^\\s*$"]) {
                    el.isDualDialogue = YES;
                    el.elementText = [el.elementText stringByReplacingOccurrencesOfRegex:
                                      @"\\s*\\^\\s*$" withString:@""];
                    NSInteger bi = (NSInteger)self.elements.count - 1;
                    while (bi >= 0) {
                        FNElement *prev = [self.elements objectAtIndex:bi];
                        if ([prev.elementType isEqualToString:@"Character"]) {
                            prev.isDualDialogue = YES; break;
                        }
                        bi--;
                    }
                }
                [self.elements addObject:el];
                isInsideDialogueBlock = YES; continue;
            }
        }

        // Dialogue and parentheticals
        if (isInsideDialogueBlock) {
            if (newlinesBefore == 0 && [line isMatchedByRegex:@"^\\s*\\("]) {
                [self.elements addObject:[FNElement elementOfType:@"Parenthetical" text:line]];
            } else {
                NSUInteger lastIdx = self.elements.count - 1;
                FNElement *prev = [self.elements objectAtIndex:lastIdx];
                if ([prev.elementType isEqualToString:@"Dialogue"]) {
                    prev.elementText = [NSString stringWithFormat:@"%@\n%@", prev.elementText, line];
                    [self.elements removeObjectAtIndex:lastIdx];
                    [self.elements addObject:prev];
                } else {
                    [self.elements addObject:[FNElement elementOfType:@"Dialogue" text:line]];
                }
            }
            continue;
        }

        // Merge adjacent action lines
        if (newlinesBefore == 0 && self.elements.count > 0) {
            NSUInteger lastIdx = self.elements.count - 1;
            FNElement *prev = [self.elements objectAtIndex:lastIdx];
            if ([prev.elementType isEqualToString:@"Scene Heading"])
                prev.elementType = @"Action";
            prev.elementText = [NSString stringWithFormat:@"%@\n%@", prev.elementText, line];
            [self.elements removeObjectAtIndex:lastIdx];
            [self.elements addObject:prev];
            newlinesBefore = 0;
        } else {
            [self.elements addObject:[FNElement elementOfType:@"Action" text:line]];
            newlinesBefore = 0;
        }
    }
}

@end
