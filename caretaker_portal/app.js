/* ═══════════════════════════════════════
   SAATHI CARETAKER PORTAL — JavaScript
═══════════════════════════════════════ */

'use strict';

// ── Demo data ──────────────────────────────────────
const DEMO = {
  patient: { name: 'Mr. Bora', age: 72, region: 'Assam, North-East India' },

  passport: {
    schemaVersion: 1,
    name: 'Mr. Bora',
    age: 72,
    region: 'Assam, North-East India',
    isDemo: false,
    revision: 1,
    entries: [
      { id: 'rahul', kind: 'family', values: { name: 'Rahul', relationship: 'Son', visits: 'Sunday', sharedActivity: 'Cricket', color: 'teal' } },
      { id: 'ananya', kind: 'family', values: { name: 'Ananya', relationship: 'Daughter', visits: 'Calls daily', sharedActivity: 'Music', color: 'amber' } },
      { id: 'meera', kind: 'family', values: { name: 'Meera', relationship: 'Wife', visits: 'Lives at home', sharedActivity: 'Tea time', color: 'rose' } },
      { id: 'breakfast', kind: 'routine', values: { name: 'Breakfast', time: '08:00' } },
      { id: 'morning-medicine', kind: 'routine', values: { name: 'Medicine', time: '09:00', instructions: 'Morning dose with water' } },
      { id: 'walk', kind: 'routine', values: { name: 'Evening Walk', time: '17:00' } },
      { id: 'evening-medicine', kind: 'routine', values: { name: 'Medicine', time: '20:00', instructions: 'Evening dose after dinner' } },
      { id: 'gardening', kind: 'activity', values: { name: 'Gardening' } },
      { id: 'place-home', kind: 'place', values: { name: 'Home — Guwahati', icon: '🏠' } },
      { id: 'place-garden', kind: 'place', values: { name: 'Neighbourhood Garden', icon: '🌳' } },
      { id: 'place-temple', kind: 'place', values: { name: 'Local Temple', icon: '🕌' } }
    ]
  },

  stabilityWeeks: [
    { label: 'Wk 1', value: 86 },
    { label: 'Wk 2', value: 84 },
    { label: 'Wk 3', value: 79 },
    { label: 'Wk 4', value: 72 },
  ],

  todayPlan: [
    { time: '08:00', name: 'Breakfast', done: true },
    { time: '09:00', name: '💊 Morning Medicine', done: true },
    { time: '17:00', name: 'Evening Walk', done: true },
    { time: '20:00', name: '💊 Evening Medicine', done: false },
  ],

  recentActivity: [
    { type: 'family',   label: 'Family Recognition', correct: true,  hints: 0, time: '2 hrs ago',   diff: 'medium' },
    { type: 'video',    label: 'Video Recall',        correct: true,  hints: 1, time: '3 hrs ago',   diff: 'medium' },
    { type: 'medicine', label: 'Medicine Recall',     correct: false, hints: 2, time: 'Yesterday',   diff: 'easy' },
    { type: 'family',   label: 'Family Recognition',  correct: true,  hints: 0, time: 'Yesterday',   diff: 'hard' },
    { type: 'video',    label: 'Video Recall',         correct: true,  hints: 1, time: '2 days ago',  diff: 'medium' },
    { type: 'medicine', label: 'Medicine Recall',      correct: true,  hints: 0, time: '3 days ago',  diff: 'easy' },
    { type: 'family',   label: 'Family Recognition',   correct: false, hints: 3, time: '4 days ago',  diff: 'hard' },
    { type: 'video',    label: 'Video Recall',          correct: true,  hints: 0, time: '5 days ago',  diff: 'easy' },
  ],

  routines: [
    { time: '08:00', name: 'Breakfast',    done: true },
    { time: '17:00', name: 'Evening Walk', done: true },
    { time: '20:30', name: 'Gardening',   done: false },
    { time: '21:00', name: 'Reading',     done: false },
  ],

  adherence: [
    { day: 'Mon', count: 2, max: 2, status: 'full' },
    { day: 'Tue', count: 2, max: 2, status: 'full' },
    { day: 'Wed', count: 1, max: 2, status: 'partial' },
    { day: 'Thu', count: 2, max: 2, status: 'full' },
    { day: 'Fri', count: 2, max: 2, status: 'full' },
    { day: 'Sat', count: 2, max: 2, status: 'full' },
    { day: 'Sun', count: 2, max: 2, status: 'full' },
  ],

  hintSparkline: [2, 1, 3, 2, 1, 0, 1],
};

// ── Navigation ──────────────────────────────────────
const pages = document.querySelectorAll('.page');
const navItems = document.querySelectorAll('.nav-item');
const pageTitles = {
  overview:  'Overview',
  cognitive: 'Cognitive Records',
  medicine:  'Medicine & Routines',
  passport:  'Memory Passport',
  alerts:    'Alerts',
  notes:     'Daily Notes',
  report:    'Weekly Report',
  settings:  'Settings',
};

function showPage(id) {
  pages.forEach(p => p.classList.remove('active'));
  navItems.forEach(n => n.classList.remove('active'));
  const target = document.getElementById(`page-${id}`);
  const nav    = document.getElementById(`nav-${id}`);
  if (target) target.classList.add('active');
  if (nav)    nav.classList.add('active');
  const titleEl = document.getElementById('pageTitle');
  if (titleEl) titleEl.textContent = pageTitles[id] ?? id;
  closeSidebar();
  if (id === 'passport') {
    renderPassportPage();
  }
  // Re-run animations for that page
  target?.querySelectorAll('[data-animate]').forEach((el, i) => {
    el.style.animationDelay = `${i * 0.06}s`;
    el.style.animation = 'none';
    void el.offsetWidth;
    el.style.animation = '';
  });
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

navItems.forEach(item => {
  item.addEventListener('click', e => {
    e.preventDefault();
    showPage(item.dataset.page);
  });
});

// ── Sidebar toggle ──────────────────────────────────
const sidebar    = document.getElementById('sidebar');
const menuBtn    = document.getElementById('menuBtn');
const closeBtn   = document.getElementById('sidebarClose');

let overlay = document.createElement('div');
overlay.className = 'overlay';
document.body.appendChild(overlay);

function openSidebar()  { sidebar.classList.add('open');  overlay.classList.add('show'); }
function closeSidebar() { sidebar.classList.remove('open'); overlay.classList.remove('show'); }

menuBtn.addEventListener('click', openSidebar);
closeBtn.addEventListener('click', closeSidebar);
overlay.addEventListener('click', closeSidebar);

// ── Live date / greeting ────────────────────────────
function updateDateTime() {
  const now = new Date();
  const hour = now.getHours();
  const greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
  const dateStr = now.toLocaleDateString('en-IN', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
  const el = document.getElementById('liveDate');
  if (el) el.textContent = dateStr;
  const greetEl = document.getElementById('heroGreeting');
  if (greetEl) greetEl.textContent = greeting;
  const todayEl = document.getElementById('todayDate');
  if (todayEl) todayEl.textContent = now.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' });
}
updateDateTime();
setInterval(updateDateTime, 60000);

// ── Stability chart ─────────────────────────────────
function renderStabilityChart() {
  const container = document.getElementById('stabilityChart');
  if (!container) return;
  const max = Math.max(...DEMO.stabilityWeeks.map(w => w.value));
  container.innerHTML = DEMO.stabilityWeeks.map((w, i) => {
    const pct = Math.round((w.value / 100) * 100);
    const declining = i === DEMO.stabilityWeeks.length - 1 && w.value < DEMO.stabilityWeeks[i - 1].value;
    return `
      <div class="chart-bar-wrap">
        <span class="chart-val">${w.value}</span>
        <div class="chart-bar${declining ? ' declining' : ''}"
             style="height: 0%"
             data-value="${w.value}"
             data-target="${pct}%"
             title="Week ${i + 1}: ${w.value}">
        </div>
      </div>
    `;
  }).join('');

  // Animate bars after paint
  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      container.querySelectorAll('.chart-bar').forEach(bar => {
        bar.style.height = bar.dataset.target;
      });
    });
  });
}

// ── Today list ──────────────────────────────────────
function renderTodayList() {
  const ul = document.getElementById('todayList');
  if (!ul) return;
  ul.innerHTML = DEMO.todayPlan.map(item => `
    <li class="today-item">
      <span class="today-time">${item.time}</span>
      <span class="today-name">${item.name}</span>
      <span class="today-check ${item.done ? 'done' : 'pending'}">
        ${item.done ? '✓' : '○'}
      </span>
    </li>
  `).join('');
}

// ── Recent activity ─────────────────────────────────
const KIND_EMOJI = {
  family:   '👨‍👩‍👧',
  video:    '🎬',
  medicine: '💊',
  culture:  '🏞️',
};

function renderRecentActivity() {
  const container = document.getElementById('recentActivity');
  if (!container) return;
  container.innerHTML = DEMO.recentActivity.slice(0, 5).map(item => `
    <div class="activity-item">
      <div class="activity-icon ${item.correct ? 'correct' : 'incorrect'}">
        ${KIND_EMOJI[item.type] ?? '🧠'}
      </div>
      <div class="activity-body">
        <div class="activity-title">${item.label}</div>
        <div class="activity-meta">
          ${item.hints} hint${item.hints !== 1 ? 's' : ''} used · ${item.time}
        </div>
      </div>
      <span class="activity-badge ${item.correct ? 'correct' : 'incorrect'}">
        ${item.correct ? '✓ Correct' : '✗ Support needed'}
      </span>
    </div>
  `).join('');
}

