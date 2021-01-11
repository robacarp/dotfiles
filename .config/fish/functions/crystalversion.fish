function crystalversion
    set -l distribution_version (curl --silent https://github.com/crystal-lang/crystal/releases.atom | xml2 | awk -F '=' '/\/feed\/entry\/title/ { print $2 }' | head -n 1)
    set -l installed_version (crystal -v | head -n 1 | awk '{ print $2 }')
    echo "Latest Crystal Release $distribution_version"
    echo "Installed Crystal $installed_version"
end
