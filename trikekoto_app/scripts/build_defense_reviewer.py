"""Builds the printable panel-questions reviewer for the proposal defense.

    python scripts/build_defense_reviewer.py   (from trikekoto_app/)

Writes docs/TrikeKoTo-Defense-Reviewer.pdf. Figures quoted here are the
system's real ones (dispatch settings, test counts, retention); keep them in
step with the slides in scripts/build_defense_slides.cjs.
"""
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import LETTER
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import (KeepTogether, ListFlowable, ListItem, PageBreak,
                                Paragraph, SimpleDocTemplate, Spacer, Table,
                                TableStyle)

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'docs' / 'TrikeKoTo-Defense-Reviewer.pdf'

NAVY = colors.HexColor('#14213D')
AMBER = colors.HexColor('#B7780A')
INK = colors.HexColor('#1B2433')
MUTED = colors.HexColor('#5B6472')
LIGHT = colors.HexColor('#F2F4F8')
LINE = colors.HexColor('#C9D1DC')

ss = {
    'title': ParagraphStyle('title', fontName='Helvetica-Bold', fontSize=24, leading=28, textColor=NAVY),
    'sub': ParagraphStyle('sub', fontName='Helvetica', fontSize=11.5, leading=15, textColor=MUTED),
    'section': ParagraphStyle('section', fontName='Helvetica-Bold', fontSize=15, leading=19, textColor=NAVY, spaceBefore=14, spaceAfter=6),
    'q': ParagraphStyle('q', fontName='Helvetica-Bold', fontSize=11, leading=14.5, textColor=INK, spaceAfter=3),
    'a': ParagraphStyle('a', fontName='Helvetica', fontSize=10.5, leading=14.5, textColor=INK, alignment=TA_LEFT),
    'note': ParagraphStyle('note', fontName='Helvetica-Oblique', fontSize=10, leading=13.5, textColor=MUTED),
    'cell': ParagraphStyle('cell', fontName='Helvetica', fontSize=10, leading=13, textColor=INK),
    'cellb': ParagraphStyle('cellb', fontName='Helvetica-Bold', fontSize=10, leading=13, textColor=INK),
}