// ── Records table ───────────────────────────────────
function renderRecordsTable(filter = 'all') {
  const tbody = document.getElementById('recordsBody');
  if (!tbody) return;
  const filtered = filter === 'all'
    ? DEMO.recentActivity
    : DEMO.recentActivity.filter(r => r.type === filter);
  tbody.innerHTML = filtered.map(r => `
    <tr>
      <td>${KIND_EMOJI[r.type] ?? '🧠'} ${r.label}</td>
      <td><span class="result-pill ${r.correct ? 'correct' : 'incorrect'}">${r.correct ? 'Correct' : 'Needed support'}</span></td>
      <td>${r.hints}</td>
      <td>${Number.isFinite(r.responseMs) && r.responseMs > 0 ? `${(r.responseMs / 1000).toFixed(1)} s` : '—'}</td>
      <td>${r.time}</td>
      <td><span class="difficulty-badge ${r.diff}">${r.diff.charAt(0).toUpperCase() + r.diff.slice(1)}</span></td>
    </tr>
  `).join('');
  if (!filtered.length) tbody.innerHTML = '<tr><td colspan="6">No synced records in this view.</td></tr>';
}

document.querySelectorAll('.filter-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    renderRecordsTable(btn.dataset.filter);
  });
});

// ── Routine list ─────────────────────────────────────
function renderRoutineList() {
  const ul = document.getElementById('routineList');
  if (!ul) return;
  ul.innerHTML = DEMO.routines.map(r => `
    <li class="routine-item">
      <span class="routine-time">${r.time}</span>
      <span class="routine-name">${r.name}</span>
      <span class="routine-check">${r.done ? '✅' : '⬜'}</span>
    </li>
  `).join('');
}

// ── Adherence grid ────────────────────────────────────
function renderAdherenceGrid() {
  const grid = document.getElementById('adherenceGrid');
  if (!grid) return;
  const icons = { full: '✅', partial: '⚠️', missed: '❌' };
  grid.innerHTML = DEMO.adherence.map(d => `
    <div class="adherence-day">
      <span class="adherence-day-label">${d.day}</span>
      <div class="adherence-dot ${d.status}">${icons[d.status]}</div>
      <span class="adherence-count">${d.count}/${d.max}</span>
    </div>
  `).join('');
}

// ── Hint sparkline ────────────────────────────────────
function renderHintSparkline() {
  const wrap = document.getElementById('hintSparkline');
  if (!wrap) return;
  const max = Math.max(...DEMO.hintSparkline, 1);
  wrap.innerHTML = DEMO.hintSparkline.map(v => {
    const ratio = v / max;
    const cls = ratio < 0.34 ? 'low' : ratio < 0.67 ? 'mid' : 'high';
    const pct = Math.round(ratio * 100);
    return `<div class="sparkline-bar ${cls}" style="height: ${Math.max(pct, 8)}%" title="Hints: ${v}"></div>`;
  }).join('');
}

// ── Alert dismiss ─────────────────────────────────────
document.querySelectorAll('.alert-dismiss').forEach(btn => {
  btn.addEventListener('click', () => {
    const card = btn.closest('.alert-card');
    card.style.transition = 'opacity 0.3s, transform 0.3s';
    card.style.opacity = '0';
    card.style.transform = 'translateX(20px)';
    setTimeout(() => card.remove(), 320);
  });
});

// ── Notes State (Declared before init) ─────────────────
const MOOD_EMOJI = { calm:'😌', happy:'😊', anxious:'😰', confused:'😕', tired:'😴', agitated:'😤' };

let selectedMood = null;
let selectedTag  = 'general';

let notes = [
  { id: 1, date: '10:30 AM, Today', mood: 'calm', tag: 'behaviour', text: 'Mr. Bora recognized his son Rahul and granddaughter Meera without any hesitation. Calm and cheerful.', author: 'Rahul' },
  { id: 2, date: 'Yesterday', mood: 'happy', tag: 'exercise', text: 'Took morning medication on time after breakfast. Enjoyed evening walk.', author: 'Rahul' }
];

try {
  const savedNotes = localStorage.getItem('saathi_notes');
  if (savedNotes) notes = JSON.parse(savedNotes);
} catch (_) {}

// ── Local Storage Helper ──────────────────────────────
const STORAGE_KEY = 'saathi_caretaker_portal_v1';

function loadState() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    return JSON.parse(raw);
  } catch (e) {
    console.warn('Could not load portal state:', e);
    return null;
  }
}

function saveState() {
  try {
    const state = {
      patient: DEMO.patient,
      passport: DEMO.passport,
      todayPlan: DEMO.todayPlan,
      routines: DEMO.routines,
      recentActivity: DEMO.recentActivity,
      notes,
    };
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    localStorage.setItem('saathi_demo_state', JSON.stringify(DEMO));
    localStorage.setItem('saathi_notes', JSON.stringify(notes));
  } catch (e) {
    console.warn('Could not save portal state:', e);
  }
}

// Restore saved state if available
const savedState = loadState();
if (savedState) {
  if (savedState.patient) DEMO.patient = { ...DEMO.patient, ...savedState.patient };
  if (savedState.passport) DEMO.passport = savedState.passport;
  if (savedState.todayPlan) DEMO.todayPlan = savedState.todayPlan;
  if (savedState.routines) DEMO.routines = savedState.routines;
  if (savedState.recentActivity) DEMO.recentActivity = savedState.recentActivity;
  if (savedState.notes) notes = savedState.notes;
}

// ── Init ──────────────────────────────────────────────
function init() {
  const safeRun = (fn, name) => {
    try {
      fn();
    } catch (err) {
      console.error(`Error in ${name}:`, err);
    }
  };
  safeRun(applyPatientName, 'applyPatientName');
  safeRun(renderStabilityChart, 'renderStabilityChart');
  safeRun(renderTodayList, 'renderTodayList');
  safeRun(renderRecentActivity, 'renderRecentActivity');
  safeRun(renderRecordsTable, 'renderRecordsTable');
  safeRun(renderRoutineList, 'renderRoutineList');
  safeRun(renderAdherenceGrid, 'renderAdherenceGrid');
  safeRun(renderHintSparkline, 'renderHintSparkline');
  safeRun(initPassportPage, 'initPassportPage');
  safeRun(renderPassportPage, 'renderPassportPage');
  safeRun(initNotes, 'initNotes');
  safeRun(initReport, 'initReport');
  safeRun(initSettings, 'initSettings');
  safeRun(initSyncModal, 'initSyncModal');
  safeRun(initAiCheckupModal, 'initAiCheckupModal');
  safeRun(initFirebase, 'initFirebase');
}

function applyPatientName() {
  const name = DEMO.patient.name || 'Mr. Bora';
  const age = DEMO.patient.age || 72;
  const region = DEMO.patient.region || 'Assam';

  // Passport & Report headers
  const passportName = document.querySelector('.passport-name');
  if (passportName) passportName.textContent = name;

  const reportHeader = document.querySelector('.report-patient h3');
  if (reportHeader) reportHeader.textContent = name;

  const inputName = document.getElementById('settingPatientName');
  if (inputName && !inputName.value) inputName.value = name;
  const inputAge = document.getElementById('settingPatientAge');
  if (inputAge && !inputAge.value) inputAge.value = age;
  const inputRegion = document.getElementById('settingPatientRegion');
  if (inputRegion && !inputRegion.value) inputRegion.value = region;
}

// ── Today list (Interactive) ──────────────────────────
function renderTodayList() {
  const ul = document.getElementById('todayList');
  if (!ul) return;
  ul.innerHTML = DEMO.todayPlan.map(item => `
    <li class="today-item">
      <span class="today-time">${item.time}</span>
      <span class="today-name">${item.name}</span>
      <span class="today-check ${item.done ? 'done' : 'pending'}" title="Updated from the Saathi phone app">
        ${item.done ? '✓' : '○'}
      </span>
    </li>
  `).join('');
}

// ── Routine list (Interactive) ────────────────────────
function renderRoutineList() {
  const ul = document.getElementById('routineList');
  if (!ul) return;
  ul.innerHTML = DEMO.routines.map((r, index) => `
    <li class="routine-item">
      <span class="routine-time">${r.time}</span>
      <span class="routine-name">${r.name}</span>
      <span class="routine-check" onclick="toggleRoutine(${index})">${r.done ? '✅' : '⬜'}</span>
    </li>
  `).join('');
}

window.toggleRoutine = function (index) {
  if (DEMO.routines[index]) {
    DEMO.routines[index].done = !DEMO.routines[index].done;
    saveState();
    renderRoutineList();
  }
};

