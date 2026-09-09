# Filipino copy — review sheet

Every user-facing Filipino string in the app, grouped by the screen it
appears on. Extracted from source, so this is what people actually see —
not a translation file that has drifted from the build.

**How to use this.** Read one screen at a time and mark anything wrong,
unnatural, or that a tricycle driver in San Marcelino would not say.
Wording that is *correct but bookish* is worth flagging too: nearly all of
it is read on a phone, in a hurry, by someone who is not a student.

The open questions at the end are ones the author cannot answer.

---

## Landing

- [ ] Kailangan ng number para makapag-book.

## Rider sign-in

- [ ] Ano ang number mo?
- [ ] Padadalhan ka namin ng code para makumpirma.
- [ ] Hindi ito ipapakita sa driver hangga't hindi ka nagbo-book.
- [ ] Ilagay ang code
- [ ] Anim na numero, ipinadala sa [number].
- [ ] Kumpirmahin

## Rider onboarding

- [ ] Litrato — puwedeng laktawan
- [ ] Anong itatawag namin sa iyo?
- [ ] Ito ang makikita ng driver kapag sinundo ka.
- [ ] Pangalan
- [ ] [number] — nakumpirma na
- [ ] Simulan

## Rider profile

- [ ] Na-save ang profile mo.
- [ ] Na-save ang pangalan, pero hindi ang litrato. [error]
- [ ] Burahin ang account mo?
- [ ] Mabubura nang tuluyan:
- [ ] • Ang pangalan at litrato mo ⏎
- [ ] • Ang ID mo, kung nagpadala ka ⏎
- [ ] • Ang mga naka-save na lugar ⏎
- [ ] • Ang account mo — kakailanganin mong magparehistro ulit
- [ ] Ang mga naunang biyahe ay mananatili bilang record ng
- [ ] TODA — pero tatanggalin dito ang pangalan at number mo,
- [ ] kaya hindi na ito maiuugnay sa iyo.
- [ ] Hindi na ito maibabalik.
- [ ] Hindi
- [ ] Burahin ang account
- [ ] Para sa seguridad, mag-sign in muli bago burahin ang account.
- [ ] Hindi mabuksan ang profile
- [ ] Tingnan ang signal mo, tapos subukang muli.
- [ ] Walang profile
- [ ] Mag-sign in muli para makagawa ng account.
- [ ] Ise-save ang litrato pagpindot mo ng Save
- [ ] Pindutin ang litrato para palitan
- [ ] Pangalan
- [ ] Ito ang makikita ng driver
- [ ] [number] — nakumpirma na

## Commuter booking

- [ ] Kasalukuyang lokasyon
- [ ] Salamat sa rating!
- [ ] Hinahanap ang lokasyon mo…

## Location picker

- [ ] Walang nakitang "[hinanap]" malapit dito. Kung malayo ito, i-drag
- [ ] muna ang mapa papunta roon — o ilagay ang pin nang manu-mano.
- [ ] Hinahanap…
- [ ] I-drag ang mapa para ilagay ang pin — o hanapin sa
- [ ] itaas, o gamitin ang lokasyon mo.

## Photo picker

- [ ] Kumuha ng litrato
- [ ] Pumili sa gallery
- [ ] Alisin ang litrato

## ID verification

