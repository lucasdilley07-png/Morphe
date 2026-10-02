# MORPHE — the Spartan record (researched 2026-10-01)

Companion to `BRAND-SPARTAN.md`. That doc is the identity; this one is the
evidence under it. Researched live on 2026-10-01 against primary texts and
current scholarship. Rule for everything below: **if it has no ancient
citation, it does not ship as a quote.** The app holds itself to the same
law for lore as for logs.

Every quote and citation here was then put through an independent
fact-check against the primary texts (audit 29, same day). It found five
errors and eighteen loose renderings in the first draft; all are corrected
below and in the app. The corrections are logged in §8 so the same
mistakes are not reintroduced from popular sources.

Re-sweep the trademark and reception sections before any App Store or
pitch use; they are the parts that go stale.

---

## 1. What is shipped in the app (2026-10-01 wave)

| Surface | What it does | Source it stands on |
|---|---|---|
| **The Code** sheet (Learn tab → "From the record" card; Profile → rank row) | Today's saying in serif, the agoge ladder with the user's rung lit, seven short reads, all eight sayings, and "What Morphe leaves behind" | every block carries its citation |
| **Saying of the day** | One line a day, picked by day number, same for everyone, never reshuffled | 8 verified sayings (§3) |
| **Agoge rank** on the level card + level-up banner | Levels 1–10 Pais, 11–19 Paidiskos, 20–29 Hēbōn, 30+ Homoios | stages: Xenophon, *Lac. Pol.* 2–4; ages: modern reconstruction |
| **Laconic** communication style | "Direct" renamed (same id, no migration). The register now lives in the style, so "Encouraging" is honored | — |
| **AI lore guardrail** (Claude prompt) | Short law on every turn (never quote from memory, never invent or "adapt", never glorify helotry, never "molon labe"); the 8 cited sayings are sent only on a turn that asks for lore | §3, §6 |
| **Built-in brain** | "Who is Talos", "who are you", "my rank", "a Spartan saying" answer from the record with no API key | §2, §3 |
| **Comeback card** | One line: Sparta withheld its honors from the reckless return | Herodotus 9.71 |
| **Bibasis** exercise + **The Thousand** badge | The Spartan counted jump in the library; badge at 1,000 lifetime logged reps | Pollux 4.102; Aristophanes, *Lysistrata* 82 |
| **Four lore quizzes** | Mantinea pipes, "add a step", Talos' circuits, Aristodemus | Thuc. 5.70; Plut.; Apollod. 1.9.26; Hdt. 9.71 |
| **Rebrand backlog** | Dedicated launch splash; Gold→Spartan Blue migration carried in the profile snapshot (`paletteEpoch`); watch icon; contrast fixes across every palette | audit 28 + 29 |

Code: `SpartanLore`, `AgogeRank`, `LaconicSaying` in `Core/MorpheModels.swift`;
`SpartanCodeSheet` in `MoreView.swift`; tests in `SpartanLoreTests`.

---

## 2. Talos — the guardian

- A man of bronze who guarded Crete. Both Apollodorus and Apollonius have
  him go round the island **three times every day**; a **single vein** ran
  from neck to ankle, closed by a **bronze nail** (Apollodorus). Apollonius:
  he threw rocks at the Argo; Medea brought him down and the ichor ran out
  "like melted lead".
  (Apollonius, *Argonautica* 4.1638–88; Apollodorus, *Library* 1.9.26.)
- Makers vary: given by Hephaestus to Minos (Apollodorus), or by Zeus to
  Europa (Apollonius), or the last of the bronze race. The *Minos*
  attributed to Plato (320c) has him carrying the laws on bronze tablets
  round the villages three times a year: the guardian as keeper of the
  record.
- Coins of Phaistos (4th to early 3rd century BC) show him winged,
  throwing a stone.
- Apollonius and Apollodorus call him a man of bronze, not a giant. Only
  the late *Orphic Argonautica* (line 1351) calls him a "bronze
  triple-giant". The towering colossus is the 1963 film.
- Adrienne Mayor (*Gods and Robots*, Princeton 2018) reads him as the
  ancient imagination of a made, programmed guardian.

