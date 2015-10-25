XCPRETTY := xcpretty -c && exit ${PIPESTATUS[0]}

SDK ?= "iphonesimulator8.4"
DESTINATION ?= "platform=iOS Simulator,name=iPhone 5"
PROJECT := Cassette
XC_ARGS := -scheme $(PROJECT) -sdk $(SDK) -destination $(DESTINATION)

default:
	build

clean:
	xcodebuild $(XC_ARGS) clean | $(XCPRETTY)

build:
	xcodebuild $(XC_ARGS) | $(XCPRETTY)

test:
	xcodebuild $(XC_ARGS) test | $(XCPRETTY)

xcbuild:
	xctool $(XC_ARGS)

xctest:
	xctool $(XC_ARGS) test

.PHONY: test build clean
.SILENT:
