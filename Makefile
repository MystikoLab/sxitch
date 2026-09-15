build:
	xcodebuild -scheme sxitch -project sxitch.xcodeproj -quiet build

release:
	xcodebuild -scheme sxitch -project sxitch.xcodeproj -configuration Release -quiet build

run: release
	pkill -x sxitch || true
	/Users/umangsurana/Library/Developer/Xcode/DerivedData/sxitch-gvgkztjbeqqvkshbtsiwxyydklwv/Build/Products/Release/sxitch.app/Contents/MacOS/sxitch
