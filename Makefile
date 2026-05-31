APP     = build/fountlion.app
BINARY  = $(APP)/Contents/MacOS/fountlion
BUNDLE  = build/FountainTests.xctest
TESTBIN = $(BUNDLE)/Contents/MacOS/FountainTests

XCDEV   = /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer
XCFWK   = $(XCDEV)/Library/Frameworks
XCTEST  = $(XCDEV)/Library/Xcode/Agents/xctest

CC      = clang
CFLAGS  = -fobjc-arc

SRCS    = src/main.m src/FountainDocument.m src/FountainHighlighter.m src/FountainTextView.m \
          src/vendor/FNElement.m src/vendor/FastFountainParser.m src/vendor/NSString+Regex.m
OBJS    = $(SRCS:%.m=build/obj/%.o)

TEST_SRCS = tests/FountainDocumentTests.m tests/FastFountainParserTests.m \
            tests/NSStringRegexTests.m tests/FountainHighlighterTests.m \
            tests/FountainTextViewTests.m
TEST_OBJS = $(TEST_SRCS:%.m=build/obj/%.o)

APP_OBJS = $(filter-out build/obj/src/main.o, $(OBJS))

.PHONY: all test deploy watch clean

all: $(BINARY)
	cp Info.plist $(APP)/Contents/
	open $(APP)

$(BINARY): $(OBJS) | $(APP)/Contents/MacOS
	$(CC) $(CFLAGS) -framework Cocoa -o $@ $^

# Test object rule must come before the generic rule (BSD make: first match wins)
build/obj/tests/%.o: tests/%.m | build/obj/tests
	$(CC) $(CFLAGS) -F $(XCFWK) -framework XCTest -I. -c -o $@ $<

build/obj/src/%.o: src/%.m | build/obj/src build/obj/src/vendor
	$(CC) $(CFLAGS) -I. -c -o $@ $<

build/obj/%.o: %.m | build/obj
	$(CC) $(CFLAGS) -c -o $@ $<

$(APP)/Contents/MacOS $(APP)/Contents build/obj build/obj/src build/obj/src/vendor build/obj/tests:
	mkdir -p $@

test: $(TESTBIN)
	$(XCTEST) $(BUNDLE)

$(TESTBIN): $(APP_OBJS) $(TEST_OBJS) | $(BUNDLE)/Contents/MacOS
	$(CC) $(CFLAGS) -framework Cocoa -F $(XCFWK) -framework XCTest -rpath $(XCFWK) \
	    -bundle -I. -o $@ $^

$(BUNDLE)/Contents/MacOS:
	mkdir -p $@

clean:
	rm -rf build
