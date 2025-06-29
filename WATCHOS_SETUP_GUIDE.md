# 🍎 WatchOS Setup Guide for GWEN App

## 📋 **Step-by-Step Instructions**

### **1. Create WatchOS Target in Xcode**

1. **Open Xcode** (should already be open)
2. **File → New → Target**
3. **Select**: watchOS → Watch App
4. **Product Name**: `GWENAppWatchOS`
5. **Language**: Swift
6. **Interface**: SwiftUI
7. **Include Notification Scene**: ✅ Checked
8. **Click "Finish"**

### **2. Configure Target Membership**

After creating the target, you need to assign files to the correct targets:

#### **iOS Target Files:**
- `Views/iOS/*.swift` → iOS Target
- `ViewModels/iOS/*.swift` → iOS Target
- `Services/Shared/*.swift` → Both Targets
- `Models/Shared/*.swift` → Both Targets

#### **WatchOS Target Files:**
- `Views/WatchOS/*.swift` → WatchOS Target
- `ViewModels/WatchOS/*.swift` → WatchOS Target
- `Services/Shared/*.swift` → Both Targets
- `Models/Shared/*.swift` → Both Targets

### **3. How to Assign Target Membership**

1. **Select a file** in the Project Navigator
2. **Show File Inspector** (right panel)
3. **Under "Target Membership"**:
   - ✅ Check "GWENApplicationXCODE" for iOS files
   - ✅ Check "GWENAppWatchOS" for watchOS files
   - ✅ Check both for shared files

### **4. Build Settings to Configure**

#### **iOS Target:**
- **Deployment Target**: iOS 17.0+
- **Swift Language Version**: Swift 5

#### **WatchOS Target:**
- **Deployment Target**: watchOS 10.0+
- **Swift Language Version**: Swift 5
- **Info.plist File**: `GWENApp 3/Views/WatchOS/Info.plist`

### **5. Test Both Apps**

#### **Test iOS App:**
1. **Select iOS Simulator** (iPhone 15 Pro)
2. **Product → Run** (⌘R)
3. **Test voice commands and features**

#### **Test WatchOS App:**
1. **Select Watch Simulator** (Apple Watch Series 9)
2. **Product → Run** (⌘R)
3. **Test "Hey GWEN" and voice features**

### **6. Troubleshooting**

#### **If files show errors:**
- Check target membership
- Clean build folder (Product → Clean Build Folder)
- Rebuild project

#### **If watchOS app doesn't build:**
- Verify Info.plist is assigned to watchOS target
- Check deployment target settings
- Ensure all shared files are in both targets

## 🎯 **Expected Results**

After setup, you should have:
- ✅ **iOS app** running on iPhone simulator
- ✅ **WatchOS app** running on Watch simulator
- ✅ **Both apps** connecting to your backend (localhost:5050)
- ✅ **Voice features** working on both platforms
- ✅ **Shared data** between iOS and watchOS

## 📱 **File Structure After Setup**

```
GWENApp/
├── iOS Target/
│   ├── Views/iOS/
│   │   ├── GwenChatView.swift
│   │   ├── PlacesView.swift
│   │   └── ContentView.swift
│   └── ViewModels/iOS/
│       ├── GwenChatViewModel.swift
│       └── PlacesViewModel.swift
├── WatchOS Target/
│   ├── Views/WatchOS/
│   │   ├── WatchContentView.swift
│   │   └── GWENAppWatchOSApp.swift
│   └── ViewModels/WatchOS/
│       ├── WatchGwenChatViewModel.swift
│       └── WatchPlacesViewModel.swift
└── Shared (Both Targets)/
    ├── Services/Shared/
    │   ├── NetworkingService.swift
    │   ├── VoiceInputService.swift
    │   └── AudioPlaybackService.swift
    └── Models/Shared/
        ├── DataModels.swift
        └── GwenInteraction.swift
```

## 🚀 **Next Steps**

1. **Complete the Xcode setup** using this guide
2. **Test both apps** in their respective simulators
3. **Verify backend connectivity** from both platforms
4. **Test voice features** on both iOS and watchOS

Let me know when you've completed the Xcode setup and I'll help you test everything! 