# Original User Request

## 2026-10-12T13:46:08Z

This is a single self-contained feature; keep it small and focused.
Implement the backend query services, state connections, and multi-format export engines (PDF, Excel, Image) for the Milk History and Export Milk History screens in the Farm Flow Flutter mobile app.

Working directory: c:\Users\Admin\Desktop\Farm manager\dairy_farm_app
Integrity mode: development

## Requirements

### R1. Milk History Backend & Query Engine
Query aggregated milk sales from SQLite joining ledger (type = 'MILK_SOLD') and dodis tables. Calculate total quantity, daily averages, gross revenue, and average rate. Clamp the in-app month picker to the last 12 calendar months.

### R2. Existing User Detection & Dual Empty States
Determine the user's earliest activity date dynamically using a 3-tier fallback query (MIN(time_unix) from activity_log -> MIN(date) from ledger -> current date). Render a distinct "Pre-Account Period" empty state when the selected month is before account inception, and "No Milk Recorded" for months after inception with zero yield.

### R3. Multi-Format Export Engine (PDF, Excel, Image)
Generate export documents for the selected date range (clamped to max 12 months):
- Multi-page tabular PDF (.pdf) using pdf: ^3.11.1.
- Formatted binary Excel workbook (.xlsx) using excel: ^4.0.6.
- High-resolution rendered image (.png) via RenderRepaintBoundary (at 3.0x pixel ratio).
Integrate native sharing and saving via share_plus and path_provider. Disable or block export actions when zero records match the date range.

## Acceptance Criteria

### Data & Query Integrity
- [ ] Correctly aggregates daily morning and evening sessions and revenue without floating point inaccuracies.
- [ ] Accurately determines earliest user activity date for both existing and newly registered accounts.

### Export Deliverables
- [ ] Valid .pdf file generated with farm name, date range, and line items.
- [ ] Valid .xlsx workbook generated with proper numeric cells and headers.
- [ ] Valid .png image captured and saved.
- [ ] Export triggers are disabled or show a validation notice when zero records match the date range.

### Quality Bar
- [ ] flutter analyze passes with zero errors.
- [ ] Modified screens and new services pass verification tests.
