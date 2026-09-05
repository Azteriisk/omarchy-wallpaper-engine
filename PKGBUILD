# Maintainer: Azteriisk <https://github.com/Azteriisk>
pkgname=omarchy-plugin-wallpaper-engine-git
pkgver=1.0.0.r0.g2923b6c
pkgrel=1
pkgdesc="Steam Wallpaper Engine integration for Omarchy Desktop with Scene, Video, Web, and PipeWire Audio Visualizer support"
arch=('any')
url="https://github.com/Azteriisk/omarchy-wallpaper-engine"
license=('MIT')
depends=('hyprland' 'quickshell' 'linux-wallpaperengine-git')
optdepends=(
  'gtk-layer-shell: for HTML5/Web wallpapers'
  'python-gobject: for HTML5/Web wallpapers'
)
makedepends=('git')
provides=('omarchy-plugin-wallpaper-engine')
conflicts=('omarchy-plugin-wallpaper-engine')
source=("git+https://github.com/Azteriisk/omarchy-wallpaper-engine.git")
md5sums=('SKIP')

pkgver() {
  cd "$srcdir/omarchy-wallpaper-engine"
  printf "1.0.0.r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

package() {
  cd "$srcdir/omarchy-wallpaper-engine"

  # 1. Install CLI helper scripts
  install -Dm755 scripts/omarchy-wpe "$pkgdir/usr/bin/omarchy-wpe"
  install -Dm755 scripts/omarchy-toggle-webkit-crash-alerts "$pkgdir/usr/bin/omarchy-toggle-webkit-crash-alerts"
  install -Dm755 scripts/wpe-layer-web.py "$pkgdir/usr/share/omarchy/plugins/azterisk.wallpaper-engine/scripts/wpe-layer-web.py"

  # 2. Install Omarchy plugin files
  install -d "$pkgdir/usr/share/omarchy/plugins/azterisk.wallpaper-engine"
  install -Dm644 manifest.json "$pkgdir/usr/share/omarchy/plugins/azterisk.wallpaper-engine/manifest.json"
  install -Dm644 Panel.qml "$pkgdir/usr/share/omarchy/plugins/azterisk.wallpaper-engine/Panel.qml"
  install -Dm644 Service.qml "$pkgdir/usr/share/omarchy/plugins/azterisk.wallpaper-engine/Service.qml"
  install -Dm644 WpeSlider.qml "$pkgdir/usr/share/omarchy/plugins/azterisk.wallpaper-engine/WpeSlider.qml"
  install -Dm644 README.md "$pkgdir/usr/share/omarchy/plugins/azterisk.wallpaper-engine/README.md"
  install -Dm755 install.sh "$pkgdir/usr/share/omarchy/plugins/azterisk.wallpaper-engine/install.sh"
  install -Dm755 uninstall.sh "$pkgdir/usr/share/omarchy/plugins/azterisk.wallpaper-engine/uninstall.sh"

  # 3. Theme hook
  install -Dm755 hooks/theme-set.sh "$pkgdir/usr/share/omarchy/hooks/theme-set.d/wpe-theme-sync.sh"
}
