# Load signing credentials from .env if it exists
-include .env
export

GO_LDFLAGS = -X main.version=$$(git describe --exact-match --tags || echo "dev") -X main.commit=$$(git rev-parse --short HEAD)

server:
	GOOS=darwin GOARCH=amd64 go build -ldflags "$(GO_LDFLAGS)" -o mobius-hotline-server-amd64 cmd/mobius-hotline-server/main.go
	GOOS=darwin GOARCH=arm64 go build -ldflags "$(GO_LDFLAGS)" -o mobius-hotline-server-arm64 cmd/mobius-hotline-server/main.go
	lipo -create -output mobius-hotline-server mobius-hotline-server-amd64 mobius-hotline-server-arm64
	rm mobius-hotline-server-amd64 mobius-hotline-server-arm64

gui:
	cd MobiusAdmin && xcodegen generate 2>/dev/null && \
	xcodebuild -project MobiusAdmin.xcodeproj -scheme MobiusAdmin -configuration Debug \
		-derivedDataPath build \
		ARCHS="x86_64 arm64" \
		ONLY_ACTIVE_ARCH=NO \
		build
	@echo "\nBuild output: MobiusAdmin/build/Build/Products/Debug/MobiusAdmin.app"

gui-release:
	cd MobiusAdmin && xcodegen generate 2>/dev/null && \
	xcodebuild -project MobiusAdmin.xcodeproj -scheme MobiusAdmin -configuration Release \
		-derivedDataPath build \
		ARCHS="x86_64 arm64" \
		ONLY_ACTIVE_ARCH=NO \
		CODE_SIGN_IDENTITY="$(APPLE_SIGNING_IDENTITY)" \
		DEVELOPMENT_TEAM="$(APPLE_TEAM_ID)" \
		build
	@echo "\nBuild output: MobiusAdmin/build/Build/Products/Release/MobiusAdmin.app"

gui-notarize: gui-release
	@echo "Creating zip for notarization..."
	ditto -c -k --keepParent MobiusAdmin/build/Build/Products/Release/MobiusAdmin.app MobiusAdmin/build/MobiusAdmin.zip
	@echo "Submitting to Apple for notarization..."
	xcrun notarytool submit MobiusAdmin/build/MobiusAdmin.zip \
		--apple-id "$(APPLE_ID)" \
		--password "$(APPLE_PASSWORD)" \
		--team-id "$(APPLE_TEAM_ID)" \
		--wait
	@echo "Stapling notarization ticket..."
	xcrun stapler staple MobiusAdmin/build/Build/Products/Release/MobiusAdmin.app
	@echo "\nNotarized app: MobiusAdmin/build/Build/Products/Release/MobiusAdmin.app"

.PHONY: server gui gui-release gui-notarize
