/*
 * app.js: builds the Referral Triage page.
 *
 * Flow:
 *   1. data/referrals.js (written by export_ui.py) runs first and sets window.REFERRAL_DATA.
 *   2. load() reads that data and cleans each referral up with prepare().
 *   3. render() groups referrals by urgency, sorts each group by Jev confidence, and draws the
 *      sidebar tabs, the table and the detail form.
 *   4. Clicking a tab, clicking a row, or typing in search changes `state`, then calls render() again.
 *
 * No frameworks or libraries: plain JavaScript that runs in any modern browser.
 */

const DATA_URL = "data/referrals.js";

// Referrals below this Jev confidence get a "Review" flag.
const LOW_CONFIDENCE = 0.6;

// Sidebar tabs, in display order. "pending" holds referrals not yet processed by Jev/Claude.
const SECTIONS = [
  { key: "urgent", label: "Urgent" },
  { key: "semi-urgent", label: "Semi-urgent" },
  { key: "routine", label: "Routine" },
  { key: "pending", label: "Awaiting AI triage" },
];

const URGENCY_ORDER = ["urgent", "semi-urgent", "routine"];

// Everything that can change while the page is open. render() redraws the page from this.
const state = {
  referrals: [],
  generatedAt: null,
  section: "urgent",
  selectedId: null,
};

// ---------- data helpers ----------
// These are deliberately forgiving about input format (casing, 0-1 vs 0-100, JSON strings),
// so small changes in the pipeline's output don't break the UI.

// Maps a Jev classification to a section key, e.g. "Semi Urgent" / "semi_urgent" -> "semi-urgent".
// Anything empty or unrecognised counts as "pending".
function normaliseUrgency(value) {
  if (!value) return "pending";
  const key = String(value).trim().toLowerCase().replace(/[\s_]+/g, "-");
  return URGENCY_ORDER.includes(key) ? key : "pending";
}

function parseMaybeJson(value) {
  if (typeof value !== "string") return value;
  try {
    return JSON.parse(value);
  } catch {
    return value;
  }
}

// Returns a 0-1 fraction; values above 1 are treated as percentages.
function toFraction(value) {
  const n = Number(value);
  if (value === null || value === undefined || Number.isNaN(n)) return null;
  return n > 1 ? n / 100 : n;
}

function normaliseProbabilities(raw) {
  const parsed = parseMaybeJson(raw);
  if (!parsed || typeof parsed !== "object") return {};
  const result = {};
  for (const [key, value] of Object.entries(parsed)) {
    const fraction = toFraction(value);
    const urgency = normaliseUrgency(key);
    // Unexpected keys are kept as-is so they still show up rather than silently disappearing.
    if (fraction !== null) result[urgency === "pending" ? key : urgency] = fraction;
  }
  return result;
}

// Turns Claude's {"reason_1": ..., "reason_2": ..., "reason_3": ...} into an ordered list.
function normaliseReasons(raw) {
  const parsed = parseMaybeJson(raw);
  if (!parsed) return [];
  if (Array.isArray(parsed)) return parsed.map(String);
  if (typeof parsed === "object") {
    return Object.keys(parsed)
      .sort()
      .map((k) => String(parsed[k]));
  }
  return [String(parsed)];
}

// Cleans up one exported row. Done once on load so rendering never has to re-clean anything.
function prepare(row) {
  const urgency = normaliseUrgency(row.classification);
  const probabilities = normaliseProbabilities(row.probabilities);
  // Fall back to the probability of the chosen class if Jev gave no explicit confidence.
  const confidence = toFraction(row.confidence) ?? probabilities[urgency] ?? null;
  const reasons = normaliseReasons(row.justification);
  const lowConfidence = urgency !== "pending" && confidence !== null && confidence < LOW_CONFIDENCE;
  // Pre-built once so filtering on every keystroke stays fast.
  const searchText = [row.referral_id, row.nhi_number, row.reason_text, row.recommendation, ...reasons]
    .filter(Boolean)
    .join(" ")
    .toLowerCase();
  return { ...row, urgency, probabilities, confidence, reasons, lowConfidence, searchText };
}

// Highest confidence first; referrals with no confidence sink to the bottom.
function byConfidenceDesc(a, b) {
  return (b.confidence ?? -1) - (a.confidence ?? -1);
}

function labelFor(key) {
  return SECTIONS.find((s) => s.key === key)?.label ?? key;
}

// ---------- DOM helpers ----------

// Creates an element: el("td", { class: "num" }, "73%") -> <td class="num">73%</td>.
// Attributes starting with "on" become event listeners. null/false children are skipped,
// which allows `condition && el(...)` for optional parts.
// Text is always added as text nodes, never raw HTML, so content from GP notes can't inject markup.
function el(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(attrs)) {
    if (value === null || value === undefined || value === false) continue;
    if (key === "class") node.className = value;
    else if (key === "style") node.style.cssText = value;
    else if (key.startsWith("on")) node.addEventListener(key.slice(2), value);
    else node.setAttribute(key, value === true ? "" : value);
  }
  for (const child of children.flat()) {
    if (child === null || child === undefined || child === false) continue;
    node.append(child instanceof Node ? child : document.createTextNode(String(child)));
  }
  return node;
}

