// NSString+Regex.m — RegexKitLite drop-in using NSRegularExpression
#import "NSString+Regex.h"

@implementation NSString (Regex)

- (NSRegularExpression *)fn_regexForPattern:(NSString *)pattern
                                    options:(NSRegularExpressionOptions)opts {
    return [NSRegularExpression regularExpressionWithPattern:pattern
                                                     options:opts
                                                       error:nil];
}

- (BOOL)isMatchedByRegex:(NSString *)pattern {
    NSRegularExpression *re = [self fn_regexForPattern:pattern options:0];
    return re && [re numberOfMatchesInString:self
                                     options:0
                                       range:NSMakeRange(0, self.length)] > 0;
}

- (BOOL)isMatchedByRegex:(NSString *)pattern
                 options:(RKLRegexOptions)options
                 inRange:(NSRange)range
                   error:(NSError **)error {
    NSRegularExpression *re =
        [NSRegularExpression regularExpressionWithPattern:pattern
                                                  options:options
                                                    error:error];
    if (!re) return NO;
    return [re numberOfMatchesInString:self options:0 range:range] > 0;
}

- (NSString *)stringByMatching:(NSString *)pattern capture:(NSInteger)capture {
    NSRegularExpression *re = [self fn_regexForPattern:pattern options:0];
    if (!re) return nil;
    NSTextCheckingResult *m = [re firstMatchInString:self
                                             options:0
                                               range:NSMakeRange(0, self.length)];
    if (!m || capture >= (NSInteger)m.numberOfRanges) return nil;
    NSRange r = [m rangeAtIndex:capture];
    if (r.location == NSNotFound) return nil;
    return [self substringWithRange:r];
}

- (NSString *)stringByReplacingOccurrencesOfRegex:(NSString *)pattern
                                       withString:(NSString *)replacement {
    NSRegularExpression *re = [self fn_regexForPattern:pattern options:0];
    if (!re) return self;
    return [re stringByReplacingMatchesInString:self
                                        options:0
                                          range:NSMakeRange(0, self.length)
                                   withTemplate:replacement];
}

- (NSRange)rangeOfRegex:(NSString *)pattern {
    NSRegularExpression *re = [self fn_regexForPattern:pattern options:0];
    if (!re) return NSMakeRange(NSNotFound, 0);
    NSTextCheckingResult *m = [re firstMatchInString:self
                                             options:0
                                               range:NSMakeRange(0, self.length)];
    return m ? m.range : NSMakeRange(NSNotFound, 0);
}

@end
