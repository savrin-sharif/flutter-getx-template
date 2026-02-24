#!/bin/bash

# -----------------------------
# 🚀 Full Release Bumper + Split APK Builder + Release Notes Generator
# -----------------------------

# 0. Ask user for version bump type
echo "🔢 Select version bump type:"
select bump_type in "MAJOR" "MINOR" "PATCH" "Custom"; do
  case $bump_type in
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

# 4. Determine next version
IFS='.' read -r major minor patch <<< "$current_version"

if [ "$bump_level" == "MAJOR" ]; then
  major=$((major + 1))
  minor=0
  patch=0
  next_version="$major.$minor.$patch"
  echo "🚀 MAJOR bump: $current_version ➔ $next_version"
elif [ "$bump_level" == "MINOR" ]; then
  minor=$((minor + 1))
  patch=0
  next_version="$major.$minor.$patch"
  echo "✨ MINOR bump: $current_version ➔ $next_version"
elif [ "$bump_level" == "PATCH" ]; then
  patch=$((patch + 1))
  next_version="$major.$minor.$patch"
  echo "🔧 PATCH bump: $current_version ➔ $next_version"
elif [ "$bump_level" == "CUSTOM" ]; then
  next_version="$new_version"
  echo "📝 Custom version set: $current_version ➔ $new_version"
fi

# 5. Always increment build number
next_build_number=$((current_build_number + 1))
echo "🔼 Build number incremented: $current_build_number ➔ $next_build_number"

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
