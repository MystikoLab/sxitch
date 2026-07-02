build:
	xcodebuild -scheme "Copy of sxitch" -project sxitch.xcodeproj -quiet build

run: build
	/Users/umangsurana/Library/Developer/Xcode/DerivedData/sxitch-gvgkztjbeqqvkshbtsiwxyydklwv/Build/Products/Release/sxitch.app/Contents/MacOS/sxitch
