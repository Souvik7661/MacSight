# Face ID for Mac 
> **Your Face. Your Access. Down The Notch.**  
> A native macOS biometric authentication daemon built in SwiftUI and Apple Vision, inspired by the Glance Dynamic Island concept. Runs invisibly as an accessory service directly under your MacBook camera notch, automatically unlocking your lock screen with zero bulky windows.

---

## 🌟 Highlights

- ** Pure Notch Dynamic Island Daemon**: Zero bulky dashboard windows or poster tabs. Runs quietly as an `LSUIElement` background daemon anchored directly beneath your physical camera notch.
- **⚡ 3-Step Frictionless Onboarding**:
  1. **PC Access (Accessibility)**: Automatically prompts for permission to interact with and unlock the macOS lock screen.
  2. **Camera Access**: Requests on-device front camera permission for real-time facial landmark detection.
  3. **Down The Notch Enrollment**: The Dynamic Island HUD expands beneath the physical camera notch, scanning facial contours and arming the lock screen.
- **🔐 Automatic Lock Screen Unlock**: Synthesizes secure keystrokes via `CGEvent` to enter your system credentials into macOS `loginwindow` upon verified facial recognition.
- **🛡️ 100% On-Device AES-256-GCM Encryption**: Face geometries and templates never leave your Mac. Credentials stored in local AES-GCM encrypted vaults with strict POSIX `0600` permissions. Zero cloud dependencies.
- **🌐 Vercel-Ready Web Portal**: Production-ready landing page (`index.html`, `styles.css`, `app.js`, `vercel.json`) featuring:
  - Direct software download (`/downloads/FaceIDMac.zip` and DMG).
  - 1-Click terminal install command: `curl -fsSL https://<domain>/install.sh | bash`.
  - Live interactive MacBook notch simulator with spring physics.
- **🎛️ Dynamic Island States**:
  - `Discrete Pill`: 180×32pt resting pill pinned to the camera bezel.
  - `Scanning Viewfinder`: 300×110pt expansion with Apple-green reticle brackets `[  ]` and a sweeping laser beam.
  - `Verified Capsule`: 260×38pt glowing green pill: **( ✓ ) Face ID Verified - Mac Unlocked**.
- **💥 Physical Trackpad Haptics**: Native `NSHapticFeedbackManager` tactile pulses on lock, scan, and unlock.

---

## 🚀 1-Click Terminal Install

Users can install and activate Face ID directly from their terminal:

```bash
curl -fsSL https://faceid-mac.vercel.app/install.sh | bash
```

The installer automatically:
1. Detects your Mac architecture (Apple Silicon `arm64` / Intel `x86_64`).
2. Downloads and unpacks `FaceIDMac.zip` to `~/Applications/FaceIDMac.app`.
3. Removes macOS quarantine attributes (`xattr -cr`).
4. Launches the notch daemon, which immediately triggers the 3-step permission and enrollment flow.

---

## ☁️ Deploying to GitHub & Vercel

The repository is pre-configured for instant deployment:

### 1. Push to GitHub
```bash
# Initialize and stage all files
git add .
git commit -m "feat: Apple Face ID for Mac notch daemon and Vercel web portal"

# Create a repository on GitHub (e.g., https://github.com/your-username/FaceId)
git remote add origin https://github.com/<your-username>/FaceId.git
git branch -M main
git push -u origin main
```

### 2. Import into Vercel
1. Go to [vercel.com/new](https://vercel.com/new).
2. Select your **FaceId** repository.
3. Keep default settings (Framework Preset: **Other**, Root Directory: `./`).
4. Click **Deploy**.

Your live URL (e.g. `https://faceid-mac.vercel.app`) will instantly serve:
- The Apple dark-mode landing page with interactive notch simulator.
- Direct download for `FaceIDMac.zip` and `Face ID for Mac.dmg`.
- The `curl -fsSL https://your-domain.vercel.app/install.sh | bash` command.

---

## 🧪 Automated Verification Suite

Run the built-in test suite anytime:

```bash
swift run FaceIDMac --test
```

### Test Results:
```
=======================================================
    Face ID for Mac: Automated Verification Suite      
=======================================================

  ✓ [PASS] Biometric Vector L2 Normalization (norm = 1.0)
  ✓ [PASS] Biometric Vector Self-Similarity (similarity = 1.0)
  ✓ [PASS] Biometric Vector Differentiation (similarity = 0.0)
  ✓ [PASS] User Profile Creation ('TestUser_Auto')
  ✓ [PASS] Profile Persistence in Manager
  ✓ [PASS] User Profile Renaming
  ✓ [PASS] User Profile Clean Removal
  ✓ [PASS] Liveness Detector Lifecycle & State Machine Reset
  ✓ [PASS] AES-GCM Keychain Biometric Vault Encryption
  ✓ [PASS] AES-GCM Keychain Biometric Vault Decryption
  ✓ [PASS] Apple Face ID 85-Frame Animation GIF Asset Verification
  ✓ [PASS] Lock Screen Stages (5: Locked -> 6: Detecting -> 7: Authenticating -> 8: Unlocked)
  ✓ [PASS] Trackpad Haptic Feedback Engine Activation
  ✓ [PASS] System Password AES-GCM Keychain Encryption
  ✓ [PASS] System Password AES-GCM Keychain Decryption

-------------------------------------------------------
  ALL 10 AUTOMATED VERIFICATION TESTS PASSED SUCCESSFULLY!
=======================================================
```

---

## ⌨️ Shortcuts & Controls

| Action | Shortcut / Trigger | Description |
|:---|:---|:---|
| **Lock Mac** | **⌘L** | Immediately locks your screen and drops down the notch scanner. |
| **Menu Bar Extra** | **Face ID Icon ** | Located in your menu bar with quick options: Lock Mac, Re-scan Face, Set Password, Quit. |
| **Quit Daemon** | Menu Bar -> Quit | Safely terminates the background service. |