function formatPercent(fraction) {
  return fraction === null || fraction === undefined ? "—" : `${Math.round(fraction * 100)}%`;
}

// Shows missing values as an em dash so fields never look broken.
function display(value) {
  return value === null || value === undefined || value === "" ? "—" : String(value);
}

function meter(fraction) {
  return el("span", { class: "meter" }, el("span", { style: `width:${Math.round((fraction ?? 0) * 100)}%` }));
}

// ---------- grouping ----------

// Applies the search filter, splits referrals into sections, and sorts each by confidence.
function groupedReferrals() {
  const query = document.getElementById("search").value.trim().toLowerCase();
  const visible = query ? state.referrals.filter((r) => r.searchText.includes(query)) : state.referrals;

  // Every section starts with an empty list so tabs with 0 referrals still appear.
  const grouped = Object.fromEntries(SECTIONS.map((s) => [s.key, []]));
  for (const referral of visible) grouped[referral.urgency].push(referral);
  for (const list of Object.values(grouped)) list.sort(byConfidenceDesc);
  return grouped;
}

// ---------- rendering ----------
// Each render function rebuilds its part of the page from scratch. Simpler than updating
// in place, and fast enough for a few hundred referrals.

// Blue tabs down the left, each with a summary like the eReferral sidebar.
function renderSidebar(grouped) {
  const tabs = SECTIONS.map((s) => {
    const list = grouped[s.key];
    const flagged = list.filter((r) => r.lowConfidence).length;
    const lines =
      s.key === "pending"
        ? [`${list.length} referral${list.length === 1 ? "" : "s"}`, "Not yet processed by Jev"]
        : [
            `${list.length} referral${list.length === 1 ? "" : "s"}`,
            list.length ? `Highest confidence ${formatPercent(list[0].confidence)}` : "No referrals",
            flagged ? `${flagged} flagged for review` : "None flagged for review",
          ];

    // Real <button>s so tabs work with the keyboard.
    return el(
      "button",
      {
        type: "button",
        class: `tab${s.key === state.section ? " selected" : ""}`,
        "aria-pressed": s.key === state.section ? "true" : "false",
        onclick: () => {
          state.section = s.key;
          state.selectedId = null; // render() then auto-selects the top referral
          render();
        },
      },
      // First letter underlined to mimic old-style keyboard-shortcut hints.
      el("strong", {}, el("span", { class: `dot dot-${s.key}` }), el("span", { class: "key" }, s.label[0]), s.label.slice(1)),
      lines.map((line) => el("div", {}, line))
    );
  });

  document.getElementById("sidebar").replaceChildren(...tabs);
}

function renderRows(list) {
  const rows = list.map((r) =>
    el(
      "tr",
      {
        // Focusable, and selectable with Enter/Space, so the table is usable without a mouse.
        tabindex: "0",
        class: r.referral_id === state.selectedId ? "selected" : null,
        onclick: () => select(r.referral_id),
        onkeydown: (e) => {
          if (e.key === "Enter" || e.key === " ") {
            e.preventDefault();
            select(r.referral_id);
          }
        },
      },
      el("td", { class: "num" }, r.urgency === "pending" ? "—" : formatPercent(r.confidence)),
      el("td", {}, display(r.referral_id)),
      el("td", {}, display(r.nhi_number)),
      el("td", { class: "num" }, display(r.patient_age)),
      // Truncated by CSS; the full note shows on hover.
      el("td", { class: "reason", title: r.reason_text ?? "" }, display(r.reason_text)),
      el("td", {}, r.lowConfidence ? el("span", { class: "flag-review" }, "Review") : "")
    )
  );

  document
    .getElementById("rows")
    .replaceChildren(...(rows.length ? rows : [el("tr", {}, el("td", { class: "empty", colspan: "6" }, "No referrals in this category."))]));
}

// One labelled field in the detail form. The values are read-only; "input"/"textarea" boxes
// just make them look like the old eReferral form fields. `required` adds a purely visual
// red asterisk, copied from the reference UI.
function field(label, value, { full = false, required = false, box = null } = {}) {
  const content =
    box === "input"
      ? el("span", { class: "input-box" }, value)
      : box === "textarea"
        ? el("div", { class: "textarea-box" }, value)
        : el("span", { class: "field-value" }, value);
  return el(
    "div",
    { class: `field${full ? " full" : ""}` },
    el("span", { class: "field-label" }, label, required ? el("span", { class: "req" }, "*") : null),
    content
  );
}