**Product reading.** Three circuits a day maps onto what the app already
does: morning plan, the session, the evening check-in. One vein = one
source of truth (the logs). The nail = the single thing that kills it:
an invented number.

**Correction to our own pitch.** `BRAND-SPARTAN.md` said "the first machine
ever imagined". Homer's self-moving tripods, golden attendants (*Iliad* 18)
and the gold-and-silver guard dogs of Alcinous (*Odyssey* 7.91–94) are
older on the page. Fixed to "one of the first machine guardians ever
imagined". Say it that way in the pitch too.

---

## 3. The sayings (verified, shipped)

All eight are verbatim from public-domain Loeb translations (Babbitt for
the *Sayings*, Helmbold for *On Talkativeness*, Perrin for the
*Lycurgus*). Do not reword one to make it punchier.

| Saying | Speaker / situation | Source |
|---|---|---|
| "If." | The Spartans, to Philip of Macedon's letter: "If I invade Laconia, I shall turn you out." | Plutarch, *On Talkativeness* 17 (511A) |
| "Add a step to it." | A mother, to a son who said his sword was short | Plutarch, *Sayings of Spartan Women* 18 |
| "Won't it be nice, then, if we shall have shade in which to fight them?" | Leonidas, told the Persian arrows would hide the sun. Herodotus gives the reply to Dienekes, in reported speech (7.226) | Plutarch, *Sayings of Spartans*, Leonidas 6 |
| "These they put on for their own sake, but the shield for the common good of the whole line." | Demaratus, on why a lost shield disgraces and a lost helmet does not | Plutarch, *Sayings of Spartans*, Demaratus 2 |
| "The Spartans did not ask 'how many are the enemy,' but 'where are they?'" | Agis II (son of Archidamus), as Plutarch reports it | Plutarch, *Sayings of Spartans*, Agis son of Archidamus 3 |
| "At every step, my child, remember your valour." | A mother, to her lame son, walking with him to the battlefield | Plutarch, *Sayings of Spartan Women* 13 |
| "A city will be well fortified which is surrounded by brave men and not by bricks." | Lycurgus, asked by letter about fortifying the city (Plutarch doubts the letters) | Plutarch, *Lycurgus* 19 |
| "Either this or upon this." | A mother, handing over the shield | Plutarch, *Sayings of Spartan Women* 16 |

Honesty notes: Plutarch wrote around AD 100, five centuries after the
events; these are the tradition, not transcripts. The famous "Then we
shall fight in the shade" is a later direct-speech adaptation that matches
no standard translation, so the app uses Babbitt's actual line.

**Held back on purpose**

- **"Molon labe" / "Come and take them"** (Plutarch, *Sayings of
  Spartans*, Leonidas 11). Real,
  but in the US it is now a gun-rights and far-right slogan, usually printed
  under a Corinthian helmet (see §6). Not in the app, not in the pitch.
- Gorgo's "we are the only women that are mothers of men" (Plutarch,
  *Sayings of Spartan Women*, Gorgo 5): verified, strong, kept for content
  about Spartan women (§5) rather than the daily rotation.
- Simonides' epitaph, "Go tell the Spartans…" (Herodotus 7.228): verified;
  it is about the dead, so it does not belong on a training screen.
- Tyrtaeus (fr. 10–12 West: stand fast, feet set apart). Real and on
  theme, but needs a translation we have rights to. Not shipped.

---

## 4. The agoge and the ladder

- Three stages, named by Xenophon without ages (boys, youths, those in
  their prime). Plutarch gives entry at seven and an *eirēn* of twenty.
  The usual modern bands: **paides** ~7–14, **paidiskoi** ~15–19,
  **hēbōntes** 20–29 (some scholars: 7–12 / 12–20 / 20–30). Election to a
  mess came at about 20; the remaining restrictions lifted at 30, full
  standing among the **homoioi** ("Equals").
- Packs (*agelai*) led by an *eirēn*; overseen by the *paidonomos*, a
  citizen magistrate, where other cities used slaves as tutors (Xenophon).
