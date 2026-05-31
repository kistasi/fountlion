// NSString+Regex.h — drop-in for RegexKitLite using NSRegularExpression (10.7+)
#import <Foundation/Foundation.h>

typedef NSUInteger RKLRegexOptions;
static const RKLRegexOptions RKLCaseless = NSRegularExpressionCaseInsensitive;

@interface NSString (Regex)
- (BOOL)isMatchedByRegex:(NSString *)pattern;
- (BOOL)isMatchedByRegex:(NSString *)pattern
                 options:(RKLRegexOptions)options
                 inRange:(NSRange)range
                   error:(NSError **)error;
- (NSString *)stringByMatching:(NSString *)pattern capture:(NSInteger)capture;
- (NSString *)stringByReplacingOccurrencesOfRegex:(NSString *)pattern
                                       withString:(NSString *)replacement;
- (NSRange)rangeOfRegex:(NSString *)pattern;
@end
