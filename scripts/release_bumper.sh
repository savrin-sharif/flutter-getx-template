#!/bin/bash

# -----------------------------
# 🚀 Full Release Bumper + Split APK Builder + Release Notes Generator
# -----------------------------

# 0. Ask user for version bump type
echo "🔢 Select version bump type:"
select bump_type in "AUTO" "MAJOR" "MINOR" "PATCH" "Custom"; do
  case $bump_type in
    AUTO)
      bump_level="AUTO"
      break
      ;;
    MAJOR)
      bump_level="MAJOR"
      break
      ;;
    MINOR)
      bump_level="MINOR"
      break
      ;;
    PATCH)
      bump_level="PATCH"
      break
      ;;
    Custom)
      bump_level="CUSTOM"
      break
      ;;
    *)
      echo "❌ Invalid option. Please choose again."
      ;;
  esac
done

# 1. New app version (if Custom)
if [ "$bump_level" == "CUSTOM" ]; then
  read -r -p "📝 Enter custom version (e.g., 2.1.0): " new_version
fi

# 2. Read current version and build number
current_version_line=$(grep '^version:' pubspec.yaml)
current_version=$(echo "$current_version_line" | sed -E 's/version: ([0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+/\1/')
current_build_number=$(echo "$current_version_line" | sed -E 's/.*\+([0-9]+)/\1/')

# 3. Show current info
echo "📋 Current version: $current_version +$current_build_number"