- One cloak a year, barefoot, short rations. Also taught: reading, music,
  choral dance, and brevity itself.
- Entry to a mess (*syssition*) of about fifteen needed a unanimous vote by
  bread ball: one flattened ball and you were out. Each member owed a fixed
  monthly share of barley, wine, cheese and figs (Plutarch, *Lycurgus* 12).
- The 300 *hippeis*: the ephors pick three men, each enrols a hundred and
  states his reasons, and the rejected watch them for any lapse (Xenophon,
  *Lac. Pol.* 4.3–4). "Yearly" is a modern inference, not in the text.
- Source warning: Xenophon is a 4th-century admirer; Plutarch describes a
  Roman-era revival that differed from the classical system.

**Mapping.** App levels use the reconstruction's upper bounds (Hēbōn at 20,
Equal at 30), and the app says so on the ladder itself. Greek titles are grammatically masculine; the app shows them with a
plain gloss, and the record itself has Spartan girls training (§5).

---

## 5. The rest of the record (idea bank, not built)

Each is a real artifact to build from later. Nothing here is shipped.

- **Bibasis as a Form Check mode.** The camera already counts reps. A
  counted "attempt on the Thousand" is the ancient contest exactly.
- **The mess (syssitia).** Train Together parties capped at 15, each member
  owing a monthly share of sessions; a new member needs every vote.
- **The Three Hundred.** A picked cohort from the board, reasons shown,
  the rest free to challenge. Xenophon's rivalry mechanic.
- **Dioscuri.** Castor and Polydeuces, Sparta's twin patrons; their sign,
  the *dokana*, is two uprights joined by crossbeams. It looks like a rack.
  A natural mark for a training pair.
- **Karneia.** The *staphylodromoi* ("grape-runners") chase one garlanded
  runner; catching him is good luck for the city. A chase challenge: one
  person sets the mark, the party runs it down.
- **Gymnopaedia.** The midsummer endurance festival, danced in the heat. A
  July challenge drop.
- **Hyakinthia.** Day one mourning, plain food; day two celebration. The
  shape of "loss card, then the next win".
- **Combing their hair** (Herodotus 7.208–209). The pre-effort routine as
  ritual: a warm-up screen with a reason.
- **The temple of Fear** (Plutarch, *Cleomenes* 9). Copy for the moment
  before a PR attempt.
- **Women of Sparta.** State physical training for girls: races and trials
  of strength (Xenophon, *Lac. Pol.* 1.4); running, wrestling, discus and
  javelin (Plutarch, *Lycurgus* 14).
  Cynisca, first woman to win at Olympia (four-horse chariot, 396 and 392
  BC), with her own inscription.
- **The scytale** (Plutarch, *Lysander* 19). Two matching staffs, one
  message. A name for coach→client claim codes.
- **Crimson.** Sparta's actual colour was the crimson cloak. A single
  earned crimson accent at level 30 would be the cloak itself.
- **The Battle of the Champions** (Herodotus 1.82). 300 against 300; the
  one man still on the field held it. A last-one-standing challenge.

---

## 6. Where the popular picture is wrong (and the brand risks)

**History**

- **Blue and white is not Spartan.** Sparta's colour was crimson. Blue and
  white is modern Greece. Fine as a design choice; never claim otherwise.
- **The lambda shield** rests on one line of a lost comedy by Eupolis
  (late 5th century). Votive figurines show individual blazons. Nothing
  places it at Thermopylae.
- **The Corinthian helmet** (our mark) is the Archaic Greek helmet in
  general, not uniquely Spartan, and was giving way to the open *pilos* by
  the later 5th century. "From the ancient form" is accurate; "what
  Leonidas wore" is not something we should say.
- **The Spartan mirage** (Ollier, 1933): almost everything is written by
  outsiders, much of it centuries late. No Spartan prose account
  survives (the poets Tyrtaeus and Alcman do).
- **Helots.** A citizen minority lived off an enslaved majority, policed by
  the *krypteia* (Thucydides 4.80; Plutarch, *Lycurgus* 28). The app says
  this in plain words in "What Morphe leaves behind". That section is the
  brand's honesty applied to its own myth; do not cut it.