# Each answer is a string, or a list: a lead string followed by bullet points.
SECTIONS = [
    ('A. Problem and relevance', [
        ('Why is this study needed? Grab and Move It already exist.',
         'They don\'t serve TODA tricycles, or they bypass the chapter. TrikeKoTo keeps the TODA in control: the chapter '
         'approves who drives, fares follow the posted tariff, and officers can suspend drivers or stop all bookings.'),
        ('Is this a real problem in San Marcelino?',
         'Answer from your data gathering: interviews, surveys or observation at the terminal. If none yet: '
         '<i>"We will validate it with the chapter officers and commuters during data gathering."</i> Never invent numbers.'),
        ('What is new about your study?',
         ['Three things together:',
          'Ride-hailing built around a TODA chapter\'s rules.',
          'Server-side nearest-driver dispatch that hides drivers\' locations from commuters.',
          'ID verification designed for the Data Privacy Act.']),
        ('Who benefits?',
         ['', '<b>Commuters:</b> less waiting, and they know who is coming.',
          '<b>Drivers:</b> fewer empty trips.',
          '<b>The chapter:</b> control over drivers and a record of rides.',
          '<b>Researchers:</b> a model for local transport groups.']),
    ]),
    ('B. Features and design', [
        ('Why doesn\'t the app show or charge a fare?',
         'TODA fares are set by municipal ordinance and posted at the terminal. A second price on a phone could only '
         'contradict the official one, and the dispute would land on the driver. Fares are paid in cash.'),
        ('Why must commuters verify an ID? Isn\'t that a barrier?',
         'It protects drivers from fake bookings and scams; a prepaid SIM alone is too cheap to stop trolls. It is done '
         'once per account. The trade-off is slower sign-up, which user testing will measure.'),
        ('What if a driver has no smartphone?',
         'They can\'t take app bookings but still pick up passengers the normal way. The app adds a channel; it doesn\'t '
         'replace the terminal.'),
        ('What if the commuter or driver has no internet?',
         'Booking needs mobile data; that is a stated limitation. Map tiles are cached on the phone, and the server keeps '
         'searching even if the commuter closes the app.'),
        ('Why Filipino and English?',
         'Many drivers are more comfortable in Filipino, while officers and the panel may prefer English. Users can switch '
         'anytime; Filipino is the default.'),
        ('What if the driver cancels or never shows up?',
         'The driver can cancel, which ends the ride, and the commuter books again. Commuters can rate the driver and '
         'report problems to the chapter through the app\'s feedback.'),
        ('Is there an emergency or safety feature?',
         'The commuter sees the driver\'s name and plate, can call them, and can track the tricycle live. A dedicated '
         'emergency button is not in scope; it is a good recommendation for future work.'),
    ]),
    ('C. Technical', [
        ('Explain your dispatch algorithm.',
         'A greedy nearest-first search. The server shortlists approved, online drivers within 5 km by straight-line '
         'distance, then ranks them by road distance. The nearest driver gets 15 seconds to accept; if not, the next is '
         'asked, up to 10 drivers or 5 minutes.'),
        ('Why greedy? It isn\'t globally optimal.',
         'It suits one booking at a time at chapter scale, and it is simple, fast and explainable. Optimal assignment '
         'matters when many rides compete for many drivers at once, which one TODA chapter rarely has.'),
        ('What if two drivers accept at the same time?',
         'A database transaction plus a security rule means the ride can only be claimed while it is unassigned. Exactly '
         'one driver wins; this is tested with simultaneous accepts.'),
        ('Why Flutter and Firebase?',
         ['', '<b>Flutter:</b> one codebase for Android and web.',
          '<b>Firebase:</b> managed sign-in, real-time database, notifications and server functions, with no servers to maintain.',
          '<b>Cost:</b> near zero at chapter scale.']),
        ('How do you prevent a fake GPS location?',
         'Honestly, a rooted phone can fake GPS. But only chapter-approved, ID-verified drivers can go online, so the '
         'person faking is identifiable and can be suspended: accountability rather than technical prevention.'),
        ('What if Firebase goes down?',
         'The app can\'t book during an outage. Google\'s managed services are more reliable than a server we would run '
         'ourselves; it is an accepted dependency.'),
        ('Can it scale?',
         'Firebase scales automatically. The practical limit is the free public map-routing services, which would be '
         'replaced by a self-hosted routing server for heavier use.'),
        ('How much does it cost to run?',
         'At chapter scale, within Firebase\'s free usage allowances. A PHP 500 monthly budget alert is set as a safeguard.'),
        ('How did you test it?',
         ['', 'Unit and widget tests for the app.',
          '216 security-rule tests, including attacks: reading others\' data, self-approval, hijacking a ride.',
          'A concurrency test for double-accepts.',
          'Manual end-to-end runs on real phones, plus a security review.']),
    ]),
    ('D. Security and data privacy', [
        ('How do you comply with RA 10173 (Data Privacy Act of 2012)?',
         ['', '<b>Access:</b> only chapter officers can see IDs.',
          '<b>Consent:</b> shown in full and recorded with a timestamp.',
          '<b>Retention:</b> ID photos and numbers are deleted automatically after 90 days.',
          '<b>Withdrawal:</b> users can delete their ID; commuters, their whole account.',
          '<b>Ethics:</b> real IDs won\'t be collected until the ethics review is complete.']),
        ('If the ID is deleted after 90 days, how do you know the user was verified?',
         'Only a record that verification happened is kept, with no ID number or photo. The ID itself is deleted without '
         'asking the user to verify again.'),
        ('Where is the data stored, and who can access it?',
         'In Google Firebase. Security rules on the server decide every read and write, so the app is never trusted. '
         'Commuters can\'t see other commuters\' rides; drivers can\'t see other drivers.'),
        ('Can someone make a fake app to access your data?',
         'App Check is enforced, so only the genuine app reaches the database and the dispatch function. Scripts and '
         'modified apps are refused.'),
    ]),
    ('E. Methodology and evaluation', [
        ('What development methodology did you use?',
         'Name the model in your Chapter 3, then: <i>"We built it iteratively in phases: requirements, backend and security, '
         'features, maps and notifications, testing, deployment."</i>'),
        ('Why only 5 drivers and 5 commuters?',
         'Usability research shows about five users per group uncover most usability problems. The SUS score is reported '
         'with its sample size and not over-generalised; the pilot adds real-use data.'),
        ('What is SUS, and how is it scored?',
         'The System Usability Scale: 10 statements rated 1 to 5, converted to a 0-100 score. About 68 is average; above '
         '80 is good.'),
        ('How will you measure success?',
         ['', 'Task completion rate and time.', 'SUS score.',
          'Whether drivers say they would use it for real work: the real acceptance test.',
          'In the pilot: rides completed, and the share of bookings that found no driver.']),
        ('Is the SUS valid in Filipino?',
         'Our Filipino version is a working translation, not a validated instrument, and that is stated as a limitation.'),
    ]),
    ('F. Feasibility and sustainability', [
        ('Has the TODA agreed to this?',
         'Answer truthfully. If not yet: <i>"The next step is to ask the chapter officers\' approval before approaching drivers."</i>'),
        ('Do you need permits from the LGU or LTFRB?',
         'The app doesn\'t change franchises, routes or fares; it only connects commuters to already-franchised TODA '
         'members. We will consult the chapter and the local transport office before a pilot.'),
        ('Who maintains it after you graduate?',
         'There is an operations runbook and a user manual. The chapter officer handles daily administration in the app; '
         'technical maintenance needs a designated person or the university.'),
        ('What if drivers don\'t adopt it?',
         'That is the key risk, which is why user testing asks drivers directly and the pilot starts small, with a stop switch.'),
    ]),
    ('G. Tough or trap questions', [
        ('Is the system finished?',
         '<i>"The prototype is built, deployed and tested. What remains is testing with actual chapter members, a native '
         'language review, ethics clearance and the pilot."</i> Never say "ready for the public."'),
        ('Did you build this yourself?',
         'Be honest about your process and tools. Know every part well enough to explain it: dispatch, security rules and data flow.'),
        ('What is the weakest part of your system?',
         '<i>"It depends on drivers being online nearby and on mobile data. It is only useful once the chapter adopts it, so '
         'adoption is our biggest risk."</i> Admitting a weakness scores better than claiming none.'),
        ('Why should this be approved?',
         '<i>"It solves a local problem, respects the existing TODA structure and the law, the prototype already works, and '
         'the evaluation plan is realistic."</i>'),
    ]),
]