- [ ] Kunan ng litrato ang ID
- [ ] Pumili sa gallery
- [ ] Kailangan ng litrato ng ID.
- [ ] Kailangan mong pumayag muna.
- [ ] Naipadala na. Hihintayin ang review.
- [ ] Bawiin ang ID?
- [ ] Buburahin ang litrato at ang detalye ng ID mo. Puwede kang
- [ ] Hindi
- [ ] Burahin
- [ ] Nabura na ang ID mo.
- [ ] Beripikado na
- [ ] Nakumpirma ng chapter ang ID mo.
- [ ] Hindi tinanggap
- [ ] Walang ibinigay na dahilan.
- [ ] Hinihintay ang review
- [ ] Ipinadala na ang ID mo. Aabisuhan ka dito pagkatapos.
- [ ] Uri ng ID
- [ ] Bawiin at burahin ang ID
- [ ] Buburahin nito ang litrato at ang detalye, kahit na-aprubahan na.
- [ ] Kumpirmahin ang pagkakakilanlan
- [ ] Kailangan ito ng TODA chapter bago ka makatanggap ng biyahe.
- [ ] Nakakatulong ito para ligtas ang lahat sa biyahe.
- [ ] Numero ng ID
- [ ] Ipadala para sa review
- [ ] Litrato ng ID
- [ ] Siguraduhing mabasa ang pangalan at numero
- [ ] Paano gagamitin ang ID mo
- [ ] • Titingnan lang ito ng opisyal ng TODA chapter para kumpirmahin
- [ ] kung sino ka. ⏎
- [ ] • Hindi ito makikita ng ibang pasahero o ng driver mo. ⏎
- [ ] • Buburahin ito 90 araw matapos ang review, o kaagad kapag
- [ ] binawi mo. ⏎
- [ ] • Puwede mong burahin anumang oras dito sa screen na ito.
- [ ] Pumapayag ako na iproseso ang ID ko para sa pagkumpirma.

## ID review (admin)

- [ ] Hindi mabuksan ang queue
- [ ] Walang naghihintay
- [ ] Lilitaw dito ang mga bagong ID na ipinadala.
- [ ] Hindi tinanggap.
- [ ] Bakit hindi tinanggap?
- [ ] Hal. Malabo ang litrato, hindi mabasa ang numero.
- [ ] Ipadala
- [ ] Tingnan ang ID
- [ ] Hindi tanggap
- [ ] Aprubahan

## Driver dashboard

- [ ] Ipadala ang lisensya o ID para sa chapter

---

**93 strings across 14 screens.**

## Open questions

These are decisions, not typos. They run across the whole app, so answering
them once fixes many strings at a time — worth settling before line-by-line
edits.

**1 · Three words are doing the job of "remove".** Deliberate or muddled?

| Word | Used for |
|---|---|
| `Alisin` | taking the profile photo off |
| `Bawiin` | withdrawing a submitted ID |
| `Burahin` | deleting the account, and deleting an ID |

The distinction was intended — *withdraw* consent versus *erase* data — and
one screen even uses both together (*"Bawiin at burahin ang ID"*). But three
words for one gesture may just read as inconsistency to someone using the app
rather than reading the source. If two of them should collapse, say which.

**2 · English and Filipino are mixed on the same screens.** Buttons like
*Sign in*, *Send code*, *Save*, *Dashboard* and every screen title sit beside
Filipino body text. Is that natural here — the way people actually speak — or
does it read as unfinished? A consistent rule matters more than which way it
goes.

**3 · Formality.** Everything uses **mo / ka**, never **po** or **ninyo**.
For an app a passenger uses alone that is probably right. For a driver being
told their account is suspended by a chapter officer, it may be too familiar.
Should any screen be more formal?

**4 · Loanwords.** *book*, *code*, *driver*, *profile*, *ID* are kept in
English because they are what people say. *Biyahe*, *litrato*, *lokasyon* are
translated. Is that line drawn in the right place?

**5 · The one that matters most.** Would a **tricycle driver in his fifties**
understand every string on the driver dashboard on first reading, without
asking anyone? Not "is it correct Filipino" — is it *his* Filipino. Anything
that needs a second read should be flagged, even if nothing is wrong with it.

---

## Notes for whoever applies the edits

- Strings live in the Dart source, not a translation file. Search for the
  exact text; each appears once.
- Two entries above are truncated by an escaped apostrophe in the source
  (`hangga\'t`). The full lines read *"Hindi ito ipapakita sa driver hangga't
  hindi ka nagbo-book"*.
- Entries containing `$phone` or `${_phone.text}` interpolate a value at
  runtime — keep the placeholder, change the words around it.
- `⏎` marks a line break inside one string.
- The three end-user guides in `docs/` are separate and also need reading.