// ══════════════════════════════════════════
// MEMORY PASSPORT (Live Interactive & Sync)
// ══════════════════════════════════════════
function initPassportPage() {
  const btnEditProfile = document.getElementById('btnEditPassportProfile');
  if (btnEditProfile) btnEditProfile.addEventListener('click', openEditProfileModal);

  const btnAddFamily = document.getElementById('btnAddFamilyMember');
  if (btnAddFamily) btnAddFamily.addEventListener('click', () => openFamilyModal(null));

  const btnAddRoutine = document.getElementById('btnAddRoutineItem');
  if (btnAddRoutine) btnAddRoutine.addEventListener('click', () => openRoutineModal(null));

  const btnAddPlace = document.getElementById('btnAddPlaceItem');
  if (btnAddPlace) btnAddPlace.addEventListener('click', () => openPlaceModal(null));

  const btnAddMemory = document.getElementById('btnAddMemoryItem');
  if (btnAddMemory) btnAddMemory.addEventListener('click', () => openMemoryModal(null));

  const btnAddActivity = document.getElementById('btnAddActivityItem');
  if (btnAddActivity) btnAddActivity.addEventListener('click', () => openActivityModal(null));

  // Profile modal
  document.getElementById('closeProfileModal')?.addEventListener('click', () => closePassportModal('passportProfileModal'));
  document.getElementById('cancelProfileBtn')?.addEventListener('click', () => closePassportModal('passportProfileModal'));
  document.getElementById('saveProfileBtn')?.addEventListener('click', handleSaveProfile);

  // Family modal
  document.getElementById('closeFamilyModal')?.addEventListener('click', () => closePassportModal('passportFamilyModal'));
  document.getElementById('cancelFamilyBtn')?.addEventListener('click', () => closePassportModal('passportFamilyModal'));
  document.getElementById('saveFamilyBtn')?.addEventListener('click', handleSaveFamily);

  // Routine modal
  document.getElementById('closeRoutineModal')?.addEventListener('click', () => closePassportModal('passportRoutineModal'));
  document.getElementById('cancelRoutineBtn')?.addEventListener('click', () => closePassportModal('passportRoutineModal'));
  document.getElementById('saveRoutineBtn')?.addEventListener('click', handleSaveRoutine);

  // Place modal
  document.getElementById('closePlaceModal')?.addEventListener('click', () => closePassportModal('passportPlaceModal'));
  document.getElementById('cancelPlaceBtn')?.addEventListener('click', () => closePassportModal('passportPlaceModal'));
  document.getElementById('savePlaceBtn')?.addEventListener('click', handleSavePlace);

  // Memory modal
  document.getElementById('closeMemoryModal')?.addEventListener('click', () => closePassportModal('passportMemoryModal'));
  document.getElementById('cancelMemoryBtn')?.addEventListener('click', () => closePassportModal('passportMemoryModal'));
  document.getElementById('saveMemoryBtn')?.addEventListener('click', handleSaveMemory);

  // Activity modal
  document.getElementById('closeActivityModal')?.addEventListener('click', () => closePassportModal('passportActivityModal'));
  document.getElementById('cancelActivityBtn')?.addEventListener('click', () => closePassportModal('passportActivityModal'));
  document.getElementById('saveActivityBtn')?.addEventListener('click', handleSaveActivity);

  // Close modals on overlay backdrop click
  ['passportProfileModal', 'passportFamilyModal', 'passportRoutineModal', 'passportPlaceModal', 'passportMemoryModal', 'passportActivityModal'].forEach(id => {
    const m = document.getElementById(id);
    if (m) {
      m.addEventListener('click', e => {
        if (e.target === m) closePassportModal(id);
      });
    }
  });
}

function openPassportModal(id) {
  document.getElementById(id)?.classList.add('show');
}
function closePassportModal(id) {
  document.getElementById(id)?.classList.remove('show');
}

function updatePassportSyncBadge(isLive, errMsg) {
  const badge = document.getElementById('passportLiveBadge');
  if (!badge) return;
  if (isLive) {
    badge.className = 'passport-badge-live';
    badge.innerHTML = '<span class="pulse-dot"></span> Live Linked (Firestore)';
  } else {
    badge.className = 'passport-badge-live offline';
    badge.innerHTML = `⚠️ Sync: ${errMsg || 'Offline'}`;
  }
}

function renderPassportPage() {
  if (!DEMO.passport) return;

  // 1. Profile card
  const avatarEl = document.getElementById('passportAvatar');
  const nameEl = document.getElementById('passportProfileName');
  const metaEl = document.getElementById('passportProfileMeta');
  const favEl = document.getElementById('passportFavActivity');

  const pName = DEMO.passport.name || DEMO.patient.name || 'Mr. Bora';
  const pAge = DEMO.passport.age || DEMO.patient.age || 72;
  const pRegion = DEMO.passport.region || DEMO.patient.region || 'Assam, North-East India';

  if (avatarEl) avatarEl.textContent = pName.charAt(0).toUpperCase() || 'P';
  if (nameEl) nameEl.textContent = pName;
  if (metaEl) metaEl.textContent = `Age ${pAge} · ${pRegion}`;

  const actEntry = (DEMO.passport.entries || []).find(e => e.kind === 'activity');
  const favActivity = actEntry ? (actEntry.values?.name || actEntry.name || '🌱 Gardening') : '🌱 Gardening';
  if (favEl) favEl.textContent = favActivity;

  // 2. Family list
  const familyListEl = document.getElementById('passportFamilyList');
  if (familyListEl) {
    const familyEntries = (DEMO.passport.entries || []).filter(e => e.kind === 'family');
    if (familyEntries.length === 0) {
      familyListEl.innerHTML = '<li class="passport-item" style="color:var(--text-muted);font-size:13px;">No family members added yet. Tap "+ Add Member" to add one.</li>';
    } else {
      familyListEl.innerHTML = familyEntries.map(entry => {
        const v = entry.values || {};
        const name = v.name || entry.name || 'Relative';
        const rel = v.relationship || 'Family';
        const visits = v.visits ? ` · ${v.visits}` : '';
        const act = v.sharedActivity ? ` · ${v.sharedActivity}` : '';
        const color = v.color || (name.startsWith('R') ? 'teal' : name.startsWith('A') ? 'amber' : 'rose');
        const initial = name.charAt(0).toUpperCase();
        const notes = v.notes ? `<small style="display:block;font-size:11px;color:var(--text-muted);">${v.notes}</small>` : '';

        return `
          <li class="passport-item" data-id="${entry.id}">
            <div class="passport-avatar ${color}">${initial}</div>
            <div style="flex:1;">
              <span class="p-name">${name}</span>
              <span class="p-rel">${rel}${visits}${act}</span>
              ${notes}
            </div>
            <div class="passport-item-actions">
              <button class="btn-icon-sm" title="Edit" onclick="openFamilyModal('${entry.id}')">✏️</button>
              <button class="btn-icon-sm delete" title="Delete" onclick="deletePassportEntry('${entry.id}')">🗑️</button>
            </div>
          </li>
        `;
      }).join('');
    }
  }

  // 3. Routine list
  const routineListEl = document.getElementById('passportRoutineList');
  if (routineListEl) {
    const routineEntries = (DEMO.passport.entries || []).filter(e => e.kind === 'routine' || e.kind === 'medicine');
    routineEntries.sort((a, b) => {
      const ta = (a.values?.time || '00:00');
      const tb = (b.values?.time || '00:00');
      return ta.localeCompare(tb);
    });

    if (routineEntries.length === 0) {
      routineListEl.innerHTML = '<li class="passport-item" style="color:var(--text-muted);font-size:13px;padding-left:12px;">No routines or medicines scheduled yet.</li>';
    } else {
      routineListEl.innerHTML = routineEntries.map(entry => {
        const v = entry.values || {};
        const time = v.time || '08:00';
        const name = v.name || entry.name || 'Routine';
        const isMed = entry.kind === 'medicine' || name.toLowerCase().includes('med') || (v.instructions && v.instructions.length > 0);
        const sub = v.instructions ? `<small style="display:block;font-size:11px;color:var(--text-muted);">${v.instructions}</small>` : '';
        const notes = v.notes ? `<small style="display:block;font-size:11px;color:var(--text-muted);">${v.notes}</small>` : '';

        return `
          <li class="passport-item timeline-item" data-id="${entry.id}">
            <span class="timeline-time">${time}</span>
            <div class="timeline-dot ${isMed ? 'medicine' : ''}"></div>
            <div style="flex:1;">
              <span class="timeline-label">${isMed && !name.includes('💊') ? '💊 ' : ''}${name}</span>
              ${sub}
              ${notes}
            </div>
            <div class="passport-item-actions">
              <button class="btn-icon-sm" title="Edit" onclick="openRoutineModal('${entry.id}')">✏️</button>
              <button class="btn-icon-sm delete" title="Delete" onclick="deletePassportEntry('${entry.id}')">🗑️</button>
            </div>
          </li>
        `;
      }).join('');
    }
  }

  // 4. Important Places list
  const placesListEl = document.getElementById('passportPlacesList');
  if (placesListEl) {
    const placeEntries = (DEMO.passport.entries || []).filter(e => e.kind === 'place');
    if (placeEntries.length === 0) {
      placesListEl.innerHTML = '<li class="passport-item" style="color:var(--text-muted);font-size:13px;">No familiar places saved yet.</li>';
    } else {
      placesListEl.innerHTML = placeEntries.map(entry => {
        const v = entry.values || {};
        const name = v.name || entry.name || 'Familiar Place';
        const icon = v.icon || '🏠';
        const notes = v.notes ? `<small style="display:block;font-size:11px;color:var(--text-muted);">${v.notes}</small>` : '';

        return `
          <li class="passport-item" data-id="${entry.id}">
            <div class="place-icon">${icon}</div>
            <div style="flex:1;">
              <span class="p-name">${name}</span>
              ${notes}
            </div>
            <div class="passport-item-actions">
              <button class="btn-icon-sm" title="Edit" onclick="openPlaceModal('${entry.id}')">✏️</button>
              <button class="btn-icon-sm delete" title="Delete" onclick="deletePassportEntry('${entry.id}')">🗑️</button>
            </div>
          </li>
        `;
      }).join('');
    }
  }

  // 5. Life Memories list
  const memoriesListEl = document.getElementById('passportMemoriesList');
  if (memoriesListEl) {
    const memoryEntries = (DEMO.passport.entries || []).filter(e => e.kind === 'memory');
    if (memoryEntries.length === 0) {
      memoriesListEl.innerHTML = '<li class="passport-item" style="color:var(--text-muted);font-size:13px;">No life memories added yet. Tap "+ Add Memory" to add one.</li>';
    } else {
      memoriesListEl.innerHTML = memoryEntries.map(entry => {
        const v = entry.values || {};
        const name = v.name || entry.name || 'Memory';
        const notes = v.notes ? `<small style="display:block;font-size:11px;color:var(--text-muted);">${v.notes}</small>` : '';
        return `
          <li class="passport-item" data-id="${entry.id}">
            <div class="place-icon">💭</div>
            <div style="flex:1;">
              <span class="p-name">${name}</span>
              ${notes}
            </div>
            <div class="passport-item-actions">
              <button class="btn-icon-sm" title="Edit" onclick="openMemoryModal('${entry.id}')">✏️</button>
              <button class="btn-icon-sm delete" title="Delete" onclick="deletePassportEntry('${entry.id}')">🗑️</button>
            </div>
          </li>
        `;
      }).join('');
    }
  }

  // 6. Activities list
  const activitiesListEl = document.getElementById('passportActivitiesList');
  if (activitiesListEl) {
    const activityEntries = (DEMO.passport.entries || []).filter(e => e.kind === 'activity');
    if (activityEntries.length === 0) {
      activitiesListEl.innerHTML = '<li class="passport-item" style="color:var(--text-muted);font-size:13px;">No activities added yet. Tap "+ Add Activity" to add one.</li>';
    } else {
      activitiesListEl.innerHTML = activityEntries.map(entry => {
        const v = entry.values || {};
        const name = v.name || entry.name || 'Activity';
        const notes = v.notes ? `<small style="display:block;font-size:11px;color:var(--text-muted);">${v.notes}</small>` : '';
        return `
          <li class="passport-item" data-id="${entry.id}">
            <div class="place-icon">🌱</div>
            <div style="flex:1;">
              <span class="p-name">${name}</span>
              ${notes}
            </div>
            <div class="passport-item-actions">
              <button class="btn-icon-sm" title="Edit" onclick="openActivityModal('${entry.id}')">✏️</button>
              <button class="btn-icon-sm delete" title="Delete" onclick="deletePassportEntry('${entry.id}')">🗑️</button>
            </div>
          </li>
        `;
      }).join('');
    }
  }
}

