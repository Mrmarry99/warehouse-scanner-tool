# Warehouse Inventory Scanner

Phone-camera tool for warehouse staff: scan a Walmart shipping label,
match it against your Google Sheet order database by the 15-digit order
ID (`2000...`), mark it **Delivered** with a quantity, and keep a
Receive/Ship movements log so stock-on-hand per warehouse (IL, TX, NC,
NJ, NY) stays accurate. Built from the verified label research in
`warehouse-scanner-research-transcript.md` — none of the four sample
Walmart labels had a QR code, and none of their barcodes encoded the
order ID, so **OCR on the printed order ID is the primary matching
path**, not barcode scanning. Barcodes (FedEx tracking, ASN) are only
captured as bonus reference data.

Runs entirely in the browser, single HTML file — same shape as your
other tools (`tracking-extractor.html`, `packing-slip-note-tool.html`).

## Why this isn't a Google Apps Script backend

The original plan was Apps Script (matching your existing IMS pattern),
but Apps Script's `HtmlService` serves pages inside a sandboxed iframe
that blocks camera access (`getUserMedia` fails there) — a long-standing
Google limitation, not something fixable from the script side. So this
tool instead talks to the Sheets API directly from the browser, reusing
the **same OAuth client** your `tracking-extractor` / `packing-slip-note-tool`
already use — just with a broader scope (read **and write**, not
read-only) since this tool needs to write Delivered status back.

## Sheet structure (created automatically)

Point this at any Google Sheet — blank or one you already use — and hit
**Connect / Initialize sheet**. It creates whatever's missing and never
touches existing data:

**Orders tab** (your real order data lives here — SKU, Order ID,
Customer Name, Product Title, Quantity; add rows yourself or import from
your existing order sheet). The tool appends five tracking columns if
they aren't already there: `Status`, `Warehouse`, `Delivered Qty`,
`Delivered At`, `Scanned By`.

**Inventory tab** (auto-created): `SKU | Warehouse | Qty On Hand | Last Movement At`
— one row per SKU+warehouse combo, kept up to date automatically.

**Movements tab** (auto-created, append-only log):
`Timestamp | SKU | Warehouse | Type | Qty | Order ID | Scanned By`

Stock on hand = every Receive minus every Ship, per SKU per warehouse —
you never edit the Inventory tab by hand, it's derived from movements.

## One-time setup

### 1. Google Cloud — add write scope + this tool's origin

Reuses the same OAuth client as your other tools — no new project.

1. [console.cloud.google.com](https://console.cloud.google.com/) → your
   existing project → **APIs & Services → Credentials** → open the same
   OAuth 2.0 Client ID.
2. Under **Authorized JavaScript origins**, add whatever origin you'll
   run this from:
   - `http://localhost:8002` for desktop testing (see below — a
     different port from your other local tools so nothing clashes).
   - Your real deployment origin for phone use — see **Phone deployment**
     below (camera access requires a real `https://` origin; a LAN IP
     like `http://192.168.x.x:8002` will NOT work on a phone, since
     that's not a secure context).
3. **OAuth consent screen** → confirm your Google account is a **Test
   user** (normal for a "Testing" mode app). The broader Sheets
   read/write scope this tool asks for shows its own consent prompt the
   first time — that's expected, just click Allow.

### 2. Phone deployment (camera needs real HTTPS)

Desktop testing over `localhost` works fine for checking the OCR/lookup
logic on a laptop webcam, but a phone browser will only grant camera
access on a genuine secure origin. Easiest free option:

1. Create a public GitHub repo (or reuse one), add this folder.
2. **Settings → Pages** → deploy from the branch/folder containing
   `warehouse-scanner-tool.html`.
3. You'll get a `https://<you>.github.io/...` URL — add that exact
   origin to the OAuth client's Authorized JavaScript origins (step 1.2
   above), then open that URL on the warehouse phone.

(Any other static HTTPS host — Netlify, Cloudflare Pages, your own
domain — works the same way. The app has no server component to deploy,
just this one HTML file.)

### 3. Python (only if you don't already have it)

- **Mac**: `brew install python` or [python.org](https://www.python.org/downloads/)
- **Windows**: [python.org](https://www.python.org/downloads/), check "Add python.exe to PATH"

## Running it (desktop testing)

**Mac:**
```bash
cd "warehouse-scanner-tool"
python3 -m http.server 8002
```
then open `http://localhost:8002/warehouse-scanner-tool.html`.

**Windows:** double-click `start-tool.bat`.

## Using it

1. **Connect Google Sheet** → sign in with Google.
2. Paste your sheet's URL (or ID), confirm the three tab names (defaults
   `Orders` / `Inventory` / `Movements` are fine for a fresh sheet), then
   **Connect / Initialize sheet**. The status line reports what it
   created vs. found.
3. Pick your **Warehouse** and type your name once — both are remembered
   on this device.
4. **Deliver Order** tab: **Start camera**, point it at the label, tap
   **Capture & read order ID**. It OCRs the frame, pulls out the
   `2000...` order ID, and shows it in an editable field (OCR misreads
   happen — fix it by hand if needed, nothing saves until you confirm).
   Any barcode the camera happens to see (FedEx tracking, ASN) shows as
   bonus info only.
5. **Look up order** → shows Customer / Product / SKU / Quantity from
   your sheet. Already-delivered orders get a warning banner (a
   double-scan safety net), and the quantity field is editable for
   partial shipments.
6. **Confirm Delivered** → writes Status/Warehouse/Qty/timestamp/your
   name back to that Orders row, logs a Ship movement, and decrements
   Inventory for that SKU+warehouse.
7. **Receive** / **Ship** tabs: simple manual quantity entry for stock
   movements that aren't tied to a scanned order (e.g. a new shipment
   arriving, or an outbound order without a Walmart label to scan).
8. **Inventory Levels** tab: read-only current stock per SKU per
   warehouse, derived from the Movements log.

## Known limitations

- OCR accuracy on glare/crumpled labels is the main failure mode — the
  confirmation screen is the safety net, nothing writes until you tap
  Confirm.
- Customer-name matching from the label text is best-effort only (shown
  as a hint, not used for lookup) — store tags truncate names ("NEHA U."),
  so the order ID is the only reliable key.
- Inventory upserts do a read-then-write against the sheet; two staff
  confirming the same SKU+warehouse at the exact same second could race.
  Not expected to matter for a small warehouse team, but worth knowing.
