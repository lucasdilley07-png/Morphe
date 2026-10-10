# Audit: food trackers and nutrition platforms — what Morphe's fuel log borrows

Researched live 2026-10-10 (app comparison rankings with DAI/Foodvision
accuracy benchmarks, the NIH photo-app study coverage, Open Food Facts and
USDA FoodData Central documentation, FoodNoms/Lifesum/MyFitnessPal
changelogs). Purpose: rebuild "Today's Fuel" as a real food log — search
and camera first, no canned quick-adds — without giving up the honesty
rule. Sources at the end.

---

## 1. The field, in one table

| App | Database | Logging methods | Serving entry | Diary | Accuracy (MAPE, DAI study) | Price |
|---|---|---|---|---|---|---|
| **MyFitnessPal** | Largest raw catalog (20M+, mostly user-submitted) | search, barcode (Premium), photo/voice/text AI | pick from DB entries | meal sections, macro ring, web client | **11.2 %** — worst of the five; "duplicate user entries require judgement on every search" | free / $79.99 yr |
| **Cronometer** | Lab-verified: USDA, NCCDB; 84–95 nutrients | search, barcode (free), voice, photo (Gold) | precise, weighing encouraged | text-dense, slower | **6.8 %** | free w/ ads / $59.88 yr |
| **MacroFactor** | curated; nutrition-label scan, recipe import | barcode, label scan, photo/text description | gram/serving, adaptive targets from scale weight | dense, for experienced trackers | **4.8 %** — best manual app | $71.99 yr, no free tier |
| **Lose It!** | thin micronutrients | search, barcode, voice, photo (Premium) | calorie budget, Small/Normal/Large portions | friendliest; "first meal in under five minutes" | ~9–10 % | free / $39.99 yr |
| **Cal AI / PlateLens / Foodvisor** | photo-first; PlateLens claims USDA+NCCDB, 1.2M entries | photo, text, barcode, voice | estimated from the photo, editable | single diary | PlateLens claims 1.1 % on its own bench; NIH kitchen test of Cal AI and others: **calories under-estimated by 250–345 kcal/meal, fat by ~30 g** | free-metered / ~$35 yr |
| **Yazio / Lifesum / FatSecret / Fitia** | mixed | search, barcode, recipes, meal plans | portion presets | plans + diary | not benchmarked | free tiers |

What the numbers say: the **database decides accuracy more than the UI**.
Verified sources (USDA, NCCDB) beat crowd-sourced catalogs by 2×; photo
estimation is the fastest input and the least accurate — peer-reviewed
2024–25 work puts food identification at 68–86 % and portion estimation as
low as 39 %, and the NIH kitchen test found the photo apps missed a third
of the calories on mixed plates and did worst on high-fat meals.

## 2. UX patterns that won (and what they cost)

1. **Search is the front door; recents/frequents are the fast lane.**
   Every app opens the add flow on a search field with "Recent" and
   "Frequent" rows above results; MacroFactor and Cronometer get most logs
   from recents after week two.
2. **Multiple capture methods, one sheet.** Photo · barcode · label scan ·
   search · voice · manual, chosen per meal, never forced.
3. **Portion input is the hardest screen.** FoodNoms redesigned it twice:
   grams or a listed serving, a "+" to stack amounts, a history of the
   portions you used before. Lose It! ships Small/Normal/Large/"Too much!"
   for first-timers.
4. **Meal sections** (Breakfast/Lunch/Dinner/Snack) with one tap to switch
   the type on the log screen; "copy yesterday" and "copy to another date"
   are the most-requested shortcuts.
5. **The day screen shows macros against targets**, not just calories —
   a ring or bars for calories, protein, carbs, fat; water separate.
6. **Photo results are presented as a draft**, editable before saving;
   the honest apps label them "estimate". The empty state is the hardest
   screen in AI logging — a camera that can't name the plate must say so.
7. **Free tiers are gating the inputs** (barcode behind MFP Premium, photo
   behind Cronometer Gold, 3 photos/day on PlateLens). Nobody ships an
   unmetered, honest photo path — because the model costs them per call.

## 3. What Morphe does with it

- **Food library**: a bundled, curated **USDA SR Legacy** set (1,195
  common whole foods, per 100 g, public domain CC0) for instant offline
  search — the verified-source choice, not the crowd catalog — plus
  **Open Food Facts** text search for packaged/branded products (free, no
  key, the same database the barcode check uses), plus the user's own
  **recents** on top. Every result shows its source.
- **One add sheet**: search field · Recents · results from both sources ·
  tap → portion (grams stepper + quick chips + the serving the product
  lists) → meal type → Add. Manual entry stays as the honest fallback
  ("Can't find it? Enter the label yourself").
- **Camera**: the plate goes to Claude **with the user's own key**; the
  result is a **draft labelled estimate** with the NIH caveat built into
  the copy ("photo estimates tend to run low on mixed and fatty plates —
  adjust the portion"), editable before it lands in the log, and the full
  origin/processing report is one tap away. Without a key the camera says
  so and opens search instead. No per-call metering — the user pays
  their own provider.
- **Day card**: calories, protein, carbs, fat against the plan from the
  nutrition chart (the three splits), water separate, meal sections,
  remove in one tap. No canned "quick add" chips — those are invented
  meals, which is exactly what the sourcing law forbids.
- **Memory**: everything logged feeds the same 14-day food memory the AI
  already reads, so "what did I eat this week" answers from the log.

## Sources (retrieved 2026-10-10)

- clinicalnutritionreport.com — Best calorie counter apps 2026 (DAI MAPE
  figures, pricing, logging methods per app)
- fitia.app — best daily calorie tracking apps 2026; AI photo app accuracy
  2026 (68–86 % identification, 39 % portion)
- HealthDay / Powers Health — "How accurate are photo-based calorie apps?
  4 are put to the test" (NIH metabolic-kitchen study: MyFitnessPal, Lose
  It!, Cal AI, Appediet; 100+ meals; −250 to −345 kcal, −30 g fat)
- foodnoms.com — portion input redesign, library tab, copy to date
- Lifesum help center — food tracking articles (meal type switching)
- USDA FoodData Central — download datasets (SR Legacy CSV, CC0)
- Open Food Facts — v2 product API and cgi/search.pl text search (verified
  live with "greek yogurt": 6,071 hits, nutriments per 100 g, serving_size)
