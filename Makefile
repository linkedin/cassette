default: build

clean:
	@xcodebuild -scheme Cassette clean

build:
	@xcodebuild -scheme Cassette build

test:
	@xcodebuild -scheme Cassette test