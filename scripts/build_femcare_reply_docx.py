from pathlib import Path
from tempfile import NamedTemporaryFile

from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "_bmad-output" / "implementation-artifacts" / "IconDB-team-reply-QA-first-FemCare-plan-2026-08-13.docx"
FALLBACK_OUTPUT = OUTPUT.with_name(f"{OUTPUT.stem}-LT-format.docx")
REVISION_OUTPUT = OUTPUT.with_name(f"{OUTPUT.stem}-LT-format-v2.docx")

BLUE = "1F4E79"
LIGHT_BLUE = "EAF2F8"
PALE_BLUE = "DBE5F1"
ORANGE = "C65911"
LIGHT_ORANGE = "FFF4E5"
GRID = "9CA3AF"
TEXT = RGBColor(31, 41, 51)


def shade(cell, fill):
    properties = cell._tc.get_or_add_tcPr()
    shading = properties.find(qn("w:shd"))
    if shading is None:
        shading = OxmlElement("w:shd")
        properties.append(shading)
    shading.set(qn("w:fill"), fill)


def set_cell_border(cell, color=GRID, size="6"):
    properties = cell._tc.get_or_add_tcPr()
    borders = properties.first_child_found_in("w:tcBorders")
    if borders is None:
        borders = OxmlElement("w:tcBorders")
        properties.append(borders)
    for edge in ("top", "left", "bottom", "right"):
        element = borders.find(qn(f"w:{edge}"))
        if element is None:
            element = OxmlElement(f"w:{edge}")
            borders.append(element)
        element.set(qn("w:val"), "single")
        element.set(qn("w:sz"), size)
        element.set(qn("w:color"), color)


def set_cell_text(cell, text, bold=False, color=None, size=8.5):
    cell.text = ""
    paragraph = cell.paragraphs[0]
    paragraph.paragraph_format.space_after = Pt(0)
    run = paragraph.add_run(text)
    run.bold = bold
    run.font.name = "Aptos"
    run.font.size = Pt(size)
    if color:
        run.font.color.rgb = RGBColor.from_string(color)
    cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER


def add_heading(document, text):
    paragraph = document.add_paragraph()
    paragraph.paragraph_format.space_before = Pt(10)
    paragraph.paragraph_format.space_after = Pt(4)
    paragraph.paragraph_format.keep_with_next = True
    run = paragraph.add_run(text)
    run.bold = True
    run.font.name = "Aptos Display"
    run.font.size = Pt(13)
    run.font.color.rgb = RGBColor.from_string(BLUE)
    bottom = OxmlElement("w:pBdr")
    border = OxmlElement("w:bottom")
    border.set(qn("w:val"), "single")
    border.set(qn("w:sz"), "6")
    border.set(qn("w:color"), "B4C7DC")
    bottom.append(border)
    paragraph._p.get_or_add_pPr().append(bottom)


def add_body(document, text, bold_prefix=None):
    paragraph = document.add_paragraph()
    paragraph.paragraph_format.space_after = Pt(5)
    if bold_prefix and text.startswith(bold_prefix):
        first, remainder = text[: len(bold_prefix)], text[len(bold_prefix) :]
        paragraph.add_run(first).bold = True
        paragraph.add_run(remainder)
    else:
        paragraph.add_run(text)
    return paragraph


def add_bullet(document, text):
    paragraph = document.add_paragraph(style="List Bullet")
    paragraph.paragraph_format.space_after = Pt(2)
    paragraph.add_run(text)


def add_number(document, text):
    paragraph = document.add_paragraph(style="List Number")
    paragraph.paragraph_format.space_after = Pt(3)
    paragraph.add_run(text)


def add_callout(document, text, warning=False):
    table = document.add_table(rows=1, cols=1)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = True
    cell = table.cell(0, 0)
    shade(cell, LIGHT_ORANGE if warning else LIGHT_BLUE)
    set_cell_border(cell, ORANGE if warning else BLUE, "12")
    set_cell_text(cell, text, bold=True, color="7F3100" if warning else "17365D", size=9.5)
    document.add_paragraph().paragraph_format.space_after = Pt(0)


