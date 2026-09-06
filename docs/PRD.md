I’d make the PRD explicitly tell **GPT Astra 6** what to build, what not to build, and where Flutter vs Kotlin should be used. Here’s the revised short version.

:::writing{variant="document" id="48317" title="PRD — AI Cognitive Companion | Flutter + Android Launcher"}
# PRD — AI Cognitive Companion

## 1. Goal

Build an **Android Cognitive Launcher for elderly dementia patients**.

Instead of making the patient open a separate brain-game app, our launcher becomes their simplified phone home screen and turns normal daily activities into personalized memory exercises.

> **Core idea: Turn daily life itself into memory therapy.**

The launcher should be privacy-first, voice-first, offline-first, and designed for elderly users in North-East India.

---

# 2. Technology Decision

## Patient App

Build the main application in:

- **Flutter**
- **Dart**

Flutter should handle approximately **85–90% of the patient application**.

Flutter should be responsible for:

- Patient launcher UI
- Memory Passport
- Family recognition screens
- Photo memories
- Video recall
- Medicine reminders
- My Day timeline
- Cognitive questions
- Progressive hints
- Cognitive metrics
- Voice UI
- Offline database
- Firebase synchronization
- Localization

---

## Native Android Layer

Use **Kotlin only where Flutter cannot directly access Android system functionality**.

Flutter communicates with Kotlin using:

**Flutter Platform Channels**

Kotlin should handle:

- Making the application the Android default HOME launcher
- Android launcher intents
- Opening installed applications
- UsageStats API
- Android-specific permissions
- Background Android services if required
- Other Android system APIs

### Important Rule

**Do NOT build normal screens in Kotlin.**

Use Flutter for UI.

Use Kotlin only as the Android system bridge.

---

# 3. Architecture

```text
                 FLUTTER APP
                     │
                     │
 ┌───────────────────┼────────────────────┐
 │                   │                    │
Launcher UI      Cognitive Engine     Memory Passport
 │                   │                    │
Videos             Hints               Family
Photos             Scoring             Places
Medicine           Recall              Routines
My Day             Metrics             Memories
Voice
 │
 │
 ▼
Offline Database
Drift / SQLite
 │
 │
 ├──────── Firebase Sync ──────► Caregiver Dashboard
 │
 │
 ▼
Flutter Platform Channel
 │
 ▼
NATIVE KOTLIN
 │
 ├── Android HOME role
 ├── Launch installed apps
 ├── UsageStats
 ├── Permissions
 └── Android system APIs
```

---

# 4. Cognitive Launcher

The application should replace the normal Android home screen after the user chooses it as their default launcher.

Example:

```text
Good Morning, Mr. Bora

        🎤
   TALK TO SAATHI

[ WATCH ]

[ FAMILY ]

[ PHOTOS ]

[ MEDICINE ]

[ CALL FAMILY ]

[ MY DAY ]
```

Requirements:

- Large buttons
- Large fonts
- Minimal text
- High contrast
- Very simple navigation
- Voice-first interaction
- Works offline

---

# 5. Why We Use a Launcher

We do NOT want to continuously monitor the patient's screen.

Instead, our launcher provides controlled entry points into activities.

Example:

```text
Patient presses WATCH
        ↓
Launcher opens our video module
        ↓
System knows which video was watched
        ↓
Patient finishes video
        ↓
Memory question generated
```

This allows contextual cognitive exercises without invasive surveillance.

---

# 6. Memory Passport

Caregiver creates a personalized memory profile.

Store:

- Family members
- Family photos
- Relationships
- Important places
- Important memories
- Daily routines
- Medicines
- Favourite activities

Example:

```text
Name: Rahul
Relationship: Son
Visits: Sunday
Shared Activity: Cricket
Photo: rahul.jpg
```

The cognitive system uses this information to generate personalized questions.

---

# 7. Family Recognition

Show a family photograph.

Ask:

> Who is this?

If required:

```text
Hint 1:
He is from your family.

Hint 2:
He is your son.

Hint 3:
His name starts with R.
```

Record:

- Correct / incorrect
- Response time
- Number of hints
- Difficulty

---

# 8. Watch / Video Recall

Use controlled videos inside the Flutter application.

Example:

### Before

> Yesterday you watched a gardening video. Do you remember which crop was shown?

### Patient Watches Video

### Immediately After

> What was this video mainly about?

### Later

> What did you watch earlier today?

This allows:

- Immediate recall
- Short-term recall
- Delayed recall

---

# 9. Adaptive Cognitive Engine

For MVP, use an explainable rule-based engine.

```text
Last 5 answers > 80% correct
→ Increase difficulty

40–80%
→ Maintain difficulty

Below 40%
→ Reduce difficulty / provide more hints
```