function syncRoutinesFromPassport() {
  if (!DEMO.passport || !DEMO.passport.entries) return;
  const routineEntries = DEMO.passport.entries.filter(e => e.kind === 'routine' || e.kind === 'medicine');
  if (routineEntries.length > 0) {
    DEMO.todayPlan = routineEntries.map(e => {
      const v = e.values || {};
      const isMed = e.kind === 'medicine' || (v.name && v.name.toLowerCase().includes('med'));
      return {
        id: e.id,
        time: v.time || '08:00',
        name: isMed && !v.name?.includes('💊') ? `💊 ${v.name}` : (v.name || 'Activity'),
        done: cloudCompletedEventIds.has(e.id)
      };
    });
    renderTodayList();
  }
  renderLinkedSchedule();
}

function renderLinkedSchedule() {
  if (!currentPatientUid || !isFirebaseOnline) return;
  const entries = (DEMO.passport?.entries || []).filter(e => e.kind === 'routine' || e.kind === 'medicine');
  const medicines = entries.filter(e => e.kind === 'medicine' || /medicin/i.test(e.values?.name || ''));
  const routines = entries.filter(e => !medicines.includes(e));
  const completed = e => cloudCompletedEventIds.has(e.id);
  const medicineList = document.getElementById('medicineList');
  const routineList = document.getElementById('routineList');

  if (medicineList) {
    medicineList.replaceChildren();
    medicines.forEach(entry => {
      const item = document.createElement('li');
      item.className = `med-item${completed(entry) ? ' done' : ''}`;
      const icon = document.createElement('div');
      icon.className = 'med-icon';
      icon.textContent = '💊';
      const body = document.createElement('div');
      body.className = 'med-body';
      const name = document.createElement('span');
      name.className = 'med-name';
      name.textContent = entry.values?.name || 'Medicine';
      const time = document.createElement('span');
      time.className = 'med-time';
      time.textContent = entry.values?.time || 'Time not set';
      body.append(name, time);
      const status = document.createElement('div');
      status.className = `med-status${completed(entry) ? ' done-badge' : ''}`;
      status.textContent = completed(entry) ? '✓ Confirmed' : '○ Not confirmed';
      item.append(icon, body, status);
      medicineList.append(item);
    });
    if (!medicines.length) medicineList.textContent = 'No medicines scheduled.';
  }

  if (routineList) {
    routineList.replaceChildren();
    routines.forEach(entry => {
      const item = document.createElement('li');
      item.className = 'routine-item';
      const time = document.createElement('span');
      time.className = 'routine-time';
      time.textContent = entry.values?.time || '—';
      const name = document.createElement('span');
      name.className = 'routine-name';
      name.textContent = entry.values?.name || 'Activity';
      const check = document.createElement('span');
      check.className = 'routine-check';
      check.textContent = completed(entry) ? '✅' : '⬜';
      item.append(time, name, check);
      routineList.append(item);
    });
    if (!routines.length) routineList.textContent = 'No routines scheduled.';
  }

  const medCount = document.getElementById('medicineDoneCount');
  const confirmedMedicines = medicines.filter(completed).length;
  if (medCount) medCount.textContent = `${confirmedMedicines} of ${medicines.length} Done`;
  const overviewValue = document.getElementById('overviewMedicineValue');
  if (overviewValue) overviewValue.textContent = `${confirmedMedicines} of ${medicines.length}`;
  const overviewStatus = document.getElementById('overviewMedicineStatus');
  if (overviewStatus) {
    overviewStatus.textContent = medicines.length
      ? (confirmedMedicines === medicines.length ? 'All confirmed today' : 'Awaiting confirmation')
      : 'No medicines scheduled';
    overviewStatus.classList.toggle('up', medicines.length > 0 && confirmedMedicines === medicines.length);
  }
  const routineCount = document.getElementById('routineDoneCount');
  if (routineCount) routineCount.textContent = `${routines.filter(completed).length} of ${routines.length} Done`;
  const history = document.getElementById('adherenceGrid');
  if (history) history.textContent = '7-day history is not available from phone sync yet.';
}

function savePassportToFirestore() {
  if (!db || !currentPatientUid || !isFirebaseOnline) {
    console.warn('Firebase db not available, passport saved locally.');
    return Promise.resolve();
  }
  DEMO.passport.revision = (DEMO.passport.revision || 1) + 1;
  const passRef = db.collection('patients').doc(currentPatientUid).collection('passport').doc('current');
  return passRef.set({
    schemaVersion: 1,
    name: DEMO.passport.name || 'Mr. Bora',
    age: DEMO.passport.age || 72,
    region: DEMO.passport.region || 'Assam, North-East India',
    isDemo: false,
    revision: DEMO.passport.revision,
    entries: DEMO.passport.entries || []
  }).then(() => {
    console.log('✓ Passport successfully saved to Firestore:', currentPatientUid);
    updatePassportSyncBadge(true);
  }).catch(err => {
    console.error('Error saving passport to Firestore:', err);
    updatePassportSyncBadge(false, err.message);
  });
}

function openEditProfileModal() {
  const p = DEMO.passport || DEMO.patient;
  document.getElementById('editProfileName').value = p.name || 'Mr. Bora';
  document.getElementById('editProfileAge').value = p.age || 72;
  document.getElementById('editProfileRegion').value = p.region || 'Assam, North-East India';
  const act = (p.entries || []).find(e => e.kind === 'activity');
  document.getElementById('editProfileActivity').value = act?.values?.name || act?.name || '🌱 Gardening';
  openPassportModal('passportProfileModal');
}

function handleSaveProfile() {
  const name = document.getElementById('editProfileName').value.trim();
  const age = parseInt(document.getElementById('editProfileAge').value, 10) || 72;
  const region = document.getElementById('editProfileRegion').value.trim();
  const activity = document.getElementById('editProfileActivity').value.trim();

  if (!name) return alert('Please enter patient name');

  DEMO.passport.name = name;
  DEMO.passport.age = age;
  DEMO.passport.region = region;
  DEMO.patient.name = name;
  DEMO.patient.age = age;
  DEMO.patient.region = region;

  let actIndex = (DEMO.passport.entries || []).findIndex(e => e.kind === 'activity');
  if (actIndex >= 0) {
    if (!DEMO.passport.entries[actIndex].values) DEMO.passport.entries[actIndex].values = {};
    DEMO.passport.entries[actIndex].values.name = activity;
  } else {
    DEMO.passport.entries.push({
      id: `act_${Date.now()}`,
      kind: 'activity',
      values: { name: activity }
    });
  }

  savePassportToFirestore();
  applyPatientName();
  renderPassportPage();
  saveState();
  closePassportModal('passportProfileModal');
}

window.openFamilyModal = function (entryId) {
  document.getElementById('editFamilyId').value = entryId || '';
  const title = document.getElementById('familyModalTitle');
  if (entryId) {
    if (title) title.textContent = '✏️ Edit Family Member';
    const entry = DEMO.passport.entries.find(e => e.id === entryId);
    if (entry) {
      const v = entry.values || {};
      document.getElementById('editFamilyName').value = v.name || entry.name || '';
      document.getElementById('editFamilyRel').value = v.relationship || '';
      document.getElementById('editFamilyVisits').value = v.visits || '';
      document.getElementById('editFamilyActivity').value = v.sharedActivity || '';
      document.getElementById('editFamilyColor').value = v.color || 'teal';
      const notesEl = document.getElementById('editFamilyNotes');
      if (notesEl) notesEl.value = v.notes || '';
    }
  } else {
    if (title) title.textContent = '➕ Add Family Member';
    document.getElementById('editFamilyName').value = '';
    document.getElementById('editFamilyRel').value = '';
    document.getElementById('editFamilyVisits').value = '';
    document.getElementById('editFamilyActivity').value = '';
    document.getElementById('editFamilyColor').value = 'teal';
    const notesEl = document.getElementById('editFamilyNotes');
    if (notesEl) notesEl.value = '';
  }
  openPassportModal('passportFamilyModal');
};

function handleSaveFamily() {
  const id = document.getElementById('editFamilyId').value.trim();
  const name = document.getElementById('editFamilyName').value.trim();
  const rel = document.getElementById('editFamilyRel').value.trim();
  const visits = document.getElementById('editFamilyVisits').value.trim();
  const activity = document.getElementById('editFamilyActivity').value.trim();
  const color = document.getElementById('editFamilyColor').value;
  const notes = document.getElementById('editFamilyNotes')?.value?.trim() || '';

  if (!name) return alert('Please enter a name');

  const values = { name, relationship: rel };
  if (visits) values.visits = visits;
  if (activity) values.sharedActivity = activity;
  if (color) values.color = color;
  if (notes) values.notes = notes;

  if (id) {
    const idx = DEMO.passport.entries.findIndex(e => e.id === id);
    if (idx >= 0) {
      DEMO.passport.entries[idx].values = values;
    }
  } else {
    DEMO.passport.entries.push({
      id: `fam_${Date.now()}`,
      kind: 'family',
      values
    });
  }

  savePassportToFirestore();
  renderPassportPage();
  saveState();
  closePassportModal('passportFamilyModal');
}

