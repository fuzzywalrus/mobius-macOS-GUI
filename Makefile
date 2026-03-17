# Load signing credentials from .env if it exists
-include .env
export

server:
	go build -ldflags "-X main.version=$$(git describe --exact-match --tags || echo "dev" ) -X main.commit=$$(git rev-parse --short HEAD)" -o mobius-hotline-server cmd/mobius-hotline-server/main.go

gui:
	cd MobiusAdmin && xcodegen generate 2>/dev/null && \
	xcodebuild -project MobiusAdmin.xcodeproj -scheme MobiusAdmin -configuration Debug -derivedDataPath build build
	@echo "\nBuild output: MobiusAdmin/build/Build/Products/Debug/MobiusAdmin.app"

gui-release:
	cd MobiusAdmin && xcodegen generate 2>/dev/null && \
	xcodebuild -project MobiusAdmin.xcodeproj -scheme MobiusAdmin -configuration Release \
		-derivedDataPath build \
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