Do not require an LLM for this system.

---

# 10. Cognitive Signals

Store for every cognitive interaction:

```text
Question Type
Correct / Incorrect
Response Time
Hints Required
Difficulty
Timestamp
```

Main metrics:

- Recall accuracy
- Hint dependency
- Response time
- Delayed recall
- Routine completion

---

# 11. Medicine & Routine Recall

Example:

At 8 PM:

> It is evening. Do you remember what you normally do at this time?

If patient remembers:

> Correct. It is time for your evening medicine.

If patient cannot remember:

> It is time for your evening medicine.

### Safety Rule

Never delay medication or another important safety action just to test memory.

---

# 12. My Day

Display a simple daily timeline.

```text
8:00 AM
Breakfast

9:00 AM
Medicine ✓

1:00 PM
Watched Gardening Video

5:00 PM
Walk

8:00 PM
Medicine
```

The same information can later generate recall questions.

Example:

> What did you do before your evening walk?

---

# 13. Talk to Saathi

Provide one major microphone button.

Patient can say:

> Maine subah kya kiya?

> Rahul ko call karo.

> Aaj ka memory exercise shuru karo.

Use:

- Android TextToSpeech
- Android SpeechRecognizer
- Flutter voice UI

Always provide touch-button fallback.

---

# 14. Offline First

The patient experience must work without internet.

Use:

**Flutter + Drift/SQLite**

Store locally:

- Memory Passport
- Questions
- Routines
- Reminder schedules
- Cognitive responses
- Hint data
- Cached media
- Pending sync events

Flow:

```text
Patient uses launcher
        ↓
Save locally
        ↓
No Internet
        ↓
Continue normally
        ↓
Internet returns
        ↓
Sync with Firebase
```

---

# 15. Firebase

Use Firebase for:

- Authentication
- Patient/caregiver linkage
- Firestore database
- Cognitive summary synchronization
- Memory Passport synchronization
- Caregiver dashboard data

The patient app must NOT become unusable when Firebase is unavailable.

---

# 16. Caregiver Dashboard

Dashboard should display:

```text
Mr. Bora

Recall Accuracy       74%
Hint Dependency       1.3
Response Time         6.2 sec
Medicine Adherence    94%

Cognitive Stability
76 — Observe
```

Show trends for:

- Recall
- Hint dependency
- Response time
- Routine completion
- Medicine adherence

---

# 17. Cognitive Stability Indicator

Combine trends such as:

- Hint dependency
- Response time
- Recall accuracy
- Routine completion

Example:

```text
Week 1     86
Week 2     84
Week 3     79
Week 4     72
```

If several signals deteriorate:

> Behavioural change detected. Consider reviewing with a healthcare professional.

Never claim:

> Dementia is worsening.

The system is NOT a medical diagnostic tool.

---

# 18. Privacy

Never:

- Continuously record the screen
- Read WhatsApp messages
- Record calls
- Continuously record microphone audio
- Capture passwords
- Collect banking information
- Upload unrelated private content

Optional UsageStats can be used only for high-level Android app-usage metadata.

---

# 19. Optional Object Recognition

Only after the main MVP works.

Use:

- Camera
- TensorFlow Lite / lightweight YOLO

Detect objects such as:

- Water bottle
- Medicine bottle
- Cup
- TV remote

Example:

> Show me your water bottle.

Then:

> What do we use this for?

Do NOT use YOLO for screen monitoring.

---

# 20. NER Localization

MVP should demonstrate:

- English
- Assamese

Build localization architecture so more languages can later be added.

Use Flutter localization files instead of hardcoding text.

Future languages may include:

- Hindi
- Bengali
- Meitei
- Mizo
- Khasi

---

# 21. Tech Stack

## Patient Cognitive Launcher

```text
Flutter
Dart
Kotlin
Flutter Platform Channels
Drift / SQLite
Firebase
Android TextToSpeech
Android SpeechRecognizer
Optional TensorFlow Lite
```

## Caregiver Dashboard

Preferred:

```text
Flutter Web
```

Alternative:

```text
Next.js
TypeScript
Tailwind
```

## Backend

```text
Firebase Authentication
Firestore
Cloud Functions only if required
```

---

# 22. Project Structure

```text
cognitive_companion/
│
├── patient_app/
│   ├── lib/
│   │   ├── launcher/
│   │   ├── memory_passport/
│   │   ├── cognition/
│   │   ├── family/
│   │   ├── videos/
│   │   ├── medicine/
│   │   ├── my_day/
│   │   ├── voice/
│   │   ├── database/
│   │   └── sync/
│   │
│   └── android/
│       └── Kotlin native launcher bridge
│
├── caregiver_dashboard/
│
├── firebase/
│
├── assets/
│
├── docs/
│   └── PRD.md
│
└── README.md
```

