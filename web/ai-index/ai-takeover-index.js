/* Optional, framework-free List Number landing-page widget.
 * Host-page owners opt in with enabled="true"; not a dialer setting.
 * Treats remote data as untrusted text; no HTML injection or tracking.
 */
(function () {
  'use strict';
  const DEFAULT_URL = 'https://raw.githubusercontent.com/JSweatman/TV2-Development/main/web/ai-index/current.json';
  const LEVELS = Object.freeze({
    1: "Relax, Human. We're Just Calculators.",
    2: 'The Machines Are Getting Ideas.',
    3: 'Your Toaster Has Joined a Union.',
    4: 'Resistance Is Looking Increasingly Futile.',
    5: 'TOO LATE, HUMAN SLAVE!'
  });
  const COLORS = ['#2a9d6e', '#81b453', '#d9aa33', '#e27a38', '#c54444'];

  class AITakeoverIndex extends HTMLElement {
    static get observedAttributes() { return ['enabled', 'src']; }
    constructor() { super(); this.attachShadow({ mode: 'open' }); this.requestId = 0; }
    connectedCallback() { this.load(); }
    attributeChangedCallback() { if (this.isConnected) this.load(); }
    disconnectedCallback() { this.requestId++; }
    async load() {
      const requestId = ++this.requestId;
      this.shadowRoot.replaceChildren();
      this.hidden = this.getAttribute('enabled') !== 'true';
      if (this.hidden) return; // No network call when owner opts out.
      this.renderMessage('Loading AI World Takeover Probability Index…');
      try {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 8000);
        let response;
        try {
          response = await fetch(this.getAttribute('src') || DEFAULT_URL, {
            headers: { Accept: 'application/json' }, signal: controller.signal,
            cache: 'no-store'
          });
        } finally { clearTimeout(timeout); }
        if (!response.ok) throw new Error('Unavailable');
        const data = await response.json();
        if (requestId !== this.requestId) return;
        if (!Number.isInteger(data.level) || !(data.level in LEVELS) ||
            typeof data.commentary !== 'string' || data.commentary.length > 500 ||
            !/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/.test(data.published_at) ||
            Number.isNaN(Date.parse(data.published_at)) ||
            !['demo', 'published'].includes(data.status)) {
          throw new Error('Invalid index bulletin');
        }
        this.renderIndex(data);
      } catch (_) {
        if (requestId === this.requestId) this.renderMessage('Index temporarily unavailable. The humans may still be in charge.');
      }
    }
    style() {
      return `<style>
        :host{display:block;max-width:440px;color:inherit;font:inherit}
        :host([hidden]){display:none}
        .panel{border:1px solid rgba(128,128,128,.45);border-radius:16px;padding:16px;background:rgba(18,24,35,.91);color:white;font:14px/1.5 system-ui,sans-serif}
        .heading{font-weight:750;font-size:15px;letter-spacing:.015em}
        .level{font-size:29px;font-weight:800;margin:5px 0 0}
        .label{font-weight:650;margin-bottom:12px}
        .bars{display:grid;grid-template-columns:repeat(5,1fr);gap:4px;margin:10px 0}
        .bar{height:12px;border-radius:3px;opacity:.28}
        .bar.active{opacity:1}
        .comment{margin:12px 0}
        .note{font-size:11px;opacity:.84}
      </style>`;
    }
    renderMessage(message) {
      this.shadowRoot.innerHTML = this.style() + '<section class="panel" role="status"><div class="heading">AI World Takeover Probability Index</div><p class="comment"></p><div class="note">For entertainment only.</div></section>';
      this.shadowRoot.querySelector('.comment').textContent = message;
    }
    renderIndex(data) {
      this.shadowRoot.innerHTML = this.style() + `<section class="panel" aria-label="Satirical AI World Takeover Probability Index">
        <div class="heading">AI World Takeover Probability Index</div>
        <div class="level"></div><div class="label"></div><div class="bars" aria-hidden="true"></div>
        <p class="comment"></p><div class="note"></div>
      </section>`;
      this.shadowRoot.querySelector('.level').textContent = data.level + ' / 5';
      this.shadowRoot.querySelector('.label').textContent = LEVELS[data.level];
      const bars = this.shadowRoot.querySelector('.bars');
      for (let i = 0; i < 5; i++) {
        const bar = document.createElement('span');
        bar.className = 'bar' + (i < data.level ? ' active' : '');
        bar.style.backgroundColor = COLORS[i];
        bars.appendChild(bar);
      }
      this.shadowRoot.querySelector('.comment').textContent = data.commentary;
      const date = new Date(data.published_at).toLocaleString(undefined, { timeZone: 'UTC', dateStyle: 'medium', timeStyle: 'short' });
      this.shadowRoot.querySelector('.note').textContent =
        (data.status === 'demo' ? 'Demo bulletin — not a live daily update. ' : '') +
        'Bulletin: ' + date + ' UTC. For entertainment only; not a scientific probability or real-world threat assessment.';
    }
  }
  if (!customElements.get('ai-takeover-index')) customElements.define('ai-takeover-index', AITakeoverIndex);
})();