**Reception risk (US)**

- The stylized Corinthian helmet over "molon labe" is established
  gun-rights and far-right iconography (documented by Pharos at Vassar at
  2017 rallies; "molon labe" flags and Greek-helmet costumes were both at
  the Capitol on 2021-01-06). Our helmet in white and blue,
  with no slogan, sits well away from that. Keep it there: no "molon labe",
  no crimson-and-black helmet treatments, no "warrior" militarism in ads.

**Trademark risk (not legal advice; check before launch)**

- **Spartan Race, Inc.** holds SPARTAN registrations across fitness and
  apparel and opposes Spartan-formative marks at the USPTO routinely: 66
  TTAB proceedings on record (Spartan Zero Six was opposed in 2018 and its
  owner renamed the apparel line). The exact class coverage of the plain
  SPARTAN registrations was not verified here; that is the lawyer's job. Morphe keeping
  its own name is the right call. Keep "Spartan" out of the App Store
  **title, subtitle and keyword field**, and never present "Spartan" as a
  product or program name. Descriptive use in body copy and the palette
  name "Spartan Blue" is a much smaller exposure, but a trademark lawyer
  should clear the App Store listing before submission.

---

## 7. Open calls for Lucas

- **The pitch clause "a single law older than Sparta itself"**
  (`BRAND-SPARTAN.md`). It is rhetoric with no source; under "nothing
  invented" it reads as a historical claim. Keep, or cut the clause.
- **The small-size mark.** Every in-app mark is now the glass-box helmet
  image. At 20–24pt (the AI button) the helmet is about 9pt tall and may
  read as a blue tile. A simplified small-size mark is a design decision.
- **The brand kit** (`Tools/make_brand_assets.swift`, `docs/brand-kit`) is
  still the gold M. Regenerating it needs the new mark as a vector.
- **Bibasis has no form diagram** (the card is hidden for it). One image
  through the media-gen pipeline, about $0.15.
- **App Store screenshots and metadata** still show the gold app.

## 8. Corrections log (audit 29)

Errors in the first draft, all from trusting popular renderings:

- "If." was credited to "the ephors" answering a threat to "raze Sparta".
  Plutarch says "they" (the Spartans) and "turn you out".
- The lame-son line was given a wound and a sense of shame. Saying 13 has
  neither; those are sayings 14–15 and a Roman parallel.
- "Then we shall fight in the shade" was presented as Herodotus' wording.
  It matches no standard translation.
- "Not how many but where" and the "wall of men" line were paraphrases
  presented as quotes.
- Aristodemus: Herodotus 9.71 says nothing about a "steady return". Sparta
  withheld honors from a man who broke rank wanting to die, and Herodotus
  disagreed with the verdict.
- "No ancient source calls Talos a giant" is false for the Orphic
  *Argonautica*.
- Xenophon was credited with Spartan girls' wrestling; that is Plutarch.
- Our own doc called Talos "the oldest machine-guardian story ever told".

## 9. Sources

Primary texts
- Herodotus, *Histories* 1.82, 7.208–209, 7.226, 7.228–231, 9.71 — https://cts.perseids.org/read/greekLit/tlg0016/tlg001/perseus-eng2/7.230.1-7.233.1
- Thucydides 4.80, 5.70 — https://livius.org/sources/content/thucydides-historian/the-battle-of-mantinea-418-bce
- Plutarch, *Sayings of Spartans* — https://penelope.uchicago.edu/Thayer/E/Roman/Texts/Plutarch/Moralia/Sayings_of_Spartans*/main.html
- Plutarch, *Sayings of Spartan Women* — https://penelope.uchicago.edu/Thayer/E/Roman/Texts/Plutarch/Moralia/Sayings_of_Spartan_Women*.html
- Plutarch, *On Talkativeness* — https://penelope.uchicago.edu/Thayer/E/Roman/Texts/Plutarch/Moralia/De_garrulitate*.html
- Plutarch, *Lycurgus* (Perrin) — https://penelope.uchicago.edu/Thayer/E/Roman/Texts/Plutarch/Lives/Lycurgus*.html
- Herodotus 9.71 — http://www.perseus.tufts.edu/hopper/text?doc=Perseus:text:1999.01.0126:book=9:chapter=71
- Pollux 4.102 (via Sider 2021) — https://edizionicafoscari.unive.it/media/pdf/books/978-88-6969-549-0/978-88-6969-549-0-ch-06.pdf
- Talos sources — https://mythopedia.com/topics/talos/
- Plutarch, *Lycurgus* 12, 16–19, 28 — https://cts.perseids.org/read/greekLit/tlg0007/tlg004/perseus-eng2/12.1-12.4
- Plutarch, *Cleomenes* 8–9 — https://cts.perseids.org/read/greekLit/tlg0007/tlg051/perseus-eng1/Cleomenes.9.1-Cleomenes.9.2
- Plutarch, *Lysander* 19 (scytale) — https://cts.perseids.org/read/greekLit/tlg0007/tlg032/perseus-eng2/19.6-20.4
- Xenophon, *Constitution of the Lacedaemonians* 1–4
- Apollonius, *Argonautica* 4.1638–88; Apollodorus, *Library* 1.9.26; Pollux, *Onomasticon* 4.102