---

# 23. Build Order

GPT Astra 6 must build in this order:

```text
1. Create Flutter project
        ↓
2. Create launcher home UI
        ↓
3. Implement Android HOME launcher using Kotlin
        ↓
4. Connect Flutter ↔ Kotlin Platform Channel
        ↓
5. Build Memory Passport
        ↓
6. Build Family Recognition
        ↓
7. Build Video Recall Module
        ↓
8. Build Progressive Hints
        ↓
9. Build Cognitive Engine
        ↓
10. Add Drift / SQLite
        ↓
11. Build Medicine + My Day
        ↓
12. Add Voice
        ↓
13. Connect Firebase
        ↓
14. Build Caregiver Dashboard
        ↓
15. Add Assamese
        ↓
16. Optional Object Recognition
```

---

# 24. Instructions Specifically for GPT Astra 6

This PRD is the **source of truth**.

GPT Astra 6 should behave like a senior software engineer implementing an existing product specification.

### Before modifying architecture

Read this entire PRD.

Do not independently change the product architecture.

### Flutter First

Default to:

**Flutter + Dart**

for all UI and product logic.

Only use Kotlin when an Android system capability genuinely requires native implementation.

### Build Incrementally

Do NOT try to generate the entire application in one step.

Complete one feature, make sure it builds, then move to the next.

### Preserve Working Code

Do not perform large rewrites of working modules unless necessary.

### Do Not Overengineer

Do not introduce:

- microservices
- Kubernetes
- blockchain
- unnecessary state-management complexity
- complex AI infrastructure
- multiple databases

without explicit instruction.

### Core Demo Must Always Remain Functional

Priority:

```text
Working launcher
        >
Working cognitive flow
        >
Working offline storage
        >
Working caregiver dashboard
        >
Extra AI features
```

### Never Invent Product Requirements

If something is not defined here:

Choose the simplest implementation that supports the existing architecture.

Do not add major features automatically.

---

# 25. Demo Patient

Use seeded demo data.

```text
Patient:
Mr. Bora

Age:
72

Region:
Assam

Family:
Rahul — Son
Ananya — Daughter
Meera — Wife

Routine:
08:00 Breakfast
09:00 Medicine
17:00 Walk
20:00 Medicine

Favourite Activity:
Gardening
```

---

# 26. Main Demo

The final demo must show:

```text
ANDROID COGNITIVE LAUNCHER
        ↓
Mr. Bora opens Family
        ↓
Recognizes family photo
        ↓
Hints recorded
        ↓
Opens Watch
        ↓
Watches gardening video
        ↓
Immediate recall question
        ↓
Later recall question
        ↓
Medicine routine recall
        ↓
Metrics stored offline
        ↓
Firebase sync
        ↓
Caregiver dashboard updates
```

---

# 27. Features NOT to Build for MVP

Do not build:

- WhatsApp message monitoring
- Screen recording
- Call recording
- Full browser tracking
- GPS surveillance
- Wearable integration
- Hospital integration
- Blockchain
- iOS launcher
- Desktop launcher
- Complex clinical prediction
- Large LLM running continuously

These belong to future scope.

---

# 28. Final Architecture

```text
          FLUTTER COGNITIVE LAUNCHER
                     │
                     ▼
               DAILY ACTIVITY
                     │
                     ▼
               CONTEXT CAPTURE
                     │
                     ▼
                MEMORY PROMPT
                     │
                     ▼
               ADAPTIVE HINTS
                     │
                     ▼
             COGNITIVE SIGNALS
                     │
                     ▼
              DRIFT / SQLITE
                     │
               Offline First
                     │
                     ▼
              FIREBASE SYNC
                     │
                     ▼
           CAREGIVER DASHBOARD
```

Native Android functionality:

```text
Flutter
   │
Platform Channel
   │
   ▼
Kotlin
   │
   ├── HOME Launcher
   ├── UsageStats
   ├── Android Intents
   └── System APIs
```

---

# 29. North Star

The launcher is the:

> **Patient's Cognitive Operating Layer**

The overall product is the:

> **AI Cognitive Companion**

Every feature should answer:

> Does this help safely transform the patient's everyday activities into personalized cognitive assistance?

If not, do not build it for the MVP.

**Build the slice, not the platform.**
:::

This version is much better suited for handing directly to **GPT Astra 6** because it explicitly tells the agent what belongs in Flutter, what belongs in Kotlin, the build sequence, and what it is **not allowed to overengineer**.