window.openRoutineModal = function (entryId) {
  document.getElementById('editRoutineId').value = entryId || '';
  const title = document.getElementById('routineModalTitle');
  if (entryId) {
    if (title) title.textContent = '✏️ Edit Schedule Item';
    const entry = DEMO.passport.entries.find(e => e.id === entryId);
    if (entry) {
      const v = entry.values || {};
      document.getElementById('editRoutineTime').value = v.time || '09:00';
      document.getElementById('editRoutineName').value = v.name || entry.name || '';
      document.getElementById('editRoutineKind').value = entry.kind === 'medicine' || (v.name && v.name.toLowerCase().includes('med')) ? 'medicine' : 'routine';
      document.getElementById('editRoutineInstructions').value = v.instructions || '';
      const notesEl = document.getElementById('editRoutineRoutine') || document.getElementById('editRoutineNotes');
      if (notesEl) notesEl.value = v.notes || '';
    }
  } else {
    if (title) title.textContent = '➕ Add Schedule Item';
    document.getElementById('editRoutineTime').value = '09:00';
    document.getElementById('editRoutineName').value = '';
    document.getElementById('editRoutineKind').value = 'routine';
    document.getElementById('editRoutineInstructions').value = '';
    const notesEl = document.getElementById('editRoutineRoutine') || document.getElementById('editRoutineNotes');
    if (notesEl) notesEl.value = '';
  }
  openPassportModal('passportRoutineModal');
};

function handleSaveRoutine() {
  const id = document.getElementById('editRoutineId').value.trim();
  const time = document.getElementById('editRoutineTime').value.trim();
  const name = document.getElementById('editRoutineName').value.trim();
  const kind = document.getElementById('editRoutineKind').value;
  const instructions = document.getElementById('editRoutineInstructions').value.trim();
  const notes = document.getElementById('editRoutineNotes')?.value?.trim() || '';

  if (!name) return alert('Please enter routine or medicine name');

  const values = { name, time };
  if (instructions) values.instructions = instructions;
  if (notes) values.notes = notes;

  if (id) {
    const idx = DEMO.passport.entries.findIndex(e => e.id === id);
    if (idx >= 0) {
      DEMO.passport.entries[idx].kind = kind;
      DEMO.passport.entries[idx].values = values;
    }
  } else {
    DEMO.passport.entries.push({
      id: `rout_${Date.now()}`,
      kind: kind,
      values
    });
  }

  syncRoutinesFromPassport();
  savePassportToFirestore();
  renderPassportPage();
  saveState();
  closePassportModal('passportRoutineModal');
}

window.openPlaceModal = function (entryId) {
  document.getElementById('editPlaceId').value = entryId || '';
  const title = document.getElementById('placeModalTitle');
  if (entryId) {
    if (title) title.textContent = '✏️ Edit Familiar Place';
    const entry = DEMO.passport.entries.find(e => e.id === entryId);
    if (entry) {
      const v = entry.values || {};
      document.getElementById('editPlaceName').value = v.name || entry.name || '';
      document.getElementById('editPlaceIcon').value = v.icon || '🏠';
    }
  } else {
    if (title) title.textContent = '➕ Add Familiar Place';
    document.getElementById('editPlaceName').value = '';
    document.getElementById('editPlaceIcon').value = '🏠';
  }
  openPassportModal('passportPlaceModal');
};

function handleSavePlace() {
  const id = document.getElementById('editPlaceId').value.trim();
  const name = document.getElementById('editPlaceName').value.trim();
  const icon = document.getElementById('editPlaceIcon').value;
  const notes = document.getElementById('editPlaceNotes')?.value?.trim() || '';

  if (!name) return alert('Please enter place name');

  const values = { name, icon };
  if (notes) values.notes = notes;

  if (id) {
    const idx = DEMO.passport.entries.findIndex(e => e.id === id);
    if (idx >= 0) {
      DEMO.passport.entries[idx].values = values;
    }
  } else {
    DEMO.passport.entries.push({
      id: `place_${Date.now()}`,
      kind: 'place',
      values
    });
  }

  savePassportToFirestore();
  renderPassportPage();
  saveState();
  closePassportModal('passportPlaceModal');
}

window.openMemoryModal = function (entryId) {
  document.getElementById('editMemoryId').value = entryId || '';
  const title = document.getElementById('memoryModalTitle');
  if (entryId) {
    if (title) title.textContent = '✏️ Edit Life Memory';
    const entry = DEMO.passport.entries.find(e => e.id === entryId);
    if (entry) {
      const v = entry.values || {};
      document.getElementById('editMemoryName').value = v.name || entry.name || '';
      document.getElementById('editMemoryNotes').value = v.notes || '';
    }
  } else {
    if (title) title.textContent = '➕ Add Life Memory';
    document.getElementById('editMemoryName').value = '';
    document.getElementById('editMemoryNotes').value = '';
  }
  openPassportModal('passportMemoryModal');
};

function handleSaveMemory() {
  const id = document.getElementById('editMemoryId').value.trim();
  const name = document.getElementById('editMemoryName').value.trim();
  const notes = document.getElementById('editMemoryNotes').value.trim();

  if (!name) return alert('Please enter a memory title');

  const values = { name };
  if (notes) values.notes = notes;

  if (id) {
    const idx = DEMO.passport.entries.findIndex(e => e.id === id);
    if (idx >= 0) DEMO.passport.entries[idx].values = values;
  } else {
    DEMO.passport.entries.push({
      id: `mem_${Date.now()}`,
      kind: 'memory',
      values
    });
  }

  savePassportToFirestore();
  renderPassportPage();
  saveState();
  closePassportModal('passportMemoryModal');
}

window.openActivityModal = function (entryId) {
  document.getElementById('editActivityId').value = entryId || '';
  const title = document.getElementById('activityModalTitle');
  if (entryId) {
    if (title) title.textContent = '✏️ Edit Activity';
    const entry = DEMO.passport.entries.find(e => e.id === entryId);
    if (entry) {
      const v = entry.values || {};
      document.getElementById('editActivityName').value = v.name || entry.name || '';
      document.getElementById('editActivityNotes').value = v.notes || '';
    }
  } else {
    if (title) title.textContent = '➕ Add Activity / Hobby';
    document.getElementById('editActivityName').value = '';
    document.getElementById('editActivityNotes').value = '';
  }
  openPassportModal('passportActivityModal');
};

function handleSaveActivity() {
  const id = document.getElementById('editActivityId').value.trim();
  const name = document.getElementById('editActivityName').value.trim();
  const notes = document.getElementById('editActivityNotes').value.trim();

  if (!name) return alert('Please enter an activity name');

  const values = { name };
  if (notes) values.notes = notes;

  if (id) {
    const idx = DEMO.passport.entries.findIndex(e => e.id === id);
    if (idx >= 0) DEMO.passport.entries[idx].values = values;
  } else {
    DEMO.passport.entries.push({
      id: `act_${Date.now()}`,
      kind: 'activity',
      values
    });
  }

  // Sync the first activity entry to the profile's favourite activity display
  const firstAct = (DEMO.passport.entries || []).find(e => e.kind === 'activity');
  if (firstAct) {
    const favEl = document.getElementById('passportFavActivity');
    if (favEl) favEl.textContent = firstAct.values?.name || '🌱 Gardening';
  }

  savePassportToFirestore();
  renderPassportPage();
  saveState();
  closePassportModal('passportActivityModal');
}

window.deletePassportEntry = function (entryId) {
  if (!confirm('Are you sure you want to remove this item from Memory Passport?')) return;
  DEMO.passport.entries = (DEMO.passport.entries || []).filter(e => e.id !== entryId);
  syncRoutinesFromPassport();
  savePassportToFirestore();
  renderPassportPage();
  saveState();
};

// ══════════════════════════════════════════
// DAILY NOTES (Persistent)
// ══════════════════════════════════════════

function renderReportNotes() {
  const reportNotesEl = document.getElementById('reportNotesList') || document.getElementById('reportNotesFeed');
  if (!reportNotesEl) return;
  reportNotesEl.innerHTML = notes.slice(0, 3).map(n => `
    <div class="report-note-item" style="padding:10px 0;border-bottom:1px solid var(--border-light);">
      <div style="font-size:12px;color:var(--text-muted);margin-bottom:4px;"><strong>${n.author}</strong> · <span>${n.date}</span></div>
      <p style="font-size:13px;line-height:1.4;">${n.text}</p>
    </div>
  `).join('');
}