Reference and scholarship
- Agoge — https://en.wikipedia.org/wiki/Agoge
- Laconic phrase — https://en.wikipedia.org/wiki/Laconic_phrase
- Talos — https://en.wikipedia.org/wiki/Talos
- Bibasis — https://en.wikipedia.org/wiki/Bibasis_(dance)
- Syssitia — https://en.wikipedia.org/wiki/Syssitia
- Hippeis — https://en.wikipedia.org/wiki/Hippeis
- Battle of the 300 Champions — https://en.wikipedia.org/wiki/Battle_of_the_300_Champions
- Cynisca — https://en.wikipedia.org/wiki/Cynisca · Women in ancient Sparta — https://en.wikipedia.org/wiki/Women_in_ancient_Sparta
- Castor and Pollux (dokana) — https://en.wikipedia.org/wiki/Castor_and_Pollux
- Hyacinthia — https://en.wikipedia.org/wiki/Hyacinthia · Karneia grape-runners — https://nunc.ch/en/grapes-on-his-heels/
- Sanctuary of Artemis Orthia — https://en.wikipedia.org/wiki/Sanctuary_of_Artemis_Orthia
- Phobos — https://en.wikipedia.org/wiki/Phobos_(mythology)
- Lambda shields — https://talesoftimesforgotten.com/2021/11/24/did-spartan-shields-really-bear-the-letter-lambda/
- Spartan music (Bad Ancient) — https://www.badancient.com/claims/spartans-music/
- The scytale — https://antigonejournal.com/2021/06/deciphering-spartan-scytale/
- Laconophilia / the Spartan mirage — https://en.wikipedia.org/wiki/Laconophilia
- Devereaux, "This. Isn't. Sparta." — https://acoup.blog/2022/08/19/collections-this-isnt-sparta-retrospective/comment-page-1/
- Mayor, *Gods and Robots* — https://classics.stanford.edu/publications/gods-and-robots-myths-machines-and-ancient-dreams-technology
- Talos and AI (Smithsonian) — https://www.smithsonianmag.com/history/was-talos-the-bronze-automaton-who-guarded-the-island-of-crete-in-greek-myth-an-early-example-of-artificial-intelligence-180986467/

Reception and trademark
- Pharos, "Scholars respond to Spartan helmets" — https://pharos.vassarspaces.net/2017/11/17/scholars-respond-to-spartan-helmets/
- Molon labe — https://en.wikipedia.org/wiki/Molon_labe
- Spartan Race v. Spartan Zero Six — https://www.audacy.com/connectingvets/articles/spartan-zero-six-trademark-dispute-spartan-race-causes-rebranding
- Spartan Race trademark strategy (WTR) — https://worldtrademarkreview.com/brand-management/how-the-spartan-race-brand-fights-back-against-trademark-norms-exclusive
- TTAB proceedings, Spartan Race, Inc. — https://ttabvue.uspto.gov/ttabvue/v?pnam=Spartan+Race%2C+Inc.++