# 3.1 Resolve AUTO baseline from last Android bump tag
auto_base_version="$current_version"
auto_base_build="$current_build_number"
auto_detected_bump="PATCH"
android_last_bump_tag=""

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  android_last_bump_tag=$(git tag --list --sort=-creatordate \
    | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$' \
    | head -n 1)
fi

if [ "$bump_level" == "AUTO" ]; then
  if [ -n "$android_last_bump_tag" ]; then
    auto_base_version=$(echo "$android_last_bump_tag" | sed -E 's/^v([0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+$/\1/')
    auto_base_build=$(echo "$android_last_bump_tag" | sed -E 's/^v[0-9]+\.[0-9]+\.[0-9]+\+([0-9]+)$/\1/')
    auto_log=$(git log "$android_last_bump_tag"..HEAD --pretty=format:"%s%n%b" --no-merges 2>/dev/null || true)

    if echo "$auto_log" | grep -Eqi 'BREAKING CHANGE|^[[:alpha:]][[:alnum:]_-]*(\([^)]+\))?!:'; then
      auto_detected_bump="MAJOR"
    elif echo "$auto_log" | grep -Eqi '^feat(\([^)]+\))?:'; then
      auto_detected_bump="MINOR"
    else
      auto_detected_bump="PATCH"
    fi

    echo "🤖 AUTO base tag: $android_last_bump_tag (detected $auto_detected_bump bump)"
  else
    echo "🤖 AUTO: No Android bump tag found. Falling back to PATCH from pubspec version."
  fi
fi

# 4. Determine next version
resolved_bump_level="$bump_level"
version_seed="$current_version"
if [ "$bump_level" == "AUTO" ]; then
  resolved_bump_level="$auto_detected_bump"
  version_seed="$auto_base_version"
fi

IFS='.' read -r major minor patch <<< "$version_seed"

if [ "$resolved_bump_level" == "MAJOR" ]; then
  major=$((major + 1))
  minor=0
  patch=0
  next_version="$major.$minor.$patch"
  if [ "$bump_level" == "AUTO" ]; then
    echo "🤖 AUTO resolved to MAJOR: $version_seed ➔ $next_version"
  else
    echo "🚀 MAJOR bump: $current_version ➔ $next_version"
  fi
elif [ "$resolved_bump_level" == "MINOR" ]; then
  minor=$((minor + 1))
  patch=0
  next_version="$major.$minor.$patch"
  if [ "$bump_level" == "AUTO" ]; then
    echo "🤖 AUTO resolved to MINOR: $version_seed ➔ $next_version"
  else
    echo "✨ MINOR bump: $current_version ➔ $next_version"
  fi
elif [ "$resolved_bump_level" == "PATCH" ]; then
  patch=$((patch + 1))
  next_version="$major.$minor.$patch"
  if [ "$bump_level" == "AUTO" ]; then
    echo "🤖 AUTO resolved to PATCH: $version_seed ➔ $next_version"
  else
    echo "🔧 PATCH bump: $current_version ➔ $next_version"
  fi
elif [ "$bump_level" == "CUSTOM" ]; then
  next_version="$new_version"
  echo "📝 Custom version set: $current_version ➔ $new_version"
fi

# 5. Always increment build number
build_seed="$current_build_number"
if [ "$bump_level" == "AUTO" ] && [ "$auto_base_build" -gt "$build_seed" ]; then
  build_seed="$auto_base_build"
fi
next_build_number=$((build_seed + 1))
echo "🔼 Build number incremented: $build_seed ➔ $next_build_number"

# 6. Update pubspec.yaml
sed -i.bak -E "s/version: .*/version: $next_version+$next_build_number/" pubspec.yaml
rm pubspec.yaml.bak

# 7. Refresh Flutter packages
echo "🔄 Running flutter pub get..."
flutter pub get

# 8. Clean project
echo "🧹 Cleaning project..."
flutter clean
flutter pub get

# 9. Build APK (split per ABI)
echo "🛠️ Building APK with split-per-abi..."
flutter build apk --split-per-abi --build-number=$next_build_number --build-name="$next_version"

# 10. Rename APKs
apk_output_dir="build/app/outputs/flutter-apk"
release_folder="build/app/releases/$next_version+$next_build_number"

mkdir -p "$release_folder"

for apk in "$apk_output_dir"/*.apk; do
    if [[ "$apk" == *"armeabi"* ]]; then
        mv "$apk" "$release_folder/app-armeabi-v7a-${next_version}+${next_build_number}.apk"
    elif [[ "$apk" == *"arm64"* ]]; then
        mv "$apk" "$release_folder/app-arm64-v8a-${next_version}+${next_build_number}.apk"
    elif [[ "$apk" == *"x86_64"* ]]; then
        mv "$apk" "$release_folder/app-x86_64-${next_version}+${next_build_number}.apk"
    fi
done

echo "📦 APKs moved and renamed into: $release_folder"

# 11. Git operations
git add pubspec.yaml
git commit -m "🔖 Bump version to $next_version+$next_build_number"
git tag "v$next_version+$next_build_number"

# 12. Push changes
read -r -p "🚀 Push to remote repository? (y/n): " push_answer
if [ "$push_answer" = "y" ]; then
  git push
  git push --tags
  echo "✅ Changes and tag pushed to remote."
else
  echo "🛑 Skipped pushing to remote."
fi

# 13. Firebase App Distribution
read -r -p "🚀 Upload APK to Firebase App Distribution? (y/n): " upload_answer
if [ "$upload_answer" = "y" ]; then
  echo "📤 Uploading to Firebase..."

  firebase appdistribution:distribute "$release_folder/app-arm64-v8a-${next_version}+${next_build_number}.apk" \
    --app "<YOUR_FIREBASE_APP_ID>" \
    --groups "<YOUR_TESTER_GROUPS>" \
    --release-notes "Release $next_version+$next_build_number"

  echo "✅ Uploaded to Firebase App Distribution!"
else
  echo "🛑 Skipped Firebase upload."
fi

# 14. Generate Auto Release Notes
release_notes_file="$release_folder/RELEASE_NOTES.txt"
last_tag=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "initial")

echo "🧾 Generating release notes from tag: $last_tag to v$next_version+$next_build_number..."

release_notes=$(git log "$last_tag"..HEAD --pretty=format:"- %s (%an)" --no-merges)

if [ -z "$release_notes" ]; then
  release_notes="- No significant changes."
fi

cat > "$release_notes_file" <<EOL
🚀 New Build Released!
Version: $next_version+$next_build_number
Date: $(date '+%Y-%m-%d %H:%M:%S')

Changes since $last_tag:
$release_notes

EOL

echo "✅ Auto-generated release notes saved at $release_notes_file"

# 15. Done
echo "🎯 Full release finished: Version $next_version+$next_build_number"