FACTS = [
    ('Search radius', '5 km (set by the chapter)'),
    ('Time to accept an offer', '15 seconds per driver'),
    ('Drivers tried per booking', 'Up to 10'),
    ('Search gives up after', '5 minutes'),
    ('Double-accept', 'Exactly 1 winner (transaction + rule)'),
    ('Security-rule tests', '216, including attack scenarios'),
    ('ID photo and number kept for', '90 days, then deleted automatically'),
    ('Build progress', '89 of 93 steps'),
    ('SUS benchmarks', '68 = average, above 80 = good'),
    ('UAT participants', '5 drivers + 5 commuters'),
    ('Budget alert', 'PHP 500 per month'),
    ('App version', '1.0.5 (6), Android and trikekoto.web.app'),
    ('Tech stack', 'Flutter + Firebase; OpenStreetMap, OSRM, Nominatim'),
]


def answer_flowable(ans):
    if isinstance(ans, str):
        return [Paragraph(ans, ss['a'])]
    lead, *points = ans
    out = []
    if lead:
        out.append(Paragraph(lead, ss['a']))
    out.append(ListFlowable(
        [ListItem(Paragraph(p, ss['a']), leftIndent=14) for p in points],
        bulletType='bullet', start='•', leftIndent=14, bulletFontSize=9, bulletColor=AMBER))
    return out


def qa_block(n, q, ans):
    inner = [Paragraph(f'<font color="#B7780A">Q{n}.</font>&nbsp; {q}', ss['q'])] + answer_flowable(ans)
    t = Table([[inner]], colWidths=[7.0 * inch])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), LIGHT),
        ('LEFTPADDING', (0, 0), (-1, -1), 10), ('RIGHTPADDING', (0, 0), (-1, -1), 10),
        ('TOPPADDING', (0, 0), (-1, -1), 7), ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
    ]))
    # A one-cell table already never splits; wrapping it in KeepTogether as
    # well, then nesting that in another, pushed every section to a new page.
    return t