def add_action_table(document):
    headers = ("Action", "Owner", "Due", "Completion evidence")
    rows = (
        ("Confirm 1-3 representative FemCare icons", "Ola / Jakub / Fady / Simge / FemCare", "24 Aug", "Icon IDs/files, category/subsector, named signer"),
        ("Record expected result for each sample", "FemCare; Lauren supports", "24 Aug", "Integration Type, Brand, Region, copy list, approval result"),
        ("Confirm EECAR handling", "Lauren / Jyoti", "24 Aug", "Supported mapping or written exclusion from first gate"),
        ("Prepare IconDB QA inventory and rollback", "Steve / Tommy", "27 Aug", "IDs, MAE IDs, counts, statuses, source files, rollback steps"),
        ("Confirm Enovia QA deployment and baseline", "Jyoti / Enovia team", "Before switch", "Refresh/no-refresh, cutoff, scrub scope, availability, stable baseline"),
        ("Reconcile baseline and approve sole endpoint switch", "Tommy / Steve", "1 Sep target", "Mismatch closure, target/config evidence, connectivity, rollback owner"),
        ("Confirm production deployment readiness", "Jyoti / Enovia team", "Before 11 Sep", "Confirm Integration Type correction is ready for production"),
        ("Prepare production validation and AAC dependencies", "Tommy / Steve / Emilian", "Before Prod", "Test/sign-off plan, IconDB names/IDs, Rule Manager owner, AAC sequence"),
    )
    table = document.add_table(rows=1, cols=4)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    widths = (Cm(5.0), Cm(3.6), Cm(2.0), Cm(6.2))
    for index, (cell, text, width) in enumerate(zip(table.rows[0].cells, headers, widths)):
        cell.width = width
        shade(cell, BLUE)
        set_cell_border(cell)
        set_cell_text(cell, text, bold=True, color="FFFFFF", size=8.5)
    for row_index, values in enumerate(rows, start=1):
        cells = table.add_row().cells
        for cell, text, width in zip(cells, values, widths):
            cell.width = width
            if row_index % 2:
                shade(cell, "F3F6F9")
            set_cell_border(cell)
            set_cell_text(cell, text)
    table.rows[0]._tr.get_or_add_trPr().append(OxmlElement("w:tblHeader"))


