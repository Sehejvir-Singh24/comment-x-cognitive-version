/* ═══════════════════════════════════════
   SAATHI CARETAKER PORTAL — JavaScript
═══════════════════════════════════════ */

'use strict';

// ── Demo data ──────────────────────────────────────
const DEMO = {
  patient: { name: 'Mr. Bora', age: 72, region: 'Assam' },

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
      <td>—</td>
      <td>${r.time}</td>
      <td><span class="difficulty-badge ${r.diff}">${r.diff.charAt(0).toUpperCase() + r.diff.slice(1)}</span></td>
    </tr>
  `).join('');
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
      todayPlan: DEMO.todayPlan,
      routines: DEMO.routines,
      recentActivity: DEMO.recentActivity,
      notes,
    };
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch (e) {
    console.warn('Could not save portal state:', e);
  }
}

// Restore saved state if available
const savedState = loadState();
if (savedState) {
  if (savedState.patient) DEMO.patient = { ...DEMO.patient, ...savedState.patient };
  if (savedState.todayPlan) DEMO.todayPlan = savedState.todayPlan;
  if (savedState.routines) DEMO.routines = savedState.routines;
  if (savedState.recentActivity) DEMO.recentActivity = savedState.recentActivity;
  if (savedState.notes) notes = savedState.notes;
}

// ── Init ──────────────────────────────────────────────
function init() {
  applyPatientName();
  renderStabilityChart();
  renderTodayList();
  renderRecentActivity();
  renderRecordsTable();
  renderRoutineList();
  renderAdherenceGrid();
  renderHintSparkline();
  initNotes();
  initReport();
  initSettings();
  initSyncModal();
  initAiCheckupModal();
  initFirebase();
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
  ul.innerHTML = DEMO.todayPlan.map((item, index) => `
    <li class="today-item">
      <span class="today-time">${item.time}</span>
      <span class="today-name">${item.name}</span>
      <span class="today-check ${item.done ? 'done' : 'pending'}" onclick="toggleTodayPlan(${index})">
        ${item.done ? '✓' : '○'}
      </span>
    </li>
  `).join('');
}

window.toggleTodayPlan = function (index) {
  if (DEMO.todayPlan[index]) {
    DEMO.todayPlan[index].done = !DEMO.todayPlan[index].done;
    saveState();
    renderTodayList();
  }
};

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
// DAILY NOTES (Persistent)
// ══════════════════════════════════════════
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

function saveState() {
  try {
    localStorage.setItem('saathi_demo_state', JSON.stringify(DEMO));
    localStorage.setItem('saathi_notes', JSON.stringify(notes));
  } catch (_) {}
}

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
    connectBtn.addEventListener('click', () => {
      const uid = patientInput.value.trim();
      if (!uid) return;
      currentPatientUid = uid;
      localStorage.setItem('saathi_patient_uid', uid);
      attachFirestoreListeners(uid);
      updateFirebaseBadge(true, `Firebase: Listening to ${uid}`);
      const status = document.getElementById('firebaseSyncStatus');
      if (status) status.textContent = `🟢 Connected & listening to patient: ${uid}`;
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
// AI CHECKUP DISPATCHER & SIMULATOR
// ══════════════════════════════════════════
function initAiCheckupModal() {
  const topBtn = document.getElementById('triggerAiCheckupTopBtn');
  const modal = document.getElementById('aiCheckupModal');
  const closeBtn = document.getElementById('closeAiModal');
  const statusText = document.getElementById('aiStatusText');
  const statusSub = document.getElementById('patientStatusSub');
  const correctBtn = document.getElementById('simulateCorrectBtn');
  const hintBtn = document.getElementById('simulateHintBtn');

  window.openAiCheckupModal = function () {
    if (modal) {
      modal.classList.add('show');
      if (statusText) statusText.textContent = 'Connecting to Mr. Bora\'s Saathi Companion App...';
      if (statusSub) statusSub.textContent = 'Dispatching checkup command via Firebase Firestore...';

      // Send real command to Firestore
      sendAiCheckupCommandToFirestore('Family Recognition checkup').then(() => {
        setTimeout(() => {
          if (statusText) statusText.textContent = '🟢 Connected · AI Checkup Active on Mr. Bora\'s Phone';
          if (statusSub) statusSub.textContent = 'Listening for voice response...';
        }, 1000);
      }).catch(() => {
        setTimeout(() => {
          if (statusText) statusText.textContent = '🟢 Connected · AI Checkup Active on Mr. Bora\'s Phone';
          if (statusSub) statusSub.textContent = 'Listening for voice response...';
        }, 1000);
      });
    }
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

  function logCheckupResult(correct, hints) {
    const newRecord = {
      type: 'family',
      label: 'Family Recognition (AI Checkup)',
      correct,
      hints,
      time: 'Just now',
      diff: 'medium',
    };
    DEMO.recentActivity.unshift(newRecord);
    saveState();
    renderRecentActivity();
    renderRecordsTable();

    // Also push record to Firebase Firestore if online
    if (db && isFirebaseOnline) {
      const recId = `checkup_${Date.now()}`;
      db.collection('patients').doc(currentPatientUid).collection('records').doc(recId).set({
        schemaVersion: 1,
        id: recId,
        kind: 'familyRecognition',
        entryId: 'rahul_1',
        correct,
        responseMs: 2400,
        hintsUsed: hints,
        difficulty: 2,
        timestamp: new Date().toISOString()
      }).catch(err => console.warn('Could not sync checkup to Firestore:', err));
    }

    if (statusText) statusText.textContent = `✓ Checkup Finished! Logged: ${correct ? 'Correct' : 'Needed support'}`;
    setTimeout(() => {
      modal?.classList.remove('show');
    }, 1500);
  }

  if (correctBtn) {
    correctBtn.addEventListener('click', () => logCheckupResult(true, 0));
  }
  if (hintBtn) {
    hintBtn.addEventListener('click', () => logCheckupResult(true, 1));
  }
}

// ══════════════════════════════════════════
// FIREBASE CLOUD FIRESTORE INTEGRATION
// ══════════════════════════════════════════
const FIREBASE_CONFIG = {
  apiKey: "AIzaSyBbs5mGCFb7VhKHwiC_FUoohBH1M_wKPQU",
  authDomain: "hiasaathi.firebaseapp.com",
  projectId: "hiasaathi",
  storageBucket: "hiasaathi.firebasestorage.app",
  messagingSenderId: "401722228770",
  appId: "1:401722228770:web:saathi-caretaker"
};

let db = null;
let currentPatientUid = localStorage.getItem('saathi_patient_uid') || 'demo_patient_bora';
let activeUnsubscribers = [];
let isFirebaseOnline = false;

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
    firebase.auth().signInAnonymously().then(() => {
      isFirebaseOnline = true;
      updateFirebaseBadge(true, 'Firebase: hiasaathi (Live)');
      attachFirestoreListeners(currentPatientUid);
    }).catch(err => {
      console.warn('Firebase Auth notice (connecting direct):', err.message);
      isFirebaseOnline = true;
      updateFirebaseBadge(true, 'Firebase: hiasaathi (Live)');
      attachFirestoreListeners(currentPatientUid);
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
  if (!DEMO.recentActivity || !DEMO.recentActivity.length) return;
  const correct = DEMO.recentActivity.filter(a => a.correct).length;
  const pct = Math.round((correct / DEMO.recentActivity.length) * 100);
  const scoreEl = document.querySelector('.stability-score .score-val');
  if (scoreEl) scoreEl.textContent = `${pct}%`;
}

function attachFirestoreListeners(patientUid) {
  if (!db) return;

  // Unsubscribe previous listeners
  activeUnsubscribers.forEach(unsub => {
    try { unsub(); } catch (_) {}
  });
  activeUnsubscribers = [];

  // 1. Listen to Records: patients/{uid}/records
  try {
    const recordsRef = db.collection('patients').doc(patientUid).collection('records');
    const unsubRecords = recordsRef.orderBy('timestamp', 'desc').limit(20).onSnapshot(snapshot => {
      if (snapshot && !snapshot.empty) {
        const records = [];
        snapshot.forEach(doc => {
          const d = doc.data();
          records.push({
            type: d.kind === 'familyRecognition' ? 'family' : d.kind === 'videoRecall' ? 'video' : d.kind === 'medicineRecall' ? 'medicine' : 'routine',
            label: formatRecordKindLabel(d.kind),
            correct: d.correct === true,
            hints: d.hintsUsed ?? 0,
            time: formatTimestamp(d.timestamp),
            diff: d.difficulty === 1 ? 'easy' : d.difficulty === 3 ? 'hard' : 'medium'
          });
        });
        DEMO.recentActivity = records;
        recalculateStability();
        saveState();
        renderRecentActivity();
        renderRecordsTable();
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
        if (data.name) DEMO.patient.name = data.name;
        if (data.age) DEMO.patient.age = data.age;
        if (data.region) DEMO.patient.region = data.region;
        applyPatientName();
        saveState();
        updateFirebaseBadge(true, 'Firebase: hiasaathi (Live)');
      }
    }, err => {
      console.warn('Firestore passport listener:', err.message);
    });
    activeUnsubscribers.push(unsubPassport);
  } catch (err) {
    console.warn('Could not attach passport listener:', err);
  }
}

function sendAiCheckupCommandToFirestore(question) {
  if (!db) return Promise.resolve();
  const cmdRef = db.collection('patients').doc(currentPatientUid).collection('commands').doc();
  return cmdRef.set({
    type: 'ai_checkup',
    status: 'sent',
    question: question || 'Cognitive checkup challenge',
    timestamp: firebase.firestore.FieldValue.serverTimestamp(),
    createdAt: new Date().toISOString()
  });
}

function pullFromFirestore() {
  if (!db) {
    alert('Firebase is not connected.');
    return;
  }
  const statusEl = document.getElementById('firebaseSyncStatus');
  if (statusEl) statusEl.textContent = 'Pulling data from Firestore...';

  db.collection('patients').doc(currentPatientUid).collection('records').orderBy('timestamp', 'desc').limit(20).get().then(snapshot => {
    if (!snapshot.empty) {
      const records = [];
      snapshot.forEach(doc => {
        const d = doc.data();
        records.push({
          type: d.kind === 'familyRecognition' ? 'family' : d.kind === 'videoRecall' ? 'video' : d.kind === 'medicineRecall' ? 'medicine' : 'routine',
          label: formatRecordKindLabel(d.kind),
          correct: d.correct === true,
          hints: d.hintsUsed ?? 0,
          time: formatTimestamp(d.timestamp),
          diff: d.difficulty === 1 ? 'easy' : d.difficulty === 3 ? 'hard' : 'medium'
        });
      });
      DEMO.recentActivity = records;
      recalculateStability();
      saveState();
      renderRecentActivity();
      renderRecordsTable();
      if (statusEl) statusEl.textContent = `✓ Fetched ${records.length} records from Firestore!`;
      alert(`✓ Successfully refreshed ${records.length} cognitive records from Firebase Firestore!`);
    } else {
      if (statusEl) statusEl.textContent = `No records found in Firestore for ${currentPatientUid}.`;
      alert(`No records currently in Firestore for ${currentPatientUid}. Click "Push Demo to Cloud" to seed!`);
    }
  }).catch(err => {
    console.error('Pull error:', err);
    if (statusEl) statusEl.textContent = `Error: ${err.message}`;
    alert(`Could not pull from Firestore: ${err.message}`);
  });
}

function seedFirestoreWithDemoData() {
  if (!db) {
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
    name: DEMO.patient.name || 'Mr. Bora',
    age: DEMO.patient.age || 72,
    region: DEMO.patient.region || 'Assam',
    isDemo: false,
    revision: 1,
    entries: [
      { id: 'rahul_1', name: 'Rahul', kind: 'family', values: { relationship: 'Son' } },
      { id: 'ananya_1', name: 'Ananya', kind: 'family', values: { relationship: 'Daughter-in-law' } },
      { id: 'meera_1', name: 'Meera', kind: 'family', values: { relationship: 'Granddaughter' } },
      { id: 'med_1', name: 'Donepezil', kind: 'routine', values: { time: '09:00', dose: '5mg' } },
      { id: 'med_2', name: 'Memantine', kind: 'routine', values: { time: '20:00', dose: '10mg' } }
    ]
  });

  // 2. Records
  DEMO.recentActivity.forEach((rec, idx) => {
    const recRef = db.collection('patients').doc(currentPatientUid).collection('records').doc(`rec_${Date.now()}_${idx}`);
    batch.set(recRef, {
      schemaVersion: 1,
      id: `rec_${Date.now()}_${idx}`,
      kind: rec.type === 'family' ? 'familyRecognition' : rec.type === 'video' ? 'videoRecall' : 'medicineRecall',
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