def lines(count):
    t = Table([[''] for _ in range(count)], colWidths=[7.0 * inch], rowHeights=[0.3 * inch] * count)
    t.setStyle(TableStyle([('LINEBELOW', (0, 0), (-1, -1), 0.5, LINE)]))
    return t


def footer(canvas, doc):
    canvas.saveState()
    canvas.setFont('Helvetica', 8.5)
    canvas.setFillColor(MUTED)
    canvas.drawString(0.75 * inch, 0.5 * inch, 'TrikeKoTo - Proposal Defense Reviewer')
    canvas.drawRightString(LETTER[0] - 0.75 * inch, 0.5 * inch, f'Page {doc.page}')
    canvas.restoreState()


def build():
    doc = SimpleDocTemplate(str(OUT), pagesize=LETTER, leftMargin=0.75 * inch, rightMargin=0.75 * inch,
                            topMargin=0.7 * inch, bottomMargin=0.8 * inch,
                            title='TrikeKoTo - Proposal Defense Reviewer', author='Jelo Jian Sabroso')
    story = [
        Paragraph('Proposal Defense Reviewer', ss['title']),
        Spacer(1, 4),
        Paragraph('TrikeKoTo: A Tricycle Ride-Hailing and Dispatch System for TODA Chapters', ss['sub']),
        Paragraph('Jelo Jian Sabroso &nbsp;|&nbsp; PRMSU - San Marcelino &nbsp;|&nbsp; September 2026', ss['sub']),
        Spacer(1, 10),
        Paragraph('How to use: read each question, answer it aloud in your own words, then check against the answer. '
                  'Don\'t memorise word for word; panels notice.', ss['note']),
        Spacer(1, 4),
    ]

    n = 0
    for title, items in SECTIONS:
        for i, (q, a) in enumerate(items):
            n += 1
            block = qa_block(n, q, a)
            # A section heading never sits alone at the foot of a page.
            if i == 0:
                story.append(KeepTogether([Paragraph(title, ss['section']), block]))
            else:
                story.append(block)
            story.append(Spacer(1, 7))

    story.append(PageBreak())
    story.append(Paragraph('Numbers to know by heart', ss['section']))
    rows = [[Paragraph(k, ss['cellb']), Paragraph(v, ss['cell'])] for k, v in FACTS]
    ft = Table(rows, colWidths=[2.6 * inch, 4.4 * inch])
    ft.setStyle(TableStyle([
        ('ROWBACKGROUNDS', (0, 0), (-1, -1), [colors.white, LIGHT]),
        ('LINEBELOW', (0, 0), (-1, -1), 0.4, LINE),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 3), ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
    ]))
    story.append(ft)

    story.append(Paragraph('If you get stuck', ss['section']))
    stuck = [
        ('You don\'t know', '"Thank you, that\'s a good point. I\'ll look into it and include it in the revision."'),
        ('You disagree', '"I understand the concern. Our reasoning was... but we\'re open to adjusting."'),
        ('The question is unclear', '"May I clarify: are you asking about...?"'),
    ]
    st = Table([[Paragraph(k, ss['cellb']), Paragraph(v, ss['cell'])] for k, v in stuck],
               colWidths=[1.9 * inch, 5.1 * inch])
    st.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), LIGHT), ('LINEBELOW', (0, 0), (-1, -2), 0.4, LINE),
        ('TOPPADDING', (0, 0), (-1, -1), 6), ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('LEFTPADDING', (0, 0), (-1, -1), 8), ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
    ]))
    story.append(st)

    story.append(Paragraph('Prepare these yourself', ss['section']))
    story.append(Paragraph('Only you know these answers. Write them down before the defense.', ss['note']))
    story.append(Spacer(1, 6))
    story.append(KeepTogether([
        Paragraph('Related studies: 2-3 from your review of related literature, and how TrikeKoTo differs', ss['q']),
        lines(4)]))
    story.append(Spacer(1, 8))
    story.append(KeepTogether([Paragraph('Why you chose this topic', ss['q']), lines(3)]))

    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    print(f'wrote {OUT.relative_to(ROOT)} ({n} questions)')


if __name__ == '__main__':
    build()