def build_document():
    document = Document()
    section = document.sections[0]
    section.page_width = Cm(21)
    section.page_height = Cm(29.7)
    section.top_margin = Cm(1.6)
    section.bottom_margin = Cm(1.6)
    section.left_margin = Cm(1.8)
    section.right_margin = Cm(1.8)

    normal = document.styles["Normal"]
    normal.font.name = "Aptos"
    normal.font.size = Pt(10)
    normal.font.color.rgb = TEXT
    normal.paragraph_format.line_spacing = 1.08

    kicker = document.add_paragraph()
    kicker.paragraph_format.space_after = Pt(1)
    run = kicker.add_run("DRAFT TEAM REPLY")
    run.bold = True
    run.font.name = "Aptos"
    run.font.size = Pt(9)
    run.font.color.rgb = RGBColor(107, 114, 128)

    title = document.add_paragraph()
    title.paragraph_format.space_after = Pt(8)
    title_run = title.add_run("QA-First FemCare And AAC Plan")
    title_run.bold = True
    title_run.font.name = "Aptos Display"
    title_run.font.size = Pt(20)
    title_run.font.color.rgb = RGBColor.from_string("17365D")

    meta = document.add_table(rows=3, cols=2)
    meta.alignment = WD_TABLE_ALIGNMENT.CENTER
    meta_values = (
        ("Suggested subject", "IconDB revised activation plan: QA validation, production dependency, and AAC impact"),
        ("To", "Jyoti, Steve, Tommy, Lauren, Ola, Jakub, Fady, Simge, Bernard, Emilian"),
        ("Cc", "Tripolina, Noelle"),
    )
    for row, values in zip(meta.rows, meta_values):
        for index, (cell, value) in enumerate(zip(row.cells, values)):
            shade(cell, PALE_BLUE if index == 0 else "FFFFFF")
            set_cell_border(cell)
            set_cell_text(cell, value, bold=index == 0, size=9)

    add_body(document, "Hi Team,")
    add_body(document, "I rebuilt the plan based on all information gathered today.")

    add_heading(document, "Help needed")
    add_body(document, "Please confirm the QA readiness plan, owners, and any constraints by Monday, 17 August. Friday, 14 August is a day off in lieu of the bank holiday. We need written confirmation of the Enovia QA baseline before changing the IconDB endpoint or starting FemCare testing.")
    add_bullet(document, "Jyoti / Enovia team: confirm the 31 August QA deployment and whether QA is refreshed or retains its current baseline. Confirm readiness for the documented 11 September production deployment.")
    add_bullet(document, "Ola / Jakub / Fady / Simge / FemCare: select one to three samples, expected results, and the business signer.")
    add_bullet(document, "Lauren / Jyoti: confirm the supported EECAR treatment or exclude EECAR from the first gate.")
    add_bullet(document, "Tommy / Steve: prepare inventory, rollback, reconciliation, and the controlled endpoint switch.")
    add_bullet(document, "Emilian / AAC team: confirm the AAC validation owner and readiness sequence after production icons and Rule Manager references are available.")

    add_heading(document, "Short LT note")
    add_callout(document, "Decision: use QA for controlled FemCare validation. Production go-live cannot occur before the Integration Type correction reaches production on 11 September and the subsequent production test is completed.")
    add_body(document, "The official Enovia plan confirms that 2022x SIT is unavailable from 31 August until the new 2026x SIT opens on 14 September. Testing that still requires 2022x should use QA from 31 August. The 28 August production database copy is confirmed for the replacement SIT only, not QA.")
    add_body(document, "The QA-first path remains conditional on deployment, baseline reconciliation, samples, expected outcomes, rollback, and owners. The production correction is documented for 11 September, followed by controlled testing before go-live.")
    add_body(document, "This also delays AAC. The required production icons must first exist with final IconDB names and IDs. Rule Manager must then replace its remaining Graphics Library references with those IconDB names and IDs before AAC can complete end-to-end validation and go live.")

    add_heading(document, "Actions")
    add_action_table(document)
    add_callout(document, "FemCare does not need to upload next week. FemCare should select samples, define expected business results, name the signer, and reserve availability for the QA test window.")

    add_heading(document, "Proposed FemCare testing sequence")
    sequence = (
        "Jyoti confirms the QA deployment and actual QA baseline in writing: refresh/copy status, cutoff, scrub scope, availability, or stable existing baseline.",
        "Tommy and Steve reconcile Enovia QA against the IconDB QA inventory, close mismatches, approve rollback readiness, and switch the sole non-production endpoint to QA. SIT and QA must never be active targets together.",
        "From 2 September, upload and approve one agreed FemCare sample in IconDB QA.",
        "Retain the IconDB ID, payload, MAE ID, target environment, Integration Type, Brand, Region, destination/copy list, file visibility, status, and errors.",
        "Jyoti confirms the Enovia result; FemCare compares it with the expected business outcome.",
        "Process the remaining approved samples only after the first sample is reconciled.",
        "Complete written FemCare sign-off by 7 September, or record the failed field, owner, correction route, and revised date.",
        "After the production correction is deployed on 11 September, run a controlled production sample. The earliest planned business-day test is Monday, 14 September, subject to deployment confirmation and availability.",
        "Go live or restart scaled production uploads only after the production result is reconciled, rollback/failure handling is confirmed, and the accountable owner approves the restart.",
        "Upload the required production icons with final IconDB names and IDs, then update Rule Manager rules from Graphics Library references to those IconDB names and IDs.",
        "Emilian's AAC team completes AAC end-to-end validation against the updated Rule Manager references before AAC go-live.",
    )
    for item in sequence:
        add_number(document, item)

    add_heading(document, "Attention")
    add_callout(document, "Monday, 17 August is the response and coordination point. Do not delete records, upload test icons, change endpoints, or perform production actions before Tommy returns on Tuesday, 18 August.", warning=True)
    add_callout(document, "If the QA baseline remains unconfirmed or cannot be reconciled, do not switch the endpoint and do not start testing. Do not use a bulk upload as the first test, and do not delete or reset production records.", warning=True)
    add_callout(document, "11 September is the production deployment prerequisite, not the go-live date. AAC follows later, after production validation, icon upload, and Rule Manager migration from Graphics Library references to IconDB names and IDs.", warning=True)
    add_body(document, "A SIT smoke test is optional and non-gating only. If the technical team sees a specific benefit, limit it to one non-EECAR record, minimum cleanup, and full evidence. It is not FemCare sign-off and does not demonstrate QA readiness.")

    add_heading(document, "Background")
    background = (
        "The copyIntegrationType correction reaches SIT on 19 August, QA on 31 August, and production on 11 September.",
        "EECAR is outside the September change scope; feasibility is expected by 24 August.",
        "Full IconDB-origin cleanup in SIT is not feasible.",
        "Existing 2022x SIT is decommissioned on 31 August; new 2026x SIT opens on 14 September from a production database copy taken on 28 August.",
        "The formal plan requires QA for 2022x testing during the SIT outage but does not confirm a production copy or refresh into QA.",
        "Michal is out 17-21 August; Tommy returns 18 August, leaving preparation but not a controlled SIT sign-off window.",
        "Bernard was told on 7 August that production routing needed correction before scaled uploads and asked whether IconDB was working with AAC; Bernard confirmed Emilian now leads AAC.",
        "The earlier 14-15 August mass-upload commitment is superseded by the newly understood Enovia environment and production-fix schedule.",
        "AAC depends on validated production icons with stable IconDB names/IDs, followed by Rule Manager replacement of Graphics Library references and AAC end-to-end validation.",
        "Scaled production restart requires the production correction, passed QA and production evidence, retained rollback/failure handling, and written approval from the accountable restart owner.",
    )
    for item in background:
        add_bullet(document, item)

    add_body(document, "Please reply only with corrections, unavailable owners, or constraints against this sequence by Monday, 17 August. If there are no objections, Tommy can use this as the operating plan from Tuesday.", bold_prefix="Please reply only")
    add_body(document, "Best regards,\nMichal")

    footer = section.footer.paragraphs[0]
    footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
    footer_run = footer.add_run("DRAFT - IconDB FemCare QA-first team reply | 13 August 2026")
    footer_run.font.name = "Aptos"
    footer_run.font.size = Pt(8)
    footer_run.font.color.rgb = RGBColor(107, 114, 128)

    return document


def main():
    document = build_document()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with NamedTemporaryFile(suffix=".docx", delete=False, dir=OUTPUT.parent) as temporary:
        temporary_path = Path(temporary.name)
    try:
        document.save(temporary_path)
        for candidate in (OUTPUT, FALLBACK_OUTPUT, REVISION_OUTPUT):
            try:
                temporary_path.replace(candidate)
                written_path = candidate
                break
            except PermissionError:
                continue
        else:
            raise PermissionError("All Word output files are open and locked.")
        print(written_path)
    finally:
        temporary_path.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
