// ==========================================================
// Face ID for Mac - Interactive Application Logic
// ==========================================================

document.addEventListener('DOMContentLoaded', () => {
  initClock();
  initNotchSimulator();
  initCopyButton();
});

// Update simulated lock screen clock
function initClock() {
  const timeEl = document.getElementById('lockTime');
  const dateEl = document.getElementById('lockDate');

  function update() {
    const now = new Date();
    if (timeEl) {
      const hours = String(now.getHours()).padStart(2, '0');
      const mins = String(now.getMinutes()).padStart(2, '0');
      timeEl.textContent = `${hours}:${mins}`;
    }
    if (dateEl) {
      const options = { weekday: 'long', day: 'numeric', month: 'long' };
      dateEl.textContent = now.toLocaleDateString('en-US', options);
    }
  }

  update();
  setInterval(update, 1000);
}

// Interactive Dynamic Island Simulator
function initNotchSimulator() {
  const island = document.getElementById('dynamicIsland');
  const led = document.getElementById('cameraLed');
  const padlock = document.getElementById('lockPadlock');
  const progressBar = document.getElementById('islandProgress');
  const testScanBtn = document.getElementById('testScanBtn');
  const subtitleEl = document.getElementById('islandSubtitle');
  const titleEl = document.getElementById('islandTitle');

  if (!testScanBtn || !island) return;

  let isAnimating = false;

  testScanBtn.addEventListener('click', () => {
    if (isAnimating) return;
    runScanSimulation();
  });

  // Also trigger when clicking directly on the notch in the simulator
  island.addEventListener('click', () => {
    if (isAnimating) return;
    runScanSimulation();
  });

  function runScanSimulation() {
    isAnimating = true;
    testScanBtn.disabled = true;
    testScanBtn.textContent = 'Authenticating…';

    // 1. Expand notch to scanning mode
    island.className = 'dynamic-island scanning';
    if (led) led.className = 'camera-led active';
    if (padlock) padlock.className = 'lock-padlock';
    if (titleEl) titleEl.textContent = 'Face ID';
    if (subtitleEl) subtitleEl.textContent = 'Looking for you…';
    if (progressBar) progressBar.style.width = '10%';

    playSubtleClick();

    // 2. Stage: Face detected
    setTimeout(() => {
      if (titleEl) titleEl.textContent = 'Face Detected';
      if (subtitleEl) subtitleEl.textContent = 'Scanning contours…';
      if (progressBar) progressBar.style.width = '45%';
    }, 400);

    // 3. Stage: Authenticating
    setTimeout(() => {
      if (subtitleEl) subtitleEl.textContent = 'Matching biometric vector…';
      if (progressBar) progressBar.style.width = '85%';
    }, 900);

    // 4. Stage: Success & Morph to capsule
    setTimeout(() => {
      if (progressBar) progressBar.style.width = '100%';
      island.className = 'dynamic-island verified';
      if (padlock) {
        padlock.innerHTML = '&#128275;'; // Unlocked padlock
        padlock.className = 'lock-padlock unlocked';
      }
      playUnlockChime();
    }, 1400);

    // 5. Retract back into the notch
    setTimeout(() => {
      island.className = 'dynamic-island';
      if (led) led.className = 'camera-led';
      if (padlock) {
        padlock.innerHTML = '&#128274;'; // Locked padlock
        padlock.className = 'lock-padlock';
      }
      isAnimating = false;
      testScanBtn.disabled = false;
      testScanBtn.innerHTML = '<span>⚡</span> Test Notch Scan';
    }, 3200);
  }
}

// Copy terminal command with animated feedback
function initCopyButton() {
  const copyBtn = document.getElementById('copyCmdBtn');
  const cmdText = document.getElementById('terminalCmdText');

  if (!copyBtn || !cmdText) return;

  copyBtn.addEventListener('click', () => {
    const textToCopy = cmdText.textContent.trim();
    navigator.clipboard.writeText(textToCopy).then(() => {
      const origHtml = copyBtn.innerHTML;
      copyBtn.innerHTML = '<span>✓</span> Copied!';
      copyBtn.style.background = '#30d158';
      copyBtn.style.color = '#000000';

      setTimeout(() => {
        copyBtn.innerHTML = origHtml;
        copyBtn.style.background = '';
        copyBtn.style.color = '';
      }, 2000);
    }).catch(err => {
      console.error('Failed to copy text: ', err);
    });
  });
}

// Web Audio API Sound Feedback
function playSubtleClick() {
  try {
    const ctx = new (window.AudioContext || window.webkitAudioContext)();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();

    osc.type = 'sine';
    osc.frequency.setValueAtTime(800, ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(400, ctx.currentTime + 0.05);

    gain.gain.setValueAtTime(0.08, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.05);

    osc.connect(gain);
    gain.connect(ctx.destination);

    osc.start();
    osc.stop(ctx.currentTime + 0.05);
  } catch (e) {
    // Audio not allowed without interaction
  }
}

function playUnlockChime() {
  try {
    const ctx = new (window.AudioContext || window.webkitAudioContext)();
    const now = ctx.currentTime;

    const playTone = (freq, start, duration) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(freq, start);
      gain.gain.setValueAtTime(0.12, start);
      gain.gain.exponentialRampToValueAtTime(0.001, start + duration);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(start);
      osc.stop(start + duration);
    };

    playTone(587.33, now, 0.15);       // D5
    playTone(880.00, now + 0.08, 0.25); // A5
  } catch (e) {
    // Audio not allowed
  }
}
