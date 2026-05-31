#import <XCTest/XCTest.h>
#import "../src/vendor/NSString+Regex.h"

@interface NSStringRegexTests : XCTestCase
@end

@implementation NSStringRegexTests

- (void)test_isMatchedByRegex_match {
    XCTAssertTrue([@"INT. OFFICE - DAY" isMatchedByRegex:@"^INT\\.?"]);
}

- (void)test_isMatchedByRegex_noMatch {
    XCTAssertFalse([@"hello" isMatchedByRegex:@"^INT\\.?"]);
}

- (void)test_isMatchedByRegex_options_caseless {
    XCTAssertTrue([@"int. office" isMatchedByRegex:@"^INT"
                                           options:RKLCaseless
                                           inRange:NSMakeRange(0, 11)
                                             error:nil]);
}

- (void)test_isMatchedByRegex_options_caseSensitive_fails {
    XCTAssertFalse([@"int. office" isMatchedByRegex:@"^INT"
                                            options:0
                                            inRange:NSMakeRange(0, 11)
                                              error:nil]);
}

- (void)test_stringByMatching_capture0_fullMatch {
    NSString *r = [@"Title: Chinatown" stringByMatching:@"^(\\w+): (.+)" capture:0];
    XCTAssertEqualObjects(r, @"Title: Chinatown");
}

- (void)test_stringByMatching_capture1 {
    NSString *r = [@"Title: Chinatown" stringByMatching:@"^(\\w+): (.+)" capture:1];
    XCTAssertEqualObjects(r, @"Title");
}

- (void)test_stringByMatching_capture2 {
    NSString *r = [@"Title: Chinatown" stringByMatching:@"^(\\w+): (.+)" capture:2];
    XCTAssertEqualObjects(r, @"Chinatown");
}

- (void)test_stringByMatching_noMatch_returnsNil {
    NSString *r = [@"hello" stringByMatching:@"^(\\d+)" capture:1];
    XCTAssertNil(r);
}

- (void)test_stringByReplacingOccurrencesOfRegex_stripsLeadingWhitespace {
    NSString *r = [@"   hello" stringByReplacingOccurrencesOfRegex:@"^\\s*" withString:@""];
    XCTAssertEqualObjects(r, @"hello");
}

- (void)test_stringByReplacingOccurrencesOfRegex_normalizeLineEndings {
    NSString *r = [@"a\r\nb\rc" stringByReplacingOccurrencesOfRegex:@"\\r\\n|\\r|\\n"
                                                         withString:@"\n"];
    XCTAssertEqualObjects(r, @"a\nb\nc");
}

- (void)test_stringByReplacingOccurrencesOfRegex_noMatch_unchanged {
    NSString *r = [@"hello" stringByReplacingOccurrencesOfRegex:@"\\d+" withString:@"X"];
    XCTAssertEqualObjects(r, @"hello");
}

- (void)test_rangeOfRegex_found {
    NSRange r = [@"## Section" rangeOfRegex:@"^\\s*#+"];
    XCTAssertNotEqual(r.location, (NSUInteger)NSNotFound);
    XCTAssertEqual(r.length, (NSUInteger)2); // "##"
}

- (void)test_rangeOfRegex_notFound {
    NSRange r = [@"hello" rangeOfRegex:@"^\\d+"];
    XCTAssertEqual(r.location, (NSUInteger)NSNotFound);
}

@end
