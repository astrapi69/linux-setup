#!/usr/bin/env bash
set -e

INSTALL_DIR="/opt/epubcheck"
BIN_LINK="/usr/local/bin/epubcheck"

# Detect latest version from GitHub
echo "Fetching latest epubcheck version..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/w3c/epubcheck/releases/latest \
    | grep '"tag_name"' | cut -d '"' -f 4 | sed 's/^v//')

if [ -z "$LATEST_VERSION" ]; then
    echo "Could not detect latest version. Aborting."
    exit 1
fi

echo "Latest version found: $LATEST_VERSION"

# Check Java
if ! command -v java >/dev/null 2>&1; then
    echo "Java not found. Installing OpenJDK..."
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y default-jre
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm jre-openjdk
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y java-11-openjdk
    else
        echo "Unsupported distro. Install Java manually."
        exit 1
    fi
fi

# Prepare install dir
sudo mkdir -p "$INSTALL_DIR"
cd /tmp

ZIPNAME="epubcheck-${LATEST_VERSION}.zip"
URL="https://github.com/w3c/epubcheck/releases/download/v${LATEST_VERSION}/${ZIPNAME}"

echo "Downloading $URL..."
wget -q "$URL"

echo "Extracting..."
unzip -q "$ZIPNAME"
sudo rm -rf "${INSTALL_DIR:?}/*"
sudo mv "epubcheck-${LATEST_VERSION}"/* "$INSTALL_DIR/"
rm -rf "epubcheck-${LATEST_VERSION}" "$ZIPNAME"

# Wrapper
sudo tee "$BIN_LINK" >/dev/null <<EOF
#!/usr/bin/env bash
java -jar ${INSTALL_DIR}/epubcheck.jar "\$@"
EOF
sudo chmod +x "$BIN_LINK"

echo "✅ epubcheck ${LATEST_VERSION} installed successfully"
epubcheck --version