function initNotes() {
  const dateEl = document.getElementById('noteFormDate');
  if (dateEl) {
    dateEl.textContent = new Date().toLocaleDateString('en-IN', { day: 'numeric', month: 'short' });
  }

  document.querySelectorAll('.mood-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.mood-btn').forEach(b => b.classList.remove('selected'));
      btn.classList.add('selected');
      selectedMood = btn.dataset.mood;
    });
  });

  document.querySelectorAll('.tag-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.tag-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      selectedTag = btn.dataset.tag;
    });
  });

  const addBtn = document.getElementById('addNoteBtn');
  if (addBtn) {
    addBtn.addEventListener('click', () => {
      const textarea = document.getElementById('noteInput');
      const text = textarea?.value?.trim();
      if (!text) { textarea?.focus(); return; }
      const newNote = {
        id: Date.now(),
        date: new Date().toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' }) + ', Today',
        mood: selectedMood || 'calm',
        tag:  selectedTag || 'general',
        text,
        author: 'Rahul',
      };
      notes.unshift(newNote);
      saveState();
      renderNotesFeed(notes);
      renderReportNotes();
      textarea.value = '';
      selectedMood = null;
      selectedTag  = 'general';
      document.querySelectorAll('.mood-btn').forEach(b => b.classList.remove('selected'));
      document.querySelectorAll('.tag-btn').forEach(b => b.classList.remove('active'));
      document.querySelector('.tag-btn[data-tag="general"]')?.classList.add('active');

      addBtn.textContent = '✓ Saved!';
      addBtn.style.background = 'var(--green-600)';
      setTimeout(() => { addBtn.textContent = 'Save Note'; addBtn.style.background = ''; }, 1800);
    });
  }

  const filterSel = document.getElementById('notesFilter');
  if (filterSel) {
    filterSel.addEventListener('change', () => {
      const val = filterSel.value;
      renderNotesFeed(val === 'all' ? notes : notes.filter(n => n.tag === val));
    });
  }

  renderNotesFeed(notes);
}

function renderNotesFeed(list) {
  const feed = document.getElementById('notesFeed');
  if (!feed) return;
  if (!list.length) {
    feed.innerHTML = '<p style="color:var(--text-muted);padding:16px 0;text-align:center">No notes yet. Add your first observation above.</p>';
    return;
  }
  feed.innerHTML = list.map(note => `
    <div class="note-card ${note.tag}">
      <div class="note-top">
        <span class="note-mood-chip">${MOOD_EMOJI[note.mood] ?? '🙂'} ${note.mood.charAt(0).toUpperCase() + note.mood.slice(1)}</span>
        <span class="note-tag-chip ${note.tag}">${note.tag}</span>
        <span class="note-meta">${note.date}</span>
      </div>
      <p class="note-text">${note.text}</p>
      <p class="note-author">Logged by ${note.author}</p>
    </div>
  `).join('');
}

// ══════════════════════════════════════════
// WEEKLY REPORT
// ══════════════════════════════════════════
function initReport() {
  const now   = new Date();
  const day   = now.getDay();
  const start = new Date(now); start.setDate(now.getDate() - day);
  const end   = new Date(start); end.setDate(start.getDate() + 6);
  const fmt   = d => d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' });
  const rangeEl = document.getElementById('reportWeekRange');
  const dateEl  = document.getElementById('reportDate');
  if (rangeEl) rangeEl.textContent = `${fmt(start)} – ${fmt(end)}`;
  if (dateEl)  dateEl.textContent  = `Generated: ${fmt(now)} ${now.getFullYear()}`;

  renderReportNotes();
}

function renderReportNotes() {
  const container = document.getElementById('reportNotes');
  if (!container) return;
  const recent = notes.slice(0, 4);
  if (!recent.length) {
    container.innerHTML = '<p style="color:var(--text-muted);font-size:13px">No caretaker notes logged this week.</p>';
    return;
  }
  container.innerHTML = recent.map(n => `
    <div class="report-note-item">
      <h4>${MOOD_EMOJI[n.mood] ?? ''} ${n.mood.charAt(0).toUpperCase() + n.mood.slice(1)} · <span style="text-transform:capitalize;font-weight:500">${n.tag}</span></h4>
      <p>${n.text}</p>
      <span>${n.date} — ${n.author}</span>
    </div>
  `).join('');
}

// ══════════════════════════════════════════
// SETTINGS (Live Updates & Persistence)
// ══════════════════════════════════════════
function initSettings() {}

window.savePatientSettings = function () {
  const name = document.getElementById('settingPatientName')?.value?.trim();
  const age = document.getElementById('settingPatientAge')?.value?.trim();
  const region = document.getElementById('settingPatientRegion')?.value?.trim();

  if (name) DEMO.patient.name = name;
  if (age) DEMO.patient.age = parseInt(age, 10) || DEMO.patient.age;
  if (region) DEMO.patient.region = region;

  saveState();
  applyPatientName();

  const badge = document.getElementById('patientSaveBadge');
  if (badge) {
    badge.textContent = '✓ Saved to Storage';
    badge.style.opacity = '1';
    setTimeout(() => { badge.style.opacity = '0'; }, 2500);
  }
};