// "Urgency | Probability" table with the chosen urgency highlighted.
function renderProbabilities(referral) {
  // Known levels in fixed order first, then any unexpected keys.
  const keys = [...URGENCY_ORDER, ...Object.keys(referral.probabilities).filter((k) => !URGENCY_ORDER.includes(k))].filter(
    (k) => k in referral.probabilities
  );
  if (!keys.length) return el("span", { class: "field-value" }, "No probabilities returned.");

  return el(
    "table",
    { class: "mini-grid" },
    el("thead", {}, el("tr", {}, el("th", {}, "Urgency"), el("th", {}, "Probability"))),
    el(
      "tbody",
      {},
      keys.map((k) =>
        el(
          "tr",
          { class: k === referral.urgency ? "chosen" : null },
          el("td", {}, labelFor(k)),
          el("td", {}, meter(referral.probabilities[k]), formatPercent(referral.probabilities[k]))
        )
      )
    )
  );
}

// Detail form for the selected referral: Referral -> Patient -> GP note -> AI Triage Assessment.
// The AI section is omitted for referrals that haven't been processed yet.
function renderDetail(referral) {
  const container = document.getElementById("detail");
  if (!referral) {
    container.replaceChildren(el("div", { class: "detail placeholder" }, "Select a referral above to view the AI triage details."));
    return;
  }

  const triaged = referral.urgency !== "pending";
  const urgencyValue = triaged
    ? el("span", {}, el("span", { class: `urgency-${referral.urgency}` }, labelFor(referral.urgency)), ` (Jev confidence ${formatPercent(referral.confidence)})`)
    : "Awaiting AI triage";

  container.replaceChildren(
    el(
      "div",
      { class: "detail" },
      el("hr"),
      el("h2", {}, "Referral"),
      el(
        "div",
        { class: "fields" },
        field("Referral number", display(referral.referral_id), { required: true }),
        field("AI urgency classification", urgencyValue, { required: true }),
        field("Facility", display(referral.facility_id), { box: "input" }),
        field("Submitting GP", display(referral.submitting_gp_id), { box: "input" })
      ),
      referral.lowConfidence
        ? el("p", { class: "caution" }, `Caution: Jev confidence is below ${formatPercent(LOW_CONFIDENCE)}. Manual review of this referral is recommended.`)
        : null,

      el("hr"),
      el("h2", {}, "Patient"),
      el(
        "div",
        { class: "fields" },
        field("NHI", display(referral.nhi_number), { box: "input" }),
        field("Age", display(referral.patient_age), { box: "input" }),
        field("Existing conditions", display(referral.existing_conditions), { full: true, box: "textarea" }),
        field("Risk history", display(referral.risk_history), { full: true, box: "textarea" })
      ),

      el("hr"),
      el("h2", {}, "Generic Referral Details"),
      el("div", { class: "fields" }, field("Reason for referral (GP note)", display(referral.reason_text), { full: true, required: true, box: "textarea" })),

      triaged && el("hr"),
      triaged && el("h2", {}, "AI Triage Assessment"),
      triaged &&
        el(
          "div",
          { class: "fields" },
          field("Justification", referral.reasons.length ? el("ol", {}, referral.reasons.map((r) => el("li", {}, r))) : "No justification returned.", {
            full: true,
            box: "textarea",
          }),
          field("Recommended next step", display(referral.recommendation), { full: true, box: "textarea" }),
          field("Jev probabilities", renderProbabilities(referral), { full: true })
        )
    )
  );
}

function render() {
  const grouped = groupedReferrals();
  const list = grouped[state.section];

  // Keep the current selection if it's still visible (e.g. after searching), otherwise show
  // the top referral so the detail form is never empty when there's something to show.
  if (!list.some((r) => r.referral_id === state.selectedId)) state.selectedId = list[0]?.referral_id ?? null;

  renderSidebar(grouped);
  document.getElementById("section-heading").textContent = `${labelFor(state.section)} referrals (${list.length})`;
  document.getElementById("section-hint").textContent =
    state.section === "pending" ? "These referrals have not been processed by Jev yet." : "Sorted by Jev confidence, highest first. Click a row to view details.";
  renderRows(list);
  renderDetail(list.find((r) => r.referral_id === state.selectedId));
}

function select(referralId) {
  state.selectedId = referralId;
  render();
  // render() replaced the rows, so restore keyboard focus to the newly selected one.
  document.querySelector("#rows tr.selected")?.focus();
}

// ---------- loading ----------

function showNotice(message, isError = false) {
  const notice = document.getElementById("notice");
  notice.textContent = message;
  notice.classList.toggle("error", isError);
  notice.hidden = false;
}

function load() {
  // Set by data/referrals.js; undefined if that file is missing.
  const data = window.REFERRAL_DATA;
  if (!data) {
    showNotice(`Unable to load ${DATA_URL}. Run "python export_ui.py" and then refresh this page.`, true);
  } else {
    const rows = Array.isArray(data) ? data : data.referrals ?? [];
    state.referrals = rows.map(prepare);
    state.generatedAt = data.generated_at ? new Date(data.generated_at) : null;
    showNotice(
      `${state.referrals.length} referrals loaded successfully.${state.generatedAt ? ` Data exported ${state.generatedAt.toLocaleString()}.` : ""}`
    );
  }
  render();
}

document.getElementById("search").addEventListener("input", render);
// Reloading the page re-reads data/referrals.js after a new export.
document.getElementById("refresh").addEventListener("click", () => location.reload());

load();
