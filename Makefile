server:
	go build -ldflags "-X main.version=$$(git describe --exact-match --tags || echo "dev" ) -X main.commit=$$(git rev-parse --short HEAD)" -o mobius-hotline-server cmd/mobius-hotline-server/main.go

gui:
	cd MobiusAdmin && xcodegen generate 2>/dev/null && \
	xcodebuild -project MobiusAdmin.xcodeproj -scheme MobiusAdmin -configuration Debug -derivedDataPath build build
	@echo "\nBuild output: MobiusAdmin/build/Build/Products/Debug/MobiusAdmin.app"

gui-release:
	cd MobiusAdmin && xcodegen generate 2>/dev/null && \
	xcodebuild -project MobiusAdmin.xcodeproj -scheme MobiusAdmin -configuration Release -derivedDataPath build build
	@echo "\nBuild output: MobiusAdmin/build/Build/Products/Release/MobiusAdmin.app"