// ══════════════════════════════════════════
// DATA SYNC / FIREBASE / IMPORT / EXPORT
// ══════════════════════════════════════════
function initSyncModal() {
  const syncBtn = document.getElementById('syncDataBtn');
  const modal = document.getElementById('syncModal');
  const closeBtn = document.getElementById('closeSyncModal');
  const exportBtn = document.getElementById('exportDataBtn');
  const fileInput = document.getElementById('jsonFileInput');
  const connectBtn = document.getElementById('btnConnectFirestore');
  const seedBtn = document.getElementById('btnSeedFirestore');
  const pullBtn = document.getElementById('btnPullFirestore');
  const patientInput = document.getElementById('patientCloudIdInput');

  if (syncBtn && modal) {
    syncBtn.addEventListener('click', () => {
      modal.classList.add('show');
      if (patientInput) patientInput.value = currentPatientUid;
    });
  }
  if (closeBtn && modal) {
    closeBtn.addEventListener('click', () => modal.classList.remove('show'));
  }
  if (modal) {
    modal.addEventListener('click', e => {
      if (e.target === modal) modal.classList.remove('show');
    });
  }

  // Connect & Listen to Custom Patient UID
  if (connectBtn && patientInput) {
    connectBtn.addEventListener('click', async () => {
      const linkCode = patientInput.value.trim();
      const status = document.getElementById('firebaseSyncStatus');
      if (!linkCode) {
        if (status) status.textContent = 'Enter the link code shown on the Saathi phone.';
        return;
      }
      connectBtn.disabled = true;
      if (status) status.textContent = 'Checking the patient link code…';
      try {
        const patientId = await claimPatientAccess(linkCode);
        currentPatientUid = patientId;
        isFirebaseOnline = true;
        localStorage.setItem('saathi_patient_uid', patientId);
        attachFirestoreListeners(patientId);
        updateFirebaseBadge(true, 'Firebase: Patient linked');
        if (status) status.textContent = `🟢 Linked to patient: ${patientId}`;
      } catch (err) {
        console.error('Patient link failed:', err);
        isFirebaseOnline = false;
        updateFirebaseBadge(false, 'Firebase: Link failed');
        if (status) status.textContent = `Could not link: ${err.message}`;
      } finally {
        connectBtn.disabled = false;
      }
    });
  }

  // Seed Firestore with Demo Data
  if (seedBtn) {
    seedBtn.addEventListener('click', seedFirestoreWithDemoData);
  }

  // Pull latest from Firestore
  if (pullBtn) {
    pullBtn.addEventListener('click', pullFromFirestore);
  }

  // Export JSON
  if (exportBtn) {
    exportBtn.addEventListener('click', () => {
      const dataStr = 'data:text/json;charset=utf-8,' + encodeURIComponent(JSON.stringify(DEMO, null, 2));
      const downloadAnchor = document.createElement('a');
      downloadAnchor.setAttribute('href', dataStr);
      downloadAnchor.setAttribute('download', `saathi_caretaker_backup_${Date.now()}.json`);
      document.body.appendChild(downloadAnchor);
      downloadAnchor.click();
      downloadAnchor.remove();
    });
  }

  // Import JSON
  if (fileInput) {
    fileInput.addEventListener('change', e => {
      const file = e.target.files[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = evt => {
        try {
          const imported = JSON.parse(evt.target.result);
          if (imported.recentActivity) DEMO.recentActivity = imported.recentActivity;
          if (imported.patient) DEMO.patient = imported.patient;
          if (imported.todayPlan) DEMO.todayPlan = imported.todayPlan;
          saveState();
          init();
          alert('✓ Data successfully imported from Saathi Patient App!');
          modal?.classList.remove('show');
        } catch (err) {
          alert('Failed to parse JSON file. Please ensure it is a valid Saathi export.');
        }
      };
      reader.readAsText(file);
    });
  }
}

// ══════════════════════════════════════════
// AI CHECKUP DISPATCHER & LIVE MONITOR
// ══════════════════════════════════════════
function initAiCheckupModal() {
  const topBtn = document.getElementById('triggerAiCheckupTopBtn');
  const modal = document.getElementById('aiCheckupModal');
  const closeBtn = document.getElementById('closeAiModal');
  const statusText = document.getElementById('aiStatusText');
  const statusSub = document.getElementById('patientStatusSub');
  let stopWatchingCommand = null;

  window.openAiCheckupModal = function () {
    if (!modal) return;
    modal.classList.add('show');
    if (!db || !currentPatientUid || !isFirebaseOnline) {
      if (statusText) statusText.textContent = 'Connect this portal to the patient first';
      if (statusSub) statusSub.textContent = 'Open Sync / Cloud Data and enter the phone link code.';
      return;
    }

    if (statusText) statusText.textContent = 'Sending memory checkup to the phone…';
    if (statusSub) statusSub.textContent = 'Waiting for Saathi to receive the request.';
    if (stopWatchingCommand) stopWatchingCommand();

    sendAiCheckupCommandToFirestore('Memory Passport cognitive checkup').then(commandRef => {
      stopWatchingCommand = commandRef.onSnapshot(snapshot => {
        const command = snapshot.data() || {};
        if (command.status === 'started') {
          if (statusText) statusText.textContent = '🟢 Checkup started on the patient\'s phone';
          if (statusSub) statusSub.textContent = 'Saathi opened the cognitive games and is reading the questions aloud.';
        } else if (command.status === 'completed') {
          const score = Number.isFinite(command.correct) && Number.isFinite(command.total)
            ? ` · Score ${command.correct}/${command.total}`
            : '';
          if (statusText) statusText.textContent = `✓ Checkup completed${score}`;
          if (statusSub) statusSub.textContent = 'The answers are now available in Cognitive Records.';
          stopWatchingCommand?.();
          stopWatchingCommand = null;
        } else {
          if (statusText) statusText.textContent = 'Checkup sent · waiting for the phone';
          if (statusSub) statusSub.textContent = 'Keep the patient phone online with Saathi running.';
        }
      }, err => {
        if (statusText) statusText.textContent = 'Could not monitor this checkup';
        if (statusSub) statusSub.textContent = err.message;
      });
    }).catch(err => {
      if (statusText) statusText.textContent = 'Could not send the checkup';
      if (statusSub) statusSub.textContent = err.message;
    });
  };

  if (topBtn) {
    topBtn.addEventListener('click', window.openAiCheckupModal);
  }

  if (closeBtn && modal) {
    closeBtn.addEventListener('click', () => modal.classList.remove('show'));
  }
  if (modal) {
    modal.addEventListener('click', e => {
      if (e.target === modal) modal.classList.remove('show');
    });
  }

}

// ══════════════════════════════════════════
// FIREBASE CLOUD FIRESTORE INTEGRATION
// ══════════════════════════════════════════
const FIREBASE_CONFIG = {
  apiKey: "AIzaSyBhfqENBQ-8V32m3-Ms6qC3EX8iT93Grcw",
  authDomain: "hiasaathi.firebaseapp.com",
  projectId: "hiasaathi",
  storageBucket: "hiasaathi.firebasestorage.app",
  messagingSenderId: "401722228770",
  appId: "1:401722228770:web:6a95332a15d2bf397bca7b"
};

let db = null;
const savedPatientUid = localStorage.getItem('saathi_patient_uid');
let currentPatientUid = savedPatientUid === 'demo_patient_bora'
  ? ''
  : (savedPatientUid || '');
let activeUnsubscribers = [];
let isFirebaseOnline = false;
let biomarkerRecords = [];
let cloudCompletedEventIds = new Set();

function localDayKey(date = new Date()) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function applyCloudCompletions() {
  DEMO.todayPlan = (DEMO.todayPlan || []).map(item => ({
    ...item,
    done: item.id ? cloudCompletedEventIds.has(item.id) : item.done === true
  }));
  renderTodayList();
  renderLinkedSchedule();
  saveState();
}

function initFirebase() {
  if (typeof firebase === 'undefined') {
    updateFirebaseBadge(false, 'Firebase: Offline mode');
    return;
  }

  try {
    if (!firebase.apps || !firebase.apps.length) {
      firebase.initializeApp(FIREBASE_CONFIG);
    }
    db = firebase.firestore();

    // Authenticate anonymously
    firebase.auth().signInAnonymously().then(async () => {
      if (currentPatientUid) {
        try {
          currentPatientUid = await claimPatientAccess(currentPatientUid);
          isFirebaseOnline = true;
          attachFirestoreListeners(currentPatientUid);
          updateFirebaseBadge(true, 'Firebase: Patient linked');
        } catch (err) {
          console.warn('Saved patient link is no longer valid:', err.message);
          localStorage.removeItem('saathi_patient_uid');
          currentPatientUid = '';
          isFirebaseOnline = false;
          updateFirebaseBadge(false, 'Firebase: Enter phone link code');
        }
      } else {
        isFirebaseOnline = false;
        updateFirebaseBadge(false, 'Firebase: Enter phone link code');
      }
    }).catch(err => {
      console.error('Firebase anonymous sign-in failed:', err.message);
      isFirebaseOnline = false;
      updateFirebaseBadge(false, 'Firebase: Sign-in failed');
    });
  } catch (err) {
    console.error('Firebase initialization error:', err);
    updateFirebaseBadge(false, 'Firebase: Offline mode');
  }
}

function updateFirebaseBadge(online, label) {
  const badge = document.getElementById('firebaseLiveBadge');
  const text = document.getElementById('firebaseStatusText');
  const syncStatus = document.getElementById('firebaseSyncStatus');
  const modalPill = document.getElementById('modalFirebaseStatusPill');
  const settingsStatus = document.getElementById('settingsFirebaseStatus');
  const settingsProject = document.getElementById('settingsFirebaseProject');
  const settingsUid = document.getElementById('settingsPatientUid');
  const settingsLastSync = document.getElementById('settingsLastSync');

  if (badge) {
    badge.className = online ? 'firebase-badge live' : 'firebase-badge offline';
  }
  if (text) text.textContent = label;
  if (modalPill) {
    modalPill.textContent = online ? 'Live Connected' : 'Offline';
    modalPill.className = online ? 'badge badge-success' : 'badge badge-neutral';
  }
  if (syncStatus) {
    syncStatus.textContent = online ? `🟢 Connected to hiasaathi Firestore · Patient: ${currentPatientUid}` : `⚠️ ${label}`;
  }
  if (settingsStatus) {
    settingsStatus.textContent = online ? 'Connected (Live Firestore)' : 'Offline mode';
    settingsStatus.className = online ? 'about-val about-active' : 'about-val about-inactive';
  }
  if (settingsProject) settingsProject.textContent = 'hiasaathi';
  if (settingsUid) settingsUid.textContent = currentPatientUid;
  if (settingsLastSync) settingsLastSync.textContent = new Date().toLocaleTimeString();
}

function formatRecordKindLabel(kind) {
  switch (kind) {
    case 'familyRecognition': return 'Family Recognition';
    case 'videoRecall': return 'Video Recall';
    case 'medicineRecall': return 'Medication Recall';
    case 'routineRecall': return 'Daily Routine Recall';
    case 'episodicRecall': return 'Life Memories';
    case 'culturalRecall': return 'North-East Memories';
    default: return kind || 'Cognitive Exercise';
  }
}

function formatTimestamp(ts) {
  if (!ts) return 'Just now';
  try {
    const d = new Date(ts);
    const diffMs = Date.now() - d.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    if (diffMins < 2) return 'Just now';
    if (diffMins < 60) return `${diffMins} min ago`;
    const diffHrs = Math.floor(diffMins / 60);
    if (diffHrs < 24) return `${diffHrs} hr${diffHrs > 1 ? 's' : ''} ago`;
    const diffDays = Math.floor(diffHrs / 24);
    if (diffDays === 1) return 'Yesterday';
    return `${diffDays} days ago`;
  } catch (_) {
    return 'Recently';
  }
}

function recalculateStability() {
  const records = DEMO.recentActivity || [];
  const correct = records.filter(a => a.correct).length;
  const pct = records.length ? Math.round((correct / records.length) * 100) : null;
  const score = document.getElementById('cognitiveAccuracyValue');
  const donut = document.getElementById('cognitiveAccuracyDonut');
  const legend = document.getElementById('cognitiveAccuracyLegend');
  if (score) score.textContent = pct === null ? '—' : `${pct}%`;
  if (donut) donut.textContent = pct === null ? '—' : `${pct}%`;
  if (legend) legend.textContent = pct === null
    ? 'No synced exercise results yet'
    : `${correct} of ${records.length} recent answers correct`;
  const ring = document.getElementById('cognitiveAccuracyRing');
  if (ring) ring.setAttribute('stroke-dashoffset', String(Math.round(276 * (1 - (pct || 0) / 100))));
}

function renderDigitalBiomarkers() {
  const metrics = computeDigitalBiomarkers(biomarkerRecords);
  const response = document.getElementById('biomarkerResponseTime');
  const hint = document.getElementById('biomarkerHintTime');
  const delayed = document.getElementById('biomarkerDelayedRecall');
  const overviewResponse = document.getElementById('overviewResponseValue');
  const overviewHints = document.getElementById('overviewHintValue');
  if (overviewResponse) overviewResponse.textContent = metrics.responseTime.medianMs === null
    ? '—' : `${(metrics.responseTime.medianMs / 1000).toFixed(1)}s`;
  if (overviewHints) overviewHints.textContent = biomarkerRecords.length
    ? (biomarkerRecords.reduce((sum, record) => sum + (Number.isFinite(record.hintsUsed) ? record.hintsUsed : 0), 0) / biomarkerRecords.length).toFixed(1)
    : '—';
  if (response) response.textContent = metrics.responseTime.medianMs === null
    ? 'No synced answers yet'
    : `Median ${(metrics.responseTime.medianMs / 1000).toFixed(1)} s across ${metrics.responseTime.count} answers`;
  if (hint) hint.textContent = metrics.firstHintTime.medianMs === null
    ? 'No tracked hint requests yet'
    : `Median ${(metrics.firstHintTime.medianMs / 1000).toFixed(1)} s across ${metrics.firstHintTime.count} first hints`;
  if (delayed) delayed.textContent = metrics.accuracyGap === null
    ? 'No immediate and delayed video results yet'
    : `Immediate ${metrics.immediate.accuracy}% (${metrics.immediate.count}); delayed ${metrics.delayed.accuracy}% (${metrics.delayed.count}); difference ${metrics.accuracyGap > 0 ? '+' : ''}${metrics.accuracyGap} percentage points. Groups are not paired by session.`;
}

function attachFirestoreListeners(patientUid) {
  if (!db || !patientUid) return;

  biomarkerRecords = [];
  renderDigitalBiomarkers();

  // Unsubscribe previous listeners
  activeUnsubscribers.forEach(unsub => {
    try { unsub(); } catch (_) {}
  });
  activeUnsubscribers = [];
  cloudCompletedEventIds = new Set();
  const narrativeText = document.getElementById('dailyNarrativeText');
  if (narrativeText) narrativeText.textContent = 'No summary shared from the phone today.';

  // Only a patient-selected summary is shown. Raw action events stay on the phone.
  try {
    const narrativeRef = db.collection('patients').doc(patientUid)
      .collection('dailyNarratives').doc(localDayKey());
    const unsubNarrative = narrativeRef.onSnapshot(doc => {
      if (!narrativeText) return;
      const data = doc.exists ? doc.data() : null;
      const lines = Array.isArray(data?.lines) ? data.lines
        .filter(line => typeof line === 'string').slice(0, 4) : [];
      narrativeText.textContent = lines.length
        ? lines.join('\n') : 'No summary shared from the phone today.';
    }, err => console.warn('Firestore daily narrative listener:', err.message));
    activeUnsubscribers.push(unsubNarrative);
  } catch (err) {
    console.warn('Could not attach daily narrative listener:', err);
  }

  // 1. Listen to Records: patients/{uid}/records
  try {
    const recordsRef = db.collection('patients').doc(patientUid).collection('records');
    const unsubRecords = recordsRef.orderBy('timestamp', 'desc').limit(20).onSnapshot(snapshot => {
      biomarkerRecords = snapshot.docs.map(doc => doc.data());
      renderDigitalBiomarkers();
      if (snapshot.empty) {
        DEMO.recentActivity = [];
        DEMO.hintSparkline = [];
        recalculateStability();
        renderRecentActivity();
        renderRecordsTable();
        renderHintSparkline();
        return;
      }
      if (snapshot && !snapshot.empty) {
        const records = [];
        snapshot.forEach(doc => {
          const d = doc.data();
          records.push({
            type: recordType(d.kind),
            label: formatRecordKindLabel(d.kind),
            correct: d.correct === true,
            hints: d.hintsUsed ?? 0,
            responseMs: d.responseMs,
            time: formatTimestamp(d.timestamp),
            diff: d.difficulty === 1 ? 'easy' : d.difficulty === 3 ? 'hard' : 'medium'
          });
        });
        DEMO.recentActivity = records;
        DEMO.hintSparkline = records.slice(0, 7).map(record => record.hints).reverse();
        recalculateStability();
        saveState();
        renderRecentActivity();
        renderRecordsTable();
        renderHintSparkline();
        updateFirebaseBadge(true, 'Firebase: hiasaathi (Live)');
      }
    }, err => {
      console.warn('Firestore records listener:', err.message);
    });
    activeUnsubscribers.push(unsubRecords);
  } catch (err) {
    console.warn('Could not attach records listener:', err);
  }

  // 2. Listen to Passport: patients/{uid}/passport/current
  try {
    const passportRef = db.collection('patients').doc(patientUid).collection('passport').doc('current');
    const unsubPassport = passportRef.onSnapshot(doc => {
      if (doc && doc.exists) {
        const data = doc.data();
        if (data) {
          DEMO.passport = {
            ...DEMO.passport,
            ...data,
            entries: data.entries || DEMO.passport.entries || []
          };
          if (data.name) DEMO.patient.name = data.name;
          if (data.age) DEMO.patient.age = data.age;
          if (data.region) DEMO.patient.region = data.region;
          syncRoutinesFromPassport();
          applyPatientName();
          renderPassportPage();
          saveState();
          updateFirebaseBadge(true, 'Firebase: hiasaathi (Live)');
          updatePassportSyncBadge(true);
        }
      } else {
        console.log('No passport in Firestore for', patientUid, '-> seeding default passport');
        savePassportToFirestore();
      }
    }, err => {
      console.warn('Firestore passport listener:', err.message);
      updatePassportSyncBadge(false, err.message);
    });
    activeUnsubscribers.push(unsubPassport);
  } catch (err) {
    console.warn('Could not attach passport listener:', err);
  }

  // 3. Listen to today's medicine and routine confirmations from the phone.
  try {
    const completionsRef = db
      .collection('patients')
      .doc(patientUid)
      .collection('dailyCompletions')
      .where('day', '==', localDayKey());
    const unsubCompletions = completionsRef.onSnapshot(snapshot => {
      const completed = new Set();
      snapshot.forEach(doc => {
        const data = doc.data();
        if (data && typeof data.eventId === 'string') completed.add(data.eventId);
      });
      cloudCompletedEventIds = completed;
      applyCloudCompletions();
      updateFirebaseBadge(true, 'Firebase: hiasaathi (Live)');
    }, err => {
      console.warn('Firestore daily completions listener:', err.message);
    });
    activeUnsubscribers.push(unsubCompletions);
  } catch (err) {
    console.warn('Could not attach daily completions listener:', err);
  }
}

function recordType(kind) {
  switch (kind) {
    case 'familyRecognition': return 'family';
    case 'videoRecall': return 'video';
    case 'medicineRecall': return 'medicine';
    case 'culturalRecall': return 'culture';
    default: return 'routine';
  }
}

async function claimPatientAccess(linkCode) {
  if (!db || !firebase.auth().currentUser) {
    throw new Error('Firebase is not signed in yet. Please try again.');
  }
  const pairing = await db.collection('pairings').doc(linkCode).get();
  if (!pairing.exists || pairing.data()?.patientId !== linkCode) {
    throw new Error('That link code was not found. Copy it again from the phone.');
  }
  const patientId = pairing.data().patientId;
  const caretakerUid = firebase.auth().currentUser.uid;
  await db
    .collection('patients')
    .doc(patientId)
    .collection('members')
    .doc(caretakerUid)
    .set({
      role: 'caretaker',
      pairingCode: linkCode,
      joinedAt: firebase.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
  return patientId;
}

function sendAiCheckupCommandToFirestore(question) {
  if (!db || !currentPatientUid || !isFirebaseOnline) {
    return Promise.reject(new Error('The patient is not linked to Firebase.'));
  }
  const cmdRef = db.collection('patients').doc(currentPatientUid).collection('commands').doc();
  return cmdRef.set({
    type: 'ai_checkup',
    status: 'sent',
    question: question || 'Cognitive checkup challenge',
    timestamp: firebase.firestore.FieldValue.serverTimestamp(),
    createdAt: new Date().toISOString()
  }).then(() => cmdRef);
}

function pullFromFirestore() {
  if (!db || !currentPatientUid || !isFirebaseOnline) {
    alert('Firebase is not connected.');
    return;
  }
  const statusEl = document.getElementById('firebaseSyncStatus');
  if (statusEl) statusEl.textContent = 'Pulling data from Firestore...';

  db.collection('patients').doc(currentPatientUid).collection('records').orderBy('timestamp', 'desc').limit(20).get().then(snapshot => {
    biomarkerRecords = snapshot.docs.map(doc => doc.data());
    renderDigitalBiomarkers();
    if (!snapshot.empty) {
      const records = [];
      snapshot.forEach(doc => {
        const d = doc.data();
        records.push({
          type: recordType(d.kind),
          label: formatRecordKindLabel(d.kind),
          correct: d.correct === true,
          hints: d.hintsUsed ?? 0,
          responseMs: d.responseMs,
          time: formatTimestamp(d.timestamp),
          diff: d.difficulty === 1 ? 'easy' : d.difficulty === 3 ? 'hard' : 'medium'
        });
      });
      DEMO.recentActivity = records;
      DEMO.hintSparkline = records.slice(0, 7).map(record => record.hints).reverse();
      recalculateStability();
      saveState();
      renderRecentActivity();
      renderRecordsTable();
      renderHintSparkline();
      if (statusEl) statusEl.textContent = `✓ Fetched ${records.length} records from Firestore!`;
      alert(`✓ Successfully refreshed ${records.length} cognitive records from Firebase Firestore!`);
    } else {
      DEMO.recentActivity = [];
      DEMO.hintSparkline = [];
      recalculateStability();
      renderRecentActivity();
      renderRecordsTable();
      renderHintSparkline();
      if (statusEl) statusEl.textContent = `No records found in Firestore for ${currentPatientUid}.`;
      alert(`No cognitive records yet for ${currentPatientUid}. Complete an exercise on the phone, then sync.`);
    }
  }).catch(err => {
    console.error('Pull error:', err);
    if (statusEl) statusEl.textContent = `Error: ${err.message}`;
    alert(`Could not pull from Firestore: ${err.message}`);
  });
}

function seedFirestoreWithDemoData() {
  if (!db || !currentPatientUid || !isFirebaseOnline) {
    alert('Firebase is not initialized.');
    return;
  }
  const statusEl = document.getElementById('firebaseSyncStatus');
  if (statusEl) statusEl.textContent = 'Pushing demo data to Firestore (hiasaathi)...';

  const batch = db.batch();

  // 1. Passport
  const passRef = db.collection('patients').doc(currentPatientUid).collection('passport').doc('current');
  batch.set(passRef, {
    schemaVersion: 1,
    name: DEMO.passport.name || 'Mr. Bora',
    age: DEMO.passport.age || 72,
    region: DEMO.passport.region || 'Assam, North-East India',
    isDemo: false,
    revision: 1,
    entries: DEMO.passport.entries || []
  });

  // 2. Records
  DEMO.recentActivity.forEach((rec, idx) => {
    const recRef = db.collection('patients').doc(currentPatientUid).collection('records').doc(`rec_${Date.now()}_${idx}`);
    batch.set(recRef, {
      schemaVersion: 1,
      id: `rec_${Date.now()}_${idx}`,
      kind: rec.type === 'family' ? 'familyRecognition' : rec.type === 'video' ? 'videoRecall' : rec.type === 'culture' ? 'culturalRecall' : rec.type === 'routine' ? 'routineRecall' : 'medicineRecall',
      entryId: 'entry_seed',
      correct: rec.correct,
      responseMs: 3200 + idx * 350,
      hintsUsed: rec.hints,
      difficulty: rec.diff === 'easy' ? 1 : rec.diff === 'hard' ? 3 : 2,
      timestamp: new Date(Date.now() - idx * 3600000).toISOString()
    });
  });

  batch.commit().then(() => {
    if (statusEl) statusEl.textContent = '✓ Firestore successfully seeded with patient records!';
    alert('✓ Successfully populated Firebase Firestore (hiasaathi) with patient data!');
    updateFirebaseBadge(true, 'Firebase: hiasaathi (Live)');
  }).catch(err => {
    console.error('Seed error:', err);
    if (statusEl) statusEl.textContent = `Error: ${err.message}`;
    alert(`Could not push to Firestore: ${err.message}`);
  });
}

// Run after DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}





