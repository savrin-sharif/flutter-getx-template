#!/bin/bash
set -e

# -----------------------------
# 🚀 Flutter AAB Release Builder + Play-Store Style Release Notes + Release Name
# -----------------------------

# 0. Ask user for version bump type
echo "🔢 Select version bump type:"
select bump_type in "MAJOR" "MINOR" "PATCH" "Custom"; do
  case $bump_type in
    MAJOR) bump_level="MAJOR"; break ;;
    MINOR) bump_level="MINOR"; break ;;
    PATCH) bump_level="PATCH"; break ;;
    Custom) bump_level="CUSTOM"; break ;;
    *) echo "❌ Invalid option. Please choose again." ;;
  esac
done

# 1. New app version (if Custom)
if [ "$bump_level" == "CUSTOM" ]; then
  read -r -p "📝 Enter custom version (e.g., 2.1.0): " new_version
fi

# 2. Read current version and build number
if [ ! -f "pubspec.yaml" ]; then
  echo "❌ pubspec.yaml not found. Run this from your Flutter project root."
  exit 1
fi

current_version_line=$(grep '^version:' pubspec.yaml || true)
if [ -z "$current_version_line" ]; then
  echo "❌ Could not find 'version:' in pubspec.yaml"
  exit 1
fi

current_version=$(echo "$current_version_line" | sed -E 's/version: ([0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+/\1/')
current_build_number=$(echo "$current_version_line" | sed -E 's/.*\+([0-9]+)/\1/')

echo "📋 Current version: $current_version +$current_build_number"

# 3. Determine next version
IFS='.' read -r major minor patch <<< "$current_version"

if [ "$bump_level" == "MAJOR" ]; then
  major=$((major + 1)); minor=0; patch=0
  next_version="$major.$minor.$patch"
  echo "🚀 MAJOR bump: $current_version ➜ $next_version"
elif [ "$bump_level" == "MINOR" ]; then
  minor=$((minor + 1)); patch=0
  next_version="$major.$minor.$patch"
  echo "✨ MINOR bump: $current_version ➜ $next_version"
elif [ "$bump_level" == "PATCH" ]; then
  patch=$((patch + 1))
  next_version="$major.$minor.$patch"
  echo "🔧 PATCH bump: $current_version ➜ $next_version"
elif [ "$bump_level" == "CUSTOM" ]; then
  if ! echo "$new_version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "❌ Invalid custom version format. Use x.y.z (e.g., 2.1.0)"
    exit 1
  fi
  next_version="$new_version"
  echo "📝 Custom version set: $current_version ➜ $next_version"
fi

# 4. Always increment build number
next_build_number=$((current_build_number + 1))
echo "🔼 Build number incremented: $current_build_number ➜ $next_build_number"

# 4.1 Release name (for Play Console - internal)
# Optional override prompt
read -r -p "🏷️ Enter release name (press Enter for auto): " custom_release_name
if [ -n "$custom_release_name" ]; then
  release_name="$custom_release_name"
else
  release_name="Production v$next_version+$next_build_number"
fi
echo "✅ Release Name: $release_name"

# 5. Update pubspec.yaml
sed -i.bak -E "s/^version: .*/version: $next_version+$next_build_number/" pubspec.yaml
rm -f pubspec.yaml.bak

# 6. Refresh packages + clean
echo "🔄 Running flutter pub get..."
flutter pub get

echo "🧹 Cleaning project..."
flutter clean
flutter pub get

# 7. Build AAB (Release)
echo "🛠️ Building App Bundle (AAB) --release..."
flutter build appbundle --release --build-number="$next_build_number" --build-name="$next_version"

# 8. Collect artifacts
aab_path="build/app/outputs/bundle/release/app-release.aab"
if [ ! -f "$aab_path" ]; then
  echo "❌ AAB not found at: $aab_path"
  exit 1
fi

release_folder="build/app/releases/$next_version+$next_build_number"
mkdir -p "$release_folder"

target_aab="$release_folder/app-release-${next_version}+${next_build_number}.aab"
cp "$aab_path" "$target_aab"
echo "📦 AAB copied to: $target_aab"

# 9. Git operations (commit + tag)
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git add pubspec.yaml

  if git diff --cached --quiet; then
    echo "ℹ️ No staged changes to commit."
  else
    git commit -m "🔖 Bump version to $next_version+$next_build_number"
  fi

  tag_name="v$next_version+$next_build_number"

  if git rev-parse "$tag_name" >/dev/null 2>&1; then
    echo "⚠️ Tag already exists: $tag_name (skipping tag creation)"
  else
    git tag "$tag_name"
    echo "🏷️ Created tag: $tag_name"
  fi
else
  echo "⚠️ Not a git repository. Skipping git commit/tag."
fi

# 10. Generate Play-Store style Release Notes (clean + no author + no bump/refactor chores)
release_notes_file="$release_folder/RELEASE_NOTES.txt"

last_tag="initial"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  last_tag=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "initial")
fi

echo "🧾 Generating Play Store style release notes from: $last_tag ..."

raw_log=$(git log "$last_tag"..HEAD --pretty=format:"%s" --no-merges 2>/dev/null || true)

filtered_log=$(echo "$raw_log" | grep -Ev \
  '^(🔖|chore:|refactor:|build:|ci:|style:|test:|docs:|bump|version|format|lint|pub get|clean|signing|release signing|update gradle)' \
  || true)

user_facing=$(echo "$filtered_log" | grep -E \
  '^(feat:|fix:|perf:|improvement:|ui:|ux:|hotfix:|security:)' \
  || true)

if [ -z "$user_facing" ]; then
  user_facing="$filtered_log"
fi

cleaned=$(echo "$user_facing" \
  | sed -E 's/^(feat:|fix:|perf:|improvement:|ui:|ux:|hotfix:|security:)[ ]*//I' \
  | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' \
  | awk 'NF')

deduped=$(echo "$cleaned" | awk '!seen[$0]++')
final_list=$(echo "$deduped" | head -n 8)

if [ -z "$final_list" ]; then
  final_list="Performance improvements and bug fixes."
fi

# shellcheck disable=SC2001
bullets=$(echo "$final_list" | sed 's/^/- /')

cat > "$release_notes_file" <<EOL
Release name: $release_name
Version: v$next_version+$next_build_number

Release notes (en-US):
$bullets
EOL

echo "✅ Release notes saved at: $release_notes_file"

# 11. Optional push
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  read -r -p "🚀 Push commit and tags to remote repository? (y/n): " push_answer
  if [ "$push_answer" = "y" ]; then
    git push
    git push --tags
    echo "✅ Changes and tag pushed to remote."
  else
    echo "🛑 Skipped pushing to remote."
  fi
fi

# 12. Done
echo "🎯 AAB release finished: Version $next_version+$next_build_number"
echo "🏷️ Release Name: $release_name"
echo "📁 Output folder: $release_folder"
echo "📝 Notes: $release_notes_file"
